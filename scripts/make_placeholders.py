#!/usr/bin/env python3
"""สร้าง sprite placeholder (ใช้จนกว่า sprite จริงจาก sprite_tool จะเสร็จ)

mem/tileset.mem : 3 ชั้น x 16 tile x 32x32, address = (floor*16 + tile)*1024 + y*32 + x
mem/player.mem  : 4 ร่าง x 4 ทิศ x 3 ท่า = 48 เฟรม 32x32, address = frame*1024 + y*32 + x
                  frame = form*12 + dir*3 + pose  (dir: 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา, pose: 0 idle 1 ก้าวA 2 ก้าวB)
mem/monster.mem : 4 เฟรม 32x32 = มอน A เฟรม 0,1 แล้วมอน B เฟรม 0,1 (frame = type*2 + anim)
mem/bullet.mem  : 8 เฟรม 16x16 = ร่าง 2, ศัตรู, ร่าง 3 กระจาย, ร่าง 4 เร็ว, ร่าง 4 ลูกใหญ่ (address = frame*256 + y*16 + x)
mem/effect.mem  : เอฟเฟกต์ฟันประชิด 4 เฟรม 32x32 ตามทิศ (0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา)
                  วาดที่ (px, py+24) / (px, py-24) / (px-24, py) / (px+24, py) ทับ hit box 24x16
ทุกสีเป็น RGB444 (hex 3 หลัก), F0F = โปร่งใส
ไฟล์ PNG preview อยู่ใน docs/

แทนที่ด้วยไฟล์จริงได้เลย ขอแค่ขนาดและลำดับเฟรมเหมือนกัน
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 0xF0F

FLOOR_PAL = [  # (wall, wall_line, floor, floor_alt)
    (0x335, 0x224, 0xCCB, 0xBBA),   # ชั้น 1
    (0x233, 0x122, 0x9AA, 0x899),   # ชั้น 2
    (0x432, 0x321, 0xDCA, 0xCB9),   # ชั้น 3
]
SIMON = [0xE33, 0x3C3, 0x36E, 0xEC2]


def blank(c):
    return [[c] * 32 for _ in range(32)]


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            img[y][x] = c


def tile(floor, tid):
    wall, wline, fl, fl2 = FLOOR_PAL[floor]

    def floor_img():
        img = blank(fl)
        for y in range(32):
            for x in range(32):
                if (x // 8 + y // 8) % 2:
                    img[y][x] = fl2
        return img

    if tid == 0:  # wall
        img = blank(wall)
        for y in range(32):
            for x in range(32):
                if y % 8 == 0 or (x + (8 if (y // 8) % 2 else 0)) % 16 == 0:
                    img[y][x] = wline
        return img
    if tid in (2, 8):  # door closed / open
        img = floor_img() if tid == 8 else blank(0x642)
        rect(img, 0, 0, 32, 2, 0x000); rect(img, 0, 30, 32, 32, 0x000)
        if tid == 2:
            rect(img, 4, 14, 28, 18, 0x321)
        return img
    if tid in (3, 9):  # boss door
        img = blank(0x722) if tid == 3 else floor_img()
        rect(img, 0, 0, 32, 3, 0xEB2); rect(img, 0, 29, 32, 32, 0xEB2)
        if tid == 3:
            rect(img, 13, 10, 19, 22, 0xEB2)  # ตัวล็อก
        return img
    if tid in (4, 10):  # exit door
        img = blank(0x252) if tid == 4 else blank(0x8E8)
        rect(img, 0, 0, 32, 3, 0xFFF); rect(img, 0, 29, 32, 32, 0xFFF)
        return img
    if tid == 5:  # hole
        img = blank(0x000)
        rect(img, 0, 0, 32, 3, 0x222)
        return img
    if tid == 6:  # fence: floor + bars
        img = floor_img()
        for x in range(2, 32, 8):
            rect(img, x, 0, x + 3, 32, 0x555)
        rect(img, 0, 6, 32, 9, 0x555); rect(img, 0, 23, 32, 26, 0x555)
        return img
    if tid in (7, 11):  # plate / plate active
        img = floor_img()
        rect(img, 4, 4, 28, 28, 0x777 if tid == 7 else 0x4C4)
        rect(img, 8, 8, 24, 24, 0x999 if tid == 7 else 0x8F8)
        if tid == 11:  # กล่องวางบนแผ่น (ขอบแผ่นเขียวโผล่รอบกล่อง)
            rect(img, 6, 6, 26, 26, 0x000); rect(img, 7, 7, 25, 25, 0xA62)
            rect(img, 7, 7, 25, 9, 0xC84)
            for t in range(16):
                rect(img, 8 + t, 8 + t, 10 + t, 10 + t, 0x741)
        return img
    if 12 <= tid <= 15:  # Simon plates
        img = floor_img()
        c = SIMON[tid - 12]
        rect(img, 1, 1, 31, 31, 0x222); rect(img, 3, 3, 29, 29, c)
        return img
    return floor_img()  # 1 floor + spare


FORM_COL = [(0x3B4, 0x172), (0x3BE, 0x17A), (0xA5D, 0x62A), (0xEB3, 0xA71)]


def player(form, d, pose):
    img = blank(T)
    body, dark = FORM_COL[form]
    rect(img, 6, 6, 26, 24, 0x000); rect(img, 7, 7, 25, 23, body)      # ตัว (ใน hitbox 4..27)
    lo, ro = {0: (0, 0), 1: (-2, 2), 2: (2, -2)}[pose]                # ขา
    rect(img, 9, 24 + max(lo, 0), 14, 28 + min(lo, 0) + 0, 0x000)
    rect(img, 18, 24 + max(ro, 0), 23, 28 + min(ro, 0) + 0, 0x000)
    if form >= 2:  # ร่าง 3-4 มีปีก (เห็นรูปทรงต่าง ไม่ใช่แค่สี)
        rect(img, 1, 10, 6, 18, dark); rect(img, 26, 10, 31, 18, dark)
    if form == 3:  # ร่าง 4 มีหมวก
        rect(img, 8, 2, 24, 6, 0x222)
    # ตา บอกทิศ
    eye = {0: [(11, 12), (19, 12)], 1: [], 2: [(9, 11)], 3: [(21, 11)]}[d]
    for ex, ey in eye:
        rect(img, ex, ey, ex + 3, ey + 3, 0xFFF)
    if d == 1:  # หันหลัง: แถบหลัง
        rect(img, 10, 9, 22, 11, dark)
    return img


def monster(kind, anim):
    img = blank(T)
    if kind == 0:  # มอน A: ก้อนแดงมีตา ไล่ผู้เล่น (ขยับขา 2 เฟรม)
        rect(img, 5, 6, 27, 25, 0x000); rect(img, 6, 7, 26, 24, 0xC33)
        rect(img, 8, 9, 24, 12, 0xE66)
        rect(img, 10, 13, 14, 17, 0xFFF); rect(img, 18, 13, 22, 17, 0xFFF)
        rect(img, 11, 14, 13, 16, 0x000); rect(img, 19, 14, 21, 16, 0x000)
        rect(img, 11, 20, 21, 22, 0x400)
        lo = 0 if anim == 0 else 2
        rect(img, 8, 25, 13, 28 - lo, 0x000); rect(img, 19, 25, 24, 26 + lo, 0x000)
    else:          # มอน B: ป้อมสี่เหลี่ยม ปากกระบอก 4 ทิศ (เฟรม 1 ปากกระบอกเรือง)
        muz = 0x333 if anim == 0 else 0xF82
        rect(img, 7, 7, 25, 25, 0x000); rect(img, 8, 8, 24, 24, 0x778)
        rect(img, 12, 12, 20, 20, 0x445); rect(img, 14, 14, 18, 18, 0xE33)
        rect(img, 13, 1, 19, 8, 0x000); rect(img, 14, 2, 18, 8, muz)       # บน
        rect(img, 13, 24, 19, 31, 0x000); rect(img, 14, 24, 18, 30, muz)   # ล่าง
        rect(img, 1, 13, 8, 19, 0x000); rect(img, 2, 14, 8, 18, muz)       # ซ้าย
        rect(img, 24, 13, 31, 19, 0x000); rect(img, 24, 14, 30, 18, muz)   # ขวา
    return img


def bullet(kind):
    """กระสุน 16x16 ต่อเฟรม: 0 ร่าง 2 ฟ้า-ขาว, 1 ศัตรู แดง-เหลือง, 2 ร่าง 3 เขียว, 3 ร่าง 4 นัดเร็ว เหลือง-ขาว (8x8 มุมซ้ายบน)
    4 ลูกใหญ่ร่าง 4 (16x16 ส้ม-ขาว มีขอบเรือง)"""
    img = [[T] * 16 for _ in range(16)]
    if kind == 4:
        for y in range(16):
            for x in range(16):
                d = (x - 7.5) ** 2 + (y - 7.5) ** 2
                if d <= 60: img[y][x] = 0xF60
                if d <= 36: img[y][x] = 0xFA2
                if d <= 12: img[y][x] = 0xFFF
        return img
    outer, inner = [(0x0AF, 0xFFF), (0xE20, 0xFE4), (0x2C3, 0xBFB), (0xEE0, 0xFFF)][kind]
    for y in range(8):
        for x in range(8):
            d = (x - 3.5) ** 2 + (y - 3.5) ** 2
            if d <= 13:
                img[y][x] = outer
            if d <= 4:
                img[y][x] = inner
    return img


def effect(d):
    """ฟันประชิด: วงเสี้ยวขาว-เหลือง อยู่ใน hit box ของทิศนั้น"""
    img = blank(T)
    x0, y0, x1, y1 = {0: (4, 4, 28, 20), 1: (4, 12, 28, 28), 2: (12, 4, 28, 28), 3: (4, 4, 20, 28)}[d]
    cx, cy = {0: (16, -6), 1: (16, 38), 2: (38, 16), 3: (-6, 16)}[d]   # ศูนย์กลางวงอยู่ฝั่งตัวผู้เล่น
    for y in range(y0, y1):
        for x in range(x0, x1):
            r = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if 17 <= r < 20:
                img[y][x] = 0xFFF
            elif 14 <= r < 23:
                img[y][x] = 0xFD4
    return img


def puzzle(i):
    """ของในห้องปริศนา: 0 หลอดดับ 1 หลอดติด 2 คันโยกขึ้น 3 คันโยกลง 4 กล่อง 5 gate ปิด 6 gate เปิด 7-9 ไอเทม 1-3"""
    img = blank(T)
    if i in (0, 1):            # หลอดไฟ
        glass, rim = (0x556, 0x334) if i == 0 else (0xFF6, 0xFC2)
        for y in range(32):
            for x in range(32):
                if (x - 15.5) ** 2 + (y - 13) ** 2 <= 100:
                    img[y][x] = rim
                if (x - 15.5) ** 2 + (y - 13) ** 2 <= 64:
                    img[y][x] = glass
        rect(img, 11, 23, 21, 29, 0x777); rect(img, 11, 25, 21, 26, 0x444)
        if i == 1:
            rect(img, 13, 8, 16, 11, 0xFFF)
    elif i in (2, 3):          # คันโยก: ขึ้น = แดง, ลง = เขียว
        rect(img, 6, 22, 26, 28, 0x000); rect(img, 7, 23, 25, 27, 0x666)
        knob = 0xD33 if i == 2 else 0x3C3
        if i == 2:
            rect(img, 15, 6, 18, 23, 0x222); rect(img, 12, 3, 21, 10, knob)
        else:
            for t in range(14):
                rect(img, 16 + t // 2, 22 - t, 19 + t // 2, 23 - t, 0x222)
            rect(img, 20, 6, 29, 13, knob)
    elif i == 4:               # กล่องไม้
        rect(img, 3, 3, 29, 29, 0x000); rect(img, 4, 4, 28, 28, 0xA62)
        rect(img, 4, 4, 28, 7, 0xC84); rect(img, 4, 25, 28, 28, 0x741)
        for t in range(22):
            rect(img, 5 + t, 5 + t, 7 + t, 7 + t, 0x741)
    elif i in (5, 6):          # gate: ปิด = ซี่เหล็ก, เปิด = เสาสองข้าง
        rect(img, 0, 0, 4, 32, 0x444); rect(img, 28, 0, 32, 32, 0x444)
        if i == 5:
            for x in range(6, 28, 6):
                rect(img, x, 0, x + 3, 32, 0x889)
            rect(img, 4, 14, 28, 18, 0x667)
    else:                      # ไอเทม 1-3: อัญมณีต่างสี
        col, hi = [(0x2C4, 0xAFA), (0x38E, 0xAEF), (0xC4E, 0xFAF)][i - 7]
        for y in range(4, 28):
            w = 12 - abs(y - 14) if y <= 14 else (28 - y) * 12 // 13
            if w > 0:
                rect(img, 16 - w, y, 16 + w, y + 1, col)
        rect(img, 12, 9, 16, 12, hi)
    return img


def boss(kind, f):
    """บอส 64x64: 1 ก้อนแดง (ขยับ 2 เฟรม), 2 ค้างคาวฟ้า (เฟรม 1 = มึน: เทา ตาเป็น X ดาววน), 3 มังกรม่วง"""
    img = [[T] * 64 for _ in range(64)]

    def r(x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(64, y1)):
            for x in range(max(0, x0), min(64, x1)):
                img[y][x] = c

    def disc(cx, cy, rad, c):
        for y in range(64):
            for x in range(64):
                if (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad:
                    img[y][x] = c
    if kind == 0:
        sq = 2 if f else 0
        disc(32, 36 + sq, 26, 0x000); disc(32, 36 + sq, 24, 0xB22); disc(26, 28 + sq, 8, 0xE55)
        r(18, 26 + sq, 27, 35 + sq, 0xFFF); r(37, 26 + sq, 46, 35 + sq, 0xFFF)
        r(21, 29 + sq, 25, 33 + sq, 0x000); r(40, 29 + sq, 44, 33 + sq, 0x000)
        r(22, 44 + sq, 42, 48 + sq, 0x400)
        for t in range(4):                                       # หนาม
            r(12 + t * 12, 8 + sq, 16 + t * 12, 16 + sq, 0x711)
    elif kind == 1:
        body, wing = (0x26C, 0x139) if f == 0 else (0x777, 0x555)
        for y in range(16, 44):                                  # ปีก
            w = (44 - y) // 2
            r(4, y, 4 + w + 8, y + 1, wing); r(60 - w - 8, y, 60, y + 1, wing)
        disc(32, 32, 18, 0x000); disc(32, 32, 16, body)
        r(22, 10, 26, 20, body); r(38, 10, 42, 20, body)          # หู
        if f == 0:
            r(24, 26, 30, 32, 0xFF2); r(34, 26, 40, 32, 0xFF2)
            r(26, 40, 38, 43, 0xFFF)
        else:                                                    # มึน: ตา X + ดาว
            for t in range(6):
                img[25 + t][24 + t] = img[25 + t][29 - t] = 0x000
                img[25 + t][35 + t] = img[25 + t][40 - t] = 0x000
            for sx, sy in ((14, 6), (30, 2), (46, 6)):
                r(sx, sy + 2, sx + 6, sy + 4, 0xFF4); r(sx + 2, sy, sx + 4, sy + 6, 0xFF4)
    else:
        sh = 2 if f else 0
        r(10, 18, 54, 58, 0x000); r(12, 20, 52, 56, 0x82B)
        r(16, 24, 48, 40, 0xA4D)
        r(18, 26 + sh, 26, 32 + sh, 0xFF0); r(38, 26 + sh, 46, 32 + sh, 0xFF0)
        r(20, 28 + sh, 24, 30 + sh, 0x000); r(40, 28 + sh, 44, 30 + sh, 0x000)
        r(20, 44, 44, 50, 0x400)
        for t in range(5):
            r(22 + t * 5, 44, 24 + t * 5, 47, 0xFFF)              # ฟัน
        r(8, 6, 16, 22, 0xFC4); r(48, 6, 56, 22, 0xFC4)          # เขา
    return img


def to_png(frames, cols, path, size=32):
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGB', (cols * size, rows * size), (255, 0, 255))
    for i, f in enumerate(frames):
        for y in range(size):
            for x in range(size):
                c = f[y][x]
                im.putpixel(((i % cols) * size + x, (i // cols) * size + y),
                            (((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(path)


def write_mem(frames, path):
    with open(path, 'w') as f:
        for fr in frames:
            for row in fr:
                for c in row:
                    f.write(f'{c:03x}\n')


tiles = [tile(fl, t) for fl in range(3) for t in range(16)]
players = [player(fm, d, p) for fm in range(4) for d in range(4) for p in range(3)]
write_mem(tiles, os.path.join(ROOT, 'mem', 'tileset.mem'))
write_mem(players, os.path.join(ROOT, 'mem', 'player.mem'))
to_png(tiles, 16, os.path.join(ROOT, 'docs', 'tileset_preview.png'))
to_png(players, 12, os.path.join(ROOT, 'docs', 'player_preview.png'))
monsters = [monster(k, a) for k in range(2) for a in range(2)]
bullets = [bullet(k) for k in range(5)]
effects = [effect(d) for d in range(4)]
write_mem(monsters, os.path.join(ROOT, 'mem', 'monster.mem'))
write_mem(bullets + [[[T] * 16 for _ in range(16)]] * 3, os.path.join(ROOT, 'mem', 'bullet.mem'))   # 8 เฟรม (address 11 bit)
write_mem(effects, os.path.join(ROOT, 'mem', 'effect.mem'))
puzzles = [puzzle(i) for i in range(10)]
write_mem(puzzles + [blank(T)] * 6, os.path.join(ROOT, 'mem', 'puzzle.mem'))   # เติมให้ครบ 16 เฟรม (address 14 bit)
to_png(puzzles, 10, os.path.join(ROOT, 'docs', 'puzzle_preview.png'))
bosses = [boss(k, f) for k in range(3) for f in range(2)]
write_mem(bosses + [[[T] * 64 for _ in range(64)]] * 2, os.path.join(ROOT, 'mem', 'boss.mem'))   # 8 เฟรม (address 15 bit)
to_png(bosses, 6, os.path.join(ROOT, 'docs', 'boss_preview.png'), size=64)
to_png(monsters + effects, 8, os.path.join(ROOT, 'docs', 'objects_preview.png'))
to_png(bullets, 5, os.path.join(ROOT, 'docs', 'bullet_preview.png'), size=16)
print(f'tileset: {len(tiles)} tiles, player: {len(players)} frames, '
      f'monster: {len(monsters)}, bullet: {len(bullets)}, effect: {len(effects)} frames')
