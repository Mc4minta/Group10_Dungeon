#!/usr/bin/env python3
"""Build everything that depends on docs/STORY.md (the source of truth of all on-screen text).

    python scripts/build_story.py          check the story file and regenerate
                                           mem/text.mem  mem/dlg.mem  mem/font.mem
                                           rtl/text_layout.vh  rtl/text_select.vh  rtl/dlg_cfg.vh
Then rebuild the Vivado project (docs/BOARD_TEST_STEPS.md). Errors in the story file (bad characters, lines over 20 characters, unknown
triggers) are listed and the built-in default texts are used (Rule 1: the game still builds).
"""
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import story
st = story.load()
for w in st.warnings:
    print("WARNING:", w)
runpy.run_path(os.path.join(HERE, "make_font.py"), run_name="__main__")
