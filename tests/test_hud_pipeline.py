#!/usr/bin/env python3
"""Tests for the HUD (hearts + boss bar) pipeline.   python tests/test_hud_pipeline.py"""
import contextlib
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
import build_hud_mem as H  # noqa: E402


def words_of(path):
    with open(path, encoding="ascii") as f:
        return [int(x, 16) for x in f.read().split()]


def run(root):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = H.main(["--root", root])
    return rc, buf.getvalue()


def project():
    tmp = tempfile.mkdtemp()
    shutil.copytree(os.path.join(ROOT, "sprites"), os.path.join(tmp, "sprites"), ignore=shutil.ignore_patterns("music"))
    shutil.copytree(os.path.join(ROOT, "my_asset", "ui"), os.path.join(tmp, "my_asset", "ui"))
    return tmp


class HudTests(unittest.TestCase):
    def test_real_art_builds_clean(self):
        tmp = project()
        try:
            rc, out = run(tmp)
            self.assertEqual(rc, 0, out)
            w = words_of(os.path.join(tmp, "mem", "hud.mem"))
            self.assertEqual(len(w), 8192)
            for page in range(4):
                self.assertTrue(any(x != 0xF0F for x in w[page * 2048:(page + 1) * 2048]), f"page {page} empty")
            self.assertNotEqual(w[0:2048], w[2048:4096])          # full heart differs from the empty one
            self.assertTrue(all(0 <= x <= 0xFFF for x in w))
        finally:
            shutil.rmtree(tmp)

    def test_committed_mem_is_current(self):
        tmp = project()
        try:
            run(tmp)
            self.assertEqual(words_of(os.path.join(tmp, "mem", "hud.mem")), words_of(os.path.join(ROOT, "mem", "hud.mem")))
        finally:
            shutil.rmtree(tmp)

    def test_missing_art_falls_back_with_warning(self):
        tmp = project()
        try:
            os.remove(os.path.join(tmp, "my_asset", "ui", "Hearts", "PNG", "basic", "heart.png"))
            os.remove(os.path.join(tmp, "my_asset", "ui", "Hearts", "PNG", "health_bar", "health_bar.png"))
            rc, out = run(tmp)
            self.assertEqual(rc, 1)
            self.assertIn("WARNING", out)
            w = words_of(os.path.join(tmp, "mem", "hud.mem"))
            for page in range(4):
                self.assertTrue(any(x != 0xF0F for x in w[page * 2048:(page + 1) * 2048]), f"fallback page {page} empty")
        finally:
            shutil.rmtree(tmp)

    def test_oversize_picture_falls_back(self):
        tmp = project()
        try:
            from PIL import Image
            Image.new("RGBA", (100, 40), (255, 0, 0, 255)).save(os.path.join(tmp, "my_asset", "ui", "Hearts", "PNG", "basic", "border.png"))
            rc, out = run(tmp)
            self.assertEqual(rc, 1)
            self.assertIn("larger than 64x32", out)
        finally:
            shutil.rmtree(tmp)

    def test_broken_config_exit_2(self):
        tmp = project()
        try:
            with open(os.path.join(tmp, "sprites", "hud.json"), "w") as f:
                f.write("{ not json")
            rc, out = run(tmp)
            self.assertEqual(rc, 2)
            self.assertFalse(os.path.exists(os.path.join(tmp, "mem", "hud.mem")))
        finally:
            shutil.rmtree(tmp)

    def test_key_colour_never_used_for_opaque(self):
        tmp = project()
        try:
            from PIL import Image
            for n in ("background", "heart", "border"):
                Image.new("RGBA", (17, 17), (255, 0, 255, 255)).save(os.path.join(tmp, "my_asset", "ui", "Hearts", "PNG", "basic", n + ".png"))
            run(tmp)
            w = words_of(os.path.join(tmp, "mem", "hud.mem"))
            self.assertNotIn(0xF0F, w[0:17 * 64][:17])           # first row of the full heart is opaque magenta -> nudged, not transparent
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
