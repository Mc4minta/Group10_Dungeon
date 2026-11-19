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
        decor = set(",;:`")
        for old in sorted(glob.glob(os.path.join(V1, "[0-9][0-9]_*.txt"))):
            cur = os.path.join(ROOT, "maps", os.path.basename(old))
            a, b = text(old).split("\n"), text(cur).split("\n")
            self.assertEqual(len(a), len(b))
            for y, (ra, rb) in enumerate(zip(a, b)):
                self.assertEqual(len(ra), len(rb))
                for x, (ca, cb) in enumerate(zip(ra, rb)):
                    if ca != cb:
                        self.assertEqual(ca, ".", f"{os.path.basename(old)} ({x},{y})")
                        self.assertIn(cb, decor)

    def test_sokoban_room_unchanged_and_solvable(self):
        n = "09_f2_puzzle_sokoban.txt"
        self.assertEqual(text(os.path.join(ROOT, "maps", n)), text(os.path.join(V1, n)))
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
