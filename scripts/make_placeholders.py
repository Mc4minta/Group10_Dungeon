#!/usr/bin/env python3
"""สร้าง sprite placeholder (ใช้จนกว่า sprite จริงจาก sprite_tool จะเสร็จ)

mem/tileset.mem : 3 ชั้น x 16 tile x 32x32, address = (floor*16 + tile)*1024 + y*32 + x
mem/player.mem  : 4 ร่าง x 4 ทิศ x 3 ท่า = 48 เฟรม 32x32, address = frame*1024 + y*32 + x
                  frame = form*12 + dir*3 + pose  (dir: 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา, pose: 0 idle 1 ก้าวA 2 ก้าวB)
mem/monster.mem : 4 เฟรม 32x32 = มอน A เฟรม 0,1 แล้วมอน B เฟรม 0,1 (frame = type*2 + anim)
mem/bullet.mem  : 2 เฟรม 8x8 = กระสุนผู้เล่น, กระสุนศัตรู (address = kind*64 + y*8 + x)
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
    img = [[T] * 8 for _ in range(8)]
    outer, inner = (0x0AF, 0xFFF) if kind == 0 else (0xE20, 0xFE4)   # ผู้เล่น ฟ้า-ขาว / ศัตรู แดง-เหลือง
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
bullets = [bullet(k) for k in range(2)]
effects = [effect(d) for d in range(4)]
write_mem(monsters, os.path.join(ROOT, 'mem', 'monster.mem'))
write_mem(bullets, os.path.join(ROOT, 'mem', 'bullet.mem'))
write_mem(effects, os.path.join(ROOT, 'mem', 'effect.mem'))
to_png(monsters + effects, 8, os.path.join(ROOT, 'docs', 'objects_preview.png'))
to_png(bullets, 2, os.path.join(ROOT, 'docs', 'bullet_preview.png'), size=8)
print(f'tileset: {len(tiles)} tiles, player: {len(players)} frames, '
      f'monster: {len(monsters)}, bullet: {len(bullets)}, effect: {len(effects)} frames')
