#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - an HD texture pack for the console, made in the kit's container.
#
#   make-texture-pack.sh [OUT]       OUT/textures/ (OUT defaults to ./out)
#
# Optional. Downloads the UHD texture pack and the HD extras from their
# authors, makes a copy sized for the console (tools/get-texture-pack.py) and
# leaves it in OUT/textures: copy that to the console as
# /data/homebrew/PPSA99312/mods/textures. Needs Docker (or Podman:
# CONTAINER=podman), an internet connection and about 5 GB of free disk space.
#
# SPDX-License-Identifier: MIT
set -euo pipefail
kit=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
out=${1:-$PWD/out}
mkdir -p "$out"
out=$(cd -- "$out" && pwd)
container=${CONTAINER:-docker}
command -v "$container" > /dev/null || { echo "make-texture-pack.sh: $container was not found: install Docker Desktop (or Podman)" >&2; exit 2; }
tag=sunshine-ps5-kit:$(<"$kit/VERSION")

"$container" image inspect "$tag" > /dev/null 2>&1 || "$container" build -t "$tag" "$kit"
exec "$container" run --rm --entrypoint python3 -v "$out":/out "$tag" /kit/tools/get-texture-pack.py /out
