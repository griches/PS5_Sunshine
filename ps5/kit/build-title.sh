#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - the builder kit: make the title on your own machine.
#
#   build-title.sh [OUT]            OUT/PPSA99312/ (OUT defaults to ./out)
#   build-title.sh --tools          only build the kit's host tools (the container's image does)
#
# The kit is a build of the port without the game's own code. This script
# fetches the two public source trees that code is compiled from (the PC port,
# chasem-dev/sms-pc-port, and the decompilation it builds, chasem-dev/sms-english,
# both at the revisions SOURCES.txt names), applies the console's patch,
# compiles the game's code with the kit's SDK and links it with the kit's
# objects, by the recipe the kit was tested with. Nothing of the game's data is
# involved: the title plays your own disc image, which you copy beside
# eboot.bin on the console.
#
# Needs: bash, git, python3, cmake, ninja, patch, a host C++ compiler with zlib,
# and LLVM 22 (clang, lld, llvm-ar). make-title.sh runs it in a container that
# has them.
#
#   JOBS        compilers at once (default: one a processor)
#   PS5_CLANG   the clang to use (default: /usr/lib/llvm-22/bin/clang, or clang-22)
#
# SPDX-License-Identifier: MIT
set -euo pipefail
kit=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk="$kit/sdk" vulkan="$kit/vulkan"
say() { printf '==> %s\n' "$*"; }
fail() { echo "build-title.sh: $*" >&2; exit 2; }

build_tools() {
    local host_cxx=${CXX:-c++} native="$vulkan/tooling/native"
    if [[ ! -x $vulkan/build/host/ps5-native-tool ]]; then
        mkdir -p "$vulkan/build/host"
        "$host_cxx" -std=c++20 -O2 "$native/native_app_builder.cpp" "$native/self_container.cpp" \
            "$native/elf_object.cpp" "$native/sce_module_writer.cpp" -lz -o "$vulkan/build/host/ps5-native-tool"
    fi
}
if [[ ${1:-} == --tools ]]; then
    build_tools
    exit 0
fi
case ${1:-} in -h | --help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

out=${1:-$PWD/out}
mkdir -p "$out"
out=$(cd -- "$out" && pwd)
work="$out/.work"
jobs=${JOBS:-$(nproc)}
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$kit/ps5/sce_sys/param.json")
app="$out/$title_id"
mkdir -p "$work/bin" "$app"

# ---- the compiler: LLVM 22, with the kit's builtins for the console's processor
real_clang=${PS5_CLANG:-}
if [[ -z $real_clang ]]; then
    for candidate in /usr/lib/llvm-22/bin/clang clang-22; do
        if command -v "$candidate" > /dev/null; then real_clang=$(command -v "$candidate"); break; fi
    done
fi
[[ -n $real_clang ]] || fail "clang 22 was not found (set PS5_CLANG, or use make-title.sh)"
real_clang=$(readlink -f "$real_clang")
llvm_bin=$(dirname "$real_clang")
for tool in ld.lld llvm-ar llvm-nm llvm-config; do
    [[ -x $llvm_bin/$tool ]] || fail "$llvm_bin/$tool is missing (LLVM's lld and tools, beside clang)"
done
export LLVM_CONFIG="$llvm_bin/llvm-config"
cat > "$work/bin/clang" <<WRAPPER
#!/bin/sh
if [ "\$#" -eq 1 ] && [ "\$1" = "--print-resource-dir" ]; then echo "$kit/clang-rt"; exit 0; fi
exec "$real_clang" "\$@"
WRAPPER
chmod +x "$work/bin/clang"
export PS5_CLANG="$work/bin/clang"
for tool in git cmake ninja patch python3; do
    command -v "$tool" > /dev/null || fail "$tool was not found"
done

build_tools

# ---- the sources of the game's code, at the revisions the kit was built from
port_url=$(sed -n 's/^port_url=//p' "$kit/REVISIONS")
port_rev=$(sed -n 's/^port_rev=//p' "$kit/REVISIONS")
decomp_rev=$(sed -n 's/^decomp_rev=//p' "$kit/REVISIONS")
source="$work/sms-pc-port"
stamp="$port_rev $decomp_rev $(sha256sum "$kit/ps5/patches/sms-pc-port.patch" | cut -d' ' -f1)"
if [[ $(cat "$work/.source-stamp" 2>/dev/null) != "$stamp" ]]; then
    say "fetching the PC port and the decompilation (about 150 MB)"
    rm -rf -- "$source" "$work/game"
    git init -q "$source"
    git -C "$source" remote add origin "$port_url"
    git -C "$source" fetch -q --depth 1 origin "$port_rev"
    git -C "$source" -c advice.detachedHead=false checkout -q FETCH_HEAD
    git -C "$source" submodule update -q --init --depth 1 decomp
    [[ $(git -C "$source/decomp" rev-parse HEAD) == "$decomp_rev" ]] ||
        fail "the decompilation is at $(git -C "$source/decomp" rev-parse HEAD), not $decomp_rev"
    say "applying the console's patch"
    git -C "$source" apply --whitespace=nowarn "$kit/ps5/patches/sms-pc-port.patch"
    echo "$stamp" > "$work/.source-stamp"
fi

# ---- the game's code
build="$work/game"
if [[ ! -f $build/build.ninja ]]; then
    say "configuring"
    mkdir -p "$build"
    cmake -S "$source" -B "$build" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$sdk/toolchain/prospero.cmake" \
        -DCMAKE_PROJECT_sms_port_INCLUDE="$kit/ps5/cmake/ps5-kit-game.cmake" \
        -DPS5_KIT_DIR="$kit" > "$build/configure.log" 2>&1 ||
        { tail -40 "$build/configure.log" >&2; fail "the configuration failed"; }
fi
say "compiling the game's code, $jobs files at a time (this is the long step)"
ninja -C "$build" -j "$jobs" sms_game
[[ -f $build/libsms_game.a ]] || fail "the game's code did not build"

# ---- the link: the kit's objects in the order they were tested in, with that archive
say "linking"
inputs=()
while IFS= read -r line; do
    case $line in
    @GAMECODE@) inputs+=("$build/libsms_game.a") ;;
    -*) inputs+=("$line") ;;
    *) inputs+=("$kit/lib/$line") ;;
    esac
done < "$kit/lib/link.txt"
PS5_DIST_DIR="$out" PS5_OPENGL_PREFIX="$kit/opengl/sdk" \
    bash "$kit/ps5/tools/link-title.sh" "$work" "$vulkan" "$sdk" "${inputs[@]}"
mkdir -p "$app/res"
cp -R "$kit/ps5/res/." "$app/res/"
cp "$kit/LICENSING.md" "$app/licenses/"

# a container runs as root: hand the result to whoever owns the output folder
if [[ $(id -u) -eq 0 ]]; then
    owner=$(stat -c '%u:%g' "$out")
    [[ $owner == 0:0 ]] || chown -R "$owner" "$out" 2>/dev/null || true
fi
say "$app"
echo "    copy the folder $title_id to /data/homebrew/ on the console (FTP), and your own"
echo "    disc image (USA, GMSE01: .iso, .gcm or .ciso) into it, beside eboot.bin."
echo "    The title you built holds the game's code: it is yours to play, not to share."
