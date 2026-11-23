import json
from tl import TL
# ---- N: floor 3 boss 3 for real (form 4 charge shots, then slash) -> key -> back to START -> maze (fig 35) -> WIN (fig 36)
# first part = G3 (same inputs, same frames) so the fight is identical; SW0 (DEBUG) only for the boss door L
g = TL().intro()
g.lines.append("0:150:9000")                          # SW0 (DEBUG): boss door L open (like G3)
g.at(160); g.pulse2('1')
g.at(460); g.pulse2('1')
g.at(760); g.pulse2('3')
g.at(1040); g.pulse2('3')
g.at(1120); g.pulse2('3')
g.at(1220); g.hold('R', 106)
g.at(1480); g.spam('2', 14, 30)
g.hold('R', 190)
g.wait(170)                                          # start charging as soon as the boss dialog is over (G3 waited 320 and lost HP)
for _ in range(20): g.hold('C', 46); g.wait(8)       # charged shots until the boss is dead
g.wait(30)
g.hold('R', 12); g.hold('L', 24); g.wait(20)         # pick up the key
g.hold('L', 60)                                      # boss room -> left door -> C1
g.wait(330); g.hold('L', 210)                        # (key dialogs) C1 -> left door -> START
g.wait(30)
for _ in range(4): g.pulse('C'); g.wait(37)           # dismiss the blocking dialog 'THE GATE IS LOCKED BY A MAZE'
g.hold('L', 260)                                     # START -> door E (open with the key) -> maze
T = 4780                                             # the maze is running (dialog over) from about frame 4700 in this run
keys = json.load(open('maze_keys_slide.json'))      # maze_slide.py: only 'hold a direction until the wall stops the ball' moves
g.at(T)
i = 0
while i < len(keys):
    j = i
    while j + 1 < len(keys) and keys[j + 1] == keys[i]: j += 1
    if keys[i]: g.lines.append(f"{keys[i]}:{g.t + i}:{g.t + j}")
    i = j + 1
g.t += len(keys)
g.save('N.txt', f'job N: boss 3 -> key -> maze -> WIN; maze keys from frame {T}')
print('maze starts at', T, 'ends', g.t)
