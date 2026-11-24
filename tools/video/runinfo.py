#!/usr/bin/env python3
"""Read a recorded input file (the --script-file format written by Vtop --record-inputs) and print
shell variables describing it, for scripts/verify_replay.sh and tools/video/render_run.sh:

    eval "$(python3 tools/video/runinfo.py RUN.txt)"

    FRAMES=<n>      frames to simulate: the '# end: frame N' footer, else last used frame + 60
    VID_A=<a>       first frame to put in the video (1 unless the file has '# render-range: A B')
    VID_B=<b>       last frame in the video; FRAMES is raised to at least this
    SEED=<text>     value of the '# seed:' header line ('' if absent)
    SKIP=<text>     value of the '# skip:' header line ('' if absent)

Format (same as Vtop --script-file): tokens separated by commas or newlines, '#' starts a comment.
  U:a:b D:a:b L:a:b R:a:b C:a:b   button held in frames a..b      B:a:b  Backspace (reset) held
  0..9 / a..f : f                 toggle SW0-9 / SW10-15 at frame f
  K:f                             clap heard by the microphone at frame f
"""
import re
import sys

TAIL = 60   # frames simulated after the last input when the file has no '# end:' footer


def parse(path):
    """-> (comments, actions) ; action = (key, from, to)"""
    comments, acts = [], []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\r\n")
            code, hash_, com = line.partition("#")
            if hash_:
                comments.append(com.strip())
            for tok in re.split(r"[,\s]+", code):
                if len(tok) < 3:
                    continue
                m = re.fullmatch(r"(.):(\d+)(?::(\d+))?", tok)
                if not m:
                    sys.stderr.write("runinfo: cannot parse token %r in %s\n" % (tok, path))
                    continue
                a = int(m.group(2))
                b = int(m.group(3)) if m.group(3) else a
                acts.append((m.group(1), a, b if b else a))
    return comments, acts


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    comments, acts = parse(sys.argv[1])
    last = max([max(a, b) for _, a, b in acts], default=0)
    frames = last + TAIL
    seed = skip = ""
    va, vb = 1, None
    for c in comments:
        m = re.match(r"end:\s*frame\s+(\d+)", c)
        if m:
            frames = int(m.group(1))
        m = re.match(r"render-range:\s*(\d+)\s+(\d+)", c)
        if m:
            va, vb = int(m.group(1)), int(m.group(2))
        m = re.match(r"seed:\s*(.*)", c)
        if m:
            seed = m.group(1)
        m = re.match(r"skip:\s*(.*)", c)
        if m:
            skip = m.group(1)
    if vb is None:
        vb = frames
    else:
        frames = vb          # a section: simulate from frame 0 but stop at its last frame
    print("FRAMES=%d" % frames)
    print("VID_A=%d" % va)
    print("VID_B=%d" % vb)
    print("SEED='%s'" % seed.replace("'", ""))
    print("SKIP='%s'" % skip.replace("'", ""))


if __name__ == "__main__":
    main()
