#!/usr/bin/env python3
"""Tests for the boss sprite pipeline.   python tests/test_boss_pipeline.py"""
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
import build_boss_mem as BM  # noqa: E402
from PIL import Image  # noqa: E402

N = BM.FRAME_WORDS
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
        rc = BM.main(["--root", root, *args])
    return rc, buf.getvalue()


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def indep64(png, row, col):
    """independent conversion: 32x32 cell -> 64x64 exact 2x; None if empty"""
    im = Image.open(png).convert("RGBA")
    out = [KEY] * N
    opq = 0
    for y in range(32):
        for x in range(32):
            r, g, b, a = im.getpixel((col * 32 + x, (row - 1) * 32 + y))
            if a < 128:
                continue
            opq += 1
            v = (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)
            if v == KEY:
                v ^= 1
            for dy in (0, 1):
                for dx in (0, 1):
                    out[(y * 2 + dy) * 64 + x * 2 + dx] = v
    return out if opq else None


class RealProject(unittest.TestCase):
    def setUp(self):
        self.cfg = BM.load_config(os.path.join(ROOT, "sprites", "bosses.json"), ROOT)
        self.mem = words_of(os.path.join(ROOT, "mem", "boss.mem"))
        self.v1 = words_of(os.path.join(ROOT, "mem", "boss_v1.mem"))
        self.b = BM.build(self.cfg, ROOT)

    def test_line_count(self):
        self.assertEqual(len(self.mem), 32768)
        self.assertEqual(len(self.v1), 32768)

    def test_mem_is_up_to_date(self):
        self.assertEqual(self.mem, self.b.out, "mem/boss.mem is stale: run python scripts/build_boss_mem.py")

    def test_key_colour_in_every_used_frame(self):
        for i in range(6):
            self.assertIn(KEY, self.mem[i * N:(i + 1) * N], f"frame {i}")

    def test_spare_frames_unchanged(self):
        self.assertEqual(self.mem[6 * N:], self.v1[6 * N:])

    def test_fallback_identical_to_v1(self):
        for r in self.b.result:
            if r["fallback"]:
                i = r["idx"]
                self.assertEqual(self.mem[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N], r["name"])

    def test_frames_are_exact_2x_of_sources(self):
        for n in (1, 2, 3):
            bc = self.cfg["bosses"][n]
            if not bc["enabled"]:
                continue
            for a, spec in enumerate(bc["frames"]):
                i = (n - 1) * 2 + a
                if self.b.result[i]["fallback"] or spec.get("skip"):
                    continue
                exp = indep64(os.path.join(ROOT, self.cfg["sheets"][spec["sheet"]]), spec["row"], spec["col"])
                self.assertEqual(self.mem[i * N:(i + 1) * N], exp, f"boss{n} frame{a}")

    def test_each_source_pixel_is_a_2x2_block(self):
        for i in range(6):
            f = self.mem[i * N:(i + 1) * N]
            for y in range(0, 64, 2):
                for x in range(0, 64, 2):
                    v = f[y * 64 + x]
                    self.assertTrue(f[y * 64 + x + 1] == v and f[(y + 1) * 64 + x] == v and f[(y + 1) * 64 + x + 1] == v)


class Fallbacks(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp(prefix="boss_test_")
        for d in ("mem", "sprites"):
            os.makedirs(os.path.join(self.t, d))
        shutil.copy(os.path.join(ROOT, "mem", "boss_v1.mem"), os.path.join(self.t, "mem"))
        self.c = load_json(os.path.join(ROOT, "sprites", "bosses.json"))
        for name, rel in self.c["sheets"].items():
            os.makedirs(os.path.dirname(os.path.join(self.t, rel)), exist_ok=True)
            shutil.copy(os.path.join(ROOT, rel), os.path.join(self.t, rel))
        self.cfgp = os.path.join(self.t, "sprites", "bosses.json")
        self.save()
        self.out = os.path.join(self.t, "mem", "boss.mem")
        self.v1p = os.path.join(self.t, "mem", "boss_v1.mem")
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
        self.assertEqual(len(w), 32768)
        self.assertEqual(sha(self.v1p), self.v1sha, "boss_v1.mem was modified!")
        return w

    def test_clean(self):
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        self.ok_shape()
        self.assertNotIn("WARNING", out)

    def test_sheet_missing_only_that_boss_falls_back(self):
        os.remove(self.sheet("vampire_attack"))
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("file missing", out)
        self.assertEqual(w[4 * N:8 * N], self.v1[4 * N:8 * N])
        self.assertNotEqual(w[0:4 * N], self.v1[0:4 * N])

    def test_corrupt_sheet_is_error_but_builds(self):
        with open(self.sheet("skeleton2_idle"), "wb") as f:
            f.write(b"junk")
        rc, out = run_build(self.t)
        self.assertEqual(rc, 1)
        w = self.ok_shape()
        self.assertEqual(w[0:N], self.v1[0:N])                           # boss 1 frame 0 (skeleton2_idle) falls back
        self.assertNotEqual(w[N:2 * N], self.v1[N:2 * N])                # frame 1 (skeleton2_dmg) is still new art

    def test_transparent_cell(self):
        p = self.sheet("skeleton2_dmg")
        im = Image.open(p).convert("RGBA")
        im.paste((0, 0, 0, 0), (64, 0, 96, 32))                         # col 2 = boss 1 stunned picture (W10)
        im.save(p)
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("fully transparent", out)
        self.assertEqual(w[N:2 * N], self.v1[N:2 * N])
        self.assertNotEqual(w[0:N], self.v1[0:N])

    def test_sheet_too_small(self):
        p = self.sheet("vampire_attack")
        Image.open(p).crop((0, 0, 160, 32)).save(p)                     # cols 0-4: col 7 (boss3 f1) missing
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("is outside it", out)
        self.assertEqual(w[5 * N:6 * N], self.v1[5 * N:6 * N])
        self.assertNotEqual(w[4 * N:5 * N], self.v1[4 * N:5 * N])

    def test_all_disabled_is_byte_identical(self):
        for k in self.c["bosses"]:
            self.c["bosses"][k]["enabled"] = False
        self.save()
        run_build(self.t)
        self.assertEqual(sha(self.out), self.v1sha)

    def test_skip(self):
        self.c["bosses"]["1"]["frames"][1] = {"skip": True}
        self.save()
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("config skip", out)
        self.assertEqual(w[N:2 * N], self.v1[N:2 * N])
        self.assertNotEqual(w[0:N], self.v1[0:N])

    def test_bad_config(self):
        for bad in ("{oops", json.dumps({"bosses": {"4": {}}}), json.dumps({"bosses": {"1": {"frames": [1, 2, 3]}}}),
                    json.dumps({"key_color": "xyz"})):
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
