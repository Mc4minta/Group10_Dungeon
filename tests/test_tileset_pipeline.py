#!/usr/bin/env python3
"""Tests for the tileset (map art) pipeline.   python tests/test_tileset_pipeline.py"""
import contextlib
import hashlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import build_tileset_mem as T  # noqa: E402
from PIL import Image  # noqa: E402

N = T.TILE_WORDS


def words_of(path):
    with open(path, encoding="ascii") as f:
        return [int(x, 16) for x in f.read().split()]


def run_build(root, *args):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = T.main(["--root", root, *args])
    return rc, buf.getvalue()


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def indep_tile(png, row, col, recolor="rgb", cs=16, scale=2, base=None, gain=1.0, cut=()):
    """independent conversion (does not use build code); None if the cell is empty"""
    im = Image.open(png).convert("RGBA")
    out = list(base) if base else [None] * N
    idx = {"r": 0, "g": 1, "b": 2}
    opq = 0
    for y in range(cs):
        for x in range(cs):
            r, g, b, a = im.getpixel((col * cs + x, row * cs + y))
            if a < 128 or (r, g, b) in cut:
                continue
            opq += 1
            ch = tuple(min(255, int(q * gain + 0.5)) for q in (r, g, b))
            v = [(ch[idx[c]] * 15 + 127) // 255 for c in recolor]
            w = (v[0] << 8) | (v[1] << 4) | v[2]
            for dy in range(scale):
                for dx in range(scale):
                    out[(y * scale + dy) * 32 + x * scale + dx] = w
    return out if opq else None


def load_json(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


class RealProject(unittest.TestCase):
    def setUp(self):
        self.cfg = T.load_config(os.path.join(ROOT, "sprites", "tileset.json"), ROOT)
        self.mem = words_of(os.path.join(ROOT, "mem", "tileset.mem"))
        self.v1 = words_of(os.path.join(ROOT, "mem", "tileset_v1.mem"))
        self.b = T.build(self.cfg, ROOT)

    def test_line_count(self):
        self.assertEqual(len(self.mem), 49152)
        self.assertEqual(len(self.v1), 49152)

    def test_mem_is_up_to_date(self):
        self.assertEqual(self.mem, self.b.out, "mem/tileset.mem is stale: run python scripts/build_tileset_mem.py")

    def test_fallback_tiles_identical_to_v1(self):
        for (n, t), r in self.b.result.items():
            if r["fallback"]:
                i = T.tidx(n, t)
                self.assertEqual(self.mem[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N], (n, t))

    def test_disabled_floors_identical_to_v1(self):
        for n, f in self.cfg["floors"].items():
            if not f["enabled"]:
                a, b = (n - 1) * 16 * N, n * 16 * N
                self.assertEqual(self.mem[a:b], self.v1[a:b])

    def test_all_values_rgb444(self):
        self.assertTrue(all(0 <= w <= 0xFFF for w in self.mem))

    def test_no_tile_shifted(self):
        """every non-base tile equals an independent conversion of its source cell"""
        for (n, t), r in self.b.result.items():
            spec = self.cfg["overrides"].get((n, t)) or self.cfg["tiles"].get(t)
            if r["fallback"] or spec.get("base") is not None:
                continue
            png = os.path.join(ROOT, self.cfg["floors"][n]["sheet"])
            exp = indep_tile(png, spec["cell"][0], spec["cell"][1], spec.get("recolor", self.cfg["floors"][n]["recolor"]), gain=spec.get("gain", self.cfg["floors"][n]["gain"]))
            i = T.tidx(n, t)
            self.assertEqual(self.mem[i * N:(i + 1) * N], exp, (n, t))

    def test_base_tiles_composite(self):
        """a tile with a base shows the base tile wherever its cell is see-through (door 2 = spikes up, cut colour = see-through)"""
        n, t = 3, 2                                            # floor 3: closed door over the floor tile
        spec = self.cfg["tiles"][t]
        png = os.path.join(ROOT, spec["file"])
        bi = T.tidx(n, spec["base"])
        base = self.mem[bi * N:(bi + 1) * N]
        exp = indep_tile(png, spec["cell"][0], spec["cell"][1], spec.get("recolor", self.cfg["floors"][n]["recolor"]),
                         cs=spec["cell_size"], scale=32 // spec["cell_size"], base=base, gain=spec.get("gain", self.cfg["floors"][n]["gain"]), cut=spec["cut"])
        i = T.tidx(n, t)
        self.assertEqual(self.mem[i * N:(i + 1) * N], exp)

    def test_doors_are_spike_traps_and_maze_door_is_a_wall(self):
        """W1: D / L doors (tiles 2, 3 closed = spikes up; 8, 9 open = spikes down) show the floor through the cut colour;
        the exit E (4) is the wall picture and vanishes when open (10 = the plain floor)"""
        for floor in (1, 2, 3):
            tile = lambda t: self.mem[T.tidx(floor, t) * N:(T.tidx(floor, t) + 1) * N]
            floor_t, wall_t = tile(1), tile(0)
            self.assertEqual(tile(4), wall_t, f"floor {floor}: closed exit looks like the wall")
            self.assertEqual(tile(10), floor_t, f"floor {floor}: open exit is plain floor")
            self.assertEqual(tile(2), tile(3), f"floor {floor}: D and L closed share the spike art")
            self.assertEqual(tile(8), tile(9), f"floor {floor}: D and L open share the spike art")
            self.assertNotEqual(tile(2), tile(8), f"floor {floor}: spikes up differ from spikes down")
            for t in (2, 3, 8, 9):
                same = sum(1 for x, y in zip(tile(t), floor_t) if x == y)
                self.assertGreater(same, 500, f"floor {floor} tile {t}: the floor shows through the cut colour")
                self.assertLess(same, N, f"floor {floor} tile {t}: spikes are drawn")

    def test_bad_cut_is_config_error(self):
        c = json.loads(json.dumps(load_json(os.path.join(ROOT, "sprites", "tileset.json"))))
        c["tiles"]["2"]["cut"] = [[1, 2]]
        t = tempfile.mkdtemp()
        try:
            p = os.path.join(t, "tileset.json")
            with open(p, "w", encoding="utf-8") as f:
                json.dump(c, f)
            with self.assertRaises(T.ConfigError):
                T.load_config(p, ROOT)
        finally:
            shutil.rmtree(t)

    def test_plate_tiles_from_own_picture(self):
        """tiles 7 / 11 (Sokoban plate raised / pressed) and 12-15 (Simon plates, tinted) come from my_asset/props/plate.png at 1:1"""
        from PIL import Image
        im = Image.open(os.path.join(ROOT, "my_asset", "props", "plate.png")).convert("RGBA")
        floor1 = self.mem[T.tidx(3, 1) * N:(T.tidx(3, 1) + 1) * N]
        for floor in (1, 2, 3):
            for t, row, tint in ((7, 0, None), (11, 1, None), (12, 0, (235, 60, 60)), (13, 0, (70, 120, 255)),
                                 (14, 0, (70, 200, 90)), (15, 0, (245, 215, 60))):
                if floor != 3 and t >= 12:
                    continue                                   # floors 1-2 use 12-15 as decoration
                base = self.mem[T.tidx(floor, 1) * N:(T.tidx(floor, 1) + 1) * N]
                exp = list(base)
                for y in range(32):
                    for x in range(32):
                        r, g, b, a = im.getpixel((x, y + row * 32))
                        if a < 128:
                            continue
                        ch = (r, g, b) if tint is None else tuple(min(255, int(v * k / 180.0 + 0.5)) for v, k in zip((r, g, b), tint))
                        exp[y * 32 + x] = T.to_rgb444(*ch)
                i = T.tidx(floor, t)
                self.assertEqual(self.mem[i * N:(i + 1) * N], exp, f"floor {floor} tile {t}")
        self.assertNotEqual(self.mem[T.tidx(2, 7) * N:(T.tidx(2, 7) + 1) * N], self.mem[T.tidx(2, 11) * N:(T.tidx(2, 11) + 1) * N])

    def test_bad_tint_is_config_error(self):
        c = json.loads(json.dumps(load_json(os.path.join(ROOT, "sprites", "tileset.json"))))
        c["tiles"]["12"]["tint"] = [1, 2]
        t = tempfile.mkdtemp()
        try:
            p = os.path.join(t, "tileset.json")
            with open(p, "w", encoding="utf-8") as f:
                json.dump(c, f)
            with self.assertRaises(T.ConfigError):
                T.load_config(p, ROOT)
        finally:
            shutil.rmtree(t)


class Fallbacks(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp(prefix="tile_test_")
        for d in ("mem", "my_asset", "sprites"):
            os.makedirs(os.path.join(self.t, d))
        shutil.copy(os.path.join(ROOT, "mem", "tileset_v1.mem"), os.path.join(self.t, "mem"))
        os.makedirs(os.path.join(self.t, "my_asset", "props"))
        for pf in ("plate.png", "peaks_1.png", "peaks_3.png"):
            shutil.copy(os.path.join(ROOT, "my_asset", "props", pf), os.path.join(self.t, "my_asset", "props"))
        shutil.copy(os.path.join(ROOT, "my_asset", "tileset", "Dungeon_Tileset.png"),
                    os.path.join(self.t, "my_asset", "sheet.png"))
        self.cfgp = os.path.join(self.t, "sprites", "tileset.json")
        self.c = load_json(os.path.join(ROOT, "sprites", "tileset.json"))
        self.c["sheet"] = "my_asset/sheet.png"
        self.save()
        self.out = os.path.join(self.t, "mem", "tileset.mem")
        self.v1p = os.path.join(self.t, "mem", "tileset_v1.mem")
        self.v1 = words_of(self.v1p)
        self.v1sha = sha(self.v1p)
        self.sheet = os.path.join(self.t, "my_asset", "sheet.png")

    def save(self):
        with open(self.cfgp, "w", encoding="utf-8") as f:
            json.dump(self.c, f)

    def tearDown(self):
        shutil.rmtree(self.t, ignore_errors=True)

    def ok_shape(self):
        w = words_of(self.out)
        self.assertEqual(len(w), 49152)
        self.assertEqual(sha(self.v1p), self.v1sha, "tileset_v1.mem was modified!")
        return w

    def test_clean(self):
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        self.ok_shape()
        self.assertNotIn("WARNING", out)

    def assert_sheet_tiles_are_v1(self, w):
        """every tile that is drawn from the sheet falls back to the old art; tiles with their own picture (plates, spike doors) stay new"""
        n_own = 0
        for f in (1, 2, 3):
            for t in range(16):
                spec = self.c["tiles"].get(str(t), {})
                spec = self.c["overrides"].get(f"f{f}.t{t}", spec)
                i = (f - 1) * 16 + t
                if spec.get("file"):
                    n_own += 1
                    continue
                self.assertEqual(w[i * 1024:(i + 1) * 1024], self.v1[i * 1024:(i + 1) * 1024], f"floor {f} tile {t}")
        self.assertGreater(n_own, 10)

    def test_sheet_missing_all_fallback(self):
        os.remove(self.sheet)
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        self.assert_sheet_tiles_are_v1(self.ok_shape())
        self.assertGreaterEqual(out.count("WARNING"), 3)   # at least one line per floor (tiles that sit on a fallen-back floor tile warn too)
        self.assertIn("file missing", out)

    def test_sheet_corrupt_is_error_but_builds(self):
        with open(self.sheet, "wb") as f:
            f.write(b"junk")
        rc, out = run_build(self.t)
        self.assertEqual(rc, 1)
        self.assert_sheet_tiles_are_v1(self.ok_shape())

    def test_sheet_too_small(self):
        im = Image.open(self.sheet)
        im.crop((0, 0, 160, 64)).save(self.sheet)              # rows 0-3 only
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("is outside it", out)
        i = T.tidx(1, 5)                                       # tile 5 = row 7 -> fallback
        self.assertEqual(w[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N])
        j = T.tidx(1, 0)                                       # tile 0 = row 0 -> new art
        self.assertNotEqual(w[j * N:(j + 1) * N], self.v1[j * N:(j + 1) * N])

    def test_transparent_cell(self):
        im = Image.open(self.sheet).convert("RGBA")
        im.paste((0, 0, 0, 0), (0, 0, 16, 16))
        im.save(self.sheet)
        self.c["tiles"]["5"] = {"cell": [0, 0]}
        self.save()
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("fully transparent", out)
        i = T.tidx(2, 5)
        self.assertEqual(w[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N])

    def test_missing_base_is_not_scrambled(self):
        self.c["tiles"]["4"] = {"cell": [4, 9]}                # see-through cell without base
        self.save()
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn('no "base" tile', out)
        i = T.tidx(1, 4)
        self.assertEqual(w[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N])

    def test_skip_override_and_floor_disable(self):
        self.c["overrides"] = {"f2.t0": {"skip": True}}
        self.c["floors"]["3"]["enabled"] = False
        self.save()
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("config skip", out)
        i = T.tidx(2, 0)
        self.assertEqual(w[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N])
        a, b = 32 * N, 48 * N
        self.assertEqual(w[a:b], self.v1[a:b])                 # floor 3 byte-identical

    def test_all_floors_disabled_is_byte_identical(self):
        for k in self.c["floors"]:
            self.c["floors"][k]["enabled"] = False
        self.save()
        run_build(self.t)
        self.assertEqual(sha(self.out), self.v1sha)

    def test_bad_config(self):
        for bad in ("{oops", json.dumps({"cell": 12}), json.dumps({"floors": {"1": {"recolor": "rrg"}}}), json.dumps({"floors": {"1": {"gain": 9}}}),
                    json.dumps({"tiles": {"99": {"cell": [0, 0]}}}), json.dumps({"overrides": {"x": {}}})):
            with open(self.cfgp, "w") as f:
                f.write(bad)
            if os.path.exists(self.out):
                os.remove(self.out)
            rc, _ = run_build(self.t)
            self.assertEqual(rc, 2, bad)
            self.assertFalse(os.path.exists(self.out))

    def test_missing_fallback_file(self):
        os.remove(self.v1p)
        rc, _ = run_build(self.t)
        self.assertEqual(rc, 2)

    def test_check_writes_nothing(self):
        rc, _ = run_build(self.t, "--check")
        self.assertEqual(rc, 0)
        self.assertFalse(os.path.exists(self.out))

    def test_sheet_never_modified(self):
        before = sha(self.sheet)
        run_build(self.t, "--preview")
        self.assertEqual(before, sha(self.sheet))


if __name__ == "__main__":
    unittest.main(verbosity=2)
