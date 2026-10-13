#!/usr/bin/env python3
"""Super Mario Sunshine for the PlayStation 5 - a placeholder icon0.png (a sun over the sea).

The title needs an icon from its first upload: ShadowMountPlus will not register
a title folder without one. Real art replaces this before any release.

SPDX-License-Identifier: MIT
"""
import math
import sys
from PIL import Image, ImageDraw

size = 512
image = Image.new("RGB", (size, size))
draw = ImageDraw.Draw(image)
for y in range(size):
    t = y / (size - 1)
    draw.line([(0, y), (size, y)], fill=(int(40 + 60 * t), int(150 + 60 * t), int(235 - 15 * t)))
draw.rectangle([0, 360, size, size], fill=(20, 110, 190))
for ray in range(12):
    angle = ray * math.pi / 6
    draw.polygon([(256 + 110 * math.cos(angle - 0.12), 220 + 110 * math.sin(angle - 0.12)),
                  (256 + 190 * math.cos(angle), 220 + 190 * math.sin(angle)),
                  (256 + 110 * math.cos(angle + 0.12), 220 + 110 * math.sin(angle + 0.12))], fill=(255, 205, 40))
draw.ellipse([156, 120, 356, 320], fill=(255, 225, 70))
image.save(sys.argv[1])
