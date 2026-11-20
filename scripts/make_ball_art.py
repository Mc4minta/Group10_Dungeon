#!/usr/bin/env python3
"""Derive the 4 maze-ball rotation pictures (my_asset/ball/ball_0..3.png, 16x16) from the AXIALE orb sheet (my_asset/ball/orb_rotate.png).

    python scripts/make_ball_art.py

The orb frames are 10x10; each is centred in a 16x16 canvas so that puzzle.mem (x2) draws a 20x20 ball in the 32x32 frame, exactly the size of the
maze collision box. Frames 0, 2, 4, 6 of the 7-frame rotation give a smooth roll. The game picks the picture from the ball position (rolling).
Edit sprites/puzzle.json (frames 10-13) to use other art; this script is only a helper and needs no re-run unless you change the orb PNG.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = Image.open(os.path.join(ROOT, "my_asset", "ball", "orb_rotate.png")).convert("RGBA")
for i, col in enumerate((0, 2, 4, 6)):
    cell = src.crop((col * 10, 0, col * 10 + 10, 10))
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    out.paste(cell, (3, 3))
    out.save(os.path.join(ROOT, "my_asset", "ball", f"ball_{i}.png"))
    print("wrote my_asset/ball/ball_%d.png" % i)
