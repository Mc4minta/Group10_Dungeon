#!/usr/bin/env python3
"""Final check: for every figure 20..37 a PPM (P6, 640x480, 8-bit) and a PNG (640x480 RGB, pixel-identical to the PPM) exist, no image is one colour."""
import os, sys
from PIL import Image, ImageChops
HERE = os.path.dirname(os.path.abspath(__file__))
NAMES = ["fig20_title","fig21_play","fig22_melee","fig23_shooting","fig24_cleared","fig25_lightbulb_start","fig26_lightbulb_solved",
         "fig27_sokoban_start","fig28_sokoban_gate_open","fig29_simon_show","fig30_simon_solved","fig31_boss1","fig32_boss2","fig33_boss3",
         "fig34_floor_clear","fig35_escape_maze","fig36_win","fig37_gameover"]
bad = 0
for n in NAMES:
    ppm = os.path.join(HERE, "ppm", n + ".ppm"); png = os.path.join(HERE, "png", n + ".png")
    errs = []
    if not os.path.exists(ppm): errs.append("PPM missing")
    if not os.path.exists(png): errs.append("PNG missing")
    if not errs:
        with open(ppm, "rb") as f: hdr = f.read(16).split()
        if hdr[0] != b"P6" or hdr[1:4] != [b"640", b"480", b"255"]: errs.append(f"PPM header {hdr[:4]}")
        a = Image.open(ppm); b = Image.open(png)
        if a.size != (640, 480) or b.size != (640, 480): errs.append(f"size {a.size} {b.size}")
        if b.mode != "RGB": errs.append(f"PNG mode {b.mode}")
        if ImageChops.difference(a.convert("RGB"), b.convert("RGB")).getbbox() is not None: errs.append("PNG differs from PPM")
        if len(a.convert("RGB").getcolors(1 << 24)) < 2: errs.append("single colour")
    print(("OK   " if not errs else "FAIL ") + n, "; ".join(errs)); bad += bool(errs)
print("ALL OK" if not bad else f"{bad} FAILED"); sys.exit(1 if bad else 0)
