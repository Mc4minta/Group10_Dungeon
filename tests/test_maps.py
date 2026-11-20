#!/usr/bin/env python3
"""Map regression tests: the decorated maps must change ONLY how floors look.   python tests/test_maps.py

Compares the current build with the pre-decoration backup in maps_v1/:
  - objects.txt, monsters.mem, puzzle_layout.vh are byte-identical (no spawn / enemy / puzzle / exit change)
  - tilemap.mem equals the old tilemap after turning decoration ids (C-F outside the Simon room) back into floor (1)
  - decoration is only used in rooms where tile ids C-F behave exactly like floor
  - the Sokoban room is untouched and still solvable
"""
import glob
import os
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
V1 = os.path.join(ROOT, "maps_v1")
DECOR_ROOMS = {0, 3, 4, 5, 6, 7, 8}
SIMON_GRID = 12


def nodecor(s):
    """wall torches / shields (t [ ] v) are drawn on wall tiles only: for the comparisons with the original maps they count as wall"""
    return "".join("#" if c in "t[]v" else c for c in s)


def text(p):
    with open(p, encoding="utf-8", newline="") as f:
        return f.read().replace("\r\n", "\n")


class Maps(unittest.TestCase):
    def test_backup_exists(self):
        self.assertEqual(len(glob.glob(os.path.join(V1, "[0-9][0-9]_*.txt"))), 13)

    def test_non_tile_outputs_identical_to_v1(self):
        for cur, old in (("mem/objects.txt", "objects_v1.txt"), ("mem/monsters.mem", "monsters_v1.mem"),
                         ("rtl/puzzle_layout.vh", "puzzle_layout_v1.vh")):
            self.assertEqual(text(os.path.join(ROOT, cur)), text(os.path.join(V1, old)), cur)

    def test_tilemap_equals_v1_except_decoration(self):
        cur = text(os.path.join(ROOT, "mem", "tilemap.mem")).split()
        old = text(os.path.join(V1, "tilemap_v1.mem")).split()
        self.assertEqual(len(cur), 4096)
        self.assertEqual(len(old), 4096)
        for i, (c, o) in enumerate(zip(cur, old)):
            g = i // 300
            if g == SIMON_GRID:
                continue                     # Simon room: plates moved to even rows (see test_simon_plates_are_even_blocks)
            if c != o:
                self.assertIn(c, "cdef", f"index {i}: only decoration ids may differ, got {c} (was {o})")
                self.assertEqual(o, "1", f"index {i}: decoration may only replace plain floor")
                self.assertIn(g, DECOR_ROOMS, f"decoration in room {g}")

    def test_decoration_only_in_allowed_rooms(self):
        cur = text(os.path.join(ROOT, "mem", "tilemap.mem")).split()
        for g in range(13):
            ids = set(cur[g * 300:(g + 1) * 300])
            if g not in DECOR_ROOMS and g != SIMON_GRID:
                self.assertFalse(ids & set("cdef"), f"room {g} must not contain tile ids C-F")

    def test_map_files_only_differ_by_decoration(self):
        decor = set(",;:`ZXY")        # decoration + W5 overlay (Z breakable block, X spike trap, Y solid decoration): all sit on plain floor
        walldecor = set("t[]v")       # wall torches / shield: replace a wall tile (looks only)
        for old in sorted(glob.glob(os.path.join(V1, "[0-9][0-9]_*.txt"))):
            cur = os.path.join(ROOT, "maps", os.path.basename(old))
            a, b = text(old).split("\n"), text(cur).split("\n")
            self.assertEqual(len(a), len(b))
            if os.path.basename(old).startswith('12_'):
                continue                     # Simon room: see test_simon_plates_are_even_blocks
            for y, (ra, rb) in enumerate(zip(a, b)):
                self.assertEqual(len(ra), len(rb))
                for x, (ca, cb) in enumerate(zip(ra, rb)):
                    if ca != cb:
                        if cb in walldecor:
                            self.assertEqual(ca, "#", f"{os.path.basename(old)} ({x},{y}): wall decoration only replaces a wall")
                            continue
                        self.assertEqual(ca, ".", f"{os.path.basename(old)} ({x},{y})")
                        self.assertIn(cb, decor)

    def test_overlay_rules(self):
        """W5 overlay.mem: codes 0..3, only on plain floor, only in allowed rooms, <= 8 breakable blocks with unique indices 0..n-1 per room,
        and the overlay never disconnects a room: every door tile stays reachable from every other one (breakable blocks and decorations count as walls)"""
        ov = text(os.path.join(ROOT, "mem", "overlay.mem")).split()
        tm = text(os.path.join(ROOT, "mem", "tilemap.mem")).split()
        self.assertEqual(len(ov), 4096)
        allowed = {0, 1, 4, 5, 7, 8, 10, 11}
        total = {1: 0, 2: 0, 3: 0}
        for g in range(13):
            ents = [int(v, 16) for v in ov[g * 300:(g + 1) * 300]]
            idxs = []
            for i, e in enumerate(ents):
                code = e & 15
                self.assertIn(code, (0, 1, 2, 3, 4, 5, 6, 7), f"room {g} tile {i}")
                self.assertEqual(e >> 7, 0, "bit 7 unused")
                if 4 <= code <= 7:                       # wall decoration: on a wall tile, no collision, any room
                    self.assertEqual(tm[g * 300 + i], "0", f"room {g} tile {i}: wall decoration only on a wall")
                    continue
                if code:
                    total[code] += 1
                    self.assertIn(g, allowed, f"overlay in room {g}")
                    self.assertEqual(tm[g * 300 + i], "1", f"room {g} tile {i}: overlay only on plain floor")
                    if code == 1:
                        idxs.append((e >> 4) & 7)
                    else:
                        self.assertEqual((e >> 4) & 7, 0)
            self.assertEqual(sorted(idxs), list(range(len(idxs))), f"room {g}: breakable indices must be 0..n-1")
            self.assertLessEqual(len(idxs), 8)
            if not any(e & 15 for e in ents):
                continue

            def reach(block):
                cells = [(x, y) for y in range(15) for x in range(20)]
                def free(x, y):
                    t = int(tm[g * 300 + y * 20 + x], 16)
                    return t not in (0, 6) and not (block and (ents[y * 20 + x] & 15) in (1, 3))
                doors = [(x, y) for (x, y) in cells if int(tm[g * 300 + y * 20 + x], 16) in (2, 3, 4)]
                start = next((c for c in cells if free(*c) and int(tm[g * 300 + c[1] * 20 + c[0]], 16) == 1), None)
                seen, todo = {start}, [start]
                while todo:
                    x, y = todo.pop()
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if 0 <= nx < 20 and 0 <= ny < 15 and (nx, ny) not in seen and (free(nx, ny) or (nx, ny) in doors):
                            seen.add((nx, ny)); todo.append((nx, ny))
                return {d for d in doors if d in seen}, {c for c in cells if free(*c) and int(tm[g * 300 + c[1] * 20 + c[0]], 16) == 1 and c in seen}
            d0, f0 = reach(False)
            d1, f1 = reach(True)
            self.assertEqual(d0, d1, f"room {g}: the overlay cuts off a door")
            self.assertTrue(f1, f"room {g}: nothing walkable left")
        self.assertGreater(total[1], 0); self.assertGreater(total[2], 0); self.assertGreater(total[3], 0)

    def test_simon_plates_are_even_blocks(self):
        """each Simon plate is a 2x2 block of tiles starting on an even column and an even row (the renderer draws it as ONE big plate);
        apart from the plate positions the room equals the original"""
        n = "12_f3_puzzle_simon.txt"
        a, b = text(os.path.join(V1, n)).split("\n"), nodecor(text(os.path.join(ROOT, "maps", n))).split("\n")
        for ch in "qwer":
            pos = [(x, y) for y, row in enumerate(b) for x, c in enumerate(row) if c == ch]
            self.assertEqual(len(pos), 4, f"plate {ch}: needs exactly 4 tiles")
            x0, y0 = min(p[0] for p in pos), min(p[1] for p in pos)
            self.assertEqual(sorted(pos), sorted([(x0, y0), (x0 + 1, y0), (x0, y0 + 1), (x0 + 1, y0 + 1)]), f"plate {ch}: not a 2x2 block")
            self.assertEqual((x0 % 2, y0 % 2), (0, 0), f"plate {ch} at ({x0},{y0}): must start on an even column and row")
        strip = lambda rows: ["".join("." if c in "qwer" else c for c in r) for r in rows]
        self.assertEqual(strip(a), strip(b), "only the plates may move")

    def test_sokoban_room_unchanged_and_solvable(self):
        n = "09_f2_puzzle_sokoban.txt"
        self.assertEqual(nodecor(text(os.path.join(ROOT, "maps", n))), text(os.path.join(V1, n)))
        r = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "solve_sokoban.py")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("min pushes", r.stdout)

    def test_build_maps_is_reproducible(self):
        """running build_maps.py again must not change any generated file"""
        before = {p: text(os.path.join(ROOT, p)) for p in ("mem/tilemap.mem", "mem/objects.txt", "mem/monsters.mem", "rtl/puzzle_layout.vh")}
        r = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "build_maps.py")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        for p, t in before.items():
            self.assertEqual(text(os.path.join(ROOT, p)), t, p)


if __name__ == "__main__":
    unittest.main(verbosity=2)
