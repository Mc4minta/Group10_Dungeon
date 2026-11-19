#!/usr/bin/env python3
"""Build mem/hud.mem (hearts for the player, health bar for the boss) from sprites/hud.json.
Rule 1: a missing / unreadable picture -> that page is drawn by a plain built-in shape + a WARNING (exit 1). Broken config -> exit 2.
Usage: python scripts/build_hud_mem.py [--root DIR] [--preview]"""
import json
import os
import sys

from PIL import Image

PAGES = ("heart full", "heart empty", "bar frame", "bar fill")
PAGE_WORDS = 32 * 64
KEY = 0xF0F


def q(v):
    return (v * 15 + 127) // 255


def conv(im, key, alpha):
    """RGBA image (<= 64x32) -> 2048 words, key colour outside / transparent."""
    words = [key] * PAGE_WORDS
    px = im.load()
    for y in range(min(im.height, 32)):
        for x in range(min(im.width, 64)):
            r, g, b, a = px[x, y]
            if a < alpha:
                continue
            w = (q(r) << 8) | (q(g) << 4) | q(b)
            if w == key:
                w = 0xF1F
            words[y * 64 + x] = w
    return words


def load(path):
    with Image.open(path) as im:
        im.load()
        return im.convert("RGBA")


def fb_heart(full):
    shape = ["..#####...#####..", ".#######.#######.", ".###############.", ".###############.", ".###############.",
             ".###############.", "..#############..", "...###########...", "....#########....", ".....#######.....",
             "......#####......", ".......###......."]
    im = Image.new("RGBA", (17, 17), (0, 0, 0, 0))
    for y, row in enumerate(shape):
        for x, c in enumerate(row):
            if c == "#":
                im.putpixel((x, y + 1), (200, 30, 40, 255) if full else (40, 40, 40, 255))
    return im


def fb_bar(fill):
    im = Image.new("RGBA", (49 if fill else 64, 17), (0, 0, 0, 0))
    for y in range(5, 12):
        for x in range(0, im.width):
            if fill:
                im.putpixel((x, y), (210, 30, 40, 255))
            elif x >= 17:
                edge = y in (5, 11) or x == 17 or x == im.width - 1
                im.putpixel((x, y), (30, 20, 30, 255) if not edge else (90, 60, 40, 255))
    if not fill:
        for y in range(1, 15):
            for x in range(1, 16):
                im.putpixel((x, y), (200, 30, 40, 255))
    return im


def compose(paths):
    base = None
    for p in paths:
        im = load(p)
        if im.width > 64 or im.height > 32:
            raise ValueError(f"{os.path.basename(p)} is {im.width}x{im.height}, larger than 64x32")
        if base is not None and im.size != base.size:
            raise ValueError(f"layer sizes differ ({os.path.basename(p)} is {im.width}x{im.height}, expected {base.width}x{base.height})")
        if base is None:
            base = Image.new("RGBA", im.size, (0, 0, 0, 0))
        base.alpha_composite(im)
    return base


def build(cfg, root):
    key = int(cfg.get("key_color", "F0F"), 16)
    alpha = cfg.get("alpha_threshold", 128)
    rel = lambda p: os.path.join(root, p)
    jobs = [
        ("heart full", [rel(cfg["heart"][k]) for k in ("background", "heart", "border")], lambda: fb_heart(True), lambda: compose([rel(cfg["heart"][k]) for k in ("background", "heart", "border")])),
        ("heart empty", [rel(cfg["heart"][k]) for k in ("background", "border")], lambda: fb_heart(False), lambda: compose([rel(cfg["heart"][k]) for k in ("background", "border")])),
        ("bar frame", [rel(cfg["bar"]["frame"])], lambda: fb_bar(False), lambda: load(rel(cfg["bar"]["frame"]))),
        ("bar fill", [rel(cfg["bar"]["fill"])], lambda: fb_bar(True), lambda: load(rel(cfg["bar"]["fill"]))),
    ]
    words, warns, imgs = [], [], []
    for name, files, fallback, real in jobs:
        try:
            missing = [f for f in files if not os.path.isfile(f)]
            if missing:
                raise FileNotFoundError(os.path.basename(missing[0]) + " missing")
            im = real()
            if im.width > 64 or im.height > 32:
                raise ValueError(f"{im.width}x{im.height} is larger than 64x32")
            if im.getchannel("A").getextrema()[1] < alpha:
                raise ValueError("fully transparent")
        except Exception as e:
            warns.append(f"WARNING: hud page '{name}': {e} -> using the plain built-in shape")
            im = fallback()
        imgs.append(im)
        words += conv(im, key, alpha)
    return words, warns, imgs


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if "--root" in argv:
        root = os.path.abspath(argv[argv.index("--root") + 1])
    try:
        with open(os.path.join(root, "sprites", "hud.json"), encoding="utf-8") as f:
            cfg = json.load(f)
        words, warns, imgs = build(cfg, root)
    except Exception as e:
        print(f"ERROR: broken hud config: {e}")
        return 2
    out = os.path.join(root, cfg.get("output_mem", "mem/hud.mem"))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    text = "".join(f"{w:03X}\n" for w in words)
    old = open(out, encoding="ascii", newline="").read().replace("\r\n", "\n") if os.path.isfile(out) else None
    if old != text:
        with open(out, "w", encoding="ascii", newline="") as f:
            f.write(text)
        print(f"Wrote {os.path.relpath(out, root)} ({len(words)} words)")
    else:
        print("Unchanged mem/hud.mem")
    for w in warns:
        print(w)
    if "--preview" in argv:
        os.makedirs(os.path.join(root, "preview"), exist_ok=True)
        sheet = Image.new("RGBA", (4 * 140, 80), (60, 60, 90, 255))
        for i, im in enumerate(imgs):
            big = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
            sheet.alpha_composite(big, (i * 140 + 4, 4))
        sheet.save(os.path.join(root, "preview", "hud_sheet.png"))
    print(f"Summary: {4 - len(warns)}/4 pages from your art, {len(warns)} fallback")
    return 1 if warns else 0


if __name__ == "__main__":
    sys.exit(main())
