#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - an HD texture pack for the console.
#
#   make-texture-pack.sh [OUT]            OUT/textures/ (OUT defaults to ./out), made on this machine
#   make-texture-pack.sh --docker [OUT]   the same, in the kit's container (Docker, or Podman: CONTAINER=podman)
#
# Optional. Downloads the UHD texture pack and the HD extras from their
# authors, makes a copy sized for the console (tools/get-texture-pack.py) and
# leaves it in OUT/textures: copy that to the console as
# /data/homebrew/PPSA99312/mods/textures. Needs Python 3, an internet
# connection and about 5 GB of free disk space. The Python packages it uses
# (Pillow, etcpak) and, on Linux, 7-Zip are fetched once into the kit's cache
# (tools.sh); a Mac's own tar opens the pack.
#
# SPDX-License-Identifier: MIT
set -euo pipefail
kit=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ${1:-} == --docker ]]; then
    shift
    out=${1:-$PWD/out}
    mkdir -p "$out"
    out=$(cd -- "$out" && pwd)
    container=${CONTAINER:-docker}
    command -v "$container" > /dev/null || { echo "make-texture-pack.sh: $container was not found: install Docker Desktop (or Podman), or run without --docker" >&2; exit 2; }
    tag=sunshine-ps5-kit:$(<"$kit/VERSION")
    "$container" image inspect "$tag" > /dev/null 2>&1 || "$container" build -t "$tag" "$kit"
    exec "$container" run --rm --entrypoint python3 -v "$out":/out "$tag" /kit/tools/get-texture-pack.py /out
fi

out=${1:-$PWD/out}
mkdir -p "$out"
out=$(cd -- "$out" && pwd)
# shellcheck source=tools.sh
source "$kit/tools.sh"
command -v python3 > /dev/null || { echo "make-texture-pack.sh: Python 3 is needed" >&2; exit 2; }
if [[ $kit_os == Darwin ]] && ! xcode-select -p > /dev/null 2>&1; then
    echo "make-texture-pack.sh: this Mac needs Apple's Command Line Tools (for Python): run   xcode-select --install" >&2
    exit 2
fi

# Pillow and etcpak, for this Python
packages=$(python3 "$kit/tools/fetch-wheels.py" "$kit_cache/python") || exit 2
export PYTHONPATH="$packages${PYTHONPATH:+:$PYTHONPATH}"

# 7-Zip on Linux (GNU tar cannot open a .7z; a Mac's tar can)
if [[ $kit_os == Linux ]] && ! command -v 7z > /dev/null && ! command -v 7zz > /dev/null && ! command -v 7za > /dev/null; then
    case $kit_arch in
    x86_64) asset=7z2604-linux-x64.tar.xz sha=fc0327ba27e89bd086cf426dff17d77de582953cdbbc10a6576540a06853ffcd ;;
    aarch64 | arm64) asset=7z2604-linux-arm64.tar.xz sha=5b0ac3aa91c1e3499f011d6af69d7f6b4de3ef2f011d9e2ff44c58ebd04aa388 ;;
    *) echo "make-texture-pack.sh: 7-Zip is needed (7z, 7zz or 7za)" >&2; exit 2 ;;
    esac
    dest="$kit_cache/7zip-26.04"
    if [[ ! -x $dest/7zz ]]; then
        echo "==> fetching 7-Zip 26.04"
        kit_fetch "https://github.com/ip7z/7zip/releases/download/26.04/$asset" "$sha" "$kit_cache/$asset" || exit 2
        mkdir -p "$dest"
        tar -xJf "$kit_cache/$asset" -C "$dest" 7zz
        rm -f "$kit_cache/$asset"
    fi
    PATH=$dest:$PATH
fi

exec python3 "$kit/tools/get-texture-pack.py" "$out"
