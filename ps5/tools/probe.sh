#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - build a probe title into dist/<TITLE_ID>/.
#
#   ps5/tools/probe.sh memprobe      ps5/probe/memprobe.c, linked as the title
#   ps5/tools/probe.sh gltriangle    the same checks, then OpenGL on a render thread
#
# A probe is one C file with its own main, linked like the game will be
# (tools/link-title.sh), so what it reports is what the game's title gets.
#
# SPDX-License-Identifier: MIT
set -euo pipefail
ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
name=${1:?usage: probe.sh NAME}
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
sdk=$(bash "$ps5/tools/setup-sdk.sh")
work=${PS5_BUILD_DIR:-$root/build/game}/probe-$name
mkdir -p "$work"
cc() { PS5_PAYLOAD_SDK="$sdk" sh "$vulkan/tooling/prospero-clang18" "$@"; }
opengl=${PS5_OPENGL_PREFIX:?set PS5_OPENGL_PREFIX to the sdk/ directory of the PS5 OpenGL SDK}
flags=(-std=gnu11 -O1 -g1 -fno-omit-frame-pointer -march=znver2 -I"$ps5/src" -I"$ps5/probe"
    -DGL_GLEXT_PROTOTYPES=1 -I"$opengl/include")
objects=()
for source in "$ps5/probe/$name.c" "$ps5/src/platform.c" "$ps5/src/shims.c"; do
    object="$work/$(basename "${source%.c}").o"
    cc "${flags[@]}" -c "$source" -o "$object"
    objects+=("$object")
done
bash "$ps5/tools/link-title.sh" "$work" "$vulkan" "$sdk" "${objects[@]}"
# The title folder now holds the probe: the game's next build must link again
rm -f "${PS5_BUILD_DIR:-$root/build/game}/sms"
