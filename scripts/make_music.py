#!/usr/bin/env python3
"""เพลง BGM 4 ท่อน + jingle 2 อัน -> mem/music.mem (ทำนองเขียนเองทั้งหมด ไม่ได้ลอกจากเพลงใคร)

รูปแบบ: 6 แทร็ก x 128 entry x 32 bit, address = track*128 + i
  entry = { dur[7:0], 6'b0, hp[17:0] }   hp = half-period ของคลื่นสี่เหลี่ยมที่ 100 MHz (0 = หยุดเสียง/rest)
                                          dur = จำนวนเฟรม (1/60 วิ) ; dur = 0 = จบแทร็ก (วนซ้ำ ยกเว้น jingle)
แทร็ก: 0 ชั้น 1 · 1 ชั้น 2 · 2 ชั้น 3 · 3 ESCAPE · 4 jingle WIN · 5 jingle GAME OVER
ทำนอง: "โน้ต:ความยาวเป็นหน่วย 1/8" เช่น C5:2 = โน้ต C5 ยาว 2 หน่วย, R:2 = หยุด

แก้ทำนองที่นี่แล้วรัน: python3 scripts/make_music.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}


def hp(note):
    if note == 'R':
        return 0
    n, o = (note[:-1], int(note[-1]))
    semis = NAMES[n] + 12 * (o - 4) - 9          # เทียบ A4 = 440 Hz
    f = 440.0 * 2 ** (semis / 12.0)
    v = round(1e8 / (2 * f))
    assert 0 < v < (1 << 18), note
    return v


# (ทำนอง, หน่วยละกี่เฟรม)
TRACKS = [
    # 0 ชั้น 1: C เมเจอร์ สดใส ~112 bpm (หน่วย 1/8 = 16 เฟรม)
    ("""C5:2 E5:2 G5:2 E5:2  D5:2 F5:2 A5:4  G5:2 E5:2 C5:2 E5:2  D5:4 G4:4
        C5:2 E5:2 G5:2 C6:2  B5:2 G5:2 A5:2 F5:2  E5:2 G5:2 D5:2 F5:2  C5:6 R:2""", 16),
    # 1 ชั้น 2: A ไมเนอร์ ลึกลับ ช้าลง (หน่วยละ 18 เฟรม)
    ("""A4:2 C5:2 E5:4  D5:2 F5:2 A5:4  G5:2 E5:2 C5:2 A4:2  B4:4 E5:2 R:2
        A4:2 C5:2 E5:2 A5:2  F5:2 E5:2 D5:2 C5:2  B4:2 D5:2 E5:4  A4:6 R:2""", 18),
    # 2 ชั้น 3: D ไมเนอร์ ฮึกเหิม เร็ว (หน่วยละ 12 เฟรม)
    ("""D5:1 D5:1 F5:2 A5:2 F5:2  G5:1 G5:1 A5:2 C6:2 A5:2  Bb5:1 A5:1 G5:2 F5:2 E5:2  D5:4 R:2 A4:2
        D5:1 D5:1 F5:2 A5:2 D6:2  C6:2 A5:2 G5:2 F5:2  E5:2 G5:2 C6:2 A5:2  D6:6 R:2""".replace('Bb5', 'A#5'), 12),
    # 3 ESCAPE: เร่งเร้า สลับโน้ตเร็ว (หน่วยละ 7 เฟรม)
    ("""A4:1 E5:1 A4:1 E5:1 A4:1 E5:1 A5:2  G4:1 D5:1 G4:1 D5:1 G4:1 D5:1 G5:2
        F4:1 C5:1 F4:1 C5:1 F4:1 C5:1 F5:2  E4:1 B4:1 E4:1 B4:1 E4:1 B4:1 E5:2
        A4:1 E5:1 A4:1 E5:1 A5:1 E5:1 A5:1 E5:1  C6:2 B5:2 A5:2 E5:2""", 7),
    # 4 jingle WIN (หน่วยละ 14 เฟรม)
    ("C5:1 E5:1 G5:1 C6:3 R:1 G5:1 C6:6", 14),
    # 5 jingle GAME OVER
    ("G4:2 E4:2 C4:2 G3:6", 18),
]

mem = []
for notes, unit in TRACKS:
    ent = []
    for tok in notes.split():
        n, d = tok.split(':')
        frames = int(d) * unit
        assert 1 <= frames <= 255, tok
        ent.append((frames, hp(n)))
    assert len(ent) < 128
    for frames, h in ent:
        mem.append((frames << 24) | h)
    mem += [0] * (128 - len(ent))               # dur = 0 = จบ
# custom track (track 6) + reserved track 7 (= "no music" sentinel in audio.v); see scripts/music_extra.py and sprites/music.json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_extra
try:
    extra = music_extra.load(ROOT)
except ValueError as e:
    print('ERROR:', e)
    sys.exit(2)
for w in extra['warnings']:
    print('WARNING:', w)
ent6 = extra['entries'] or []
for frames, h in ent6:
    mem.append((frames << 24) | h)
mem += [0] * (128 - len(ent6))                  # track 6
mem += [0] * 128                                # track 7 (reserved)
assert len(mem) == 1024
if music_extra.write_text_if_changed(os.path.join(ROOT, 'rtl', 'bgm_cfg.vh'), music_extra.bgm_vh(extra['ids'])):
    print('wrote rtl/bgm_cfg.vh')
print('custom track:', extra['name'] or 'none', '| plays:', {k: v for k, v in extra['ids'].items()})
with open(os.path.join(ROOT, 'mem', 'music.mem'), 'w') as f:
    f.write('\n'.join(f'{v:08x}' for v in mem) + '\n')
tot = [sum(int(t.split(':')[1]) * u for t in n.split()) for n, u in TRACKS]
print('music.mem:', len(mem), 'entries; track lengths (s):', [round(t / 60, 1) for t in tot])
