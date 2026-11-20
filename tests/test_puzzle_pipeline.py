#!/usr/bin/env python3
"""Tests for the puzzle-object sprite pipeline.   python tests/test_puzzle_pipeline.py"""
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
import build_puzzle_mem as PZ  # noqa: E402
from PIL import Image  # noqa: E402

N = PZ.FW
KEY = 0xF0F


def words_of(path):
    with open(path, encoding="ascii") as f:
        return [int(x, 16) for x in f.read().split()]


def jload(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def jsave(p, c):
    with open(p, "w", encoding="utf-8") as f:
        json.dump(c, f)


def run_build(root, *args):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = PZ.main(["--root", root, *args])
    return rc, buf.getvalue()


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def indep(png, scale=2, cut=(), cell=None):
    """independent: exact integer upscale, centred in 32x32, see-through -> key; None if empty. cell = [row, col] of a 32x32-cell sheet"""
    im = Image.open(png).convert("RGBA")
    if cell:
        im = im.crop((cell[1] * 32, cell[0] * 32, cell[1] * 32 + 32, cell[0] * 32 + 32))
    w, h = im.size
    out, opq = [KEY] * 1024, 0
    ox, oy = (32 - w * scale) // 2, (32 - h * scale) // 2
    for y in range(h):
        for x in range(w):
            r, g, b, a = im.getpixel((x, y))
            if a < 128 or (r, g, b) in cut:
                continue
            v = (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)
            v = v ^ 1 if v == KEY else v
            opq += 1
            for dy in range(scale):
                for dx in range(scale):
                    out[(oy + y * scale + dy) * 32 + ox + x * scale + dx] = v
    return out if opq else None


def indep_mem(path, frame, scale=2):
    """independent parse of a sprite_tool .mem frame (16x16 RGB444), exact upscale, centred in 32x32"""
    lines = [ln for ln in open(path, encoding="utf-8").read().splitlines()]
    hdr = [ln for ln in lines if ln.startswith("//")][0]
    parts = dict(p.split("=") for p in hdr.split() if "=" in p)
    w, h, key = int(parts["W"]), int(parts["H"]), int(parts["KEY"], 16)
    toks = [int(t, 16) for ln in lines if not ln.startswith("//") for t in ln.split()]
    fr = toks[frame * w * h:(frame + 1) * w * h]
    out = [KEY] * 1024
    ox, oy = (32 - w * scale) // 2, (32 - h * scale) // 2
    for y in range(h):
        for x in range(w):
            c = fr[y * w + x]
            if c == key:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    out[(oy + y * scale + dy) * 32 + ox + x * scale + dx] = c
    return out


class RealProject(unittest.TestCase):
    def setUp(self):
        self.cfg = PZ.load_config(os.path.join(ROOT, "sprites", "puzzle.json"), ROOT)
        self.mem = words_of(os.path.join(ROOT, "mem", "puzzle.mem"))
        self.v1 = words_of(os.path.join(ROOT, "mem", "puzzle_v1.mem"))
        self.b = PZ.build(self.cfg, ROOT)

    def test_line_count(self):
        self.assertEqual(len(self.mem), 16384)
        self.assertEqual(len(self.v1), 16384)

    def test_mem_is_up_to_date(self):
        self.assertEqual(self.mem, self.b.out, "mem/puzzle.mem is stale: run python scripts/build_puzzle_mem.py")

    def test_spare_frames_unchanged(self):
        self.assertEqual(self.mem[15 * N:], self.v1[15 * N:])        # frames 10-13 = maze ball, 14 = key (W7)

    def test_fallback_identical_to_v1(self):
        for r in self.b.result:
            if r["fallback"]:
                i = r["idx"]
                self.assertEqual(self.mem[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N], r["name"])

    def test_frames_not_empty(self):
        for i in range(10):
            f = self.mem[i * N:(i + 1) * N]
            self.assertTrue(any(v != KEY for v in f), f"frame {i} empty")

    def test_untinted_frames_match_sources(self):
        for i, spec in self.cfg["frames"].items():
            if spec.get("skip") or spec.get("tint") or self.b.result[i]["fallback"]:
                continue
            if "mem" in spec:
                exp = indep_mem(os.path.join(ROOT, spec["mem"]), spec["frame"], self.cfg["scale"])
            else:
                exp = indep(os.path.join(ROOT, spec["file"]), spec.get("scale", self.cfg["scale"]), set(spec["cut"]), spec.get("cell"))
            self.assertEqual(self.mem[i * N:(i + 1) * N], exp, PZ.NAMES[i])

    def test_bulbs_come_from_the_torch_mem_and_differ(self):
        off, on = self.mem[0:N], self.mem[N:2 * N]
        self.assertNotEqual(off, on)
        self.assertEqual(self.cfg["frames"][0]["mem"], "my_asset/props/torch.mem")


class Fallbacks(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp(prefix="puz_test_")
        for d in ("mem", "sprites", "my_asset/props", "my_asset/ball"):
            os.makedirs(os.path.join(self.t, d))
        shutil.copy(os.path.join(ROOT, "mem", "puzzle_v1.mem"), os.path.join(self.t, "mem"))
        self.c = jload(os.path.join(ROOT, "sprites", "puzzle.json"))
        for spec in self.c["frames"].values():
            rel = spec.get("file") or spec.get("mem")
            dst = os.path.join(self.t, rel)
            if not os.path.exists(dst):
                shutil.copy(os.path.join(ROOT, rel), dst)
        self.cfgp = os.path.join(self.t, "sprites", "puzzle.json")
        jsave(self.cfgp, self.c)
        self.out = os.path.join(self.t, "mem", "puzzle.mem")
        self.v1p = os.path.join(self.t, "mem", "puzzle_v1.mem")
        self.v1 = words_of(self.v1p)
        self.v1sha = sha(self.v1p)

    def f(self, i):
        sp = self.c["frames"][str(i)]
        return os.path.join(self.t, sp.get("file") or sp.get("mem"))

    def tearDown(self):
        shutil.rmtree(self.t, ignore_errors=True)

    def ok_shape(self):
        w = words_of(self.out)
        self.assertEqual(len(w), 16384)
        self.assertEqual(sha(self.v1p), self.v1sha, "puzzle_v1.mem was modified!")
        return w

    def test_clean(self):
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        self.ok_shape()
        self.assertNotIn("WARNING", out)

    def test_missing_file_only_that_frame_falls_back(self):
        os.remove(self.f(4))
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("file missing", out)
        self.assertEqual(w[4 * N:5 * N], self.v1[4 * N:5 * N])
        self.assertNotEqual(w[3 * N:4 * N], self.v1[3 * N:4 * N])

    def test_corrupt_png_is_error_but_builds(self):
        with open(self.f(2), "wb") as fh:
            fh.write(b"junk")
        rc, out = run_build(self.t)
        self.assertEqual(rc, 1)
        w = self.ok_shape()
        self.assertEqual(w[2 * N:3 * N], self.v1[2 * N:3 * N])

    def test_transparent_png(self):
        Image.new("RGBA", (16, 16), (0, 0, 0, 0)).save(self.f(7))
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("fully transparent", out)
        self.assertEqual(w[7 * N:8 * N], self.v1[7 * N:8 * N])

    def test_too_big_png_falls_back_not_scrambled(self):
        Image.new("RGBA", (24, 24), (255, 0, 0, 255)).save(self.f(8))      # x2 = 48 > 32
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("does not fit", out)
        self.assertEqual(w[8 * N:9 * N], self.v1[8 * N:9 * N])

    def test_mem_source_missing_corrupt_or_bad_frame_falls_back(self):
        os.remove(self.f(1))                                              # frame 1 = torch.mem #0 (shared file with frame 0)
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertEqual(rc, 0)
        self.assertIn("file missing", out)
        self.assertEqual(w[0:2 * N], self.v1[0:2 * N])                    # both bulbs use the missing file
        with open(self.f(1), "w") as fh:
            fh.write("// sprite_tool W=16 H=16 FRAMES=2 KEY=F0F" + chr(10) + "F0F F0F" + chr(10))      # too few words
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertEqual(rc, 1)
        self.assertIn("cannot read", out)
        self.assertEqual(w[0:2 * N], self.v1[0:2 * N])
        shutil.copy(os.path.join(ROOT, "my_asset/props/torch.mem"), self.f(1))
        self.c["frames"]["0"]["frame"] = 99                               # frame does not exist
        jsave(self.cfgp, self.c)
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertEqual(rc, 0)
        self.assertIn("does not exist", out)
        self.assertEqual(w[0:N], self.v1[0:N])
        self.assertNotEqual(w[N:2 * N], self.v1[N:2 * N])

    def test_switch_cell_outside_sheet_falls_back(self):
        self.c["frames"]["2"] = {"file": self.c["frames"]["2"]["file"], "cell": [7, 7], "scale": 1}
        jsave(self.cfgp, self.c)
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertEqual(rc, 0)
        self.assertIn("is outside it", out)
        self.assertEqual(w[2 * N:3 * N], self.v1[2 * N:3 * N])

    def test_skip_and_bad_config(self):
        self.c["frames"]["9"] = {"skip": True}
        jsave(self.cfgp, self.c)
        rc, out = run_build(self.t)
        w = self.ok_shape()
        self.assertIn("config skip", out)
        self.assertEqual(w[9 * N:10 * N], self.v1[9 * N:10 * N])
        for bad in ("{oops", json.dumps({"frames": {"99": {"skip": True}}}), json.dumps({"scale": 9}),
                    json.dumps({"frames": {"0": {"file": "x", "tint": "nope"}}}),
                    json.dumps({"frames": {"0": {"file": "x", "cut": [[1, 2]]}}}),
                    json.dumps({"frames": {"0": {"file": "x", "cell": [1]}}}),
                    json.dumps({"frames": {"0": {"file": "x", "scale": 9}}})):
            with open(self.cfgp, "w") as fh:
                fh.write(bad)
            if os.path.exists(self.out):
                os.remove(self.out)
            rc, _ = run_build(self.t)
            self.assertEqual(rc, 2, bad)
            self.assertFalse(os.path.exists(self.out))

    def test_missing_fallback_and_check(self):
        rc, _ = run_build(self.t, "--check")
        self.assertEqual(rc, 0)
        self.assertFalse(os.path.exists(self.out))
        os.remove(self.v1p)
        self.assertEqual(run_build(self.t)[0], 2)

    def test_sources_never_modified(self):
        before = {i: sha(self.f(i)) for i in range(10)}
        run_build(self.t, "--preview")
        self.assertEqual(before, {i: sha(self.f(i)) for i in range(10)})


if __name__ == "__main__":
    unittest.main(verbosity=2)
