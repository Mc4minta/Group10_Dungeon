from tl import TL
# ---- D: floor 3 Simon (fig 29, 30). SW1 x2 (skip floors 1-2), SW3 x3 (form 4, flies over pits), SW2 clears waves, SW0 boss door (all DEBUG)
# Simon walk is computed here (the old floor3.txt steps were made for an older plate layout). The game takes the plate under the hero's CENTRE;
# walking along py=222 keeps the centre on row 7 (no plate), plates: q (6-7, 4-5) w (12-13, 4-5) e (6-7, 8-9) r (12-13, 8-9).
d = TL().intro()
d.lines.append("0:150:9000")
d.at(160); d.pulse2('1')
d.at(460); d.pulse2('1')
d.at(760); d.pulse2('3')
d.at(1040); d.pulse2('3')
d.at(1120); d.pulse2('3')
d.at(1220); d.hold('R', 106)                  # START -> C1
d.at(1480); d.spam('2', 14, 30)               # C1 waves
d.hold('R', 93); d.hold('U', 110)             # C1 -> gap in the pit rows -> top door -> C2
d.at(2270); d.spam('2', 16, 30)               # C2 lock dialog + waves + clear dialog
d.wait(10); d.hold('U', 55); d.hold('R', 112)   # C2 -> right door -> Simon room
A = d.t - 12                                   # about when the hero arrives in the Simon room
d.at(A + 215)                                  # room dialog (150) is over
d.hold('U', 6); d.hold('R', 88)                # centre of the room along row 7 (px 43 -> 307, py 222)
SEQ = "wqqeq"
LEN = [3, 4, 5]
touch_off = {'w': 32 + 17, 'q': 32 + 17, 'e': 32 + 6, 'r': 32 + 6}
def step(ch):
    h, v = ('R', 'U') if ch == 'w' else ('L', 'U') if ch == 'q' else ('L', 'D') if ch == 'e' else ('R', 'D')
    vb = 'D' if v == 'U' else 'U'
    n = 25 if v == 'U' else 16
    hb = 'L' if h == 'R' else 'R'
    d.hold(h, 32); d.hold(v, n); d.wait(2); d.hold(vb, n); d.hold(hb, 32); d.wait(6)
    return
ready = d.t + 5                                # round 1 input is already open (its show ran during the dialog)
for r, L in enumerate(LEN):
    if d.t < ready: d.at(ready)
    last = None
    for ch in SEQ[:L]:
        t0 = d.t
        step(ch); last = t0 + touch_off[ch]
    if r < 2: ready = last + 45 + LEN[r + 1] * 45 + 25 - 40   # SM_OK wait 45, then the show of the next round, then the first step needs ~40 frames before it touches a plate
d.wait(30)
d.save('D.txt', 'job D: floor 3 Simon (gen_d.py)')
