#!/usr/bin/env python3
"""Figure 13: the four hero forms, decoded from mem/player.mem (the ROM the renderer reads).
player.mem: 48 frames x 1024 lines, one 12-bit hex word per line (RGB444 = r<<8 | g<<4 | b), 12'hF0F = transparent,
frame = form*12 + dir*3 + pose, word = y*32 + x   (rtl/roms.v player_rom: addr = frame*1024 + y*32 + x; scripts/build_player_mem.py).
Stats come from rtl/params.vh (SPDn, HPn, melee / shot comments).  Output: report_shots/fig13_hero_forms.png, fig13_hero_forms_4dirs.png (+ copies in preview/)."""
import os, re, shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "report_shots"); PREV = os.path.join(ROOT, "preview")
SCALE = 8
FONT_CANDIDATES = ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/DejaVuSans.ttf", "DejaVuSans.ttf"]
def font(size):
    for f in FONT_CANDIDATES:
        try: return ImageFont.truetype(f, size)
        except OSError: pass
    return ImageFont.load_default(size)

words = [int(l, 16) for l in open(os.path.join(ROOT, "mem", "player.mem")).read().split()]
assert len(words) == 48 * 1024
def frame_image(form, d, pose, bg):
    f = form * 12 + d * 3 + pose
    im = Image.new("RGB", (32, 32), bg); px = im.load()
    for y in range(32):
        for x in range(32):
            w = words[f * 1024 + y * 32 + x]
            if w != 0xF0F: px[x, y] = (((w >> 8) & 15) * 17, ((w >> 4) & 15) * 17, (w & 15) * 17)
    return im

# ---- stats from rtl/params.vh (value + line number)
P = open(os.path.join(ROOT, "rtl", "params.vh"), encoding="utf-8").read().split("\n")
def param(name):
    for i, l in enumerate(P, 1):
        m = re.search(r"localparam\s*(?:\[[^\]]*\]\s*)?%s\s*=\s*(?:\d+')?[dD]?(\d+)" % name, l)
        if m: return int(m.group(1)), i
    return None
STATS = []
for n in range(1, 5):
    hp, spd = param("HP%d" % n), param("SPD%d" % n)
    parts = []
    if hp: parts.append("HP %d" % hp[0])
    if spd: parts.append("speed %d px/frame" % spd[0])
    parts.append("melee" if n == 1 else "shot")        # params.vh: MELEE_* = form 1 (line 30-31), PB_COOLDOWN = forms 2-4 (line 34)
    STATS.append((" | ".join(parts), hp, spd))
NAMES = ["Form 1 - Human", "Form 2 - Orc", "Form 3 - Angel", "Form 4 - Final form"]
GREY = (225, 225, 225); TXT = (0, 0, 0); SUB = (110, 110, 110)

def tw(d, s, f): b = d.textbbox((0, 0), s, font=f); return b[2] - b[0]
def center(d, cx, y, s, f, fill, lo=20, hi=1580): d.text((min(max(cx - tw(d, s, f) / 2, lo), hi - tw(d, s, f)), y), s, font=f, fill=fill)   # keep >= 20 px from the edges

def sprite8(form, d, pose):
    return frame_image(form, d, pose, GREY).resize((32 * SCALE, 32 * SCALE), Image.NEAREST)

def fig_row():
    W, H = 1600, 520
    im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
    sq = 272; gap = (W - 2 * 40 - 4 * sq) // 3; y0 = 40
    for i in range(4):
        x = 40 + i * (sq + gap)
        d.rounded_rectangle([x, y0, x + sq - 1, y0 + sq - 1], radius=24, fill=GREY)
        im.paste(sprite8(i, 0, 0), (x + 8, y0 + 8))
        cx = x + sq // 2
        center(d, cx, y0 + sq + 20, NAMES[i], font(28), TXT)
        center(d, cx, y0 + sq + 70, STATS[i][0], font(20), SUB)
        if i < 3:
            ax0 = x + sq + 20; ax1 = x + sq + gap - 20; ay = y0 + sq // 2
            d.line([ax0, ay, ax1 - 4, ay], fill="black", width=3)
            d.line([ax1 - 20, ay - 12, ax1, ay], fill="black", width=3); d.line([ax1 - 20, ay + 12, ax1, ay], fill="black", width=3)
            center(d, (ax0 + ax1) // 2, ay - 38, "Evolve", font(20), TXT)
    return im

def fig_grid():
    cell = 32 * SCALE; sp = 12; left = 250; top = 60
    W = left + 4 * (cell + sp) + 20; H = top + 4 * (cell + sp) + 20
    im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
    for c, n in enumerate(["Down", "Up", "Left", "Right"]):
        center(d, left + c * (cell + sp) + cell // 2, 16, n, font(28), TXT)
    for r in range(4):
        y = top + r * (cell + sp)
        d.text((20, y + cell // 2 - 14), NAMES[r].replace(" - ", " -\n", 1) if False else NAMES[r], font=font(28) if tw(d, NAMES[r], font(28)) < left - 30 else font(22), fill=TXT)
        for c in range(4):
            x = left + c * (cell + sp)
            im.paste(sprite8(r, c, 0), (x, y)); d.rectangle([x - 1, y - 1, x + cell, y + cell], outline=(90, 90, 90), width=1)
    return im

if __name__ == "__main__":
    os.makedirs(PREV, exist_ok=True)
    frame_image(0, 0, 0, (255, 0, 255)).save(os.path.join(PREV, "_check_frame0.png"))   # 1:1, transparent = magenta (check only)
    for name, im in (("fig13_hero_forms.png", fig_row()), ("fig13_hero_forms_4dirs.png", fig_grid())):
        im.save(os.path.join(OUT, name), optimize=False, compress_level=6)
        print(name, im.size)
    shutil.copyfile(os.path.join(OUT, "fig13_hero_forms.png"), os.path.join(PREV, "fig13_hero_forms.png"))
    shutil.copyfile(os.path.join(OUT, "fig13_hero_forms_4dirs.png"), os.path.join(PREV, "fig13_hero_forms_4dirs.png"))
    for i, (s, hp, spd) in enumerate(STATS, 1): print("Form", i, s, "HP line", hp and hp[1], "speed line", spd and spd[1])
