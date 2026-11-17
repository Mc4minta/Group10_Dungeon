#!/usr/bin/env python3
"""แปลง maps/*.txt (ASCII 20x15) -> mem/tilemap.mem + mem/objects.txt + mem/monsters.mem

tilemap.mem  : 4096 บรรทัด, 1 hex digit ต่อ tile, address = grid*300 + ty*20 + tx
objects.txt  : รายการ object ต่อห้อง (อ่านง่ายสำหรับคน)
monsters.mem : ROM มอนต่อห้องสำหรับ rtl/objects.v, 128 บรรทัด x 16 bit, address = grid*8 + i (i = 0..7)
               bit 15 = valid, bit 14..12 = ชนิด (0 = มอน A 'S' ไล่, 1 = มอน B 'T' ป้อม),
               bit 11..8 = ty (แถว tile), bit 4..0 = tx (คอลัมน์ tile)
               มอนเกิดที่มุมซ้ายบน sprite = (tx*32, ty*32); สูงสุด 6 ตัวต่อห้อง (= slot ใน objects.v)

รัน:  python3 scripts/build_maps.py
"""
import glob
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ASCII -> tile ID (ดูตาราง tile ID ในเอกสาร Asset + แผน Implement)
TILE = {
    '#': 0x0,  # wall
    '.': 0x1,  # floor
    'D': 0x2,  # door (closed state; renderer/logic เลือกเปิด-ปิดเอง)
    'L': 0x3,  # boss door
    'E': 0x4,  # exit door
    'H': 0x5,  # hole
    'F': 0x6,  # fence
    'O': 0x7,  # pressure plate
    'q': 0xC, 'w': 0xD, 'e': 0xE, 'r': 0xF,  # Simon plates 1-4
}
# object -> tile ใต้ object (object เองเก็บแยกใน objects.txt)
OBJ_FLOOR = set('PSTBabcd1234KGIN')
MONSTER = {'S': 0, 'T': 1}   # ตัวอักษรในแมพ -> ชนิดมอน (0 = A ไล่, 1 = B ป้อม)
MAX_MON = 6                  # slot มอนใน objects.v

maps = sorted(glob.glob(os.path.join(ROOT, 'maps', '*.txt')))
assert len(maps) == 13, f'expected 13 maps, found {len(maps)}'

mem = []
objs = []
mons = [[] for _ in range(16)]
for g, path in enumerate(maps):
    rows = open(path, encoding='utf-8').read().rstrip('\n').split('\n')
    assert len(rows) == 15, f'{path}: {len(rows)} rows'
    for ty, row in enumerate(rows):
        assert len(row) == 20, f'{path} row {ty}: {len(row)} chars'
        for tx, ch in enumerate(row):
            if ch in TILE:
                mem.append(TILE[ch])
            elif ch in OBJ_FLOOR:
                mem.append(TILE['.'])
                objs.append(f'{g:2d} {os.path.basename(path):32s} {ch} x={tx:2d} y={ty:2d}')
                if ch in MONSTER:
                    mons[g].append(0x8000 | (MONSTER[ch] << 12) | (ty << 8) | tx)
            else:
                raise ValueError(f'{path} ({tx},{ty}): unknown char {ch!r}')

mem += [0] * (4096 - len(mem))
with open(os.path.join(ROOT, 'mem', 'tilemap.mem'), 'w') as f:
    f.write('\n'.join(f'{v:x}' for v in mem) + '\n')
with open(os.path.join(ROOT, 'mem', 'objects.txt'), 'w') as f:
    f.write('# grid file char x y\n' + '\n'.join(objs) + '\n')

rom = []
for g, m in enumerate(mons):
    assert len(m) <= MAX_MON, f'grid {g}: {len(m)} monsters > {MAX_MON} slots'
    rom += m + [0] * (8 - len(m))
with open(os.path.join(ROOT, 'mem', 'monsters.mem'), 'w') as f:
    f.write('\n'.join(f'{v:04x}' for v in rom) + '\n')

# ---------- ตำแหน่งของในห้องปริศนา -> rtl/puzzle_layout.vh (include ใน puzzles.v) ----------
def find(g, ch):
    out = []
    rows = open(maps[g], encoding='utf-8').read().rstrip('\n').split('\n')
    for ty, row in enumerate(rows):
        for tx, c in enumerate(row):
            if c == ch:
                out.append((tx, ty))
    return out


G_LB, G_SOKO, G_SIMON = 6, 9, 12
lay = ['// สร้างโดย scripts/build_maps.py จาก maps/*.txt — อย่าแก้มือ (แก้แมพแล้วรันสคริปต์ใหม่)',
       f'localparam [3:0] G_LB = 4\'d{G_LB}, G_SOKO = 4\'d{G_SOKO}, G_SIMON = 4\'d{G_SIMON};']
for f, g in enumerate((G_LB, G_SOKO, G_SIMON)):
    (ix, iy), = find(g, 'I')
    lay.append(f'localparam [4:0] ITEM{f}_TX = 5\'d{ix};  localparam [3:0] ITEM{f}_TY = 4\'d{iy};')
for k, ch in enumerate('abcd'):
    (x, y), = find(G_LB, ch)
    lay.append(f'localparam [4:0] LEVER{k}_TX = 5\'d{x};  localparam [3:0] LEVER{k}_TY = 4\'d{y};')
for k, ch in enumerate('1234'):
    (x, y), = find(G_LB, ch)
    lay.append(f'localparam [4:0] BULB{k}_TX = 5\'d{x};  localparam [3:0] BULB{k}_TY = 4\'d{y};')
bx = find(G_SOKO, 'K'); pl = find(G_SOKO, 'O'); (gx, gy), = find(G_SOKO, 'G')
assert len(bx) == 2 and len(pl) == 2, 'Sokoban: ต้องมีกล่อง K 2 และแผ่น O 2'
for k in range(2):
    lay.append(f'localparam [4:0] BOX{k}_TX = 5\'d{bx[k][0]};  localparam [3:0] BOX{k}_TY = 4\'d{bx[k][1]};')
    lay.append(f'localparam [4:0] PLATE{k}_TX = 5\'d{pl[k][0]};  localparam [3:0] PLATE{k}_TY = 4\'d{pl[k][1]};')
lay.append(f'localparam [4:0] GATE_TX = 5\'d{gx};  localparam [3:0] GATE_TY = 4\'d{gy};')
with open(os.path.join(ROOT, 'rtl', 'puzzle_layout.vh'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(lay) + '\n')

print(f'tilemap.mem: {len(maps)} rooms, objects: {len(objs)}, '
      f'monsters.mem: {sum(len(m) for m in mons)} monsters')
