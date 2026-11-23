#!/usr/bin/env python3
"""Figure 14 (monsters, bosses, obstacles) from the game ROMs, all words = 12-bit hex per line, RGB444 (r<<8|g<<4|b), F0F = transparent:
  monster.mem  4 x 32x32,  addr = frame*1024 + y*32 + x, frame = type*2 + anim   (rtl/objline.v maddr, scripts/build_monster_mem.py)
  boss.mem     8 x 64x64,  addr = frame*4096 + y*64 + x, frame = boss*2 + n     (rtl/roms.v bossspr_rom; only frames 0-5 are used)
  ovtile.mem  16 x 32x32,  addr = pic*1024 + y*32 + x, 0 = breakable block Z, 1 = spike trap X   (rtl/roms.v, scripts/build_overlay_mem.py)
  tileset.mem 48 x 32x32,  addr = (floor*16 + tile)*1024 + y*32 + x; floor 0 (= floor 1), tile 1 = "floor" (sprites/tileset.json tile_names, build_maps.py '.')
Output: report_shots/fig14_enemies_bosses_obstacles.png (+ copy in preview/).  HP values come from rtl/params.vh."""
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
def load(name, n): 
    w = [int(l, 16) for l in open(os.path.join(ROOT, "mem", name)).read().split()]; assert len(w) == n, (name, len(w)); return w
MON, BOSS, OVT, TS = load("monster.mem", 4 * 1024), load("boss.mem", 8 * 4096), load("ovtile.mem", 16 * 1024), load("tileset.mem", 48 * 1024)
def decode(words, frame, size, bg=None):
    """RGBA image; transparent (F0F) -> alpha 0, or bg colour when given"""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0)); px = im.load()
    for y in range(size):
        for x in range(size):
            w = words[frame * size * size + y * size + x]
            if w != 0xF0F: px[x, y] = (((w >> 8) & 15) * 17, ((w >> 4) & 15) * 17, (w & 15) * 17, 255)
    if bg is not None:
        base = Image.new("RGBA", (size, size), bg + (255,)); base.alpha_composite(im); im = base
    return im
FLOOR1 = decode(TS, 0 * 16 + 1, 32)                      # floor 1 (index 0), tile 1 = plain floor
def on_floor(pic): t = FLOOR1.copy(); t.alpha_composite(decode(OVT, pic, 32)); return t
P = open(os.path.join(ROOT, "rtl", "params.vh"), encoding="utf-8").read().split("\n")
def param(name):
    for i, l in enumerate(P, 1):
        m = re.search(r"localparam\s+%s\s*=\s*(\d+)" % name, l)
        if m: return int(m.group(1)), i
hp = [param("BOSS%d_HP" % n) for n in (1, 2, 3)]
GREY = (225, 225, 225)
def tw(d, s, f): b = d.textbbox((0, 0), s, font=f); return b[2] - b[0]
def make():
    W, H = 1400, 1000
    im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
    sq, gap = 224, 120
    rows = [("Monsters", 30, [("Chaser", decode(MON, 0, 32), 6, None), ("Turret", decode(MON, 2, 32), 6, None)]),
            ("Bosses", 345, [("Boss 1 (Floor 1)", decode(BOSS, 0, 64), 3, "HP %d" % hp[0][0]), ("Boss 2 (Floor 2)", decode(BOSS, 2, 64), 3, "HP %d" % hp[1][0]),
                             ("Boss 3 (Floor 3)", decode(BOSS, 4, 64), 3, "HP %d (charged hits)" % hp[2][0])]),
            ("Obstacles", 660, [("Spike trap", on_floor(1), 6, None), ("Breakable block", on_floor(0), 6, None)])]
    for r, (title, y0, items) in enumerate(rows):
        if r: d.line([(24, y0 - 15), (W - 24, y0 - 15)], fill=(200, 200, 200), width=1)
        d.text((24, y0 + sq // 2 - 14), title, font=font(24), fill=(130, 130, 130))
        n = len(items); x0 = (W - (n * sq + (n - 1) * gap)) // 2
        for i, (lab, pic, sc, sub) in enumerate(items):
            x = x0 + i * (sq + gap)
            d.rounded_rectangle([x, y0, x + sq - 1, y0 + sq - 1], radius=22, fill=GREY)
            big = pic.resize((192, 192), Image.NEAREST); assert pic.width * sc == 192
            im.paste(big.convert("RGB") if pic.getpixel((0, 0))[3] == 255 else big, (x + 16, y0 + 16), None if pic.getpixel((0, 0))[3] == 255 else big)
            cx = x + sq // 2; f = font(26, True)
            d.text((cx - tw(d, lab, f) / 2, y0 + sq + 12), lab, font=f, fill=(0, 0, 0))
            if sub: f2 = font(20); d.text((cx - tw(d, sub, f2) / 2, y0 + sq + 50), sub, font=f2, fill=(110, 110, 110))
    return im
if __name__ == "__main__":
    os.makedirs(PREV, exist_ok=True)
    M = (255, 0, 255)
    for n, im in (("monsterA0", decode(MON, 0, 32, M)), ("monsterB0", decode(MON, 2, 32, M)), ("boss1", decode(BOSS, 0, 64, M)), ("boss2", decode(BOSS, 2, 64, M)),
                  ("boss3", decode(BOSS, 4, 64, M)), ("ovtile0_block", decode(OVT, 0, 32, M)), ("ovtile1_trap", decode(OVT, 1, 32, M)), ("floor_tile1", FLOOR1)):
        im.save(os.path.join(PREV, "_check_%s.png" % n))
    im = make(); name = "fig14_enemies_bosses_obstacles.png"
    im.save(os.path.join(OUT, name)); shutil.copyfile(os.path.join(OUT, name), os.path.join(PREV, name)); print(name, im.size)
    for i, h in enumerate(hp, 1): print("BOSS%d_HP" % i, h)
