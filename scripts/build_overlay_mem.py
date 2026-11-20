#!/usr/bin/env python3
"""Build mem/ovtile.mem (W5 overlay art) from sprites/overlay.json.

    python scripts/build_overlay_mem.py              build mem/ovtile.mem
    python scripts/build_overlay_mem.py --preview    also write preview/overlay_tiles.png

16 pictures x 32x32 x 12-bit words (address = pic*1024 + y*32 + x): 0 breakable block, 1 spike trap, 2 solid decoration, 3-6 wall torch (4 flame frames),
7 left-wall torch, 8 right-wall torch, 9 wall shield, 10-15 spare.
F0F = see-through (the floor shows). A 16x16 source is scaled exactly 2x (nearest neighbour). "cut" = exact [r,g,b] colours made see-through,
"plate" = [r,g,b] rectangle drawn under the picture (the trap's red base).
Rule 1: a missing / unreadable / empty picture falls back to a simple procedural placeholder with a printed warning. Exit code 0 always (the game builds).
"""
import json
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = 0xF0F
NPIC = 16
NAMES = ["breakable block", "spike trap", "solid decoration", "torch 0", "torch 1", "torch 2", "torch 3", "torch left", "torch right", "wall shield"] + ["spare"] * 6


def to444(r, g, b):
    return (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)


def placeholder(i):
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if i == 0:
        d.rectangle((3, 3, 28, 28), fill=(150, 100, 50, 255), outline=(60, 35, 15, 255))
        d.line((3, 3, 28, 28), fill=(60, 35, 15, 255)); d.line((28, 3, 3, 28), fill=(60, 35, 15, 255))
    elif i == 1:
        d.rectangle((2, 2, 29, 29), fill=(80, 32, 32, 255))
        for x in (6, 14, 22):
            d.polygon([(x, 26), (x + 4, 6), (x + 8, 26)], fill=(220, 220, 230, 255))
    elif i == 2:
        d.rectangle((9, 4, 22, 29), fill=(120, 120, 135, 255), outline=(50, 50, 60, 255))
    return im


def load_pic(i, spec, alpha, warn):
    path = os.path.join(ROOT, spec.get("file", "")) if spec else ""
    if not spec or not os.path.isfile(path):
        warn.append(f"pic {i} ({NAMES[i]}): file missing -> placeholder")
        return placeholder(i), True
    try:
        src = Image.open(path).convert("RGBA")
    except Exception as e:  # pragma: no cover
        warn.append(f"pic {i} ({NAMES[i]}): cannot read {path}: {e} -> placeholder")
        return placeholder(i), True
    if "cell" in spec:                                     # a cell of a sheet: {"cell": [row, col], "cell_size": 16}
        cs = int(spec.get("cell_size", 16))
        r0, c0 = spec["cell"]
        src = src.crop((c0 * cs, r0 * cs, c0 * cs + cs, r0 * cs + cs))
    if spec.get("flip") == "h":
        src = src.transpose(Image.FLIP_LEFT_RIGHT)
    sc = int(spec.get("scale", 2))
    cut = {tuple(c) for c in spec.get("cut", [])}
    if src.width * sc > 32 or src.height * sc > 32:
        warn.append(f"pic {i}: {src.size} x{sc} is larger than 32x32 -> placeholder")
        return placeholder(i), True
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    if "plate" in spec:
        ImageDraw.Draw(out).rectangle((2, 2, 29, 29), fill=tuple(spec["plate"]) + (255,))
    ox, oy = (32 - src.width * sc) // 2, (32 - src.height * sc) // 2
    px = src.load()
    op = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a < alpha or (r, g, b) in cut:
                continue
            for dy in range(sc):
                for dx in range(sc):
                    op[ox + x * sc + dx, oy + y * sc + dy] = (r, g, b, 255)
    if all(op[x, y][3] == 0 for x in range(32) for y in range(32)):
        warn.append(f"pic {i} ({NAMES[i]}): fully transparent -> placeholder")
        return placeholder(i), True
    return out, False


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    root = ROOT
    with open(os.path.join(root, "sprites", "overlay.json"), encoding="utf-8") as f:
        cfg = json.load(f)
    alpha = cfg.get("alpha_threshold", 128)
    warn, words, imgs = [], [], []
    for i in range(NPIC):
        spec = cfg.get("pics", {}).get(str(i))
        if i >= 10 and not spec:
            im, fb = Image.new("RGBA", (32, 32), (0, 0, 0, 0)), False
        else:
            im, fb = load_pic(i, spec, alpha, warn)
        imgs.append(im)
        px = im.load()
        for y in range(32):
            for x in range(32):
                r, g, b, a = px[x, y]
                words.append(KEY if a < 128 else to444(r, g, b))
        print(f"  {i}  {NAMES[i]:18s} {'placeholder' if fb else 'ok'}")
    for w in warn:
        print("WARNING:", w)
    with open(os.path.join(root, "mem", "ovtile.mem"), "w") as f:
        f.write(chr(10).join(f"{w:03x}" for w in words) + chr(10))
    print("Wrote mem/ovtile.mem (%d words)" % (NPIC * 1024))
    if "--preview" in argv:
        sheet = Image.new("RGBA", (10 * 68, 68 * 2), (60, 100, 60, 255))
        for i, im in enumerate(imgs[:10]):
            sheet.paste(im.resize((64, 64), Image.NEAREST), (i * 68 + 2, 2), im.resize((64, 64), Image.NEAREST))
        os.makedirs(os.path.join(root, "preview"), exist_ok=True)
        sheet.save(os.path.join(root, "preview", "overlay_tiles.png"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
