"""Timing-robust maze solution: only 'hold a direction until the ball is stopped by a wall' moves (the wall zeroes the velocity, so every
move ends at rest and the result does not depend on exact frame timing). BFS over rest positions with the exact model of rtl/maze.v."""
import collections, json, sys
src = open('maze_solve.py').read().split("pq = [")[0]
exec(src.replace("sys.argv[1]", "'3'"))
HOLDN = 200
def slide(s, k):
    seq = []
    for i in range(HOLDN):
        s = step(s, k); seq.append(s)
        if goal(s): return s, i + 1, True
        if i > 4 and s[2] == 0 and s[3] == 0 and seq[-2][:2] == s[:2]: return s, i + 1, False   # stopped by a wall
    return s, HOLDN, False
q = collections.deque([START]); par = {START: None}; found = None
while q and not found:
    s = q.popleft()
    for k in 'UDLR':
        t, n, g = slide(s, k)
        key = (t[0], t[1])
        if g: par[('goal',)] = (s, k, n); found = ('goal',); break
        if key == (s[0], s[1]) or (t[0], t[1], 0, 0) in par: continue
        par[(t[0], t[1], 0, 0)] = (s, k, n); q.append((t[0], t[1], 0, 0))
if not found: print('NO SLIDE-ONLY SOLUTION'); sys.exit(1)
path = []; cur = found
while par[cur]: s, k, n = par[cur]; path.append((k, n)); cur = (s[0], s[1], 0, 0) if s != START else START
path.reverse(); print(path, sum(n for _, n in path))
json.dump(path, open('maze_slide.json', 'w'))
