#!/usr/bin/env python3
"""W5 overlay art pipeline tests.   python tests/test_overlay_pipeline.py

mem/ovtile.mem is generated from sprites/overlay.json (+ PNGs). Checks: file shape, up to date, the pictures equal an independent conversion,
the spare picture is see-through, and Rule 1 (missing file -> placeholder, still exit code 0, never a broken file).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
KEY = 0xF0F


def words(path):
    with open(path) as f:
        return [int(x, 16) for x in f.read().split()]


def to444(r, g, b):
    return (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)


def indep(path, cut=(), plate=None):
    """independent 16x16 -> 32x32 (2x) conversion with the picture centred"""
    im = Image.open(path).convert("RGBA")
    out = [KEY] * 1024
    if plate:
        for y in range(2, 30):
            for x in range(2, 30):
                out[y * 32 + x] = to444(*plate)
    for y in range(16):
        for x in range(16):
            r, g, b, a = im.getpixel((x, y))
            if a < 128 or (r, g, b) in cut:
                continue
            for dy in range(2):
                for dx in range(2):
                    out[(y * 2 + dy) * 32 + x * 2 + dx] = to444(r, g, b)
    return out


class Real(unittest.TestCase):
    def setUp(self):
        self.mem = words(os.path.join(ROOT, "mem", "ovtile.mem"))
        with open(os.path.join(ROOT, "sprites", "overlay.json"), encoding="utf-8") as f:
            self.cfg = json.load(f)

    def test_shape(self):
        self.assertEqual(len(self.mem), 4096)
        self.assertTrue(all(0 <= w <= 0xFFF for w in self.mem))

    def test_pictures_match_independent_conversion(self):
        for i in ("0", "1", "2"):
            spec = self.cfg["pics"][i]
            exp = indep(os.path.join(ROOT, spec["file"]), {tuple(c) for c in spec.get("cut", [])}, spec.get("plate"))
            self.assertEqual(self.mem[int(i) * 1024:(int(i) + 1) * 1024], exp, f"picture {i}")

    def test_spare_is_see_through_and_pictures_have_art(self):
        self.assertTrue(all(w == KEY for w in self.mem[3 * 1024:]))
        for i in range(3):
            pic = self.mem[i * 1024:(i + 1) * 1024]
            self.assertGreater(sum(1 for w in pic if w != KEY), 100, f"picture {i} is mostly empty")
            self.assertGreater(sum(1 for w in pic if w == KEY), 50, f"picture {i} lets no floor through")

    def test_up_to_date(self):
        def read():
            with open(os.path.join(ROOT, "mem", "ovtile.mem"), "rb") as f:
                return f.read()
        before = read()
        r = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "build_overlay_mem.py")], capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(read(), before, "mem/ovtile.mem was stale")


class Fallback(unittest.TestCase):
    def test_missing_file_uses_placeholder(self):
        """Rule 1: a missing picture -> placeholder + warning, exit code 0, other pictures unchanged"""
        t = tempfile.mkdtemp(prefix="ov_test_")
        try:
            for d in ("mem", "sprites", os.path.join("my_asset", "props"), "scripts"):
                os.makedirs(os.path.join(t, d))
            shutil.copy(os.path.join(ROOT, "scripts", "build_overlay_mem.py"), os.path.join(t, "scripts"))
            for f in ("peaks_1.png", "candlestick_1_1.png"):                 # box_1_1.png is left out
                shutil.copy(os.path.join(ROOT, "my_asset", "props", f), os.path.join(t, "my_asset", "props"))
            shutil.copy(os.path.join(ROOT, "sprites", "overlay.json"), os.path.join(t, "sprites"))
            r = subprocess.run([sys.executable, os.path.join(t, "scripts", "build_overlay_mem.py")], capture_output=True, text=True, timeout=60)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn("WARNING", r.stdout)
            w = words(os.path.join(t, "mem", "ovtile.mem"))
            real = words(os.path.join(ROOT, "mem", "ovtile.mem"))
            self.assertEqual(len(w), 4096)
            self.assertNotEqual(w[0:1024], real[0:1024])
            self.assertGreater(sum(1 for x in w[0:1024] if x != KEY), 100, "placeholder is drawn")
            self.assertEqual(w[1024:], real[1024:])
        finally:
            shutil.rmtree(t, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
