# Super Mario Sunshine for the PlayStation 5 - the builder kit's container: a Linux with what
# build-title.sh needs (LLVM 22, CMake, Ninja, git, Python 3, a host C++ compiler) and the kit.
#
#   docker build -t sunshine-ps5-kit .
#   docker run --rm -v "$PWD/out":/out sunshine-ps5-kit /out
#
# make-title.sh does both. Nothing of the game is in the image: its source code
# is fetched when the container runs, and what it makes goes to /out.
#
# SPDX-License-Identifier: MIT
FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates wget git patch python3 g++ zlib1g-dev cmake ninja-build \
        python3-pip python3-pil 7zip \
 && pip3 install --break-system-packages --no-cache-dir etcpak \
 && wget -qO /etc/apt/trusted.gpg.d/apt.llvm.org.asc https://apt.llvm.org/llvm-snapshot.gpg.key \
 && echo "deb https://apt.llvm.org/noble/ llvm-toolchain-noble-22 main" > /etc/apt/sources.list.d/llvm.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends clang-22 lld-22 llvm-22 \
 && rm -rf /var/lib/apt/lists/*
COPY . /kit
RUN bash /kit/build-title.sh --tools
WORKDIR /out
ENTRYPOINT ["bash", "/kit/build-title.sh"]
