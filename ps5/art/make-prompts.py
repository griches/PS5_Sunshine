#!/usr/bin/env python3
"""Super Mario Sunshine for the PlayStation 5 - the DualSense's buttons for the game's prompts.

Makes ps5/res/prompts/playstation.png, which the PC port reads when its button
prompts are set to `playstation` (SMS_BUTTON_PROMPTS): eight 64x64 icons in a
row, standing for the GameCube's A B X Y Z L R and C-stick in that order. The
port's own controller layout puts them on Cross, Circle, Square, Triangle, R1,
L2, R2 and the right stick.

The pictures are Kenney's Input Prompts (www.kenney.nl, CC0: ps5/art/kenney/).
On a PC the port's launcher draws this file from the player's bindings; the
console has no launcher, so the title brings it.

Needs Python with Pillow.

SPDX-License-Identifier: MIT
"""
from pathlib import Path

from PIL import Image

CELL = 64
art = Path(__file__).resolve().parent
order = [
    "playstation_button_cross_outline",     # A
    "playstation_button_circle_outline",    # B
    "playstation_button_square_outline",    # X
    "playstation_button_triangle_outline",  # Y
    "playstation_trigger_r1_outline",       # Z
    "playstation_trigger_l2_outline",       # L
    "playstation_trigger_r2_outline",       # R
    "playstation_stick_r",                  # C-stick
]
sheet = Image.new("RGBA", (CELL * len(order), CELL), (0, 0, 0, 0))
for index, name in enumerate(order):
    picture = Image.open(art / "kenney" / (name + ".png")).convert("RGBA")
    sheet.paste(picture.resize((CELL, CELL), Image.LANCZOS), (index * CELL, 0))
out = art.parent / "res" / "prompts" / "playstation.png"
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(out)
