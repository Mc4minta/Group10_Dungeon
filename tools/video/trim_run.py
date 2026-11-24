#!/usr/bin/env python3
"""Cut a recording to a frame range so one section can be re-rendered alone.

    trim_run.py RUN.txt START END OUT.txt [--standalone]

Default (what you want for re-rendering a section of a long run):
  The game state at frame START exists only because of everything that was pressed before it, so
  every input up to END is kept (all earlier switch toggles and buttons included: the switch state
  that is active at START is therefore reproduced exactly). Inputs after END are dropped, buttons
  held across END are closed at END. The file gets the comment line '# render-range: START END';
  tools/video/render_run.sh simulates frames 1..END but only puts START..END into the video/audio
  (Vtop --rec START:END). The replay is as slow as the run up to END.

--standalone:
  A self-contained cut: frame START becomes frame 1. Buttons held at START are clipped to start at
  frame 1, an odd number of toggles of a switch before START becomes one toggle at frame 1, claps
  before START are dropped. The game then starts at the TITLE screen, NOT at the place it was in the
  original run, so this only makes sense for checking the input format or for sections that start
  from a fresh game.

Format: see tools/video/runinfo.py.
"""
import os
import re
import sys
from collections import OrderedDict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from runinfo import parse  # noqa: E402

RANGE_KEYS = "UDLRCB"


def fmt(key, a, b=None):
    return "%s:%d" % (key, a) if b is None else "%s:%d:%d" % (key, a, b)


def main():
    args = [a for a in sys.argv[1:] if a != "--standalone"]
    standalone = "--standalone" in sys.argv[1:]
    if len(args) != 4:
        sys.exit(__doc__)
    src, start, end, out = args[0], int(args[1]), int(args[2]), args[3]
    if start < 1 or end < start:
        sys.exit("trim_run: need 1 <= START <= END")

    comments, acts = parse(src)
    keep_comments = [c for c in comments if not re.match(r"(end|render-range|trimmed)\b", c)]
    events = []          # (sort_frame, order, text)

    if not standalone:
        for k, a, b in acts:
            if a > end:
                continue
            if k in RANGE_KEYS:
                events.append((a, 0, fmt(k, a, min(b, end))))
            else:
                events.append((a, 1, fmt(k, a)))
        head = ["trimmed from %s: frames %d..%d (all inputs up to %d kept, game state at %d is reproduced)"
                % (src.replace("\\", "/").rsplit("/", 1)[-1], start, end, end, start),
                "render-range: %d %d" % (start, end)]
        total = end
    else:
        parity = OrderedDict()
        shift = start - 1
        for k, a, b in acts:
            if k in RANGE_KEYS:
                if b < start or a > end:
                    continue
                events.append((max(a, start) - shift, 0, fmt(k, max(a, start) - shift, min(b, end) - shift)))
            elif k == "K":
                if start <= a <= end:
                    events.append((a - shift, 1, fmt(k, a - shift)))
            else:                                     # switch toggle
                if a < start:
                    parity[k] = parity.get(k, 0) ^ 1
                elif a <= end:
                    events.append((a - shift, 1, fmt(k, a - shift)))
        for k, odd in parity.items():
            if odd:
                events.append((1, 1, fmt(k, 1)))
        head = ["trimmed from %s: frames %d..%d STANDALONE (frame %d -> 1; the game starts at TITLE, not where the original run was)"
                % (src.replace("\\", "/").rsplit("/", 1)[-1], start, end, start)]
        total = end - shift

    events.sort(key=lambda e: (e[0], e[1], e[2]))
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        for c in keep_comments:
            f.write("# %s\n" % c)
        for h in head:
            f.write("# %s\n" % h)
        for _, _, t in events:
            f.write(t + "\n")
        f.write("# end: frame %d\n" % total)
    print("trim_run: %d inputs -> %s (%d frames)" % (len(events), out, total))


if __name__ == "__main__":
    main()
