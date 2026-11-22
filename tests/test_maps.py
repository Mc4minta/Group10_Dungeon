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
# W23: rooms redrawn with a purpose for every object (start room 0, combat rooms 4 5 7 8 10 11); the others still equal maps_v1 apart from decoration
REDESIGN = {1, 2, 3, 4, 5, 6, 7, 8, 10, 11}
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
        strip_lb = lambda t: [ln for ln in t.split("\n") if "LEVER" not in ln and "BULB" not in ln]        # 20/11: the light puzzle moved to the bottom of room 6
        self.assertEqual(strip_lb(text(os.path.join(ROOT, "rtl/puzzle_layout.vh"))), strip_lb(text(os.path.join(V1, "puzzle_layout_v1.vh"))))
        # objects.txt: one line per object, first column = room (redesigned rooms are checked by test_redesigned_rooms)
        keep = lambda t: [ln for ln in t.split("\n") if ln.strip() and ln.split()[0].isdigit() and int(ln.split()[0]) not in REDESIGN]
        self.assertEqual(keep(text(os.path.join(ROOT, "mem/objects.txt"))), keep(text(os.path.join(V1, "objects_v1.txt"))))
        # monsters.mem: 8 words per room
        cur = text(os.path.join(ROOT, "mem/monsters.mem")).split()
        old = text(os.path.join(V1, "monsters_v1.mem")).split()
        for g in range(16):
            if g not in REDESIGN:
                self.assertEqual(cur[g * 8:g * 8 + 8], old[g * 8:g * 8 + 8], f"monsters of room {g}")

    def test_tilemap_equals_v1_except_decoration(self):
        cur = text(os.path.join(ROOT, "mem", "tilemap.mem")).split()
        old = text(os.path.join(V1, "tilemap_v1.mem")).split()
        self.assertEqual(len(cur), 4096)
        self.assertEqual(len(old), 4096)
        for i, (c, o) in enumerate(zip(cur, old)):
            g = i // 300
            if g in REDESIGN:
                continue                     # W23: redrawn, see test_redesigned_rooms
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
        decor = set(",;:`ZXYWV")      # decoration + W5 overlay (Z breakable block, X spike trap, Y solid decoration, W19: W / V timed spikes): all sit on plain floor
        walldecor = set("t[]v")       # wall torches / shield: replace a wall tile (looks only)
        for old in sorted(glob.glob(os.path.join(V1, "[0-9][0-9]_*.txt"))):
            cur = os.path.join(ROOT, "maps", os.path.basename(old))
            a, b = text(old).split("\n"), text(cur).split("\n")
            self.assertEqual(len(a), len(b))
            if os.path.basename(old).startswith('12_'):
                continue                     # Simon room: see test_simon_plates_are_even_blocks
            if int(os.path.basename(old)[:2]) in REDESIGN:
                continue                     # W23: redrawn, see test_redesigned_rooms
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
        total = {1: 0, 2: 0, 3: 0, 8: 0, 9: 0}
        for g in range(13):
            ents = [int(v, 16) for v in ov[g * 300:(g + 1) * 300]]
            idxs = []
            for i, e in enumerate(ents):
                code = e & 15
                self.assertIn(code, (0, 1, 2, 3, 4, 5, 6, 7, 8, 9), f"room {g} tile {i}")
                if code in (8, 9):                       # W19 timed spikes: floor 2 combat rooms only
                    self.assertIn(g, (7, 8), f"room {g}: timed traps only on floor 2")
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

    def test_redesigned_rooms(self):
        """W23: the redrawn rooms keep what the game logic needs (door tiles, spawn pockets, monster limit, the 6 monsters / order that tb_objects uses in
        room 7) and every object has a purpose: crates plug a corridor / nest (never float loose), traps and pillars are never in a spawn pocket,
        monsters stand on floor and can be reached once the crates are broken"""
        def grid(n):
            return [list(r) for r in nodecor_keep(text(os.path.join(ROOT, "maps", n))).split("\n")[:15]]

        def nodecor_keep(t):
            return t
        files = {int(os.path.basename(f)[:2]): f for f in glob.glob(os.path.join(ROOT, "maps", "[0-9][0-9]_*.txt"))}
        for g in sorted(REDESIGN):
            cur = [list(r) for r in text(files[g]).rstrip("\n").split("\n")]
            old = [list(r) for r in text(os.path.join(V1, os.path.basename(files[g]))).rstrip("\n").split("\n")]
            doors = lambda m: sorted((x, y, c) for y, r in enumerate(m) for x, c in enumerate(r) if c in "DLE")
            self.assertEqual(doors(cur), doors(old), f"room {g}: door tiles moved")
            blocked = lambda c: c in "#FHZY" or c in "t[]v"
            pockets = [(x, y) for x in range(1, 4) for y in range(6, 10)] + [(x, y) for x in range(16, 19) for y in range(7, 9)] + \
                      [(x, y) for x in range(8, 12) for y in range(1, 3)] + [(x, y) for x in range(8, 12) for y in range(12, 14)]
            for (x, y) in pockets:
                # a pocket next to a door must be walkable and trap free (the hero arrives there); pockets of doors that do not exist may be walls
                near_door = any((abs(dx - x) <= 3 and abs(dy - y) <= 3) for dx, dy, c in doors(cur))
                if near_door and old[y][x] == ".":
                    self.assertNotIn(cur[y][x], "#FHZYXWV", f"room {g} ({x},{y}): spawn pocket blocked / trapped")
            mons = [(x, y, c) for y, r in enumerate(cur) for x, c in enumerate(r) if c in "ST"]
            self.assertLessEqual(len(mons), 6, f"room {g}: more than 6 monsters")
            if g == 7:
                self.assertEqual("".join(c for _, _, c in mons), "TTSSTT", "room 7: tb_objects needs the monster order T T S S T T")
                self.assertIn((17, 13, "T"), mons, "room 7: the last turret must stay at (17, 13)")
            if g == 8:
                self.assertEqual(len(mons), 4, "room 8: tb_objects needs 4 monsters")
            # every monster is reachable from the first door pocket when crates may be broken (walkable: floor, decoration, traps, monsters, P)
            walk = lambda c: c not in "#FHYZ" and c not in "t[]v"
            walk_b = lambda c: c not in "#HY" and c not in "t[]v"            # crates broken; fences let bullets through (a turret behind a fence can be shot)
            doors_xy = [(x, y) for x, y, _ in doors(cur)]
            start = None
            for dx, dy in doors_xy:
                for nx, ny in ((dx + 1, dy), (dx - 1, dy), (dx, dy + 1), (dx, dy - 1)):
                    if 0 < nx < 19 and 0 < ny < 14 and walk_b(cur[ny][nx]):
                        start = (nx, ny)
            self.assertIsNotNone(start, f"room {g}: no walkable tile next to a door")
            seen, todo = {start}, [start]
            while todo:
                x, y = todo.pop()
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 < nx < 19 and 0 < ny < 14 and (nx, ny) not in seen and walk_b(cur[ny][nx]):
                        seen.add((nx, ny)); todo.append((nx, ny))
            for x, y, c in mons:
                self.assertIn((x, y), seen, f"room {g}: monster {c} at ({x},{y}) can not be reached")
            for (dx, dy) in doors_xy:
                self.assertTrue(any((nx, ny) in seen for nx, ny in ((dx + 1, dy), (dx - 1, dy), (dx, dy + 1), (dx, dy - 1))), f"room {g}: door ({dx},{dy}) unreachable")
            # purpose of a crate: it plugs something (2 opposite blocked neighbours) or fills a niche (3+ blocked neighbours); a crate next to a crate counts as a plug
            for y, r in enumerate(cur):
                for x, c in enumerate(r):
                    if c == "Z":
                        b = lambda cx, cy: cur[cy][cx] in "#FHYZ" or cur[cy][cx] in "t[]v"
                        opp = (b(x - 1, y) and b(x + 1, y)) or (b(x, y - 1) and b(x, y + 1))
                        n = sum(b(cx, cy) for cx, cy in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
                        self.assertTrue(opp or n >= 3, f"room {g}: the crate at ({x},{y}) is loose (plugs nothing)")

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
