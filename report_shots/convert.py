#!/usr/bin/env python3
"""Convert every Vtop BMP in /tmp/g10shots to report_shots/ppm/<name>.ppm (P6, 640x480) and
report_shots/png/<name>.png (read back from that PPM, lossless).

Vtop --shot-at writes 640x552: the 640x480 VGA frame on top + a 72 px simulator panel
(7-seg / LEDs / switches) under it. The VGA frame is cut out with a plain crop (no resize);
the panel is not part of the game picture.
Usage: python3 convert.py [src_dir]   (default /tmp/g10shots)
"""
import glob, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/g10shots"
PPM = os.path.join(HERE, "ppm"); PNG = os.path.join(HERE, "png")
os.makedirs(PPM, exist_ok=True); os.makedirs(PNG, exist_ok=True)

for bmp in sorted(glob.glob(os.path.join(SRC, "*.bmp"))):
    name = os.path.splitext(os.path.basename(bmp))[0]
    ppm = os.path.join(PPM, name + ".ppm")
    png = os.path.join(PNG, name + ".png")
    im = Image.open(bmp).convert("RGB")
    assert im.size[0] == 640 and im.size[1] >= 480, im.size
    im.crop((0, 0, 640, 480)).save(ppm, format="PPM")          # BMP -> PPM (P6, 8-bit)
    Image.open(ppm).convert("RGB").save(png, format="PNG")     # PPM -> PNG (read back from the PPM)
    print(name, "->", ppm, png)
