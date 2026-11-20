#!/usr/bin/env python3
"""W26: build my_asset/props/plate_box.png = the pressed Sokoban plate WITH the box on it (the owner's plate.png has no box).

    python scripts/make_plate_box.py

Row 0 = the raised plate (copy of plate.png row 0), row 1 = pressed plate (plate.png row 1) with the box (box_1_1.png, 2x like the puzzle object)
drawn on top, plus a green rim on the plate edge so 'pressed' still reads. sprites/tileset.json tile 11 uses this file, cell [1, 0].
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
plate = Image.open(os.path.join(ROOT, "my_asset", "props", "plate.png")).convert("RGBA")
box = Image.open(os.path.join(ROOT, "my_asset", "props", "box_1_1.png")).convert("RGBA")
sc = 32 // box.width if box.width and 32 % box.width == 0 else 2
box = box.resize((box.width * sc, box.height * sc), Image.NEAREST)
out = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
out.paste(plate.crop((0, 0, 32, 32)), (0, 0))
pressed = plate.crop((0, 32, 32, 64))
# green rim on the plate border (only on pixels that the box leaves visible)
px = pressed.load()
for y in range(32):
    for x in range(32):
        if (x in (0, 31) or y in (0, 31)) and px[x, y][3] > 0:
            px[x, y] = (90, 220, 110, 255)
pressed.alpha_composite(box, ((32 - box.width) // 2, (32 - box.height) // 2))
out.paste(pressed, (0, 32))
out.save(os.path.join(ROOT, "my_asset", "props", "plate_box.png"))
print("wrote my_asset/props/plate_box.png (box %dx%d)" % box.size)
