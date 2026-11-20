#!/usr/bin/env python3
"""Parser for docs/STORY.md - the source of truth of every on-screen sentence (W16).

    python scripts/story.py          check the file and print a summary

docs/STORY.md contains markdown tables with a header row that has the columns  ID | Tier | Trigger | ... | Speaker | Line 1 | Line 2
(the Thai column names "ผู้พูด", "บรรทัด 1", "บรรทัด 2", "จังหวะ" are used). Every row is one message:
  * Trigger "screen:<name>"  -> a full-screen text (title, prologue pages, NEW FORM banners, floor clear, maze banner, win, timeout, game over)
  * any other trigger        -> a dialogue box message shown by rtl/dialog.v when the game event happens (see EVENTS)
make_font.py (which build_story.py runs) turns the result into mem/text.mem, mem/dlg.mem and the generated .vh files.
Rule 1: a missing or broken docs/STORY.md falls back to the built-in default texts (printed warning), the game still builds.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -:!.")
MAX_LINE = 20
MAX_DLG = 128
MAX_CHARS = 3500
SPEAKERS = {"PLAYER": 0, "VOICE": 1, "SYSTEM": 2}

# hardware events, in the order of the `ev` vector of rtl/dialog.v (indices are generated into rtl/dlg_cfg.vh; add new ones at the END)
EVENTS = ["start", "first_attack",
          "lock_f1c1", "clear_f1c1", "lock_f1c2", "clear_f1c2", "enter_f1puz", "item_f1", "got_f1", "evolved_f1", "enter_f1boss", "bossdead_f1",
          "enter_f2start", "lock_f2c1", "enter_f2c1", "lock_f2c2", "clear_f2c2", "enter_f2puz", "item_f2", "evolved_f2", "enter_f2boss", "vuln_f2", "bossdead_f2",
          "enter_f3start", "lock_f3c1", "lock_f3c2", "clear_f3c2", "enter_f3puz", "item_f3", "evolved_f3", "enter_f3boss", "charge_f3", "interrupt_f3",
          "key_drop", "enter_f3start_key", "maze_banner_end", "start_again"]

SCREENS = ["settings1", "settings2", "settings3", "settings4", "settings5", "controls1", "controls2", "controls3", "controls4", "controls5", "credits1", "credits2", "credits3", "title", "prologue1", "prologue2", "prologue3", "prologue4", "evolve2", "evolve3", "evolve4",
           "floorclear", "maze", "win", "timeout", "gameover"]

# Rule 1 fallback texts (the screens exist even without STORY.md)
DEFAULT_SCREENS = {
    "title": ("THE CHOSEN ONE", "PRESS BTNC"), "prologue1": ("ROME WASNT BUILT", "IN A DAY."),
    "prologue2": ("BUT WE HAVE ONLY", "4 HOURS LEFT."), "prologue3": ("I NEED COFFEE...", "DONT FALL ASLEEP!"),
    "prologue4": ("I CANT STAY AWAKE...", "ALL WENT QUIET."), "evolve2": ("NEW FORM: ORC!", "RANGED SHOT!"),
    "evolve3": ("NEW FORM: ANGEL!", "SHOTS SPLIT ON HIT!"), "evolve4": ("NEW FORM: FORM 4!", "HOLD ATTACK: CHARGE!"),
    "floorclear": ("FLOOR 1 CLEAR!", ""), "maze": ("TILT THE BOARD TO", "ROLL THE BALL OUT!"), "win": ("YOU ESCAPED!", "YOU WIN!"),
    "timeout": ("TIME IS UP!", "TRAPPED FOREVER."), "gameover": ("GAME OVER", "PRESS BTNC"),
    "settings1": ("CLAP LEVEL", "VERY LOW - EASY"), "settings2": ("CLAP LEVEL", "LOW"), "settings3": ("CLAP LEVEL", "MID"),
    "settings4": ("CLAP LEVEL", "HIGH"), "settings5": ("CLAP LEVEL", "VERY HIGH - HARD"),
    "controls1": ("MOVE", "ARROWS WASD OR BTNS"), "controls2": ("ATTACK", "SPACE J ENTER BTNC"),
    "controls3": ("SPRINT AND PAUSE", "SHIFT SW14  P SW15"), "controls4": ("AUTO AIM", "L OR SW9  FACE SW12"),
    "controls5": ("OTHER KEYS", "R BOXES  C CLAP SW11"), "credits1": ("THE CHOSEN ONE", "GROUP 10"),
    "credits2": ("DESIGN AND CODE", "NAMES HERE"), "credits3": ("ART AND SOUND", "SEE ASSET PACKS"),
}


class StoryError(Exception):
    pass


class Entry:
    def __init__(self, id_, tier, trigger, speaker, l1, l2, line_no):
        self.id, self.tier, self.trigger, self.speaker, self.l1, self.l2, self.line_no = id_, tier, trigger, speaker, l1, l2, line_no
        self.screen = None       # name for screen:<name>
        self.event = None        # event index for a plain event trigger
        self.hint = None         # W32: name of a hint-strip text (trigger hint:<name>)
        self.after = None        # ID of the entry it follows
        self.block = False       # trailing "!" = freezes the game until BTNC
        self.index = None        # dialogue index (0..NDLG-1) for dialogue entries


def _cells(line):
    s = line.strip()
    if not (s.startswith("|") and s.endswith("|")):
        return None
    return [c.strip() for c in s.strip("|").split("|")]


def parse_text(text):
    """-> list of Entry (file order)"""
    entries, header, line_no = [], None, 0
    for raw in text.replace("\r\n", "\n").split("\n"):
        line_no += 1
        cells = _cells(raw)
        if cells is None:
            header = None if not raw.strip().startswith("|") else header
            if not raw.strip():
                header = None
            continue
        if header is None:
            if "ID" in cells and "Trigger" in cells:
                header = {name: i for i, name in enumerate(cells)}
            continue
        if all(set(c) <= set("-: ") for c in cells):
            continue                                                   # the |---|---| separator row
        def col(*names):
            for n in names:
                if n in header and header[n] < len(cells):
                    return cells[header[n]]
            return ""
        id_ = col("ID")
        if not id_:
            continue
        entries.append(Entry(id_, col("Tier"), col("Trigger"), col("ผู้พูด", "Speaker"), col("บรรทัด 1", "Line 1"), col("บรรทัด 2", "Line 2"), line_no))
    return entries


def validate(entries):
    """resolve the triggers, check characters / lengths / ids. Raises StoryError listing every problem."""
    errs = []
    ids = {}
    for e in entries:
        if e.id in ids:
            errs.append(f"line {e.line_no}: duplicate ID {e.id}")
        ids[e.id] = e
        for k, t0 in (("line 1", e.l1), ("line 2", e.l2)):
            t = t0.replace("{F}", "0")                                    # W32: {F} = one live digit (the enemies left)
            bad = sorted(set(t) - CHARS)
            if bad:
                errs.append(f"{e.id} {k}: characters not in the font: {' '.join(repr(c) for c in bad)} (allowed: A-Z 0-9 space - : ! .)")
            if len(t) > MAX_LINE:
                errs.append(f"{e.id} {k}: {len(t)} characters, the limit is {MAX_LINE}: {t!r}")
        if not e.l1:
            errs.append(f"{e.id}: line 1 is empty")
        if e.speaker and e.speaker.upper() not in SPEAKERS:
            errs.append(f"{e.id}: speaker {e.speaker!r} must be Player, Voice or System")
    seen_screens = {}
    hints_seen = set()
    for e in entries:
        t = e.trigger.strip()
        if t.startswith("screen:"):
            name = t[7:].strip()
            if name not in SCREENS:
                errs.append(f"{e.id}: unknown screen {name!r} (known: {', '.join(SCREENS)})")
            elif name in seen_screens and name != "floorclear":
                errs.append(f"{e.id}: screen {name} is already used by {seen_screens[name]}")
            else:
                seen_screens.setdefault(name, e.id)
                e.screen = name
            continue
        if t in ("none", "", "-"):
            continue
        if t.startswith("hint:"):
            e.hint = t[5:].strip()
            if not e.hint or e.hint in hints_seen:
                errs.append(f"{e.id}: hint name {e.hint!r} is empty or used twice")
            hints_seen.add(e.hint)
            continue
        e.block = t.endswith("!")
        t = t.rstrip("!").strip()
        if t.startswith("after:"):
            e.after = t[6:].strip()
            if e.after not in ids:
                errs.append(f"{e.id}: after:{e.after} - no such ID")
            elif ids[e.after].trigger.startswith("screen:"):
                errs.append(f"{e.id}: after:{e.after} - {e.after} is a full screen, a dialogue can only follow a dialogue")
        elif t in EVENTS:
            e.event = EVENTS.index(t)
        else:
            errs.append(f"{e.id}: unknown trigger {e.trigger!r} (events: {', '.join(EVENTS)})")
    dlg = [e for e in entries if e.screen is None and (e.event is not None or e.after is not None or e.hint)]
    for i, e in enumerate(dlg):
        e.index = i
    if len(dlg) > MAX_DLG:
        errs.append(f"{len(dlg)} dialogue messages, the limit is {MAX_DLG}")
    for e in dlg:                                                      # after-chains must end in an event (no cycles)
        cur, n = e, 0
        while cur.after is not None and n < 200:
            cur = ids.get(cur.after) or cur
            n += 1
            if cur is e:
                break
        if cur.after is not None:
            errs.append(f"{e.id}: the after: chain loops")
    chars = sum(len(e.l1) + len(e.l2) for e in dlg)
    if chars > MAX_CHARS:
        errs.append(f"dialogue text is {chars} characters, the limit is {MAX_CHARS}")
    if errs:
        raise StoryError("\n".join(errs))
    return dlg


class Story:
    def __init__(self):
        self.screens = {}      # name -> (line1, line2)
        self.dialogs = []      # Entry list with .index (hint entries are in the list too: they have .hint and are never triggered)
        self.warnings = []
        self.source = None


def load(path=None):
    st = Story()
    path = path or os.path.join(ROOT, "docs", "STORY.md")
    st.source = path
    try:
        with open(path, encoding="utf-8") as f:
            entries = parse_text(f.read())
        dlg = validate(entries)
    except (OSError, StoryError) as e:
        st.warnings.append(f"docs/STORY.md not usable -> built-in default texts, no dialogue boxes: {e}")
        st.screens = dict(DEFAULT_SCREENS)
        return st
    for e in entries:
        if e.screen and e.screen not in st.screens:
            st.screens[e.screen] = (e.l1, e.l2)
    for name in SCREENS:
        if name not in st.screens:
            st.warnings.append(f"screen {name!r} is not in docs/STORY.md -> default text")
            st.screens[name] = DEFAULT_SCREENS[name]
    for e in entries:
        if e.screen is None and e.event is None and e.after is None and not e.hint:
            st.warnings.append(f"{e.id} has no trigger (none) -> not shown")
    st.dialogs = dlg
    # floor clear: "FLOOR 1 CLEAR!" -> the digit becomes the live floor number {F}
    a, b = st.screens["floorclear"]
    st.screens["floorclear"] = (re.sub(r"\bFLOOR \d\b", "FLOOR {F}", a), b)
    return st


def main():
    st = load()
    for w in st.warnings:
        print("WARNING:", w)
    print(f"{len(st.screens)} screens, {len(st.dialogs)} dialogue messages, {sum(len(d.l1) + len(d.l2) for d in st.dialogs)} dialogue characters")
    return 0


if __name__ == "__main__":
    sys.exit(main())
