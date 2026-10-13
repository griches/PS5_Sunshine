#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - build the game into dist/<TITLE_ID>/.
#
#   ps5/tools/build.sh [ninja arguments]
#
# Applies the console's patch to vendor/sms-pc-port (tools/setup-source.sh),
# configures it with the payload SDK's CMake toolchain (once) and
# ps5/cmake/ps5-game.cmake, which gives it SDL2 with the console's drivers and
# the title's link (tools/link-title.sh). The title folder gets eboot.bin,
# sce_sys/ and the licences. No game data: the disc image is yours, placed
# beside eboot.bin.
#
#   PS5_BUILD_DIR      the build tree (default build/game; the Linux VM's own disk
#                      is several times faster than the shared folder)
#   PS5_VULKAN_DIR     the PS5_Vulkan checkout (default ../PS5_Vulkan)
#   PS5_OPENGL_PREFIX  the PS5 OpenGL SDK's sdk/ directory
#
# SPDX-License-Identifier: MIT
set -euo pipefail

ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
opengl=${PS5_OPENGL_PREFIX:?set PS5_OPENGL_PREFIX to the sdk/ directory of the PS5 OpenGL SDK}
bash "$ps5/tools/setup-source.sh"
sdl=$(bash "$ps5/tools/setup-sdl.sh")
sdk=$(bash "$ps5/tools/setup-sdk.sh")
build=${PS5_BUILD_DIR:-$root/build/game}
ninja=$(command -v ninja || echo "$HOME/.local/bin/ninja")
export PS5_CLANG=${PS5_CLANG:-$(command -v clang || true)}

if [[ ! -f $build/build.ninja ]]; then
    mkdir -p "$build"
    cmake -S "$root/vendor/sms-pc-port" -B "$build" -G Ninja -DCMAKE_MAKE_PROGRAM="$ninja" \
        -DCMAKE_TOOLCHAIN_FILE="$sdk/toolchain/prospero.cmake" \
        -DCMAKE_PROJECT_sms_port_INCLUDE="$ps5/cmake/ps5-game.cmake" \
        -DPS5_PORT_DIR="$root" -DPS5_VULKAN_DIR="$vulkan" -DSDL_DIR="$sdl" -DPS5_OPENGL_PREFIX="$opengl" \
        -DCMAKE_VERBOSE_MAKEFILE=OFF > "$build/configure.log" 2>&1 \
        || { tail -60 "$build/configure.log" >&2; exit 1; }
fi
"$ninja" -C "$build" "${@:-sms}"

# The title's name and art, as this tree has them (the link copies them too, but
# only when something relinks)
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$ps5/sce_sys/param.json")
app="${PS5_DIST_DIR:-$root/dist}/$title_id"
if [[ -d $app/sce_sys ]]; then
    cp "$ps5/sce_sys/param.json" "$ps5/sce_sys/icon0.png" "$ps5/sce_sys/pic0.dds" "$ps5/sce_sys/pic1.dds" "$app/sce_sys/"
fi
# What the title brings beside its executable: the DualSense's button prompts
if [[ -d $app ]]; then
    mkdir -p "$app/res"
    cp -R "$ps5/res/." "$app/res/"
fi
