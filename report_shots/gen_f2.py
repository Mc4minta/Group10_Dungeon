import re
INTRO = open('scripts/A.txt',encoding='utf-8').read().split('R:150:305')[0]   # title + intro taps (to frame 145)
BASE = 125
# (orig frame >= t, extra frames): dialogs that freeze the game
EXTRA = [(170,160),(330,320),(600,160),(610,160),(845,160)]
def sh(t): return t + BASE + sum(e for o,e in EXTRA if t >= o)
out = [INTRO.replace('# job A','# job C'), '# floor 2 (Sokoban): SW1 (DEBUG) skips floor 1, SW2 (DEBUG) clears combat rooms; walking/pushing = floor2.txt shifted by the dialog freezes\n']
for ln in open('../sim/verilator/scripts/floor2.txt',encoding='utf-8'):
    ln = ln.split('#')[0].strip()
    if not ln: continue
    if ln.startswith('C:20'): continue
    for it in ln.split(','):
        p = it.split(':')
        s = sh(int(p[1])); e = sh(int(p[2])) if len(p) > 2 else None
        out.append(f"{p[0]}:{s}" + (f":{e}" if e is not None else '') + '\n')
open('scripts/C.txt','w',encoding='utf-8').writelines(out)
print(out[-1], sh(2368))
