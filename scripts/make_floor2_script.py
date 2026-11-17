#!/usr/bin/env python3
"""สร้าง sim/verilator/scripts/floor2.txt: ชั้น 2 ตั้งแต่ TITLE -> ข้ามชั้น (SW1) -> START -> C1 -> C2 -> Sokoban
แล้วเล่นตามคำตอบของ scripts/solve_sokoban.py (ก้าวละ 16 เฟรม ที่ความเร็ว 2 px/เฟรม) -> gate เปิด -> เก็บไอเทม 2

รัน: python3 scripts/make_floor2_script.py   (แล้วเล่นด้วย Vtop --script-file ../sim/verilator/scripts/floor2.txt)
ห้อง Combat เคลียร์ด้วย SW2 (DEBUG) ให้สคริปต์สั้น — การต่อสู้จริงดูได้ใน README (สคริปต์ P3)
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sol = json.loads(subprocess.check_output([sys.executable, os.path.join(ROOT, 'scripts', 'solve_sokoban.py'), '--json']))
STEP = 16                                    # เฟรมต่อ 1 ช่องที่ 2 px/เฟรม

out = ['# ชั้น 2: สร้างโดย scripts/make_floor2_script.py — อย่าแก้มือ',
       f'# Sokoban: ดันน้อยสุด {sol["pushes"]} ครั้ง, {len(sol["moves"])} ก้าว จาก solver',
       'C:20:23          # TITLE -> PLAY',
       '1:40', '1:45     # SW1 (DEBUG) floor_done -> FLOOR_CLEAR 2 วิ -> ชั้น 2',
       'R:170:321        # START -> ประตูขวา',
       '2:330', '2:335   # C1: SW2 (DEBUG) เคลียร์ห้อง',
       'R:340:471', 'U:480:592   # C1 -> ประตูบน',
       '2:600', '2:605   # C2: SW2 เคลียร์ห้อง',
       'U:610:685', 'R:690:833   # C2 -> ประตูขวา -> ห้อง Sokoban (เกิดที่ 40, 240)',
       'L:845:848', 'U:855:862   # จัดให้ตรงช่อง (1, 7) = (32, 224)']
base = 870
f = base
moves = sol['moves']
out.append(f'# เล่นตาม solver เริ่มเฟรม {base}: {moves}')
for c in moves:
    out.append(f'{c.upper()}:{f}:{f + STEP - 1}')
    f += STEP
ex, ey = sol['end']
out.append(f'# จบที่ช่อง {sol["end"]} gate เปิด -> เดินไปไอเทม (16, 7): ขวาถึงคอลัมน์ 12, ขึ้นถึงแถว 7, ขวาผ่าน gate')
f += 10
path = 'R' * (12 - ex) + 'U' * (ey - 7) + 'R' * 4
for c in path:
    out.append(f'{c}:{f}:{f + STEP - 1}')
    f += STEP
out.append(f'# จบสคริปต์ราวเฟรม {f}')
path_out = os.path.join(ROOT, 'sim', 'verilator', 'scripts', 'floor2.txt')
with open(path_out, 'w', encoding='utf-8') as fh:
    fh.write('\n'.join(out) + '\n')
print('wrote', path_out, 'last frame', f)
