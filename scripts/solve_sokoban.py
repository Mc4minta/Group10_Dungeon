#!/usr/bin/env python3
"""BFS solver ห้อง Sokoban (maps/09_f2_puzzle_sokoban.txt)

กติกาเดียวกับ rtl/puzzles.v:
  - ผู้เล่นเดินได้บน '.' 'O' (และช่องที่มีของ 'K' 'P' 'I' 'S' ... = พื้น) ยกเว้นช่องที่มีกล่อง; ประตู D/G/L/E = กำแพง
  - ดันกล่องได้ทีละ 1 ช่องตามแกนเดียว ช่องถัดไปต้องเป็นพื้นหรือแผ่น (ไม่ใช่กำแพง กล่อง gate ประตู H F)
  - เป้าหมาย: แผ่น O ทั้ง 2 มีกล่องทับ (gate (13,7) เปิด)
  - ผู้เล่นเริ่มที่ช่องหน้าประตูซ้าย (1, 7) = จุดเกิด (40, 240) ของ world.v

BFS ตามจำนวนครั้งที่ดัน (ระหว่างดันเดินได้ไม่จำกัด) -> จำนวนดันน้อยสุด
ผลลัพธ์: จำนวนดัน + ลำดับก้าวทีละช่อง (U D L R) ตั้งแต่จุดเกิด

รัน: python3 scripts/solve_sokoban.py [--moves] [--json] [--vh]
     --vh เขียน sim/sokoban_solution.vh ให้ sim/tb_puzzles.v เล่นตามคำตอบ
"""
import collections
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP = os.path.join(ROOT, 'maps', '09_f2_puzzle_sokoban.txt')
START = (1, 7)
DIRS = {'U': (0, -1), 'D': (0, 1), 'L': (-1, 0), 'R': (1, 0)}

rows = open(MAP, encoding='utf-8').read().rstrip('\n').split('\n')
H, W = len(rows), len(rows[0])
FLOOR = set('.OKPISTabcd1234NqwerB')        # พื้นหรือของที่วางบนพื้น (ยกเว้น G)
boxes0 = tuple(sorted((x, y) for y in range(H) for x in range(W) if rows[y][x] == 'K'))
plates = frozenset((x, y) for y in range(H) for x in range(W) if rows[y][x] == 'O')


def walk(x, y):
    return 0 <= x < W and 0 <= y < H and rows[y][x] in FLOOR


def reach(p, boxes):
    """ช่องที่ผู้เล่นเดินไปถึงได้ + เส้นทาง (parent)"""
    bs = set(boxes)
    par = {p: None}
    q = collections.deque([p])
    while q:
        c = q.popleft()
        for k, (dx, dy) in DIRS.items():
            n = (c[0] + dx, c[1] + dy)
            if n not in par and walk(*n) and n not in bs:
                par[n] = (c, k)
                q.append(n)
    return par


def path_to(par, t):
    out = []
    while par[t] is not None:
        t, k = par[t]
        out.append(k)
    return out[::-1]


def solve():
    # state = (ตำแหน่งผู้เล่นตัวแทน = ช่องซ้ายบนสุดที่เดินถึง, กล่อง)
    def norm(p, boxes):
        return min(reach(p, boxes))
    s0 = (norm(START, boxes0), boxes0)
    prev = {s0: None}
    q = collections.deque([(s0, START)])
    while q:
        (rp, boxes), real = q.popleft()
        if set(boxes) == plates:
            # ย้อนรอย
            seq = []
            st = (rp, boxes)
            while prev[st] is not None:
                st, step = prev[st]
                seq.append(step)
            return seq[::-1]
        par = reach(real, boxes)
        for i, b in enumerate(boxes):
            for k, (dx, dy) in DIRS.items():
                stand = (b[0] - dx, b[1] - dy)
                dest = (b[0] + dx, b[1] + dy)
                if stand not in par or not walk(*dest) or dest in boxes:
                    continue
                nb = tuple(sorted(boxes[:i] + (dest,) + boxes[i + 1:]))
                ns = (norm(b, nb), nb)
                if ns in prev:
                    continue
                prev[ns] = ((rp, boxes), (stand, k, b))
                q.append((ns, b))
    return None


def moves(seq):
    """แปลงลำดับดันเป็นก้าวทีละช่องจากจุดเกิด"""
    p, boxes = START, list(boxes0)
    out = []
    for stand, k, b in seq:
        par = reach(p, tuple(boxes))
        out += path_to(par, stand)
        out.append(k.lower())                 # ตัวเล็ก = ก้าวที่ดันกล่อง
        dx, dy = DIRS[k]
        boxes[boxes.index(b)] = (b[0] + dx, b[1] + dy)
        p = b
    return out, p


if __name__ == '__main__':
    seq = solve()
    if seq is None:
        print('UNSOLVABLE')
        sys.exit(1)
    mv, end = moves(seq)
    if '--vh' in sys.argv:
        path = os.path.join(ROOT, 'sim', 'sokoban_solution.vh')
        with open(path, 'w', encoding='utf-8') as f:
            f.write('// สร้างโดย scripts/solve_sokoban.py --vh — อย่าแก้มือ\n')
            f.write(f'// ดันน้อยสุด {len(seq)} ครั้ง, {len(mv)} ก้าว (ตัวเล็ก = ก้าวที่ดันกล่อง), เริ่มที่ช่อง {START}\n')
            f.write(f'localparam SOKO_PUSHES = {len(seq)};\n')
            f.write(f'localparam SOKO_N = {len(mv)};\n')
            f.write(f'localparam [8*{len(mv)}-1:0] SOKO_MOVES = "{"".join(mv)}";\n')
        print('wrote', path)
    if '--json' in sys.argv:
        print(json.dumps({'pushes': len(seq), 'moves': ''.join(mv), 'start': START, 'end': end,
                          'boxes': boxes0, 'plates': sorted(plates)}))
    else:
        print(f'boxes {boxes0}  plates {sorted(plates)}')
        print(f'min pushes = {len(seq)}, steps = {len(mv)} (lowercase = push)')
        if '--moves' in sys.argv:
            print(''.join(mv))
