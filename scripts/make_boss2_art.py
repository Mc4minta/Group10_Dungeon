#!/usr/bin/env python3
"""Derive the boss-2 sheet (my_asset/enemies/boss2_priest.png, 2 cells of 32x32) from the 2D Pixel Dungeon Asset Pack: the blue-sparked priest (priest1 v2),
a robed caster that fits a boss who SUMMONS minions.

    python scripts/make_boss2_art.py

Needs my_asset/2D Pixel Dungeon Asset Pack v2.0.zip. Frames 1 and 3 of the 4-frame idle are centred in 32x32 cells (cell 0, cell 1). sprites/bosses.json
uses them as boss 2 (frames = sheet "priest", cols 0 and 1). Re-run only if you change the source frames.
"""
import io
import os
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIP = os.path.join(ROOT, "my_asset", "2D Pixel Dungeon Asset Pack v2.0.zip")
BASE = "2D Pixel Dungeon Asset Pack/Character_animation/priests_idle/priest1/v2/priest1_v2_%d.png"
zf = zipfile.ZipFile(ZIP)
sheet = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
for cell, frame in enumerate((1, 3)):
    im = Image.open(io.BytesIO(zf.read(BASE % frame))).convert("RGBA")
    sheet.paste(im, (cell * 32 + 8, 8))
out = os.path.join(ROOT, "my_asset", "enemies", "boss2_priest.png")
sheet.save(out)
print("wrote", os.path.relpath(out, ROOT))
