BASE = 125
EXTRA = [(170,160),(300,160),(370,200),(440,200),(550,160),(740,160),(750,160),(915,160)]
def sh(t): return t + BASE + sum(e for o,e in EXTRA if t >= o)
INTRO = open('scripts/A.txt',encoding='utf-8').read().split('R:150:305')[0]
out = [INTRO.replace('# job A','# job D'), '# floor 3 (Simon): SW1 x2 skips floors 1-2, SW3 x2 = form 3 (flies over pits), SW2 clears combat rooms (all DEBUG); Simon walk = floor3.txt shifted by the dialog freezes\n']
for ln in open('../sim/verilator/scripts/floor3.txt',encoding='utf-8'):
    ln = ln.split('#')[0].strip()
    if not ln or ln.startswith('C:20'): continue
    for it in ln.split(','):
        p = it.split(':'); s = sh(int(p[1])); e = sh(int(p[2])) if len(p) > 2 else None
        out.append(f"{p[0]}:{s}" + (f":{e}" if e is not None else '') + '\n')
open('scripts/D.txt','w',encoding='utf-8').writelines(out); print(sh(1002), sh(1105), sh(2833))
