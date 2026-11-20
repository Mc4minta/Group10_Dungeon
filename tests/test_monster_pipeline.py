#!/usr/bin/env python3
"""Tests for the monster (enemy sprite) pipeline.   python tests/test_monster_pipeline.py"""
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
import build_monster_mem as M  # noqa: E402
from PIL import Image  # noqa: E402

N = M.FRAME_WORDS
KEY = 0xF0F


def words_of(path):
    with open(path, encoding="ascii") as f:
        return [int(x, 16) for x in f.read().split()]


def load_json(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def run_build(root, *args):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = M.main(["--root", root, *args])
    return rc, buf.getvalue()


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def indep(png, row, col):
    im = Image.open(png).convert("RGBA")
    out, opq = [], 0
    for y in range(32):
        for x in range(32):
            r, g, b, a = im.getpixel((col * 32 + x, (row - 1) * 32 + y))
            if a < 128:
                out.append(KEY)
            else:
                v = (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)
                out.append(v ^ 1 if v == KEY else v)
                opq += 1
    return out if opq else None


class RealProject(unittest.TestCase):
    def setUp(self):
        self.cfg = M.load_config(os.path.join(ROOT, "sprites", "monsters.json"), ROOT)
        self.mem = words_of(os.path.join(ROOT, "mem", "monster.mem"))
        self.v1 = words_of(os.path.join(ROOT, "mem", "monster_v1.mem"))
        self.b = M.build(self.cfg, ROOT)

    def test_line_count(self):
        self.assertEqual(len(self.mem), 4096)
        self.assertEqual(len(self.v1), 4096)

    def test_mem_is_up_to_date(self):
        self.assertEqual(self.mem, self.b.out, "mem/monster.mem is stale: run python scripts/build_monster_mem.py")

    def test_key_colour_in_every_frame(self):
        for i in range(4):
            self.assertIn(KEY, self.mem[i * N:(i + 1) * N], f"frame {i}")

    def test_fallback_identical_to_v1(self):
        for r in self.b.result:
            if r["fallback"]:
                i = r["idx"]
                self.assertEqual(self.mem[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N], r["name"])

    def test_frames_match_sources(self):
        for k, mi in (("A", 0), ("B", 1)):
            mc = self.cfg["monsters"][k]
            if not mc["enabled"]:
                continue
            for a, spec in enumerate(mc["frames"]):
                i = mi * 2 + a
                if self.b.result[i]["fallback"] or spec.get("skip"):
                    continue
                if mc["scale"] == 2:
                    continue                                   # checked by test_scale2_windows
                exp = indep(os.path.join(ROOT, self.cfg["sheets"][spec["sheet"]]), spec["row"], spec["col"])
                self.assertEqual(self.mem[i * N:(i + 1) * N], exp, f"{k}{a}")

    def test_scale2_windows(self):
        """scale 2: the 16x16 source window centred on the art (one anchor per monster) is doubled to 32x32 - the monster is as big as the hero"""
        def bb(w):
            xs = [i % 32 for i, v in enumerate(w) if v != KEY]
            ys = [i // 32 for i, v in enumerate(w) if v != KEY]
            return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
        for k, mi in (("A", 0), ("B", 1)):
            mc = self.cfg["monsters"][k]
            if not mc["enabled"] or mc["scale"] != 2:
                continue
            cells = [indep(os.path.join(ROOT, self.cfg["sheets"][sp["sheet"]]), sp["row"], sp["col"]) for sp in mc["frames"][:2]]
            boxes = [bb(c) for c in cells]
            cx = (min(b[0] for b in boxes) + max(b[2] for b in boxes)) / 2.0
            cy = (min(b[1] for b in boxes) + max(b[3] for b in boxes)) / 2.0
            x0 = min(max(int(round(cx - 8)), 0), 16)
            y0 = min(max(int(round(cy - 8)), 0), 16)
            for a, c in enumerate(cells):
                exp = [c[(y0 + y // 2) * 32 + x0 + x // 2] for y in range(32) for x in range(32)]
                self.assertEqual(self.mem[(mi * 2 + a) * N:(mi * 2 + a + 1) * N], exp, f"{k}{a}")


class Fallbacks(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp(prefix="mon_test_")
        for d in ("mem", "my_asset", "sprites"):
            os.makedirs(os.path.join(self.t, d))
        shutil.copy(os.path.join(ROOT, "mem", "monster_v1.mem"), os.path.join(self.t, "mem"))
        self.c = load_json(os.path.join(ROOT, "sprites", "monsters.json"))
        for name, rel in self.c["sheets"].items():
            os.makedirs(os.path.dirname(os.path.join(self.t, rel)), exist_ok=True)
            shutil.copy(os.path.join(ROOT, rel), os.path.join(self.t, rel))
        self.cfgp = os.path.join(self.t, "sprites", "monsters.json")
        self.save()
        self.out = os.path.join(self.t, "mem", "monster.mem")
        self.v1p = os.path.join(self.t, "mem", "monster_v1.mem")
        self.v1 = words_of(self.v1p)
        self.v1sha = sha(self.v1p)

    def save(self):
        with open(self.cfgp, "w", encoding="utf-8") as f:
            json.dump(self.c, f)

    def sheet(self, name):
        return os.path.join(self.t, self.c["sheets"][name])

    def tearDown(self):
        shutil.rmtree(self.t, ignore_errors=True)

    def ok_shape(self):
        w = words_of(self.out)
        self.assertEqual(len(w), 4096)
        self.assertEqual(sha(self.v1p), self.v1sha, "monster_v1.mem was modified!")
        return w

    def test_clean(self):
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertNotIn("WARNING", out)
        self.assertNotEqual(w, self.v1)

    def test_sheet_missing_only_that_monster_falls_back(self):
        os.remove(self.sheet("vampire_idle"))
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("file missing", out)
        self.assertEqual(w[2 * N:4 * N], self.v1[2 * N:4 * N])          # B old
        self.assertNotEqual(w[0:2 * N], self.v1[0:2 * N])               # A still new

    def test_corrupt_sheet_is_error_but_builds(self):
        with open(self.sheet("skeleton1_move"), "wb") as f:
            f.write(b"junk")
        rc, out = run_build(self.t)
        self.assertEqual(rc, 1)
        w = self.ok_shape()
        self.assertEqual(w[0:2 * N], self.v1[0:2 * N])

    def test_transparent_cell(self):
        p = self.sheet("skeleton1_move")
        im = Image.open(p).convert("RGBA")
        im.paste((0, 0, 0, 0), (32, 0, 64, 32))                          # col 1 = A0
        im.save(p)
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("fully transparent", out)
        self.assertEqual(w[0:N], self.v1[0:N])
        self.assertNotEqual(w[N:2 * N], self.v1[N:2 * N])

    def test_sheet_too_small(self):
        p = self.sheet("skeleton1_move")
        Image.open(p).crop((0, 0, 96, 32)).save(p)                       # only cols 0-2: col 4 (A1) missing
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("is outside it", out)
        self.assertEqual(w[N:2 * N], self.v1[N:2 * N])
        self.assertNotEqual(w[0:N], self.v1[0:N])

    def test_wrong_size_not_multiple_of_32(self):
        Image.new("RGBA", (100, 40), (255, 0, 0, 255)).save(self.sheet("vampire_idle"))
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("wrong size 100x40", out)
        self.assertEqual(w[2 * N:4 * N], self.v1[2 * N:4 * N])

    def test_disabled_and_skip(self):
        self.c["monsters"]["A"]["enabled"] = False
        self.c["monsters"]["B"]["frames"][0] = {"skip": True}
        self.save()
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertEqual(w[0:2 * N], self.v1[0:2 * N])
        self.assertEqual(w[2 * N:3 * N], self.v1[2 * N:3 * N])
        self.assertNotEqual(w[3 * N:4 * N], self.v1[3 * N:4 * N])

    def test_all_disabled_is_byte_identical(self):
        self.c["monsters"]["A"]["enabled"] = False
        self.c["monsters"]["B"]["enabled"] = False
        self.save()
        run_build(self.t)
        self.assertEqual(sha(self.out), self.v1sha)

    def test_bad_config(self):
        for bad in ("{oops", json.dumps({"monsters": {"C": {}}}), json.dumps({"monsters": {"A": {"frames": [1, 2, 3]}}}),
                    json.dumps({"key_color": "xyz"}), json.dumps({"monsters": {"A": {"frames": [{"sheet": "x"}]}}})):
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

    def test_sheets_never_modified(self):
        before = {n: sha(self.sheet(n)) for n in self.c["sheets"]}
        run_build(self.t, "--preview")
        self.assertEqual(before, {n: sha(self.sheet(n)) for n in self.c["sheets"]})


if __name__ == "__main__":
    unittest.main(verbosity=2)
