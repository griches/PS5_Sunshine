#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - the builder kit: everything of a build but the game.
#
#   ps5/tools/package-kit.sh [VERSION]      dist/kit/sunshine-ps5-kit-<VERSION>/ and its .zip
#
# A built title is not shared: eboot.bin holds the game's code, compiled from
# the decompilation. The kit is the rest of one, as it stands after
# tools/build.sh: the port's own objects (the platform layer, the graphics
# layer, SDL2), the OpenGL driver, the SDK's headers, libraries and link
# scripts, and kit/build-title.sh, which on somebody else's machine fetches the
# PC port and the decompilation, compiles the game's code and links the same
# title with the same recipe (tools/link-title.sh). What goes in is listed
# here, file by file; the game's code (libsms_game.a) and anything from a disc
# never do, and the script checks that before it finishes.
#
# The link line is the build's own (ninja's), so the kit links what was tested.
#
# SPDX-License-Identifier: MIT
set -euo pipefail

ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
opengl=${PS5_OPENGL_PREFIX:?set PS5_OPENGL_PREFIX to the sdk/ directory of the PS5 OpenGL SDK}
sdk=$(bash "$ps5/tools/setup-sdk.sh")
build=${PS5_BUILD_DIR:-$root/build/game}
ninja=$(command -v ninja || echo "$HOME/.local/bin/ninja")
export PS5_CLANG=${PS5_CLANG:-$(command -v clang || true)}
version=${1:-$(python3 -c 'import json,sys; v=json.load(open(sys.argv[1]))["contentVersion"].split("."); print("%d.%d.%d" % tuple(int(x) for x in v))' "$ps5/sce_sys/param.json")}
name=sunshine-ps5-kit-$version
kit="$root/dist/kit/$name"
source="$root/vendor/sms-pc-port"

# the kit is the build as the sources stand now: bring it up to date first
bash "$ps5/tools/build.sh"

rm -rf -- "$kit"
mkdir -p "$kit/lib" "$kit/ps5/tools"

# ---- the title's link inputs, in the build's order, without the game's code
# (ninja's command: ... link-title.sh BUILD VULKAN SDK INPUT... && :)
mapfile -t inputs < <("$ninja" -C "$build" -t commands sms | tail -1 |
    sed -e 's/.*link-title\.sh //' -e 's/ && :$//' | tr ' ' '\n' | sed -n '4,$p' | sed '/^$/d')
strip="$sdk/bin/llvm-strip"
: > "$kit/lib/link.txt"
game_code=0
for input in "${inputs[@]}"; do
    case $input in
    -*) echo "$input" >> "$kit/lib/link.txt"; continue ;;
    libsms_game.a | */libsms_game.a) echo "@GAMECODE@" >> "$kit/lib/link.txt"; game_code=$((game_code + 1)); continue ;;
    esac
    file=$input
    [[ $file == /* ]] || file="$build/$input"
    [[ -f $file ]] || { echo "package-kit.sh: link input $input is missing" >&2; exit 2; }
    relative=${file#"$build"/}
    [[ $relative != /* ]] || { echo "package-kit.sh: link input $input is outside the build tree" >&2; exit 2; }
    if [[ ! -f $kit/lib/$relative ]]; then
        mkdir -p "$(dirname "$kit/lib/$relative")"
        # no debug information: it names this machine's folders, and is most of the size
        "$strip" --strip-debug -o "$kit/lib/$relative" "$file"
    fi
    echo "$relative" >> "$kit/lib/link.txt"
done
[[ $game_code -eq 1 ]] || { echo "package-kit.sh: expected the game's code once in the link line, found it $game_code times" >&2; exit 2; }

# ---- the port: the link, the title's own files, and what the game's code is built with
cp "$ps5/tools/link-title.sh" "$ps5/tools/cc-init-array.sh" "$kit/ps5/tools/"
cp -R "$ps5/sce_sys" "$kit/ps5/sce_sys"
cp -R "$ps5/res" "$kit/ps5/res"
mkdir -p "$kit/ps5/stubs" "$kit/ps5/cmake" "$kit/ps5/patches" "$kit/ps5/opengl"
cp "$ps5/stubs/libSceMouse_stub.c" "$kit/ps5/stubs/"
cp "$ps5/cmake/ps5-kit-game.cmake" "$kit/ps5/cmake/"
cp "$ps5/patches/sms-pc-port.patch" "$ps5/patches/sdl.patch" "$kit/ps5/patches/"
cp "$ps5/opengl/build-runtime.sh" "$kit/ps5/opengl/"
cp "$ps5/kit/build-title.sh" "$ps5/kit/make-title.sh" "$ps5/kit/Dockerfile" "$kit/"
cp "$ps5/kit/README.md" "$kit/README.md"
chmod +x "$kit/build-title.sh" "$kit/make-title.sh"
mkdir -p "$kit/tools"
cp "$ps5/tools/shrink-texture-pack.py" "$ps5/tools/get-texture-pack.py" "$kit/tools/"
cp "$ps5/kit/make-texture-pack.sh" "$kit/"
chmod +x "$kit/make-texture-pack.sh"
# the revisions build-title.sh fetches: the ones this build was made from
port_rev=$(git -C "$source" rev-parse HEAD)
decomp_rev=$(git -C "$source/decomp" rev-parse HEAD)
{
    echo "port_url=$(git -C "$source" remote get-url origin)"
    echo "port_rev=$port_rev"
    echo "decomp_rev=$decomp_rev"
} > "$kit/REVISIONS"
# ... and the patch must be the tree's whole difference from that revision
bash "$ps5/tools/setup-source.sh" > /dev/null

# ---- the payload SDK: compiler wrappers, link scripts, the CMake toolchain, headers, libraries
mkdir -p "$kit/sdk/target"
cp -R "$sdk/bin" "$sdk/ldscripts" "$sdk/toolchain" "$kit/sdk/"
cp -R "$sdk/target/include" "$sdk/target/lib" "$kit/sdk/target/"
cp "$sdk/.ps5-sdk-revision" "$kit/sdk/"

# ---- PS5_Vulkan: the link recipe, the CRT, the fake-SELF tool's source, libc.prx
mkdir -p "$kit/vulkan/tools" "$kit/vulkan/tooling/psbc" "$kit/vulkan/tooling/native" "$kit/vulkan/runtime"
cp "$vulkan/LICENSE" "$vulkan/NOTICE.md" "$kit/vulkan/"
cp "$vulkan/tools/radv-link.sh" "$kit/vulkan/tools/"
cp "$vulkan/tooling/prospero-clang18" "$kit/vulkan/tooling/"
cp "$vulkan/tooling/psbc/ps5-pie-unwind.ld" "$kit/vulkan/tooling/psbc/"
cp "$vulkan"/tooling/native/*.cpp "$vulkan"/tooling/native/*.hpp "$vulkan"/tooling/native/*.map \
    "$vulkan"/tooling/native/*.ld "$kit/vulkan/tooling/native/"
cp "$vulkan/runtime/libc.prx" "$vulkan/runtime/libc.prx.sha256" "$vulkan/runtime/README.md" "$kit/vulkan/runtime/"

# ---- the PS5 OpenGL SDK: the driver's archive and the console's two GPU import stubs
mkdir -p "$kit/opengl/sdk/lib"
cp "$opengl/../LICENSE" "$opengl/../THIRD_PARTY_NOTICES.md" "$kit/opengl/"
# (as released: libPS5OpenGL.a is a linker script naming the others)
cp -R "$opengl"/lib/. "$kit/opengl/sdk/lib/"
rm -rf "$kit/opengl/sdk/lib/cmake" "$kit/opengl/sdk/lib/pkgconfig"
[[ -f $opengl/sunshine-runtime-defines.txt ]] && cp "$opengl/sunshine-runtime-defines.txt" "$kit/opengl/"

# ---- Clang's builtins for the console's processor: a Linux on arm64 does not install x86-64's
builtins="$("$PS5_CLANG" --print-resource-dir)/lib/linux/libclang_rt.builtins-x86_64.a"
[[ -f $builtins ]] || { echo "package-kit.sh: missing $builtins" >&2; exit 2; }
mkdir -p "$kit/clang-rt/lib/linux"
cp "$builtins" "$kit/clang-rt/lib/linux/"

# ---- licences, and where each part's source is
mkdir -p "$kit/licenses"
cp "$root/LICENSE" "$kit/LICENSE"
cp "$root/LICENSING.md" "$kit/"
cp "$root"/licenses/* "$kit/licenses/"
cp "$source/LICENSE" "$kit/licenses/sms-pc-port-LICENSE.txt"
sdl_revision=$(git -C "$root/.deps/SDL2" describe --tags --always 2>/dev/null || echo "release-2.32.10")
own_revision=$(git -C "$root" rev-parse HEAD 2>/dev/null || echo "(this kit's own files: ps5/ in the kit)")
{
    echo "The builder kit $version of Super Mario Sunshine for the PlayStation 5 was built from:"
    echo
    echo "PS5_Sunshine     https://github.com/griches/PS5_Sunshine                $own_revision"
    echo "sms-pc-port      https://github.com/chasem-dev/sms-pc-port              $port_rev (+ ps5/patches/sms-pc-port.patch)"
    echo "sms-english      https://github.com/chasem-dev/sms-english              $decomp_rev (fetched by build-title.sh, not in the kit)"
    echo "PS5 OpenGL SDK   https://github.com/blackbearreloaded/ps5-opengl        release 1.0.2, with three runtime objects rebuilt (ps5/opengl/build-runtime.sh; defines in opengl/sunshine-runtime-defines.txt)"
    echo "PS5_PayloadSDK   https://github.com/mihawk-99/PS5_PayloadSDK            $(<"$sdk/.ps5-sdk-revision")"
    echo "PS5_Vulkan       https://github.com/mihawk-99/PS5_Vulkan                $(git -C "$vulkan" rev-parse HEAD) (its link recipe, CRT and native tool; no Vulkan driver is linked)"
    echo "SDL2             https://github.com/libsdl-org/SDL                      $sdl_revision (+ ps5/patches/sdl.patch and the console's drivers)"
    echo "Clang builtins   https://github.com/llvm/llvm-project                   $("$PS5_CLANG" --version | head -1)"
    echo
    echo "LICENSING.md says which licence covers which part."
} > "$kit/SOURCES.txt"
echo "$version" > "$kit/VERSION"

# ---- nothing of the game: no game code archive or object, no decompilation, no disc image or save
leaks=$(find "$kit" \( -name 'libsms_game*' -o -path '*/sms_game.dir/*' -o -path '*/decomp/*' -o -path '*/patched/*' \
    -o -iname '*.iso' -o -iname '*.gcm' -o -iname '*.ciso' -o -iname '*.rvz' -o -iname '*.gci' -o -iname '*.szs' -o -iname '*.thp' \
    -o -iname '*.dol' -o -iname '*.arc' \) -print)
[[ -z $leaks ]] || { echo "package-kit.sh: these must not be in a kit:" >&2; echo "$leaks" >&2; exit 1; }
(cd "$root/dist/kit" && rm -f "$name.zip" && zip -qry "$name.zip" "$name")
printf '==> %s (%s unpacked, %s zipped)\n' "$root/dist/kit/$name.zip" \
    "$(du -sh "$kit" | cut -f1)" "$(du -sh "$root/dist/kit/$name.zip" | cut -f1)"
sha256sum "$root/dist/kit/$name.zip"
