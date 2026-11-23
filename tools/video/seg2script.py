#!/usr/bin/env python3
"""Segment script -> frame script for sim/verilator Vtop (--script-file format).

Input, one segment per line:   <frames> [token ...]        '#' starts a comment
  <frames>  length of the segment in 60 Hz frames (a bare number, or 'Ns' for N seconds)
  @skip     following segments are simulated but NOT recorded (set-up: dialogs, debug-switch skips, walking to a room)
  @rec      following segments are recorded (default at the start of the file)
  tokens    U D L R   direction buttons (BTNU/D/L/R) held for the whole segment
            C         centre button (BTNC) held
            K         clap: the simulated microphone hears a clap for 100 ms at the segment start
            SW0..SW15 slide switch held ON for this segment only (OFF again when a segment without it starts)
            +SW0 / -SW0  switch turned ON and left on until a later '-SW0' (sticky; e.g. +SW0 keeps the boss door open)
            -         nothing (idle); a line with only a number is also idle
Output (stdout): the script text Vtop reads (U:from:to, 3:frame, K:frame ...).
Options: --total  print the number of frames to simulate (up to the last recorded frame)
         --rec    print the recorded ranges A:B (one per line, for Vtop --rec)
         --count  print the number of recorded frames
"""
import re, sys

BTN = "UDLRC"

def parse(lines):
    segs, rec, sticky = [], True, set()
    for no, raw in enumerate(lines, 1):
        t = raw.split('#', 1)[0].split()
        if not t:
            continue
        if t[0] in ('@rec', '@skip'):
            rec = t[0] == '@rec'
            continue
        m = re.fullmatch(r'(\d+)(s?)', t[0])
        if not m:
            sys.exit(f"line {no}: first field must be a frame count (or Ns), got {t[0]!r}")
        n = int(m.group(1)) * (60 if m.group(2) else 1)
        keys = set()
        for k in t[1:]:
            if k == '-':
                continue
            m2 = re.fullmatch(r'([+-])(SW(?:\d|1[0-5]))', k)
            if m2:
                (sticky.add if m2.group(1) == '+' else sticky.discard)(m2.group(2))
                continue
            if k in BTN or k == 'K':
                keys.add(k)
            elif re.fullmatch(r'SW(\d|1[0-5])', k):
                keys.add(k)
            else:
                sys.exit(f"line {no}: unknown token {k!r}")
        segs.append((n, keys | sticky, rec))
    return segs

def convert(segs):
    out, f = [], 1                       # frame numbers start at 1 (first vsync)
    open_btn = {}                        # key -> start frame
    sw_on = set()
    for n, keys, _rec in segs:
        for b in BTN:
            if b in keys and b not in open_btn:
                open_btn[b] = f
            elif b not in keys and b in open_btn:
                out.append(f"{b}:{open_btn.pop(b)}:{f-1}")
        for s in sorted(k for k in keys if k.startswith('SW')):
            if s not in sw_on:
                out.append(f"{ch(int(s[2:]))}:{f}  # {s} on"); sw_on.add(s)
        for s in sorted(sw_on - keys):
            out.append(f"{ch(int(s[2:]))}:{f}  # {s} off"); sw_on.discard(s)
        if 'K' in keys:
            out.append(f"K:{f}")
        f += n
    for b, st in open_btn.items():
        out.append(f"{b}:{st}:{f-1}")
    for s in sorted(sw_on):
        out.append(f"{ch(int(s[2:]))}:{f}  # {s} off")
    return out, f - 1

def ranges(segs):
    out, f = [], 1
    for n, _k, rec in segs:
        if rec:
            if out and out[-1][1] == f - 1: out[-1][1] = f + n - 1
            else: out.append([f, f + n - 1])
        f += n
    return out

def ch(i):                               # Vtop: 0-9 = SW0-9, a-f = SW10-15
    return str(i) if i < 10 else "abcdef"[i - 10]

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    src = open(args[0], encoding='utf-8').read().splitlines() if args else sys.stdin.read().splitlines()
    segs = parse(src)
    out, total = convert(segs)
    rg = ranges(segs)
    if '--total' in sys.argv:
        print(rg[-1][1] if rg else total)
    elif '--rec' in sys.argv:
        print("\n".join(f"{a}:{b}" for a, b in rg))
    elif '--count' in sys.argv:
        print(sum(b - a + 1 for a, b in rg))
    else:
        print("\n".join(out))
        print(f"TOTAL {total}", file=sys.stderr)
