"""tiny timeline builder: builds a Vtop --script-file (key:start:end per line) from hold/wait/pulse steps"""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
class TL:
    def __init__(s): s.t = 0; s.lines = []
    def at(s, t): s.t = t; return s
    def wait(s, n): s.t += n; return s
    def hold(s, k, n): s.lines.append(f"{k}:{s.t}:{s.t+n-1}"); s.t += n; return s
    def pulse(s, k): s.lines.append(f"{k}:{s.t}:{s.t+1}"); s.t += 3; return s   # 2-frame press
    def pulse2(s, k): s.lines.append(f"{k}:{s.t}"); s.lines.append(f"{k}:{s.t+5}"); s.t += 12; return s  # 1-frame pulses as in floorN.txt (SW debug)
    def spam(s, k, n, gap): 
        for _ in range(n): s.pulse2(k); s.wait(gap - 12)
        return s
    def intro(s):
        s.lines.append("C:20:23")
        for t in range(30, 150, 6): s.lines.append(f"C:{t}:{t+1}")
        s.t = 150; return s
    def save(s, name, head=""):
        open(os.path.join(HERE, "scripts", name), "w", encoding="utf-8").write(f"# {head}\n" + "\n".join(s.lines) + "\n")
        print(name, "ends at frame", s.t)
