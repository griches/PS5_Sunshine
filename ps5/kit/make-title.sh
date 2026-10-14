#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - the builder kit: make the title.
#
#   make-title.sh [OUT]            OUT/PPSA99312/ (OUT defaults to ./out), built on this machine
#   make-title.sh --docker [OUT]   the same, built in a container (Docker, or Podman: CONTAINER=podman)
#
# On this machine (macOS on Apple silicon, Linux, or WSL on Windows) it runs
# build-title.sh, which uses the compiler and build tools this machine has, or
# fetches them once (LLVM 22 is about 1.5 GB). Each title build fetches the
# game's source code from GitHub the first time (it is kept in OUT/.work
# afterwards). See README.md.
#
#   JOBS        compilers at once (default: one a processor)
#
# SPDX-License-Identifier: MIT
set -euo pipefail
kit=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ${1:-} != --docker ]]; then
    exec bash "$kit/build-title.sh" "$@"
fi
shift
out=${1:-$PWD/out}
mkdir -p "$out"
out=$(cd -- "$out" && pwd)
container=${CONTAINER:-docker}
command -v "$container" > /dev/null || { echo "make-title.sh: $container was not found: install Docker Desktop (or Podman), or build without --docker" >&2; exit 2; }
tag=sunshine-ps5-kit:$(<"$kit/VERSION")

"$container" image inspect "$tag" > /dev/null 2>&1 || "$container" build -t "$tag" "$kit"
exec "$container" run --rm ${JOBS:+-e JOBS="$JOBS"} -v "$out":/out "$tag" /out
