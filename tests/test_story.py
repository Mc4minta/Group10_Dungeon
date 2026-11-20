#!/usr/bin/env python3
"""docs/STORY.md is the source of truth of every on-screen sentence (W16).   python tests/test_story.py

Checks: the real file is valid and complete, the generated files match it (text ROM, dialogue ROM, trigger table),
every kind of mistake is reported (characters, length, duplicates, triggers), and Rule 1 (a broken file -> default texts).
"""
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import story as S

CODE = {c: i for i, c in enumerate("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")}
CODE.update({" ": 36, "-": 37, ":": 38, "!": 39, ".": 40})

HEAD = "| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |\n| --- | --- | --- | --- | --- | --- | --- |\n"


def row(id_, trig, l1, l2="", spk="Player"):
    return f"| {id_} | B | {trig} | x | {spk} | {l1} | {l2} |\n"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


class RealStory(unittest.TestCase):
    def setUp(self):
        self.entries = S.parse_text(read(os.path.join(ROOT, "docs", "STORY.md")))
        self.dlg = S.validate(self.entries)
        self.st = S.load()

    def test_no_warnings_and_everything_present(self):
        self.assertEqual(self.st.warnings, [])
        self.assertEqual(sorted(self.st.screens), sorted(S.SCREENS))
        self.assertGreaterEqual(len(self.entries), 60)

    def test_game_title_is_the_chosen_one(self):
        self.assertEqual(self.st.screens["title"][0], "THE CHOSEN ONE")

    def test_all_approved_lines_are_in_the_file(self):
        ids = {e.id for e in self.entries}
        for i in ["PRO-01", "PRO-04", "F1-01", "F1-12", "F1-25", "F2-01", "F2-14", "F3-01", "F3-11", "END-01", "END-08", "TITLE-01"]:
            self.assertIn(i, ids)
        f101 = next(e for e in self.entries if e.id == "F1-01")
        self.assertEqual((f101.l1, f101.l2, f101.block), ("GASP! WHERE AM I!", "WHAT IS THIS PLACE!", True))

    def test_floor_clear_uses_the_live_floor_number(self):
        self.assertEqual(self.st.screens["floorclear"][0], "FLOOR {F} CLEAR!")

    def test_generated_text_rom_matches(self):
        """mem/text.mem: every dialogue line is stored where mem/dlg.mem says, character by character"""
        txt = [int(x, 16) for x in read(os.path.join(ROOT, "mem", "text.mem")).split()]
        dlg = [int(x, 16) for x in read(os.path.join(ROOT, "mem", "dlg.mem")).split()]
        self.assertEqual(len(txt), 4096)
        self.assertEqual(len(dlg), 128)
        for e in self.dlg:
            w = dlg[e.index]
            b0, n0, b1, n1, spk, blk = w & 0xFFF, (w >> 12) & 31, (w >> 17) & 0xFFF, (w >> 29) & 31, (w >> 34) & 3, (w >> 36) & 1
            self.assertEqual(txt[b0:b0 + n0], [CODE[c] for c in e.l1], e.id)
            self.assertEqual(txt[b1:b1 + n1], [CODE[c] for c in e.l2], e.id)
            self.assertEqual(spk, S.SPEAKERS[e.speaker.upper()], e.id)
            self.assertEqual(blk, int(e.block), e.id)
        for w in dlg[len(self.dlg):]:
            self.assertEqual(w, 0)

    def test_trigger_table_matches(self):
        vh = read(os.path.join(ROOT, "rtl", "dlg_cfg.vh"))
        self.assertIn(f"localparam NDLG = {len(self.dlg)};", vh)
        for e in self.dlg:
            if e.event is not None:
                self.assertIn(f"dlg_trigs[{e.index}] = ev[{e.event}];", vh, e.id)
            else:
                j = next(d for d in self.dlg if d.id == e.after).index
                self.assertIn(f"dlg_trigs[{e.index}] = fin[{j}];", vh, e.id)
        for i, n in enumerate(S.EVENTS):
            self.assertIn(f"localparam EV_{n.upper()} = {i};", vh)

    def test_every_event_is_used_by_the_game_or_story(self):
        """each event name in the story must exist in rtl/top.v as a dlg_ev[] assignment (so no message can silently never appear)"""
        top = read(os.path.join(ROOT, "rtl", "top.v"))
        for e in self.dlg:
            if e.event is not None:
                self.assertIn(f"dlg_ev[EV_{S.EVENTS[e.event].upper()}]", top, f"{e.id}: event {S.EVENTS[e.event]} is not driven by top.v")

    def test_screen_text_fits_the_screen(self):
        for name, (l1, l2) in self.st.screens.items():
            for t in (l1, l2):
                self.assertLessEqual(len(t.replace("{F}", "1")), 20, name)


class Mistakes(unittest.TestCase):
    def check_err(self, text, needle):
        with self.assertRaises(S.StoryError) as cm:
            S.validate(S.parse_text(text))
        self.assertIn(needle, str(cm.exception))

    def test_bad_character(self):
        self.check_err(HEAD + row("A-1", "start", "HELLO, WORLD"), "characters not in the font")

    def test_lowercase_is_rejected(self):
        self.check_err(HEAD + row("A-1", "start", "Hello"), "characters not in the font")

    def test_line_too_long(self):
        self.check_err(HEAD + row("A-1", "start", "A" * 21), "limit is 20")

    def test_duplicate_id(self):
        self.check_err(HEAD + row("A-1", "start", "X") + row("A-1", "first_attack", "Y"), "duplicate ID")

    def test_unknown_event(self):
        self.check_err(HEAD + row("A-1", "nonsense", "X"), "unknown trigger")

    def test_after_unknown_id(self):
        self.check_err(HEAD + row("A-1", "after:NOPE", "X"), "no such ID")

    def test_after_chain_loop(self):
        self.check_err(HEAD + row("A-1", "after:A-2", "X") + row("A-2", "after:A-1", "Y"), "loops")

    def test_unknown_speaker(self):
        self.check_err(HEAD + row("A-1", "start", "X", spk="Dragon"), "speaker")

    def test_valid_minimal_file(self):
        dlg = S.validate(S.parse_text(HEAD + row("A-1", "start!", "X") + row("A-2", "after:A-1", "Y", "Z", "Voice")))
        self.assertEqual([(d.id, d.event, d.after, d.block) for d in dlg], [("A-1", 0, None, True), ("A-2", None, "A-1", False)])

    def test_none_trigger_is_ignored_not_an_error(self):
        dlg = S.validate(S.parse_text(HEAD + row("A-1", "none", "X")))
        self.assertEqual(dlg, [])


class Rule1(unittest.TestCase):
    def test_broken_file_falls_back_to_default_texts(self):
        import tempfile
        with tempfile.TemporaryDirectory() as t:
            p = os.path.join(t, "STORY.md")
            with open(p, "w", encoding="utf-8") as f:
                f.write(HEAD + row("A-1", "start", "BAD, TEXT"))
            st = S.load(p)
        self.assertTrue(st.warnings)
        self.assertEqual(st.screens["title"], S.DEFAULT_SCREENS["title"])
        self.assertEqual(st.dialogs, [])

    def test_missing_file_falls_back_to_default_texts(self):
        st = S.load(os.path.join(ROOT, "docs", "does_not_exist.md"))
        self.assertTrue(st.warnings)
        self.assertEqual(sorted(st.screens), sorted(S.SCREENS))


if __name__ == "__main__":
    unittest.main(verbosity=2)
