#!/usr/bin/env bash
# Super Mario Sunshine for the PlayStation 5 - the game's sources, with the console's changes.
#
#   ps5/tools/setup-source.sh          apply ps5/patches/sms-pc-port.patch
#   ps5/tools/setup-source.sh --save   write the tree's changes back to the patch
#
# vendor/sms-pc-port is the PC port (chasem-dev/sms-pc-port) at an upstream
# revision, with the decompilation as its own submodule. What the console needs
# changed is kept here as a patch, not as a fork. A patch already applied is
# left alone, so this can run before every build.
#
# SPDX-License-Identifier: MIT
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source="$root/vendor/sms-pc-port"
patch="$root/ps5/patches/sms-pc-port.patch"
[[ -f $source/decomp/configure.py ]] || {
    echo "setup-source.sh: vendor/sms-pc-port is missing (git clone --recurse-submodules https://github.com/chasem-dev/sms-pc-port.git)" >&2
    exit 2
}

if [[ ${1:-} == --save ]]; then
    # new files too: a patch without them built a tree without three of the console's decomp patches
    git -C "$source" add --intent-to-add -- .
    git -C "$source" diff --ignore-submodules -- . > "$patch"
    exit 0
fi
[[ -s $patch ]] || exit 0
if git -C "$source" apply --reverse --check "$patch" 2>/dev/null; then
    exit 0 # applied already
fi
git -C "$source" apply --check "$patch" || {
    echo "setup-source.sh: sms-pc-port.patch does not apply to $source (a different upstream revision, or edits not yet saved with --save?)" >&2
    exit 2
}
git -C "$source" apply --whitespace=nowarn "$patch"
echo "setup-source.sh: applied sms-pc-port.patch" >&2
