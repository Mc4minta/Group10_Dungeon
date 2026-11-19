#!/usr/bin/env python3
"""Build mem/boss.mem (3 bosses x 2 frames, 64x64) from 32x32 sprite cells scaled exactly 2x (config: sprites/bosses.json).

    python scripts/build_boss_mem.py              build mem/boss.mem
    python scripts/build_boss_mem.py --check      validate only, write nothing
    python scripts/build_boss_mem.py --preview    build + preview/boss_*.png

Layout (unchanged, no Verilog change): 8 frames x 64x64 RGB444 = 32768 words (6 used, 2 spare),
frame = boss*2 + n :  boss 1 / boss 3: n = animation frame 0/1;  boss 2: n = 1 is the STUNNED picture.
Every source pixel becomes a 2x2 block (nearest neighbour, never smoothed). Transparent -> key colour F0F.
Rule 1: anything missing / skipped / transparent / outside the sheet falls back to the old art (mem/boss_v1.mem)
with a warning; the build never fails because art is missing.
It also reports colour counts per frame (8-bit vs RGB444) so banding can be judged.

Exit code: 0 ok | 1 unreadable sheet (still builds, old art) | 2 bad config / bad fallback file.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_player_mem as P  # noqa: E402

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    print("ERROR: Pillow is required (pip install pillow)")
    sys.exit(2)

ConfigError = P.ConfigError
BOSS_PX = 64
FRAME_WORDS = BOSS_PX * BOSS_PX
SLOTS = 8
USED = 6
TOTAL = SLOTS * FRAME_WORDS
SCALE = 2
NAMES = ["boss1.f0", "boss1.f1", "boss2.f0", "boss2.f1(stunned)", "boss3.f0", "boss3.f1"]
ROOT_DEFAULT = P.ROOT_DEFAULT


def load_config(path, root):
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = json.load(f)
    except FileNotFoundError:
        raise ConfigError(f"config not found: {path}")
    except (OSError, ValueError) as e:
        raise ConfigError(f"cannot read config {path}: {e}")
    if not isinstance(raw, dict):
        raise ConfigError("config top level must be an object")
    cfg = {"key": P.parse_color(raw.get("key_color", "F0F")),
           "alpha": P._int(raw.get("alpha_threshold", 128), 1, 255, "alpha_threshold"),
           "fallback": os.path.join(root, raw.get("fallback_mem", "mem/boss_v1.mem")),
           "output": os.path.join(root, raw.get("output_mem", "mem/boss.mem"))}
    sheets = raw.get("sheets", {})
    if not isinstance(sheets, dict) or not all(isinstance(v, str) for v in sheets.values()):
        raise ConfigError('"sheets" must map a sheet name to a PNG path')
    cfg["sheets"] = {k: v for k, v in sheets.items() if not k.startswith("_")}

    def spec(v, what):
        if isinstance(v, dict) and v.get("skip"):
            return {"skip": True}
        if not (isinstance(v, dict) and isinstance(v.get("sheet"), str) and "col" in v):
            raise ConfigError(f'{what}: use {{"sheet": "name", "col": 1}} (optional "row", default 1) or {{"skip": true}}')
        return {"sheet": v["sheet"], "col": P._int(v["col"], 0, 255, f"{what} col"),
                "row": P._int(v.get("row", 1), 1, 64, f"{what} row")}

    bs = raw.get("bosses", {})
    if not isinstance(bs, dict):
        raise ConfigError('"bosses" must be an object')
    for k in bs:
        if k not in ("1", "2", "3"):
            raise ConfigError(f'unknown boss "{k}" (valid: 1, 2, 3)')
    cfg["bosses"] = {}
    for n in ("1", "2", "3"):
        e = bs.get(n, {})
        if not isinstance(e, dict):
            raise ConfigError(f'bosses."{n}" must be an object')
        en = e.get("enabled", True)
        if not isinstance(en, bool):
            raise ConfigError(f'bosses."{n}".enabled must be true or false')
        fr = e.get("frames", [])
        if not isinstance(fr, list) or len(fr) > 2:
            raise ConfigError(f'bosses."{n}".frames must be a list of at most 2 entries')
        cfg["bosses"][int(n)] = {"enabled": en, "frames": [spec(v, f'bosses."{n}".frames[{i}]') for i, v in enumerate(fr)]}
    return cfg


def read_fallback(path):
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        raise ConfigError(f"cannot read fallback art {path}: {e}")
    nl = "\r\n" if b"\r\n" in data else "\n"
    words = []
    for i, ln in enumerate(data.decode("ascii", "replace").split()):
        try:
            v = int(ln, 16)
        except ValueError:
            raise ConfigError(f"{path}: line {i + 1} is not hex: {ln!r}")
        if not 0 <= v <= 0xFFF:
            raise ConfigError(f"{path}: line {i + 1} out of RGB444 range: {ln!r}")
        words.append(v)
    if len(words) != TOTAL:
        raise ConfigError(f"{path}: has {len(words)} words, expected {TOTAL} ({SLOTS} frames x {FRAME_WORDS})")
    return words, nl


def scale2(words32):
    """32x32 words -> 64x64 words, each pixel becomes a 2x2 block (exact, nearest neighbour)"""
    out = [0] * FRAME_WORDS
    for y in range(32):
        for x in range(32):
            c = words32[y * 32 + x]
            for dy in range(SCALE):
                for dx in range(SCALE):
                    out[(y * SCALE + dy) * BOSS_PX + x * SCALE + dx] = c
    return out


def colour_counts(cell, alpha):
    """(8-bit colours, RGB444 colours) of the opaque pixels of an RGBA cell"""
    cols = set()
    for cnt, (r, g, b, a) in cell.getcolors(maxcolors=1 << 20):
        if a >= alpha:
            cols.add((r, g, b))
    return len(cols), len({P.to_rgb444(*c) for c in cols})


class Build:
    pass


def build(cfg, root):
    b = Build()
    b.fallback, b.nl = read_fallback(cfg["fallback"])
    P._ROOT[0] = root
    b.sheets, b.unreadable = {}, []
    for name, rel in cfg["sheets"].items():
        sh = P.Sheet(name, os.path.join(root, rel))
        b.sheets[name] = sh
        if sh.status == "unreadable":
            b.unreadable.append(sh.detail)
    b.out = list(b.fallback)          # spare frames 6, 7 stay as in the old file
    b.result = []
    for n in (1, 2, 3):
        bc = cfg["bosses"][n]
        for a in range(2):
            i = (n - 1) * 2 + a
            info = {"idx": i, "name": NAMES[i], "source": None, "fallback": None, "stats": None, "colours": None}
            words = None
            if not bc["enabled"]:
                info["fallback"] = "boss disabled in config"
            elif a >= len(bc["frames"]):
                info["fallback"] = "frame not configured"
            elif bc["frames"][a].get("skip"):
                info["fallback"] = "config skip"
            else:
                sp = bc["frames"][a]
                sh = b.sheets.get(sp["sheet"])
                if sh is None:
                    info["fallback"] = f"sheet '{sp['sheet']}' not configured"
                else:
                    w, st, why = P.get_cell_words(sh, sp["row"], sp["col"], cfg)
                    if w is None:
                        info["fallback"] = why
                    else:
                        words = scale2(w)
                        info["stats"] = st
                        info["source"] = f"{sh.label} r{sp['row']} c{sp['col']} x2"
                        cell = sh.cell(sp["row"], sp["col"])[1]
                        info["colours"] = colour_counts(cell, cfg["alpha"])
            if words is None:
                words = b.fallback[i * FRAME_WORDS:(i + 1) * FRAME_WORDS]
            b.out[i * FRAME_WORDS:(i + 1) * FRAME_WORDS] = words
            b.result.append(info)
    return b


def report(b, previous):
    for n in (1, 2, 3):
        lst = b.result[(n - 1) * 2:n * 2]
        fb = [r for r in lst if r["fallback"]]
        if len(fb) == 2 and fb[0]["fallback"] == fb[1]["fallback"]:
            print(f"WARNING: boss {n}: both frames -> FALLBACK old art: {fb[0]['fallback']}")
        else:
            for r in fb:
                print(f"WARNING: {r['name']} -> FALLBACK old art: {r['fallback']}")
    print(f"\n{'idx':>3}  {'name':<18} {'source':<42} status")
    for r in b.result:
        if r["fallback"]:
            print(f"{r['idx']:>3}  {r['name']:<18} {'old art (boss_v1)':<42} FALLBACK ({r['fallback']})")
        else:
            c8, c4 = r["colours"]
            note = [f"colours {c8} -> {c4} after RGB444" + (f" (merged {c8 - c4})" if c8 != c4 else " (no banding)")]
            if r["stats"]["nudged"]:
                note.append(f"{r['stats']['nudged']} px nudged off key colour")
            if r["stats"]["semi"]:
                note.append(f"{r['stats']['semi']} semi-transparent px")
            print(f"{r['idx']:>3}  {r['name']:<18} {r['source']:<42} ok  [{'; '.join(note)}]")
    nfb = sum(1 for r in b.result if r["fallback"])
    print(f"\nSummary: {USED - nfb} new-art frames, {nfb} fallback frames (old art); spare frames 6-7 unchanged")
    if previous is not None and len(previous) == TOTAL:
        ch = [NAMES[i] for i in range(USED) if previous[i * FRAME_WORDS:(i + 1) * FRAME_WORDS] != b.out[i * FRAME_WORDS:(i + 1) * FRAME_WORDS]]
        print("Changed since previous mem/boss.mem: " + (", ".join(ch) if ch else "nothing"))


def frame_img(words, i, key, zoom):
    from sprite_preview import _checker
    im = _checker(BOSS_PX * zoom, BOSS_PX * zoom, max(2, zoom * 2))
    d = ImageDraw.Draw(im)
    for y in range(BOSS_PX):
        for x in range(BOSS_PX):
            c = words[i * FRAME_WORDS + y * BOSS_PX + x]
            if c != key:
                d.rectangle([x * zoom, y * zoom, x * zoom + zoom - 1, y * zoom + zoom - 1],
                            fill=(((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return im


def make_previews(cfg, b, root):
    pdir = os.path.join(root, "preview")
    os.makedirs(pdir, exist_ok=True)
    z, pad = 3, 8
    cw = BOSS_PX * z
    W = pad + USED * (cw + pad)
    H = 20 + 2 * (cw + 18 + pad)
    im = Image.new("RGB", (W, H), (30, 30, 30))
    d = ImageDraw.Draw(im)
    d.text((pad, 4), "boss.mem: NEW (top) vs OLD boss_v1.mem (bottom); red border = fallback", fill=(255, 255, 255))
    for i in range(USED):
        x = pad + i * (cw + pad)
        fb = b.result[i]["fallback"]
        im.paste(frame_img(b.out, i, cfg["key"], z), (x, 20))
        d.text((x, 20 + cw + 2), NAMES[i], fill=(255, 120, 120) if fb else (220, 220, 220))
        if fb:
            d.rectangle([x - 2, 18, x + cw + 1, 20 + cw + 1], outline=(255, 0, 0), width=3)
        y2 = 20 + cw + 18 + pad
        im.paste(frame_img(b.fallback, i, cfg["key"], z), (x, y2))
        d.text((x, y2 + cw + 2), NAMES[i] + " old", fill=(180, 180, 180))
    im.save(os.path.join(pdir, "boss_contact.png"))
    print(f"Boss previews written to {pdir}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Build mem/boss.mem from 32x32 sprite cells scaled 2x.")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--root", default=ROOT_DEFAULT)
    ap.add_argument("--config", default=None)
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)
    try:
        cfg = load_config(a.config or os.path.join(root, "sprites", "bosses.json"), root)
        b = build(cfg, root)
    except ConfigError as e:
        print(f"ERROR: {e}")
        return 2
    for u in b.unreadable:
        print(f"ERROR: {u}  (its frames use old art)")
    report(b, P.read_words_quiet(cfg["output"]))
    if a.check:
        print("\n--check: nothing written.")
    else:
        P.write_mem(cfg["output"], b.out, b.nl)
        print(f"\nWrote {P.shortpath(cfg['output'])}  ({len(b.out)} words)")
    if a.preview:
        make_previews(cfg, b, root)
    return 1 if b.unreadable else 0


if __name__ == "__main__":
    sys.exit(main())
