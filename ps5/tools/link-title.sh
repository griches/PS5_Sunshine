#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - link the title and package its folder.
#
#   link-title.sh BUILD_DIR PS5_VULKAN_DIR SDK OBJECT...
#
# Run by the build (ps5/cmake/ps5-game.cmake) once the objects are compiled, and
# by tools/probe.sh. The link is PS5_Vulkan's without its Vulkan driver: its link
# recipe (tools/radv-link.sh: the platform layer of this title's SDK pin, the
# heap and thread wraps, the libc names bound to ps5_*), its CRT, its native
# tool (ELF -> the console's fake SELF) and its libc.prx. The graphics are the
# PS5 OpenGL SDK's (blackbearreloaded/ps5-opengl: Mesa's OpenGL 4.6 over the
# console's own GPU interface, EGL for the screen), a static archive group and
# its two import stubs. The title folder, dist/<TITLE_ID>/, gets the signed
# eboot.bin, sce_sys/ and the licences. OBJECT may be an archive.
# PS5_DIST_DIR is where the title folder goes instead of dist/ (the builder kit).
# PS5_OPENGL_PREFIX is the OpenGL SDK's sdk/ directory.
#
# Copyright (C) 2026 Mihawk
# SPDX-License-Identifier: MIT

set -euo pipefail
[[ -n ${LINK_TRACE:-} ]] && set -x

work=$1 vulkan=$2 sdk=$3
shift 3
# CMake's link line for the game arrives as it would go to the compiler driver:
# -Xlinker only introduces a linker argument there
objects=()
for argument in "$@"; do
    case $argument in
    # ... and its groups go: the link below makes one group of everything
    -Xlinker | --start-group | --end-group) ;;
    # the compiler driver's word size: the linker has one, the console's
    -m64) ;;
    # the console's C library has the maths functions, threads and dlopen
    -lm | -lpthread | -ldl | -pthread | -lrt) ;;
    # every symbol is the title's own already: nothing loads a module against it
    -Wl,-export-dynamic | -Wl,--export-dynamic | -rdynamic | -E) ;;
    # a linker argument as the compiler driver takes it, for the linker itself
    -Wl,*) IFS=, read -r -a linker_arguments <<<"${argument#-Wl,}"; objects+=("${linker_arguments[@]}") ;;
    *) objects+=("$argument") ;;
    esac
done
ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
opengl=${PS5_OPENGL_PREFIX:?set PS5_OPENGL_PREFIX to the sdk/ directory of the PS5 OpenGL SDK}
export PS5_CLANG=${PS5_CLANG:-$(command -v clang || true)}
tool="$vulkan/build/host/ps5-native-tool"
native="$vulkan/tooling/native"
param="$ps5/sce_sys/param.json"

for file in "$opengl/lib/libPS5OpenGL.a" "$opengl/lib/libSceAgc.so" "$opengl/lib/libSceAgcDriver.so" "$tool" "$param" "$sdk/bin/prospero-lld" "$vulkan/tools/radv-link.sh" \
        "$vulkan/runtime/libc.prx"; do
    [[ -e $file ]] || { echo "missing: $file" >&2; exit 2; }
done
mkdir -p "$work/link/obj" "$work/link/stubs"
cc() { PS5_PAYLOAD_SDK="$sdk" sh "$vulkan/tooling/prospero-clang18" "$@"; }

# The CRT, as in
# PS5_Vulkan's CTS title.
cc -std=c++20 -O2 -fno-exceptions -fno-rtti -c "$native/app_crt.cpp" -o "$work/link/obj/app_crt.o"
stub() {
    local library=$1 source=$2
    [[ $source == /* ]] || source="$vulkan/$source"
    cc -std=c11 -O2 -fPIC -c "$source" -o "$work/link/obj/${library}_stub.o"
    "$sdk/bin/prospero-lld" --shared -soname "${library}.prx" \
        -o "$work/link/stubs/${library}.so" "$work/link/obj/${library}_stub.o"
}
# The console's GPU interface (AGC), which the payload SDK has no stubs for: the
# OpenGL SDK brings the two it imports from.
cp "$opengl/lib/libSceAgc.so" "$opengl/lib/libSceAgcDriver.so" "$work/link/stubs/"
# The SDK has no stub for the console's mouse library either (src/platform.c reads it).
stub libSceMouse "$ps5/stubs/libSceMouse_stub.c"

# shellcheck source=/dev/null
source "$vulkan/tools/radv-link.sh"
# The recipe links its Vulkan driver whole: this title has none, so it gets an
# archive with nothing in it
empty="$work/link/no-vulkan.a"
rm -f "$empty"
"$sdk/bin/llvm-ar" rcs "$empty"
radv_link_recipe "$vulkan" "$sdk" "$empty" || exit 2
# localeconv in the C locale, '.' the decimal point (the console's gives none, and
# tinygltf's JSON parser then read 0.62 as 0): the platform layer's since SDK fork
# 6b63a2a (tools/setup-sdk.sh's pin is never older), bound by PS5_Vulkan's recipe
# since its 6a6dfa6. With an older recipe the title binds it here, kept local as
# the recipe keeps its bound names. The symbol listing is read whole before it
# is searched: piped into grep -q under pipefail, llvm-nm's SIGPIPE made the
# found symbol a miss about half the time once the archive grew (SDK 611893f).
platform_has_localeconv=false
grep -q " T ps5_localeconv$" <<<"$("$sdk/bin/llvm-nm" --defined-only "$sdk/target/lib/libps5platform.a" 2>/dev/null)" &&
    platform_has_localeconv=true
if $platform_has_localeconv && [[ " ${radv_link_flags[*]} " != *" --defsym=localeconv=ps5_localeconv "* ]]; then
    printf '{\n    local:\n        localeconv;\n};\n' > "$work/link/localeconv-local.map"
    radv_link_flags+=(--defsym=localeconv=ps5_localeconv --version-script "$work/link/localeconv-local.map")
fi
# std::jthread and std::stop_token are libc++'s experimental library in the SDK's LLVM 18
experimental=()
[[ -f $sdk/target/lib/libc++experimental.a ]] && experimental=("$sdk/target/lib/libc++experimental.a")
# libc names no module a title loads exports, which the libraries linked in
# call: ps5/src/shims.c answers each as ps5dl_<name>, kept local like the
# recipe's own bound names
shims=(isatty getresuid getresgid dl_iterate_phdr fchown fork vfork setsid pathconf getnameinfo gai_strerror lstat tmpfile clock_gettime execlp getcwd realpath backtrace_symbols)
{ printf '{\n    local:\n'; printf '        %s;\n' "${shims[@]}"; printf '};\n'; } > "$work/link/shims-local.map"
for name in "${shims[@]}"; do
    radv_link_flags+=("--defsym=$name=ps5dl_$name")
done
radv_link_flags+=(--version-script "$work/link/shims-local.map")
# Standard output goes nowhere in a title: what is printed there (the OpenGL
# SDK's driver reports) is written to stderr, which klog has (ps5/src/shims.c)
radv_link_flags+=(--wrap=printf --wrap=vprintf --wrap=puts --wrap=putchar)
# The port's code mods register themselves in a section of their own, which the
# port bounds with weak __start/__stop names: with no mod built in there is no
# such section, and a weak name left undefined would be an import. Both are 0
# (an empty list), and the title's own.
# The same for three tables only a code mod supplies, which the game tests for
# null (the port's Windows build defines them as 0 too).
absent=(__start_sms_mod_ctors __stop_sms_mod_ctors sPlayerAnimeDatas sPlayerAnimeInfos sPlayerAnimeInfosSize)
{ printf '{\n    local:\n'; printf '        %s;\n' "${absent[@]}"; printf '};\n'; } > "$work/link/game-local.map"
for name in "${absent[@]}"; do
    radv_link_flags+=("--defsym=$name=0")
done
radv_link_flags+=(--version-script "$work/link/game-local.map")
"$sdk/bin/prospero-lld" "${radv_linker_script[@]}" --eh-frame-hdr "${radv_link_flags[@]}" \
    --version-script "$native/app-symbols.map" --exclude-libs=ALL \
    -e _start -o "$work/link/llvm-pie.elf" \
    -u ps5_agc_gate2_run \
    "$work/link/obj/app_crt.o" --start-group "${objects[@]}" "${experimental[@]}" \
    -L "$opengl/lib" -lPS5OpenGL --end-group \
    "$work/link/stubs/libSceAgc.so" "$work/link/stubs/libSceAgcDriver.so" \
    "$work/link/stubs/libSceMouse.so" \
    "${radv_link_inputs[@]}" \
    --as-needed "$sdk"/target/lib/*.so
# A title whose localeconv is still the console's reads every glTF fraction as 0
# (black materials, models scaled to nothing): refuse it here, not on the console
if $platform_has_localeconv &&
        grep -q " U localeconv$" <<<"$("$sdk/bin/llvm-nm" "$work/link/llvm-pie.elf" 2>/dev/null)"; then
    echo "link-title.sh: localeconv is not bound to the platform layer's ps5_localeconv" >&2
    exit 1
fi
# A title loads neither libkernel_sys's exports nor libScePosixForWebKit's: an
# import only their stubs define links, and is null at run time, so its first call
# jumps to address 0 (PS5_RetroArch's strcasestr did; RADV imports readlink and
# mkstemp). PS5_Vulkan's recipe binds those the platform layer has: refuse a
# title that still imports one, here rather than on the console.
null_imports=$(comm -23 \
    <("$sdk/bin/llvm-nm" -D --undefined-only "$work/link/llvm-pie.elf" |
        awk '$1 == "U" { sub(/@.*/, "", $2); print $2 }' | sort -u) \
    <(for library in "$sdk"/target/lib/*.so "$work/link/stubs/libSceAgc.so" "$work/link/stubs/libSceAgcDriver.so" \
        "$work/link/stubs/libSceMouse.so"; do
        case ${library##*/} in libkernel_sys.so | libScePosixForWebKit.so) continue ;; esac
        "$sdk/bin/llvm-nm" -D --defined-only "$library" 2>/dev/null | awk '{ print $NF }'
    done | sort -u))
if [[ -n $null_imports ]]; then
    echo "link-title.sh: imports that no module a title loads exports (null at run time): ${null_imports//$'\n'/ }" >&2
    echo "link-title.sh: bind them to the platform layer (PS5_Vulkan's tools/radv-link.sh)" >&2
    exit 1
fi
"$tool" link --in "$work/link/llvm-pie.elf" --out "$work/eboot.elf.new" \
    --stub-dir "$sdk/target/lib" --stub "$work/link/stubs/libSceAgc.so" \
    --stub "$work/link/stubs/libSceAgcDriver.so" --stub "$work/link/stubs/libSceMouse.so" --module-sdk 0x02000009 \
    --companion-sdk 0x08050001 --file-name eboot.elf

# The title folder
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$param")
app="${PS5_DIST_DIR:-$root/dist}/$title_id"
mkdir -p "$app/sce_sys" "$app/sce_module"
"$tool" self --sign --in "$work/eboot.elf.new" --out "$app/eboot.bin" --magic 0x1D3D154F
"$tool" self --inspect --file "$app/eboot.bin" > /dev/null
cp "$param" "$app/sce_sys/param.json"
for asset in icon0.png pic0.dds pic1.dds snd0.at9; do
    [[ -f $ps5/sce_sys/$asset ]] && cp "$ps5/sce_sys/$asset" "$app/sce_sys/$asset"
done
(cd "$vulkan/runtime" && sha256sum --check --strict --quiet libc.prx.sha256)
cp "$vulkan/runtime/libc.prx" "$app/sce_module/libc.prx"
mv "$work/eboot.elf.new" "$work/eboot.elf"
# The linked ELF of the title last packaged, for tools/run.sh to symbolise a crash with
# (the game's build tree may be on the VM's own disk)
mkdir -p "$root/build"
cp "$work/link/llvm-pie.elf" "$root/build/last-title.elf"
printf '==> %s: %s (eboot.bin %s bytes)\n' "$title_id" "$app" "$(stat -c %s "$app/eboot.bin")"
# The licences beside eboot.bin
mkdir -p "$app/licenses"

cp "$vulkan/LICENSE" "$app/licenses/PS5_Vulkan-LICENSE.txt"
cp "$opengl/../LICENSE" "$app/licenses/PS5_OpenGL-LICENSE.txt"
cp "$opengl/../THIRD_PARTY_NOTICES.md" "$app/licenses/PS5_OpenGL-THIRD_PARTY_NOTICES.md"
