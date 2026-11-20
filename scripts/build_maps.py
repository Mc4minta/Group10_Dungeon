#!/usr/bin/env python3
"""แปลง maps/*.txt (ASCII 20x15) -> mem/tilemap.mem + mem/objects.txt + mem/monsters.mem

tilemap.mem  : 4096 บรรทัด, 1 hex digit ต่อ tile, address = grid*300 + ty*20 + tx
overlay.mem  : 4096 บรรทัด x 8 bit (W5), address เดียวกัน: [3:0] = 0 ไม่มี, 1 กล่องพังได้ (Z), 2 กับดักหนาม (X), 3 เสาตกแต่งตัน (Y); [6:4] = ลำดับกล่องพังได้ในห้อง (0..7)
                ใต้ overlay ใน tilemap.mem เป็นพื้น (1) เสมอ
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
    # decoration (visual only): tile ids C-F are walkable like floor for the player, monsters and bullets everywhere
    # except inside the Simon puzzle, so on floors 1-2 they carry floor decoration art (see sprites/tileset.json)
    ',': 0xC,  # cracked floor
    ';': 0xD,  # bones
    ':': 0xE,  # skull
    '`': 0xF,  # rubble
}
DECOR = set(',;:`')
# W5 overlay layer (separate 4-bit code map, see docs/DESIGN_PLAN.md 5.1): Z breakable block, X spike trap, Y solid decoration
OVL = {'Z': 1, 'X': 2, 'Y': 3}
MAX_BRK = 8                  # breakable blocks per room (state bits in overlay.v)
# overlay only in rooms without puzzle logic and not the boss rooms: start rooms 0,1 and combat rooms 4,5,7,8,10,11
OVL_ROOMS = {0, 1, 4, 5, 7, 8, 10, 11}
# rooms where decoration is allowed: only rooms that are drawn with floor 1 or 2 art and are not a puzzle room that reads tile ids.
# NOT allowed: 1 (floor 3), 2 (boss, floors 1+3), 9 (Sokoban: boxes only move onto tile 1/7), 10-12 (floor 3: C-F = Simon plate art)
DECOR_ROOMS = {0, 3, 4, 5, 6, 7, 8}
# object -> tile ใต้ object (object เองเก็บแยกใน objects.txt)
OBJ_FLOOR = set('PSTBabcd1234KGIN')
MONSTER = {'S': 0, 'T': 1}   # ตัวอักษรในแมพ -> ชนิดมอน (0 = A ไล่, 1 = B ป้อม)
MAX_MON = 6                  # slot มอนใน objects.v

maps = sorted(glob.glob(os.path.join(ROOT, 'maps', '[0-9][0-9]_*.txt')))
assert len(maps) == 13, f'expected 13 maps, found {len(maps)}'

mem = []
ovl = []
objs = []
mons = [[] for _ in range(16)]
for g, path in enumerate(maps):
    rows = open(path, encoding='utf-8').read().rstrip('\n').split('\n')
    assert len(rows) == 15, f'{path}: {len(rows)} rows'
    nbrk = 0
    for ty, row in enumerate(rows):
        assert len(row) == 20, f'{path} row {ty}: {len(row)} chars'
        for tx, ch in enumerate(row):
            if ch in DECOR and g not in DECOR_ROOMS:
                raise ValueError(f'{path} ({tx},{ty}): decoration {ch!r} is not allowed in this room (grid {g})')
            if ch in OVL:
                if g not in OVL_ROOMS:
                    raise ValueError(f'{path} ({tx},{ty}): overlay {ch!r} is not allowed in this room (grid {g})')
                mem.append(TILE['.'])
                if ch == 'Z':
                    assert nbrk < MAX_BRK, f'{path}: more than {MAX_BRK} breakable blocks'
                    ovl.append(OVL[ch] | (nbrk << 4)); nbrk += 1
                else:
                    ovl.append(OVL[ch])
                continue
            if ch in TILE:
                mem.append(TILE[ch])
            elif ch in OBJ_FLOOR:
                mem.append(TILE['.'])
                objs.append(f'{g:2d} {os.path.basename(path):32s} {ch} x={tx:2d} y={ty:2d}')
                if ch in MONSTER:
                    mons[g].append(0x8000 | (MONSTER[ch] << 12) | (ty << 8) | tx)
            else:
                raise ValueError(f'{path} ({tx},{ty}): unknown char {ch!r}')
            ovl.append(0)

mem += [0] * (4096 - len(mem))
ovl += [0] * (4096 - len(ovl))
with open(os.path.join(ROOT, 'mem', 'overlay.mem'), 'w') as f:
    f.write(chr(10).join(f'{v:02x}' for v in ovl) + chr(10))
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

# ---------- W7 maze (not a room): maps/maze/maze.txt -> mem/maze.mem (512 x 2 bit: 0 floor, 1 wall, 2 goal G, 3 start S; address = row*20 + col) ----------
mz = open(os.path.join(ROOT, 'maps', 'maze', 'maze.txt'), encoding='utf-8').read().rstrip(chr(10)).split(chr(10))
assert len(mz) == 15 and all(len(r) == 20 for r in mz), 'maze.txt must be 20x15'
MZ = {'#': 1, '.': 0, 'G': 2, 'S': 3}
mzv = [MZ[c] for r in mz for c in r]
assert mzv.count(2) == 1 and mzv.count(3) == 1, 'maze: exactly one S and one G'
with open(os.path.join(ROOT, 'mem', 'maze.mem'), 'w') as f:
    f.write(chr(10).join(f'{v:x}' for v in mzv + [1] * (512 - len(mzv))) + chr(10))

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
(b1x, b1y), = find(2, 'B')
(b2x, b2y), = find(3, 'B')
lay.append(f'localparam [4:0] BOSSA_TX = 5\'d{b1x};  localparam [3:0] BOSSA_TY = 4\'d{b1y};   // ห้องบอสชั้น 1, 3 (grid 2)')
lay.append(f'localparam [4:0] BOSSB_TX = 5\'d{b2x};  localparam [3:0] BOSSB_TY = 4\'d{b2y};   // ห้องบอสชั้น 2 (grid 3)')
with open(os.path.join(ROOT, 'rtl', 'puzzle_layout.vh'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(lay) + '\n')

print(f'tilemap.mem: {len(maps)} rooms, objects: {len(objs)}, '
      f'monsters.mem: {sum(len(m) for m in mons)} monsters')
