#!/usr/bin/env python3
"""Figure 14: the three bosses, decoded from mem/boss.mem (rtl/roms.v bossspr_rom: 32768 x 12 bit, addr = frame*4096 + y*64 + x,
RGB444 = r<<8 | g<<4 | b, F0F = transparent; frame = boss*2 + n, rtl/top.v b_frame: boss 1 n=1 is the stunned picture).
HP values are read from rtl/params.vh.  Output: report_shots/fig14_bosses.png, fig14_bosses_stun.png (+ copies in preview/)."""
import os, re, shutil
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "report_shots"); PREV = os.path.join(ROOT, "preview")
def font(size, bold=False):
    for f in (["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/DejaVuSans-Bold.ttf"] if bold else
              ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/DejaVuSans.ttf"]):
        try: return ImageFont.truetype(f, size)
        except OSError: pass
    return ImageFont.load_default(size)
words = [int(l, 16) for l in open(os.path.join(ROOT, "mem", "boss.mem")).read().split()]
assert len(words) == 8 * 4096
def frame_image(f, bg):
    im = Image.new("RGB", (64, 64), bg); px = im.load()
    for y in range(64):
        for x in range(64):
            w = words[f * 4096 + y * 64 + x]
            if w != 0xF0F: px[x, y] = (((w >> 8) & 15) * 17, ((w >> 4) & 15) * 17, (w & 15) * 17)
    return im
P = open(os.path.join(ROOT, "rtl", "params.vh"), encoding="utf-8").read().split("\n")
def param(name):
    for i, l in enumerate(P, 1):
        m = re.search(r"localparam\s+%s\s*=\s*(\d+)" % name, l)
        if m: return int(m.group(1)), i
hp = [param("BOSS%d_HP" % n) for n in (1, 2, 3)]
GREY = (225, 225, 225)
PANELS = [("Boss 1 (Floor 1)", "HP %d" % hp[0][0], 0), ("Boss 2 (Floor 2)", "HP %d" % hp[1][0], 2),
          ("Boss 3 (Floor 3)", "HP %d (charged hits)" % hp[2][0], 4)]
STUN = ("Boss 1 stunned", "same boss, frame 1", 1)
def tw(d, s, f): b = d.textbbox((0, 0), s, font=f); return b[2] - b[0]
def make(panels):
    W, H = 1500, 560
    im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
    sq = 280; n = len(panels); m = 60; gap = (W - 2 * m - n * sq) // (n - 1); y0 = 50
    for i, (lab, sub, f) in enumerate(panels):
        x = m + i * (sq + gap)
        d.rounded_rectangle([x, y0, x + sq - 1, y0 + sq - 1], radius=24, fill=GREY)
        im.paste(frame_image(f, GREY).resize((256, 256), Image.NEAREST), (x + 12, y0 + 12))
        cx = x + sq // 2
        for s, y, ft, col in ((lab, y0 + sq + 24, font(30, True), (0, 0, 0)), (sub, y0 + sq + 76, font(22), (110, 110, 110))):
            xx = min(max(cx - tw(d, s, ft) / 2, 20), W - 20 - tw(d, s, ft)); d.text((xx, y), s, font=ft, fill=col)
    return im
if __name__ == "__main__":
    os.makedirs(PREV, exist_ok=True)
    frame_image(0, (255, 0, 255)).save(os.path.join(PREV, "_check_boss0.png"))
    for name, pan in (("fig14_bosses.png", PANELS), ("fig14_bosses_stun.png", PANELS + [STUN])):
        im = make(pan); im.save(os.path.join(OUT, name)); shutil.copyfile(os.path.join(OUT, name), os.path.join(PREV, name)); print(name, im.size)
    for i, h in enumerate(hp, 1): print("BOSS%d_HP" % i, h)
