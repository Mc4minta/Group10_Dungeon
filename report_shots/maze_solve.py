"""Exact Python model of rtl/maze.v (button mode) + best-first search for a key sequence that rolls the ball from S to G.
Output: list of (key, frames) segments -> maze_keys.json. Frame 0 = first maze frame_tick after 'start'."""
import heapq, json, sys, collections
rows = [l.rstrip('\n') for l in open('../maps/maze/maze.txt')]
H, W = len(rows), len(rows[0])
wall = lambda tx, ty: rows[ty][tx] == '#'
BS, MAXV, ACC = 20, 96, 8
def blocked(x, y):  # box top-left pixel position -> any corner in wall
    for cx in (x, x + BS - 1):
        for cy in (y, y + BS - 1):
            if wall(cx >> 5, cy >> 5): return True
    return False
def step(s, key):
    px, py, vx, vy = s
    ax = ACC if key == 'R' else -ACC if key == 'L' else 0
    ay = ACC if key == 'D' else -ACC if key == 'U' else 0
    ovx, ovy = vx, vy
    nv = vx + ax; nv -= nv >> 4; vx = max(-MAXV, min(MAXV, nv))
    nv = vy + ay; nv -= nv >> 4; vy = max(-MAXV, min(MAXV, nv))
    nx = px + ovx
    if blocked(nx >> 4, py >> 4): vx = 0
    else: px = nx
    ny = py + vy        # maze.v: Y uses the NEW vy (X uses the old vx)
    if blocked(px >> 4, ny >> 4): vy = 0
    else: py = ny
    return (px, py, vx, vy)
def goal(s): return rows[((s[1] >> 4) + BS // 2) >> 5][((s[0] >> 4) + BS // 2) >> 5] == 'G'
# tile distance field from G
dist = {}
q = collections.deque()
for y in range(H):
    for x in range(W):
        if rows[y][x] == 'G': dist[(x, y)] = 0; q.append((x, y))
while q:
    x, y = q.popleft()
    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
        n = (x+dx, y+dy)
        if 0 <= n[0] < W and 0 <= n[1] < H and not wall(*n) and n not in dist:
            dist[n] = dist[(x, y)] + 1; q.append(n)
def h(s):
    tx, ty = ((s[0] >> 4) + BS // 2) >> 5, ((s[1] >> 4) + BS // 2) >> 5
    return dist.get((tx, ty), 99) * 32 / 5.0   # frames at ~5 px/frame
START = ((32 + 6) * 16, (32 + 6) * 16, 0, 0)
HOLD = int(sys.argv[1]) if len(sys.argv) > 1 else 3
def key(s): return (s[0] >> 5, s[1] >> 5, s[2] >> 4, s[3] >> 4)
pq = [(h(START), 0, START, None)]
seen = {key(START): 0}
par = {}
cnt = 0
while pq:
    f, g, s, _ = heapq.heappop(pq)
    if goal(s): break
    for k in 'UDLR':
        t = s
        for _ in range(HOLD): t = step(t, k)
        # coast variants
        for coast in (0, 6):
            u = t
            for _ in range(coast): u = step(u, '')
            kk = key(u); ng = g + HOLD + coast
            if kk in seen and seen[kk] <= ng: continue
            seen[kk] = ng; par[(u)] = (s, k, HOLD, coast)
            heapq.heappush(pq, (ng + 1.5 * h(u), ng, u, None))
    cnt += 1
    if cnt > 400000: print('give up'); sys.exit(1)
path = []
cur = s
while cur in par:
    p, k, hd, co = par[cur]; path.append((k, hd, co)); cur = p
path.reverse()
# frame list
frames = []
for k, hd, co in path: frames += [k] * hd + [''] * co
# verify
st = START
for k in frames: st = step(st, k)
print('goal' if goal(st) else 'FAIL', len(frames), 'frames', 'expanded', cnt)
json.dump(frames, open('maze_keys.json', 'w'))
