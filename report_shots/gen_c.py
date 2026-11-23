from tl import TL
# ---- C: floor 2 Sokoban (fig 27, 28). SW1 (DEBUG) skips floor 1, SW2 (DEBUG) clears combat rooms, pushes = solver of floor2.txt
t = TL().intro()
t.at(160); t.pulse2('1')
t.at(455); t.hold('R', 152)                     # START -> right door -> C1
t.at(935); t.spam('2', 6, 30)                   # C1: lock + box dialogs, then clear
t.hold('U', 30); t.hold('R', 236); t.hold('U', 40); t.hold('L', 100); t.hold('U', 80)   # C1 -> top door (row 5 -> col 16 -> row 3 -> col 9/10)
t.at(1770); t.spam('2', 14, 30)                 # C2: lock dialog, clear, clear dialog
t.wait(10); t.hold('U', 80); t.wait(5); t.hold('R', 70); t.wait(5); t.hold('U', 25); t.wait(5); t.wait(83); t.hold('R', 105)   # C2 -> right door -> Sokoban room
t.wait(215)                                      # room dialog
t.hold('L', 5); t.wait(4); t.hold('U', 8)          # align on tile (1,7) = (32,224) from the spawn (42,240), as floor2.txt
t.wait(8)
S = t.t - 870
for ln in open('../sim/verilator/scripts/floor2.txt', encoding='utf-8'):
    ln = ln.split('#')[0].strip()
    if not ln: continue
    for it in ln.split(','):
        p = it.split(':')
        if int(p[1]) < 870: continue
        t.lines.append(f"{p[0]}:{int(p[1])+S}" + (f":{int(p[2])+S}" if len(p) > 2 else ''))
        t.t = max(t.t, int(p[-1]) + S)
t.save('C.txt', 'job C: floor 2 Sokoban (gen_c.py)')
