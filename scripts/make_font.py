#!/usr/bin/env python3
"""ฟอนต์ 8x8 1 bit + ข้อความบนจอ (P5) — วาดเองในสคริปต์ ไม่ใช้ไฟล์ฟอนต์ภายนอก

mem/font.mem  : 64 ตัว x 8 แถว = 512 บรรทัด, ค่า 2 hex ต่อแถว (bit 7 = คอลัมน์ซ้ายสุด), address = code*8 + row
mem/text.mem  : รหัสตัวอักษรของทุกข้อความต่อกัน (2 hex ต่อตัว)
rtl/text_layout.vh : ตำแหน่ง/ขนาด/ที่อยู่ของข้อความแต่ละบรรทัด (include ใน renderer.v)

รหัสตัวอักษร: 0-9 ตัวเลข, 10-35 A-Z, 36 ช่องว่าง, 37 '-', 38 ':', 39 '!', 40 '.'
             59-63 = ตัวเลขสด: 59 ชั้น (1-3), 60-63 = เวลา m m s s
ข้อความทั้งหมดอยู่ใน docs/STORY.md (ชื่อเกม = TITLE-01) — แก้ที่นั่น แล้วรัน python scripts/build_story.py

รัน: python3 scripts/make_font.py
"""
import os
import sys


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------- glyph 5x7 (วางที่คอลัมน์ 1-5 แถว 0-6 ของช่อง 8x8) ----------
G = {
    '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
    '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
    '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
    '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
    'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
    'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
    'C': ['01110', '10001', '10000', '10000', '10000', '10001', '01110'],
    'D': ['11100', '10010', '10001', '10001', '10001', '10010', '11100'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
    'G': ['01110', '10001', '10000', '10111', '10001', '10001', '01111'],
    'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
    'I': ['01110', '00100', '00100', '00100', '00100', '00100', '01110'],
    'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
    'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
    'N': ['10001', '10001', '11001', '10101', '10011', '10001', '10001'],
    'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
    'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
    'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
    'W': ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
    'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
    'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
    'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
    ' ': ['00000'] * 7,
    '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
    ':': ['00000', '01100', '01100', '00000', '01100', '01100', '00000'],
    '!': ['00100', '00100', '00100', '00100', '00100', '00000', '00100'],
    '.': ['00000', '00000', '00000', '00000', '00000', '01100', '01100'],
}
CODE = {c: i for i, c in enumerate('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')}
CODE.update({' ': 36, '-': 37, ':': 38, '!': 39, '.': 40})
LIVE = {'{F}': 59, '{M1}': 60, '{M0}': 61, '{S1}': 62, '{S0}': 63}

font = [[0] * 8 for _ in range(64)]
for ch, rows in G.items():
    for r, bits in enumerate(rows):
        font[CODE[ch]][r] = int(bits, 2) << 2      # 5 bit ชิดคอลัมน์ 1-5 ของ 8
# รหัสสด 59-63: ให้ glyph ว่าง (renderer แทนด้วยตัวเลขจริง)


def encode(s):
    out, i = [], 0
    while i < len(s):
        if s[i] == '{':
            j = s.index('}', i) + 1
            out.append(LIVE[s[i:j]]); i = j
        else:
            out.append(CODE[s[i]]); i += 1
    return out


# ---------- ข้อความต่อหน้าจอ: มาจาก docs/STORY.md (source of truth, scripts/story.py) ----------
# หน้าจอ: 1 TITLE, 2 FLOOR CLEAR, 3 ป้ายเขาวงกต, 4 WIN, 5 GAME OVER, 6 PAUSED, 7-10 prologue, 11-13 NEW FORM, 14 = กล่อง dialogue (renderer วาดเอง), 15 หมดเวลา
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story as story_mod
STORY = story_mod.load()
for w_ in STORY.warnings:
    print('WARNING:', w_)
S = STORY.screens
# (หน้าจอ, ชื่อใน STORY.md, [(scale, y, กะพริบ) ต่อบรรทัด])
SCREEN_SPECS = [
    (1, 'title', [(4, 96, 0), (2, 360, 1)]),
    (2, 'floorclear', [(4, 176, 0)]),
    (3, 'maze', [(2, 40, 0), (2, 64, 0)]),
    (4, 'win', [(4, 160, 0), (4, 260, 0)]),
    (5, 'gameover', [(4, 160, 0), (2, 300, 1)]),
    (7, 'prologue1', [(4, 160, 0), (4, 220, 0)]), (8, 'prologue2', [(4, 160, 0), (4, 220, 0)]),
    (9, 'prologue3', [(4, 160, 0), (4, 220, 0)]), (10, 'prologue4', [(4, 160, 0), (4, 220, 0)]),
    (11, 'evolve2', [(4, 140, 0), (2, 190, 0)]), (12, 'evolve3', [(4, 140, 0), (2, 190, 0)]), (13, 'evolve4', [(4, 140, 0), (2, 190, 0)]),
    (15, 'timeout', [(4, 160, 0), (4, 260, 0)]),
]
LINES = [(6, 0, 'PAUSED', 4, 208, 0)]
for scr_, name_, specs_ in SCREEN_SPECS:
    for ln_, (sc_, y_, bl_) in enumerate(specs_):
        t_ = S[name_][ln_] if ln_ < len(S[name_]) else ''
        if t_:
            LINES.append((scr_, ln_, t_, sc_, y_, bl_))
for scr_, ln_, t_, sc_, y_, bl_ in LINES:
    assert all(c in CODE or c in '{}FMS01' for c in t_), (scr_, t_)
SCR_LIST = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15]
text = []
desc = {}
for scr, ln, s_, sc, y, bl in LINES:
    codes = encode(s_)
    w = len(codes) * 8 * sc
    assert w <= 640, f'screen {scr} line {ln}: {s_!r} is {w}px wide at scale {sc}'
    x = (640 - w) // 2
    desc[(scr, ln)] = (y, x, w, 8 * sc, 1 if sc == 4 else 0, len(text), bl)
    text += codes
# ---------- dialogue messages (rtl/dialog.v): text appended after the screens, entry = {block, speaker, n1, b1, n0, b0} ----------
dlg_words = []
for e in STORY.dialogs:
    c0, c1 = encode(e.l1), encode(e.l2) if e.l2 else []
    b0 = len(text); text += c0
    b1 = len(text); text += c1
    spk = story_mod.SPEAKERS.get(e.speaker.upper(), 2)
    dlg_words.append((int(e.block) << 36) | (spk << 34) | (len(c1) << 29) | (b1 << 17) | (len(c0) << 12) | b0)
TEXT_SIZE = 4096
assert len(text) <= TEXT_SIZE, f'text ROM overflow: {len(text)} > {TEXT_SIZE}'

with open(os.path.join(ROOT, 'mem', 'font.mem'), 'w') as f:
    f.write('\n'.join(f'{v:02x}' for g in font for v in g) + '\n')
with open(os.path.join(ROOT, 'mem', 'text.mem'), 'w') as f:
    f.write('\n'.join(f'{v:02x}' for v in text + [36] * (TEXT_SIZE - len(text))) + '\n')

vh = ['// สร้างโดย scripts/make_font.py — อย่าแก้มือ (แก้ข้อความที่ docs/STORY.md)',
      '// บรรทัดข้อความ: หน้าจอ s (1..13, 15) บรรทัด l (0..1): Y, X, W(px), H(px), S (0 = 2x, 1 = 4x), B (ที่อยู่ใน text.mem), K (กะพริบ)']
sel = ['// generated by scripts/make_font.py - do not edit. Body of the text-screen case in renderer.v (included inside `case (txt_scr)`)']
for scr in SCR_LIST:
    for ln in range(2):
        y, x, w, h, s4, b, bl = desc.get((scr, ln), (0, 0, 0, 0, 0, 0, 0))
        vh.append(f"localparam [9:0] T{scr}_{ln}_Y = 10'd{y}, T{scr}_{ln}_X = 10'd{x}, T{scr}_{ln}_W = 10'd{w}, "
                  f"T{scr}_{ln}_H = 10'd{h}; localparam T{scr}_{ln}_S = {s4}, T{scr}_{ln}_B = {b}, T{scr}_{ln}_K = {bl};")
    sel.append(f"4'd{scr}: begin ly0 = T{scr}_0_Y; lx0 = T{scr}_0_X; lw0 = T{scr}_0_W; lh0 = T{scr}_0_H; ls0 = T{scr}_0_S; lb0 = T{scr}_0_B; lk0 = T{scr}_0_K;")
    sel.append(f"            ly1 = T{scr}_1_Y; lx1 = T{scr}_1_X; lw1 = T{scr}_1_W; lh1 = T{scr}_1_H; ls1 = T{scr}_1_S; lb1 = T{scr}_1_B; lk1 = T{scr}_1_K; end")
sel.append("default: begin ly0 = 0; lx0 = 0; lw0 = 0; lh0 = 0; ls0 = 0; lb0 = 0; lk0 = 0; ly1 = 0; lx1 = 0; lw1 = 0; lh1 = 0; ls1 = 0; lb1 = 0; lk1 = 0; end")
with open(os.path.join(ROOT, 'rtl', 'text_select.vh'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(sel) + '\n')
with open(os.path.join(ROOT, 'rtl', 'text_layout.vh'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(vh) + '\n')

# ---------- dialogue ROM + trigger table ----------
with open(os.path.join(ROOT, 'mem', 'dlg.mem'), 'w') as f:
    f.write(chr(10).join(f'{v:010x}' for v in dlg_words + [0] * (128 - len(dlg_words))) + chr(10))
tl = ['// generated by scripts/make_font.py from docs/STORY.md - do not edit by hand',
      f'localparam NDLG = {len(STORY.dialogs)};', f'localparam NEV = {len(story_mod.EVENTS)};'] + \
     [f'localparam EV_{n.upper()} = {i};' for i, n in enumerate(story_mod.EVENTS)] + [

      '// trigger of each dialogue message: a game event (ev) or the end of another message (fin)',
      'function [127:0] dlg_trigs(input [63:0] ev, input [127:0] fin);', '    begin', "        dlg_trigs = 128'd0;"]
for e in STORY.dialogs:
    if e.event is not None:
        tl.append(f'        dlg_trigs[{e.index}] = ev[{e.event}];   // {e.id} {story_mod.EVENTS[e.event]}')
    else:
        j = [d for d in STORY.dialogs if d.id == e.after][0].index
        tl.append(f'        dlg_trigs[{e.index}] = fin[{j}];   // {e.id} after {e.after}')
tl += ['    end', 'endfunction', '']
with open(os.path.join(ROOT, 'rtl', 'dlg_cfg.vh'), 'w', encoding='utf-8') as f:
    f.write(chr(10).join(tl))

# preview
try:
    from PIL import Image
    im = Image.new('RGB', (16 * 9 * 4, 4 * 9 * 4), (30, 30, 50))
    for c in range(64):
        for r in range(8):
            for b in range(8):
                if font[c][r] >> (7 - b) & 1:
                    for dy in range(4):
                        for dx in range(4):
                            im.putpixel(((c % 16) * 36 + b * 4 + dx, (c // 16) * 36 + r * 4 + dy), (255, 255, 255))
    im.save(os.path.join(ROOT, 'docs', 'font_preview.png'))
except ImportError:
    pass
print(f'font: {len(G)} glyphs, text ROM: {len(text)} of {TEXT_SIZE} chars, {len(LINES)} screen lines, {len(STORY.dialogs)} dialogue messages')
