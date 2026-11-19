#!/usr/bin/env python3
"""Tests for the sprite pipeline.   python tests/test_sprite_pipeline.py   (no pytest needed)

Part A checks the REAL mem/player.mem against the real config + PNGs.
Part B runs the build on throw-away copies of the project and breaks the art on purpose.
"""
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
import build_player_mem as B  # noqa: E402
from PIL import Image  # noqa: E402

KEY = 0xF0F
N = B.FRAME_WORDS


def words_of(path):
    with open(path, encoding="ascii") as f:
        return [int(x, 16) for x in f.read().split()]


def run_build(root, *args):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = B.main(["--root", root, *args])
    return rc, buf.getvalue()


def jload(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def jsave(p, c):
    with open(p, "w", encoding="utf-8") as f:
        json.dump(c, f)


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def indep_frame(png, row1, col, scale=1, tint=None):
    """independent conversion of one cell (does not use build code), exact integer upscale about the cell centre; None if empty"""
    im = Image.open(png).convert("RGBA")
    out, opaque = [KEY] * 1024, 0
    for y in range(32):
        for x in range(32):
            r, g, b, a = im.getpixel((col * 32 + x, (row1 - 1) * 32 + y))
            if a < 128:
                continue
            if tint:                                              # independent luminance tint (same definition as the config help)
                d, lt = tint["dark"], tint["light"]
                lum = (r * 299 + g * 587 + b * 114) // 1000
                if lum < 40:
                    r, g, b = int(d[0] * 0.25), int(d[1] * 0.25), int(d[2] * 0.25)
                else:
                    t = (lum - 40) / 215
                    r, g, b = (int(d[i] + (lt[i] - d[i]) * t + 0.5) for i in range(3))
            v = (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)
            v = v ^ 1 if v == KEY else v
            opaque += 1
            for dy in range(scale):
                for dx in range(scale):
                    X, Y = scale * (x - 16) + 16 + dx, scale * (y - 16) + 16 + dy
                    if 0 <= X < 32 and 0 <= Y < 32:
                        out[Y * 32 + X] = v
    return out if opaque else None


class RealProject(unittest.TestCase):
    def setUp(self):
        self.cfg = B.load_config(os.path.join(ROOT, "sprites", "sprites.json"), ROOT)
        self.mem = words_of(os.path.join(ROOT, "mem", "player.mem"))
        self.v1 = words_of(os.path.join(ROOT, "mem", "player_v1.mem"))
        _b = B.run(self.cfg, ROOT)
        self.out, self.result = _b.main, _b.result

    def test_line_count(self):
        with open(os.path.join(ROOT, "mem", "player.mem"), encoding="ascii") as f:
            lines = f.read().split()
        self.assertEqual(len(lines), 49152)
        self.assertTrue(all(len(x) == 3 for x in lines))

    def test_v1_is_original_size(self):
        self.assertEqual(len(self.v1), 49152)

    def test_key_colour_in_every_frame(self):
        for i in range(48):
            self.assertIn(KEY, self.mem[i * N:(i + 1) * N], f"frame {i} has no key colour")

    def test_mem_is_up_to_date(self):
        self.assertEqual(self.mem, self.out, "mem/player.mem is stale: run python scripts/build_player_mem.py")

    def test_fallback_frames_identical_to_v1(self):
        for r in self.result:
            i = r["idx"]
            if r["fallback"]:
                self.assertEqual(self.mem[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N], r["name"])

    def test_disabled_forms_identical_to_v1(self):
        for n, f in self.cfg["forms"].items():
            if not f["enabled"]:
                a, b = (n - 1) * 12 * N, n * 12 * N
                self.assertEqual(self.mem[a:b], self.v1[a:b], f"form{n}")

    def test_no_frame_shifted(self):
        """every new-art frame equals an independent conversion of its source cell"""
        for r in self.result:
            if r["fallback"]:
                continue
            sname, row, col = r["src"]
            png = os.path.join(ROOT, self.cfg["forms"][r["form"]]["sheets"][sname])
            fc = self.cfg["forms"][r["form"]]
            exp = indep_frame(png, row, col, fc["scale"], self.cfg["tints"][fc["tint"]] if fc["tint"] else None)
            i = r["idx"]
            self.assertEqual(self.mem[i * N:(i + 1) * N], exp, r["name"])

    def test_default_mapping_sources(self):
        """A-1 / A-2: idle <- Idle.png col0 (form 1) else Walk col0; A <- Walk col1; B <- Walk col3; row 4 unused"""
        rows = {"down": 1, "up": 3, "left": 2, "right": 1}
        for r in self.result:
            if r["fallback"]:
                continue
            sname, row, col = r["src"]
            self.assertEqual(row, rows[B.DIRS[r["dir"]]], r["name"])
            self.assertNotEqual(row, 4, r["name"])
            has_idle = "idle" in self.cfg["forms"][r["form"]]["sheets"]
            want = {0: ("idle" if has_idle else "walk", 0), 1: ("walk", 1), 2: ("walk", 3)}[r["pose"]]
            self.assertEqual((sname, col), want, r["name"])


class Fallbacks(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp(prefix="sprite_test_")
        for d in ("mem", "picture", "sprites"):
            os.makedirs(os.path.join(self.t, d))
        shutil.copy(os.path.join(ROOT, "mem", "player_v1.mem"), os.path.join(self.t, "mem"))
        for i in (1, 2, 3):
            self.make_sheet(f"picture/form{i}_walk.png", 128, 128, i)
        self.make_sheet("picture/form1_idle.png", 512, 128, 9)
        sheets = {"1": {"walk": "picture/form1_walk.png", "idle": "picture/form1_idle.png"},
                  "2": {"walk": "picture/form2_walk.png"}, "3": {"walk": "picture/form3_walk.png"}, "4": {}}
        self.cfgp = os.path.join(self.t, "sprites", "sprites.json")
        jsave(self.cfgp, {"forms": {k: {"sheets": v} for k, v in sheets.items()}})
        self.v1p = os.path.join(self.t, "mem", "player_v1.mem")
        self.out = os.path.join(self.t, "mem", "player.mem")
        self.v1sha = sha(self.v1p)
        self.v1 = words_of(self.v1p)

    def make_sheet(self, rel, w, h, i):
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for c in range(w // 32):
            for r in range(h // 32):                    # distinct coloured square per cell
                for y in range(8, 24):
                    for x in range(8, 24):
                        im.putpixel((c * 32 + x, r * 32 + y), ((60 * i) % 256, (50 * r + 20) % 256, (60 * c + 15) % 256, 255))
        im.save(os.path.join(self.t, rel))

    def tearDown(self):
        shutil.rmtree(self.t, ignore_errors=True)

    def fb(self, out, name):
        return [ln for ln in out.splitlines() if ln.startswith("WARNING") and name in ln]

    def ok_shape(self):
        w = words_of(self.out)
        self.assertEqual(len(w), 49152)
        self.assertEqual(sha(self.v1p), self.v1sha, "player_v1.mem was modified!")
        return w

    def test_clean(self):
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        warns = [ln for ln in out.splitlines() if ln.startswith("WARNING")]
        self.assertEqual(len(warns), 1)                                  # form4: one line for the whole form
        self.assertIn("form4", warns[0])
        self.assertEqual(w[36 * N:], self.v1[36 * N:])

    def test_missing_file(self):
        os.remove(os.path.join(self.t, "picture", "form2_walk.png"))
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertEqual(len(self.fb(out, "form2")), 1)                 # whole-form warning
        self.assertIn("file missing", out)
        self.assertEqual(w[12 * N:24 * N], self.v1[12 * N:24 * N])
        self.assertNotEqual(w[:12 * N], self.v1[:12 * N])          # form1 still new

    def test_transparent_cell(self):
        p = os.path.join(self.t, "picture", "form1_walk.png")
        im = Image.open(p)
        im.paste((0, 0, 0, 0), (32, 0, 64, 32))                    # row1 col1 = down.A and right.A
        im.save(p)
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("fully transparent", out)
        self.assertEqual(len(self.fb(out, "form1.")), 2)
        for i in (1, 10):
            self.assertEqual(w[i * N:(i + 1) * N], self.v1[i * N:(i + 1) * N])
        self.assertNotEqual(w[0:N], self.v1[0:N])

    def test_wrong_size_not_multiple(self):
        Image.new("RGBA", (100, 100), (255, 0, 0, 255)).save(os.path.join(self.t, "picture", "form3_walk.png"))
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("wrong size 100x100", out)
        self.assertEqual(w[24 * N:36 * N], self.v1[24 * N:36 * N])

    def test_small_sheet_only_missing_cells_fall_back(self):
        p = os.path.join(self.t, "picture", "form1_walk.png")
        Image.open(p).crop((0, 0, 128, 64)).save(p)                # only rows 1-2: up (row 3) missing
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        fb = self.fb(out, "form1.")
        self.assertEqual(len(fb), 2)                               # up.A, up.B only; up.idle still comes from Idle.png
        self.assertTrue(all("form1.up." in x for x in fb))
        self.assertIn("is outside it", out)
        self.assertEqual(w[4 * N:6 * N], self.v1[4 * N:6 * N])
        self.assertNotEqual(w[3 * N:4 * N], self.v1[3 * N:4 * N])
        self.assertNotEqual(w[0:N], self.v1[0:N])

    def test_bigger_sheet_ok(self):
        p = os.path.join(self.t, "picture", "form1_walk.png")
        im = Image.open(p)
        big = Image.new("RGBA", (128, 192), (0, 0, 0, 0))
        big.paste(im, (0, 0))
        big.save(p)
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        self.assertEqual(len(self.fb(out, "form1.")), 0)

    def test_corrupt_png_is_error_but_still_builds(self):
        with open(os.path.join(self.t, "picture", "form2_walk.png"), "wb") as f:
            f.write(b"not a png")
        rc, out = run_build(self.t)
        self.assertEqual(rc, 1)
        self.assertIn("ERROR", out)
        w = self.ok_shape()
        self.assertEqual(w[12 * N:24 * N], self.v1[12 * N:24 * N])

    def test_bad_config(self):
        cp = self.cfgp
        for bad in ("{not json", json.dumps({"mapping": {"dir_row": {"down": 0}}}),
                    json.dumps({"forms": {"1": {"cell": 64}}}), json.dumps({"key_color": "xyz"})):
            with open(cp, "w") as f:
                f.write(bad)
            if os.path.exists(self.out):
                os.remove(self.out)
            rc, out = run_build(self.t)
            self.assertEqual(rc, 2, bad)
            self.assertFalse(os.path.exists(self.out), "must not write on bad config")

    def test_missing_fallback_file_is_error(self):
        os.remove(self.v1p)
        rc, _ = run_build(self.t)
        self.assertEqual(rc, 2)

    def test_all_disabled_is_byte_identical_to_v1(self):
        cp = self.cfgp
        c = jload(cp)
        for k in c["forms"]:
            c["forms"][k]["enabled"] = False
        jsave(cp, c)
        rc, _ = run_build(self.t)
        self.assertEqual(rc, 0)
        self.assertEqual(sha(self.out), self.v1sha)

    def test_skip_and_override(self):
        cp = self.cfgp
        c = jload(cp)
        c["overrides"] = {"form1.down.idle": {"skip": True}, "form1.left.A": [4, 2]}
        jsave(cp, c)
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("config skip", out)
        self.assertEqual(w[0:N], self.v1[0:N])
        exp = indep_frame(os.path.join(self.t, "picture", "form1_walk.png"), 4, 2)
        self.assertEqual(w[7 * N:8 * N], exp)                      # form1.left.A = frame 7

    def test_idle_comes_from_idle_sheet(self):
        rc, out = run_build(self.t)
        w = self.ok_shape()
        for d, row in ((0, 1), (1, 3), (2, 2), (3, 1)):
            exp = indep_frame(os.path.join(self.t, "picture", "form1_idle.png"), row, 0)
            self.assertEqual(w[(d * 3) * N:(d * 3 + 1) * N], exp, B.DIRS[d])
        exp = indep_frame(os.path.join(self.t, "picture", "form2_walk.png"), 1, 0)    # form 2: walk col 0
        self.assertEqual(w[12 * N:13 * N], exp)

    def test_idle_sheet_missing_uses_walk_col0_without_warning(self):
        os.remove(os.path.join(self.t, "picture", "form1_idle.png"))
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertEqual(self.fb(out, "form1"), [])                # chain worked: not a fallback to old art
        exp = indep_frame(os.path.join(self.t, "picture", "form1_walk.png"), 1, 0)
        self.assertEqual(w[0:N], exp)
        self.assertIn("used after", out)

    def test_idle_sheet_too_small_uses_walk(self):
        p = os.path.join(self.t, "picture", "form1_idle.png")
        Image.open(p).crop((0, 0, 128, 64)).save(p)                # rows 3-4 missing
        rc, out = run_build(self.t)
        w = self.ok_shape()
        exp = indep_frame(os.path.join(self.t, "picture", "form1_walk.png"), 3, 0)   # up.idle
        self.assertEqual(w[3 * N:4 * N], exp)

    def test_scale2_is_exact_integer_upscale(self):
        c = jload(self.cfgp)
        c["forms"]["1"]["scale"] = 2
        jsave(self.cfgp, c)
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertNotIn("CUT OFF", out)
        self.assertIn("x2", out)
        exp = indep_frame(os.path.join(self.t, "picture", "form1_walk.png"), 1, 1, 2)       # down.A = walk r1 c1
        self.assertEqual(w[1 * N:2 * N], exp)
        f = w[1 * N:2 * N]
        for y in range(0, 32, 2):                                    # every pixel is a 2x2 block
            for x in range(0, 32, 2):
                self.assertTrue(f[y * 32 + x] == f[y * 32 + x + 1] == f[(y + 1) * 32 + x] == f[(y + 1) * 32 + x + 1])
        w2 = words_of(self.out)
        exp3 = indep_frame(os.path.join(self.t, "picture", "form2_walk.png"), 1, 1, 1)      # other forms unchanged (scale 1)
        self.assertEqual(w2[13 * N:14 * N], exp3)

    def test_scale_too_big_reports_cut_off_pixels(self):
        c = jload(self.cfgp)
        c["forms"]["2"]["scale"] = 4
        jsave(self.cfgp, c)
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        self.ok_shape()
        self.assertIn("CUT OFF", out)

    def test_bad_scale_is_config_error(self):
        for bad in (0, 9, "2", 1.5):
            c = jload(self.cfgp)
            c["forms"]["1"]["scale"] = bad
            jsave(self.cfgp, c)
            rc, _ = run_build(self.t)
            self.assertEqual(rc, 2, bad)

    def test_tint_keeps_shape_and_changes_colour(self):
        c = jload(self.cfgp)
        c["tints"] = {"gold": {"dark": [110, 66, 0], "light": [255, 226, 90]}}
        c["forms"]["2"]["tint"] = "gold"
        jsave(self.cfgp, c)
        rc, out = run_build(self.t)
        self.assertEqual(rc, 0)
        w = self.ok_shape()
        self.assertIn("(gold)", out)
        tint = c["tints"]["gold"]
        exp = indep_frame(os.path.join(self.t, "picture", "form2_walk.png"), 1, 1, 1, tint)
        self.assertEqual(w[13 * N:14 * N], exp)
        plain = indep_frame(os.path.join(self.t, "picture", "form2_walk.png"), 1, 1, 1)
        self.assertNotEqual(exp, plain)
        self.assertEqual([v == KEY for v in exp], [v == KEY for v in plain])        # same transparency mask
        # other forms untouched
        self.assertEqual(w[1 * N:2 * N], indep_frame(os.path.join(self.t, "picture", "form1_walk.png"), 1, 1, 1))

    def test_undefined_or_bad_tint_is_config_error(self):
        c = jload(self.cfgp)
        c["forms"]["1"]["tint"] = "nope"
        jsave(self.cfgp, c)
        self.assertEqual(run_build(self.t)[0], 2)
        c["forms"]["1"]["tint"] = "gold"
        c["tints"] = {"gold": {"dark": [0, 0, 999], "light": [255, 255, 255]}}
        jsave(self.cfgp, c)
        self.assertEqual(run_build(self.t)[0], 2)

    def test_check_writes_nothing(self):
        rc, _ = run_build(self.t, "--check")
        self.assertEqual(rc, 0)
        self.assertFalse(os.path.exists(self.out))

    def test_picture_never_modified(self):
        before = {f: sha(os.path.join(self.t, "picture", f)) for f in os.listdir(os.path.join(self.t, "picture"))}
        run_build(self.t, "--preview")
        after = {f: sha(os.path.join(self.t, "picture", f)) for f in os.listdir(os.path.join(self.t, "picture"))}
        self.assertEqual(before, after)
        self.assertTrue(os.path.isfile(os.path.join(self.t, "preview", "all_forms.png")))
        self.assertTrue(os.path.isfile(os.path.join(self.t, "preview", "form1_down_walk.gif")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
