#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - pack the built title folder as a release archive.
#
#   ps5/tools/package-release.sh [VERSION]      (through tools/vm.sh package-release)
#
# Writes dist/Sunshine-PS5-vVERSION.zip: the title folder dist/<TITLE_ID>/ as the
# console takes it (eboot.bin, sce_sys/, sce_module/, res/, licenses/), with
# SOURCE.txt beside eboot.bin naming the revision of every part the build
# linked. A built title is under GPL-3.0: that file is how a release says where
# its source is. No disc image, save or texture pack goes in, and it refuses if
# one is in the folder. VERSION defaults to param.json's contentVersion.
#
# After PS5_SwitchWaker's package-release.sh.
# SPDX-License-Identifier: MIT
set -euo pipefail
ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
opengl=${PS5_OPENGL_PREFIX:?set PS5_OPENGL_PREFIX to the sdk/ directory of the PS5 OpenGL SDK}
source="$root/vendor/sms-pc-port"
param="$ps5/sce_sys/param.json"
version=${1:-$(python3 -c 'import json,sys; v=json.load(open(sys.argv[1]))["contentVersion"].split("."); print("%d.%d.%d" % tuple(int(x) for x in v))' "$param")}
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$param")
app="$root/dist/$title_id"
for file in eboot.bin sce_sys/param.json sce_sys/icon0.png sce_sys/pic0.dds sce_sys/pic1.dds sce_module/libc.prx \
    res/prompts/playstation.png; do
    [[ -e $app/$file ]] || { echo "missing $app/$file: run build.sh first" >&2; exit 2; }
done
cmp -s "$param" "$app/sce_sys/param.json" || { echo "the title's param.json is not this tree's: run build.sh first" >&2; exit 2; }
# a console's own files, a disc, a save or a pack are not for a release
stray=$(find "$app" \( -iname '*.iso' -o -iname '*.ciso' -o -iname '*.gcm' -o -iname '*.rvz' -o -iname '*.gci' \
    -o -iname '*.dol' -o -iname '*.szs' -o -path "$app/userdata" -o -path "$app/mods" -o -name env.txt \
    -o -name settings.txt -o -name bindings.txt \) -print -quit)
[[ -z $stray ]] || { echo "game data or a save in the title folder ($stray): a release never carries it" >&2; exit 2; }
# the submodule's working tree carries the console's patch: that is not a change here
[[ -z $(git -C "$root" status --porcelain --ignore-submodules=dirty) ]] ||
    { echo "uncommitted changes: a release is built from a commit" >&2; exit 2; }
sdk=$(bash "$ps5/tools/setup-sdk.sh")
sdl_revision=$(git -C "$root/.deps/SDL2" describe --tags --always 2>/dev/null || echo "release-2.32.10")
mkdir -p "$app/licenses"
cp "$root/licenses/GPL-3.0.txt" "$root/licenses/MIT.txt" "$root/licenses/Zlib.txt" "$app/licenses/"
cp "$source/LICENSE" "$app/licenses/sms-pc-port-LICENSE.txt"
cp "$source/decomp/LICENSE" "$app/licenses/sms-english-LICENSE.txt"
cp "$root/LICENSING.md" "$app/licenses/LICENSING.md"
cat > "$app/SOURCE.txt" <<SOURCE
Super Mario Sunshine for PlayStation 5, version $version
An unofficial homebrew port of chasem-dev's sms-pc-port. Not affiliated with
Nintendo or Sony Interactive Entertainment.

This title is distributed under the GNU General Public License, version 3
(licenses/GPL-3.0.txt). Its source is these projects at these revisions:

The port (patch, SDL2 drivers, platform layer, build)
  $(git -C "$root" remote get-url origin 2>/dev/null || echo "this repository")
  $(git -C "$root" rev-parse HEAD)
The PC port: sms-pc-port (MIT), with ps5/patches/sms-pc-port.patch
  https://github.com/chasem-dev/sms-pc-port
  $(git -C "$source" rev-parse HEAD)
The game's code: the sms-english decompilation it builds (CC0-1.0)
  https://github.com/chasem-dev/sms-english
  $(git -C "$source/decomp" rev-parse HEAD)
OpenGL: the PS5 OpenGL SDK (GPL-3.0-or-later), release 1.0.2, with three runtime
objects rebuilt by ps5/opengl/build-runtime.sh
  https://github.com/blackbearreloaded/ps5-opengl
SDL2 (Zlib), with ps5/patches/sdl.patch and the drivers in ps5/sdl
  https://github.com/libsdl-org/SDL
  $sdl_revision
The link recipe, CRT, libc.prx and packaging: PS5_Vulkan (GPL-3.0)
  https://github.com/mihawk-99/PS5_Vulkan
  $(git -C "$vulkan" rev-parse HEAD)
The platform layer and SDK: PS5_PayloadSDK (GPL-3.0), over ps5-payload-dev/sdk
  https://github.com/mihawk-99/PS5_PayloadSDK
  $(<"$sdk/.ps5-sdk-revision")
Compiler: $(${PS5_CLANG:-clang} --version | head -1)

No game data is included. Super Mario Sunshine belongs to Nintendo; this title
does nothing without a GameCube disc image of the USA disc (GMSE01, revision 0,
.iso, .gcm or .ciso) that you provide, placed beside eboot.bin. The pictures in
sce_sys/ are the port's own, and res/prompts holds button symbols drawn from
Kenney's CC0 Input Prompts.

eboot.bin sha256: $(sha256sum "$app/eboot.bin" | cut -d' ' -f1)
SOURCE
out="$root/dist/Sunshine-PS5-v$version.zip"
rm -f "$out"
(cd "$root/dist" && zip -q -r -X "$out" "$title_id" -x '*/.DS_Store')
printf '==> %s (%s bytes)\n' "$out" "$(stat -c %s "$out")"
sha256sum "$out"
