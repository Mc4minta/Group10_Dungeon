#!/usr/bin/env python3
"""Old frame script (key:from:to, as in sim/verilator/scripts/*.txt) -> segment script for render.sh.
Helper for turning a verified frame-exact script into the segment format. usage: frames2seg.py in.txt [total_frames]"""
import re, sys

def convert(text, total=None):
    ev = []                                    # (frame, kind, key)
    for raw in text.splitlines():
        s = ''.join(raw.split('#', 1)[0].split())
        for item in filter(None, s.split(',')):
            m = re.fullmatch(r'([UDLRCK0-9a-f]):(\d+)(?::(\d+))?', item)
            if not m: sys.exit(f"bad item {item!r}")
            k, a, b = m.group(1), int(m.group(2)), int(m.group(3) or m.group(2))
            if k in 'UDLRC': ev.append((a, '+', k)); ev.append((b + 1, '-', k))
            elif k == 'K': ev.append((a, 'k', k))
            else:
                sw = int(k) if k.isdigit() else 10 + 'abcdef'.index(k)
                ev.append((a, 't', sw))
    pts = sorted({e[0] for e in ev} | {1})
    end = total or (max(pts) + 1)
    held, sw, out = set(), set(), []
    for i, t in enumerate(pts):
        for f, kind, k in ev:
            if f != t: continue
            if kind == '+': held.add(k)
            elif kind == '-': held.discard(k)
            elif kind == 't': sw ^= {k}
        clap = any(f == t and kind == 'k' for f, kind, k in ev)
        nxt = pts[i + 1] if i + 1 < len(pts) else end
        if nxt <= t: continue
        toks = sorted(held) + (['K'] if clap else []) + [f"SW{s}" for s in sorted(sw)]
        out.append((nxt - t, toks))
    return out

if __name__ == '__main__':
    segs = convert(open(sys.argv[1], encoding='utf-8').read(), int(sys.argv[2]) if len(sys.argv) > 2 else None)
    for n, toks in segs:
        print(f"{n:5d} {' '.join(toks)}".rstrip())
