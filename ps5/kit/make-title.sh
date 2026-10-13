#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - the builder kit, run in a container.
#
#   make-title.sh [OUT]       OUT/PPSA99312/ (OUT defaults to ./out)
#
# Needs Docker (or Podman: CONTAINER=podman) and an internet connection: the
# first run builds the container's image, which downloads a compiler, and each
# title build fetches the game's source code from GitHub the first time (it is
# kept in OUT/.work afterwards). See README.md.
#
#   JOBS        compilers at once (default: one a processor)
#
# SPDX-License-Identifier: MIT
set -euo pipefail
kit=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
out=${1:-$PWD/out}
mkdir -p "$out"
out=$(cd -- "$out" && pwd)
container=${CONTAINER:-docker}
command -v "$container" > /dev/null || { echo "make-title.sh: $container was not found: install Docker Desktop (or Podman)" >&2; exit 2; }
tag=sunshine-ps5-kit:$(<"$kit/VERSION")

"$container" image inspect "$tag" > /dev/null 2>&1 || "$container" build -t "$tag" "$kit"
exec "$container" run --rm ${JOBS:+-e JOBS="$JOBS"} -v "$out":/out "$tag" /out
