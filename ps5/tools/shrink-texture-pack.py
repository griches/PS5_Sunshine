#!/usr/bin/env python3
"""Super Mario Sunshine for the PlayStation 5 - a texture pack sized for the console.

    shrink-texture-pack.py SOURCE DEST [MAX]

Copies a Dolphin texture pack, making every BC7 .dds wider or taller than MAX
(2048) that size with a full mipmap chain. The PS5's OpenGL driver takes
texture data slowly (about 35 MiB a second) and a title's graphics memory is
limited: the UHD pack's 4096 and 8192 pixel images are two thirds of its 3 GB,
cost Delfino Plaza a 17 second load, and ran Bianco Hills out of memory.
Needs Python with Pillow and etcpak.

SPDX-License-Identifier: MIT
"""
import os, shutil, struct, sys
from multiprocessing import Pool
from PIL import Image
import etcpak

Image.MAX_IMAGE_PIXELS = None


def blocks(image):
    w, h = image.size
    pw, ph = (w + 3) // 4 * 4, (h + 3) // 4 * 4
    if (pw, ph) != (w, h):  # the small levels: repeat the edge into the 4x4 block
        image = image.resize((pw, ph), Image.NEAREST)
    # the parameters are not optional: without them etcpak crashes
    return etcpak.compress_bc7(image.tobytes(), pw, ph, etcpak.BC7CompressBlockParams())


def convert(job):
    source, dest, limit = job
    header = bytearray(open(source, "rb").read(148))
    height, width = struct.unpack_from("<II", header, 12)
    dxgi = struct.unpack_from("<I", header, 128)[0] if header[84:88] == b"DX10" else 0
    if max(width, height) <= limit or dxgi not in (98, 99):
        shutil.copyfile(source, dest)
        return 0
    image = Image.open(source).convert("RGBA")
    scale = limit / max(width, height)
    w, h = max(4, round(width * scale)), max(4, round(height * scale))
    levels = []
    while True:
        level = image.resize((w, h), Image.LANCZOS)
        levels.append(blocks(level))
        if w == 1 and h == 1:
            break
        w, h = max(1, w // 2), max(1, h // 2)
    w, h = max(4, round(width * scale)), max(4, round(height * scale))
    struct.pack_into("<I", header, 8, struct.unpack_from("<I", header, 8)[0] | 0x20000 | 0x80000)  # mip count, linear size
    struct.pack_into("<II", header, 12, h, w)
    struct.pack_into("<I", header, 20, len(levels[0]))
    struct.pack_into("<I", header, 28, len(levels))
    struct.pack_into("<I", header, 108, 0x401008)  # complex, mipmapped texture
    with open(dest, "wb") as out:
        out.write(header)
        for level in levels:
            out.write(level)
    return 1


def main():
    source, dest = sys.argv[1], sys.argv[2]
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 2048
    jobs = []
    for root, _, files in os.walk(source):
        target = os.path.join(dest, os.path.relpath(root, source))
        os.makedirs(target, exist_ok=True)
        for name in files:
            if name.startswith("."):
                continue
            path = os.path.join(root, name)
            if name.endswith(".dds"):
                jobs.append((path, os.path.join(target, name), limit))
            else:
                shutil.copyfile(path, os.path.join(target, name))
    with Pool() as pool:
        made = sum(pool.imap_unordered(convert, jobs, chunksize=4))
    print("%d images, %d made smaller" % (len(jobs), made))


if __name__ == "__main__":
    main()
