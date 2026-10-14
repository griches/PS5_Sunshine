# Super Mario Sunshine for the PlayStation 5 - the builder kit's tools: found on this machine, or fetched once.
#
# Sourced by build-title.sh. Sets kit_clang (LLVM 22's clang, with lld and the
# LLVM tools beside it), and puts CMake and Ninja on PATH. Each comes from this
# machine when it has a version that works:
#
#   LLVM 22    PS5_CLANG, /usr/lib/llvm-22 (apt.llvm.org), clang-22 on PATH, or
#              Homebrew's llvm@22 with lld beside it
#   CMake      3.20 to 3.x on PATH (CMake 4 drops what SDL's build still asks for)
#   Ninja      on PATH
#
# and otherwise from its project's own release for this kind of machine, checked
# against the SHA-256 below and kept in the kit's cache (KIT_CACHE; by default
# ~/Library/Caches/sunshine-ps5-kit on a Mac, ~/.cache/sunshine-ps5-kit on Linux),
# so it is fetched once for every kit. LLVM's release is the large one: about
# 1.5 GB to fetch (1.9 GB for Linux), of which about 450 MB is kept.
#
# On Ubuntu and Debian (and WSL), apt.llvm.org's packages are the better way to
# LLVM 22, and the kit's README says so: LLVM's own Linux build needs
# libxml2.so.2, which Ubuntu 26.04 and Debian 13 no longer have (they moved to
# libxml2.so.16). It is fetched only where the libraries it needs are there.
#
# Bash 3.2 (a Mac's) runs this: no associative arrays.
#
# SPDX-License-Identifier: MIT

kit_llvm_version=22.1.8
kit_cmake_version=3.31.12
kit_ninja_version=1.13.2

kit_os=$(uname -s)
kit_arch=$(uname -m)
case $kit_os-$kit_arch in
Darwin-arm64)
    kit_llvm_asset=LLVM-$kit_llvm_version-macOS-ARM64.tar.xz
    kit_llvm_sha=f260f4f7c0d430828a81ae8a3826a1d63fc0963ec2459489308cc23b1f7eab4f
    ;;
Linux-x86_64)
    kit_llvm_asset=LLVM-$kit_llvm_version-Linux-X64.tar.xz
    kit_llvm_sha=df0e1ecf16caf3489a272a5eea4eec9b0d82878f6477fa309504f918a0006384
    ;;
Linux-aarch64 | Linux-arm64)
    kit_llvm_asset=LLVM-$kit_llvm_version-Linux-ARM64.tar.xz
    kit_llvm_sha=805efad2bb91cb4967fa569e0881d10c0f69c04461cf671cccbae19f547acc34
    ;;
*) kit_llvm_asset= ;; # (an Intel Mac: LLVM publishes no build for it)
esac
case $kit_os-$kit_arch in
Darwin-*)
    kit_cmake_asset=cmake-$kit_cmake_version-macos-universal.tar.gz
    kit_cmake_sha=799af7fd545db9bf1b9cfe72f8095880e727a2d4e0df0e3dffc3bc7b95c2d3b0
    kit_cmake_bin=CMake.app/Contents/bin
    kit_ninja_asset=ninja-mac.zip
    kit_ninja_sha=c99048673aa765960a99cf10c6ddb9f1fad506099ff0a0e137ad8960a88f321b
    ;;
Linux-x86_64)
    kit_cmake_asset=cmake-$kit_cmake_version-linux-x86_64.tar.gz
    kit_cmake_sha=0dc2e9a6860f06bf10bd8fadc03e35d9eeb4df46e33763a7e480e987758f385c
    kit_cmake_bin=bin
    kit_ninja_asset=ninja-linux.zip
    kit_ninja_sha=5749cbc4e668273514150a80e387a957f933c6ed3f5f11e03fb30955e2bbead6
    ;;
Linux-aarch64 | Linux-arm64)
    kit_cmake_asset=cmake-$kit_cmake_version-linux-aarch64.tar.gz
    kit_cmake_sha=83f8fd91d2038a56556e1400390fcfe42f79602940c494f6c6f1cdae7f9e7f40
    kit_cmake_bin=bin
    kit_ninja_asset=ninja-linux-aarch64.zip
    kit_ninja_sha=fd2cacc8050a7f12a16a2e48f9e06fca5c14fc4c2bee2babb67b58be17a607fc
    ;;
*) kit_cmake_asset= kit_ninja_asset= ;;
esac

if [[ -n ${KIT_CACHE:-} ]]; then
    kit_cache=$KIT_CACHE
elif [[ $kit_os == Darwin ]]; then
    kit_cache=$HOME/Library/Caches/sunshine-ps5-kit
else
    kit_cache=${XDG_CACHE_HOME:-$HOME/.cache}/sunshine-ps5-kit
fi

kit_sha256() { python3 -c 'import hashlib,sys; h=hashlib.sha256(); f=open(sys.argv[1],"rb"); [h.update(b) for b in iter(lambda: f.read(1<<20), b"")]; print(h.hexdigest())' "$1"; }

# kit_fetch URL SHA256 FILE: download, check, and keep it only if it matches
kit_fetch() {
    local url=$1 sha=$2 file=$3
    mkdir -p "$(dirname "$file")"
    # (one already here, from a run stopped while unpacking it)
    [[ -f $file && $(kit_sha256 "$file") == "$sha" ]] && return 0
    if command -v curl > /dev/null; then
        curl -fL --retry 3 --progress-bar -o "$file.part" "$url" || { rm -f "$file.part"; return 1; }
    elif command -v wget > /dev/null; then
        wget -q --show-progress -O "$file.part" "$url" || { rm -f "$file.part"; return 1; }
    else
        echo "tools.sh: curl or wget is needed to download $url" >&2
        return 1
    fi
    if [[ $(kit_sha256 "$file.part") != "$sha" ]]; then
        rm -f "$file.part"
        echo "tools.sh: $url did not download correctly (its SHA-256 is not the expected one); try again" >&2
        return 1
    fi
    mv "$file.part" "$file"
}

kit_is_llvm22() {
    [[ -x $1 ]] && "$1" --version 2>/dev/null | head -1 | grep -q "version 22\." || return 1
    local bin
    bin=$(dirname "$(kit_realpath "$1")")
    local tool
    for tool in ld.lld llvm-ar llvm-nm llvm-config llvm-objcopy llvm-strip; do
        [[ -x $bin/$tool ]] || return 1
    done
    # (lld needs a library clang does not: it has to run too)
    "$bin/ld.lld" --version > /dev/null 2>&1
}

# The shared libraries LLVM's own Linux build needs, that this machine lacks
kit_llvm_missing_libraries() {
    [[ $kit_os == Linux ]] || return 0
    local cache library
    cache=$( (ldconfig -p || /sbin/ldconfig -p) 2>/dev/null)
    for library in libz.so.1 libstdc++.so.6 libgcc_s.so.1 libxml2.so.2; do
        grep -q "^[[:space:]]*$library " <<< "$cache" || printf '%s ' "$library"
    done
}

kit_llvm_advice() {
    echo "tools.sh: install LLVM 22 from apt.llvm.org (about 150 MB), then run this again:" >&2
    echo "    sudo apt install -y lsb-release wget gnupg software-properties-common" >&2
    echo "    curl -fsSL https://apt.llvm.org/llvm.sh -o /tmp/llvm.sh && sudo bash /tmp/llvm.sh 22 && sudo apt install -y llvm-22" >&2
}

kit_realpath() { python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }

kit_find_llvm() {
    local candidate
    if [[ -n ${PS5_CLANG:-} ]]; then
        kit_is_llvm22 "$PS5_CLANG" && { kit_clang=$(kit_realpath "$PS5_CLANG"); return 0; }
        echo "tools.sh: PS5_CLANG ($PS5_CLANG) is not LLVM 22's clang with lld, llvm-ar, llvm-nm, llvm-config, llvm-objcopy and llvm-strip beside it" >&2
        return 1
    fi
    for candidate in /usr/lib/llvm-22/bin/clang "$(command -v clang-22 || true)" \
            /opt/homebrew/opt/llvm@22/bin/clang /usr/local/opt/llvm@22/bin/clang \
            "$kit_cache/llvm-$kit_llvm_version/bin/clang"; do
        [[ -n $candidate ]] && kit_is_llvm22 "$candidate" && { kit_clang=$(kit_realpath "$candidate"); return 0; }
    done
    [[ -n $kit_llvm_asset ]] || {
        echo "tools.sh: LLVM 22 was not found, and LLVM publishes no build for $kit_os on $kit_arch to fetch." >&2
        echo "tools.sh: install LLVM 22 with lld (Homebrew: brew install llvm@22 lld@22) and set PS5_CLANG to its clang." >&2
        return 1
    }
    local missing
    missing=$(kit_llvm_missing_libraries)
    if [[ -n $missing ]]; then
        echo "tools.sh: LLVM 22 was not found, and LLVM's own Linux build would not run here: it needs ${missing% }." >&2
        kit_llvm_advice
        return 1
    fi
    local dest="$kit_cache/llvm-$kit_llvm_version" top=${kit_llvm_asset%.tar.xz}
    echo "==> fetching LLVM $kit_llvm_version, the compiler (about 1.5 GB, once: it is kept in $kit_cache)"
    kit_fetch "https://github.com/llvm/llvm-project/releases/download/llvmorg-$kit_llvm_version/$kit_llvm_asset" \
        "$kit_llvm_sha" "$kit_cache/$kit_llvm_asset" || return 1
    echo "==> unpacking the parts of it the build uses"
    rm -rf "$dest.part"
    mkdir -p "$dest.part"
    local members=() name
    for name in clang clang-22 clang++ lld ld.lld llvm-ar llvm-ranlib llvm-nm llvm-config llvm-objcopy llvm-strip \
            llvm-readobj llvm-readelf; do
        members+=("$top/bin/$name")
    done
    members+=("$top/lib/clang/22/include")
    tar -xJf "$kit_cache/$kit_llvm_asset" -C "$dest.part" "${members[@]}" || return 1
    rm -rf "$dest"
    mv "$dest.part/$top" "$dest"
    rm -rf "$dest.part" "$kit_cache/$kit_llvm_asset"
    kit_is_llvm22 "$dest/bin/clang" || {
        echo "tools.sh: the LLVM fetched into $dest does not run here" >&2
        [[ $kit_os == Linux ]] && kit_llvm_advice
        return 1
    }
    kit_clang=$dest/bin/clang
}

kit_cmake_works() {
    local version
    version=$("$1" --version 2>/dev/null | head -1 | sed -n 's/^cmake version \([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
    [[ -n $version ]] || return 1
    set -- $version
    [[ $1 -eq 3 && $2 -ge 20 ]]
}

kit_find_cmake() {
    local found
    found=$(command -v cmake || true)
    [[ -n $found ]] && kit_cmake_works "$found" && return 0
    local dest="$kit_cache/cmake-$kit_cmake_version"
    if [[ ! -x $dest/$kit_cmake_bin/cmake ]]; then
        [[ -n $kit_cmake_asset ]] || { echo "tools.sh: CMake 3.20 or later (but not 4) is needed" >&2; return 1; }
        echo "==> fetching CMake $kit_cmake_version (about 60 MB, once)"
        kit_fetch "https://github.com/Kitware/CMake/releases/download/v$kit_cmake_version/$kit_cmake_asset" \
            "$kit_cmake_sha" "$kit_cache/$kit_cmake_asset" || return 1
        rm -rf "$dest" "$dest.part"
        mkdir -p "$dest.part"
        tar -xzf "$kit_cache/$kit_cmake_asset" -C "$dest.part" || return 1
        mv "$dest.part/${kit_cmake_asset%.tar.gz}" "$dest"
        rm -rf "$dest.part" "$kit_cache/$kit_cmake_asset"
    fi
    PATH=$dest/$kit_cmake_bin:$PATH
}

kit_find_ninja() {
    ninja --version > /dev/null 2>&1 && return 0
    local dest="$kit_cache/ninja-$kit_ninja_version"
    if [[ ! -x $dest/ninja ]]; then
        [[ -n $kit_ninja_asset ]] || { echo "tools.sh: Ninja is needed" >&2; return 1; }
        echo "==> fetching Ninja $kit_ninja_version"
        kit_fetch "https://github.com/ninja-build/ninja/releases/download/v$kit_ninja_version/$kit_ninja_asset" \
            "$kit_ninja_sha" "$kit_cache/$kit_ninja_asset" || return 1
        mkdir -p "$dest"
        python3 -m zipfile -e "$kit_cache/$kit_ninja_asset" "$dest" && chmod +x "$dest/ninja" || return 1
        rm -f "$kit_cache/$kit_ninja_asset"
    fi
    PATH=$dest:$PATH
}

# What no download supplies: say what to install, for this machine
kit_check_basics() {
    local missing=() tool
    for tool in git python3 patch tar; do
        command -v "$tool" > /dev/null || missing+=("$tool")
    done
    # a Mac's python3 and git are stand-ins until the Command Line Tools are installed
    if [[ $kit_os == Darwin ]] && ! xcode-select -p > /dev/null 2>&1; then
        echo "build-title.sh: this Mac needs Apple's Command Line Tools (git, Python and a C++ compiler)." >&2
        echo "build-title.sh: run   xcode-select --install   and start this again once they are installed." >&2
        return 1
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "build-title.sh: missing: ${missing[*]}" >&2
        [[ $kit_os == Linux ]] && echo "build-title.sh: on Ubuntu or Debian (and WSL): sudo apt install git python3 patch xz-utils curl" >&2
        return 1
    fi
}
