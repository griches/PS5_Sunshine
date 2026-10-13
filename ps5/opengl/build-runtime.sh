#!/usr/bin/env bash
# Rebuild the PS5 OpenGL SDK runtime objects for the Sunshine port and put them in ~/ps5/opengl/sdk-sunshine.
# The Sunshine port adds -UPS5_RENDER_ARENA_BYTES -DPS5_RENDER_ARENA_BYTES=0x40000000u: the released 256 MiB buffer arena overflows in the plaza.
#   build-runtime.sh "RUNTIME DEFINES" [screen source]
#
# Expects the SDK's source at ~/ps5/opengl/src/ps5-opengl (with Mesa's generated
# headers built) and its 1.0.2 release at ~/ps5/opengl/ps5-opengl-sdk-1.0.2;
# PS5_PAYLOAD_SDK is the payload SDK (default: this repository's .deps copy).
set -euo pipefail
root=~/ps5/opengl/src/ps5-opengl
sdk=${PS5_PAYLOAD_SDK:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/.deps/native/ps5-payload-sdk}
rel=~/ps5/opengl/ps5-opengl-sdk-1.0.2
fix() { sed "s#/home/runner/work/ps5-opengl/ps5-opengl#$root#g"; }
common=$(sed -n 2p $rel/runtime-config.txt | fix)
psbc=$(sed -n 3p $rel/runtime-config.txt | fix)
core=$(sed -n 4p $rel/runtime-config.txt)
runtime=$1
screen=${2:-$root/src/gallium/ps5/ps5_screen.c.orig}
out=$root/build/drv/obj; mkdir -p $out
cc="$sdk/bin/prospero-clang"
run=ps5_agc_gate2_run; [[ $runtime == *PS5_ASYNC_NATIVE_PREP=1* ]] && run=ps5_agc_gate2_run_sync
cp "$screen" $out/ps5_screen.c
$cc $common -Wno-error -DHAVE_PTHREAD=1 $runtime -DHAVE_STRUCT_TIMESPEC=1 -DPS5_ENABLE_COMPRESSED_FALLBACK_CANDIDATE=1 \
    -DPS5_ENABLE_CORE_CONTEXT_CANDIDATE=1 -Wno-unreachable-code-generic-assoc -I$root/third_party/mesa-26.2.0/src/mesa \
    -c -o $out/ps5_egl.o $root/src/egl/ps5_egl.c &
$cc $common $psbc $core $runtime -Wno-error -I$root/build/mesa-ps5-probe/src/compiler -I$root/src/platform -I$root/src/gallium/ps5 \
    -c -o $out/ps5_screen.o $out/ps5_screen.c &
$cc $common -Wno-error -femulated-tls -DHAVE_PTHREAD=1 -DHAVE_STRUCT_TIMESPEC=1 -I$root/third_party/opengnm-psbc/libpsbc \
    $runtime -Dmain=$run -DAGC_TRIANGLE_SUBMIT=1 -DAGC_RUNTIME_PACKAGES=1 \
    -c -o $out/ps5_agc_runtime_backend.o $root/src/platform/ps5_agc_runtime_backend.c &
wait
ls -la $out/*.o
rm -rf ~/ps5/opengl/sdk-sunshine && cp -a $rel/sdk ~/ps5/opengl/sdk-sunshine
llvm-ar r ~/ps5/opengl/sdk-sunshine/lib/libps5_opengl_core33.a $out/ps5_egl.o $out/ps5_screen.o $out/ps5_agc_runtime_backend.o
echo "$runtime" > ~/ps5/opengl/sdk-sunshine/sunshine-runtime-defines.txt
