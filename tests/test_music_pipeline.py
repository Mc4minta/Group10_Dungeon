#!/usr/bin/env python3
"""Tests for the music tools: scripts/audio_to_music.py (audio -> notes) and scripts/music_extra.py (custom track + bgm_cfg.vh).
    python tests/test_music_pipeline.py"""
import json
import os
import sys
import tempfile
import unittest
import wave
import contextlib
import io

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import audio_to_music as A  # noqa: E402
import music_extra as M  # noqa: E402

SR = 16000


def write_wav(path, samples, sr=SR):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(samples, -1, 1) * 32767).astype(np.int16).tobytes())


def melody(spec):
    """spec = [(freq_hz or 0, seconds)] -> sine melody with a little harmonic content"""
    out = []
    for f, sec in spec:
        t = np.arange(int(sec * SR)) / SR
        out.append(np.zeros_like(t) if f == 0 else 0.4 * np.sin(2 * np.pi * f * t) + 0.1 * np.sin(2 * np.pi * 2 * f * t))
    return np.concatenate(out).astype(np.float32)


def run(argv):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = A.main(argv)
    return rc, buf.getvalue()


def parse_out(path):
    with open(path, encoding="utf-8") as f:
        lines = [ln for ln in f.read().splitlines() if not ln.startswith("#")]
    return [(t.split(":")[0], int(t.split(":")[1])) for t in " ".join(lines).split()]


class AudioToMusic(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp(prefix="music_test_")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.d, ignore_errors=True)

    def test_simple_melody_is_recognised(self):
        wav = os.path.join(self.d, "m.wav")
        write_wav(wav, melody([(523.25, 0.5), (659.25, 0.5), (783.99, 0.5), (0, 0.3), (523.25, 0.5)]))
        out = os.path.join(self.d, "t.txt")
        rc, text = run([wav, "--out", out])
        self.assertEqual(rc, 0, text)
        notes = parse_out(out)
        names = [n for n, f in notes if n != "R"]
        self.assertEqual(names, ["C5", "E5", "G5", "C5"])
        for n, f in notes:
            if n != "R":
                self.assertTrue(24 <= f <= 36, (n, f))          # 0.5 s = 30 frames
        self.assertTrue(any(n == "R" for n, f in notes))          # the silence became a rest

    def test_transpose_and_octave_fold(self):
        wav = os.path.join(self.d, "m.wav")
        write_wav(wav, melody([(523.25, 0.6), (659.25, 0.6)]))
        out = os.path.join(self.d, "t.txt")
        rc, _ = run([wav, "--out", out, "--transpose", "2"])
        self.assertEqual(rc, 0)
        self.assertEqual([n for n, f in parse_out(out)], ["D5", "F#5"])

    def test_fits_the_rom_by_merging_fast_notes(self):
        wav = os.path.join(self.d, "fast.wav")
        spec = []
        for i in range(200):                                       # 200 notes of 0.12 s alternating -> cannot fit 127 entries as is
            spec.append((440.0 if i % 2 == 0 else 554.37, 0.12))
        write_wav(wav, melody(spec))
        out = os.path.join(self.d, "t.txt")
        rc, text = run([wav, "--out", out])
        self.assertEqual(rc, 0, text)
        self.assertLessEqual(len(parse_out(out)), 127)

    def test_output_is_accepted_by_the_music_engine_parser(self):
        wav = os.path.join(self.d, "m.wav")
        write_wav(wav, melody([(440.0, 0.5), (0, 0.2), (587.33, 0.5)]))
        out = os.path.join(self.d, "t.txt")
        self.assertEqual(run([wav, "--out", out])[0], 0)
        with open(out, encoding="utf-8") as f:
            entries = M.parse_track_text(f.read())
        self.assertTrue(all(1 <= fr <= 255 and 0 <= hp < (1 << 18) for fr, hp in entries))

    def test_preview_wav_is_written(self):
        wav = os.path.join(self.d, "m.wav")
        write_wav(wav, melody([(440.0, 1.3)]))
        pv = os.path.join(self.d, "p.wav")
        self.assertEqual(run([wav, "--preview", pv])[0], 0)
        self.assertGreater(os.path.getsize(pv), 1000)

    def test_bad_inputs_are_errors_not_crashes(self):
        self.assertEqual(run([os.path.join(self.d, "missing.wav")])[0], 2)
        sil = os.path.join(self.d, "sil.wav")
        write_wav(sil, np.zeros(SR * 3, dtype=np.float32))
        rc, text = run([sil])
        self.assertEqual(rc, 2)
        self.assertIn("no clear melody", text)
        short = os.path.join(self.d, "short.wav")
        write_wav(short, melody([(440.0, 0.3)]))
        self.assertEqual(run([short])[0], 2)
        noise = os.path.join(self.d, "noise.wav")
        write_wav(noise, (np.random.RandomState(1).randn(SR * 3) * 0.2).astype(np.float32))
        self.assertEqual(run([noise])[0], 2)

    def test_grid_snaps_rhythm(self):
        wav = os.path.join(self.d, "m.wav")
        write_wav(wav, melody([(440.0, 0.31), (523.25, 0.34), (659.25, 0.62)]))   # beat about 20 frames
        out = os.path.join(self.d, "t.txt")
        self.assertEqual(run([wav, "--out", out, "--grid", "20"])[0], 0)
        self.assertEqual([f for n, f in parse_out(out) if n != "R"], [20, 20, 40])


class MusicExtra(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp(prefix="music_cfg_")
        os.makedirs(os.path.join(self.t, "sprites", "music"))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.t, ignore_errors=True)

    def cfg(self, tracks, play):
        with open(os.path.join(self.t, "sprites", "music.json"), "w", encoding="utf-8") as f:
            json.dump({"tracks": tracks, "play": play}, f)

    def track(self, text, name="a.txt"):
        with open(os.path.join(self.t, "sprites", "music", name), "w", encoding="utf-8") as f:
            f.write(text)

    def test_no_config_means_default_music(self):
        r = M.load(self.t)
        self.assertIsNone(r["entries"])
        self.assertEqual(r["ids"], M.DEFAULT_IDS)

    def test_custom_track_is_used_where_configured(self):
        self.track("# comment\nC5:20 E5:20 R:10 G5:30\n")
        self.cfg({"x": {"file": "sprites/music/a.txt"}}, {"floor1": "x", "floor2": "default"})
        r = M.load(self.t)
        self.assertEqual(len(r["entries"]), 4)
        self.assertEqual(r["ids"]["floor1"], 6)
        self.assertEqual(r["ids"]["floor2"], 1)
        self.assertEqual(r["ids"]["win"], 4)
        vh = M.bgm_vh(r["ids"])
        self.assertIn("BGM_F1   = 3'd6;", vh)
        self.assertIn("BGM_F2   = 3'd1;", vh)

    def test_missing_or_bad_file_falls_back_with_warning(self):
        self.cfg({"x": {"file": "sprites/music/nope.txt"}}, {"floor1": "x"})
        r = M.load(self.t)
        self.assertIsNone(r["entries"])
        self.assertEqual(r["ids"]["floor1"], 0)
        self.assertTrue(r["warnings"])
        for bad in ("C5:0", "C5", "H5:10", "C5:300", "C2:10", ""):
            self.track(bad)
            self.cfg({"x": {"file": "sprites/music/a.txt"}}, {"floor1": "x"})
            r = M.load(self.t)
            self.assertIsNone(r["entries"], bad)
            self.assertEqual(r["ids"]["floor1"], 0, bad)
            self.assertTrue(r["warnings"], bad)

    def test_too_many_entries_falls_back(self):
        self.track(" ".join(["C5:5"] * 128))
        self.cfg({"x": {"file": "sprites/music/a.txt"}}, {"floor1": "x"})
        self.assertTrue(M.load(self.t)["warnings"])
        self.track(" ".join(["C5:5"] * 127))
        self.assertFalse(M.load(self.t)["warnings"])

    def test_bad_config_is_a_clear_error(self):
        self.cfg({"x": {"file": "a"}, "y": {"file": "b"}}, {})
        with self.assertRaises(ValueError):
            M.load(self.t)
        self.cfg({"x": {"file": "a"}}, {"floor9": "x"})
        with self.assertRaises(ValueError):
            M.load(self.t)
        self.cfg({"x": {"file": "a"}}, {"floor1": "nope"})
        with self.assertRaises(ValueError):
            M.load(self.t)

    def test_hp_matches_the_builtin_formula(self):
        self.assertEqual(M.hp("A4"), round(1e8 / (2 * 440.0)))
        self.assertEqual(M.hp("R"), 0)

    def test_real_project_music_mem_matches_the_config(self):
        """mem/music.mem has 1024 entries and track 6 equals the custom track (or is empty when none is configured)"""
        with open(os.path.join(ROOT, "mem", "music.mem"), encoding="ascii") as f:
            ent = [int(x, 16) for x in f.read().split()]
        self.assertEqual(len(ent), 1024)
        r = M.load(ROOT)
        t6 = ent[6 * 128:7 * 128]
        exp = [(fr << 24) | hp for fr, hp in (r["entries"] or [])]
        self.assertEqual(t6[:len(exp)], exp)
        self.assertTrue(all(v == 0 for v in t6[len(exp):]))
        self.assertTrue(all(v == 0 for v in ent[7 * 128:]))
        with open(os.path.join(ROOT, "rtl", "bgm_cfg.vh"), encoding="utf-8") as f:
            self.assertEqual(f.read().replace("\r\n", "\n"), M.bgm_vh(r["ids"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
