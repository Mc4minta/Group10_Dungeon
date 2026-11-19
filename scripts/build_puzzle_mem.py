#!/usr/bin/env python3
"""Build mem/puzzle.mem (objects in the puzzle rooms) from single sprite PNGs (config: sprites/puzzle.json).

    python scripts/build_puzzle_mem.py              build mem/puzzle.mem
    python scripts/build_puzzle_mem.py --check      validate only, write nothing
    python scripts/build_puzzle_mem.py --preview    build + preview/puzzle_*.png

Layout (unchanged, no Verilog change): 16 frames x 32x32 RGB444 = 16384 words (10 used):
    0 bulb off   1 bulb on   2 lever up   3 lever down   4 box   5 gate closed   6 gate open   7-9 item of floor 1-3
Each source PNG (16x16) is scaled by an exact integer factor (nearest neighbour, never smoothed) to fill the 32x32 frame;
see-through pixels become key colour F0F. An optional "tint" recolours a sprite by luminance (e.g. an unlit torch).
Rule 1: a missing / skipped / empty / unreadable / wrongly sized file falls back to the old art (mem/puzzle_v1.mem) with a warning.

Exit code: 0 ok | 1 unreadable PNG (still builds, old art) | 2 bad config / bad fallback file.
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
FRAMES = 16
FW = P.FRAME_WORDS
TOTAL = FRAMES * FW
NAMES = ["bulb off", "bulb on", "lever up", "lever down", "box", "gate closed", "gate open",
         "item floor 1", "item floor 2", "item floor 3"] + [f"spare {i}" for i in range(10, 16)]
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
           "scale": P._int(raw.get("scale", 2), 1, 4, "scale"),
           "fallback": os.path.join(root, raw.get("fallback_mem", "mem/puzzle_v1.mem")),
           "output": os.path.join(root, raw.get("output_mem", "mem/puzzle.mem"))}
    tints = {}
    for name, t in raw.get("tints", {}).items():
        if name.startswith("_"):
            continue
        ok = isinstance(t, dict) and all(isinstance(t.get(k), list) and len(t[k]) == 3 and
                                         all(isinstance(v, int) and not isinstance(v, bool) and 0 <= v <= 255 for v in t[k])
                                         for k in ("dark", "light"))
        if not ok:
            raise ConfigError(f'tints."{name}" must be {{"dark": [r,g,b], "light": [r,g,b]}} with values 0-255')
        tints[name] = {"dark": tuple(t["dark"]), "light": tuple(t["light"])}
    cfg["tints"] = tints
    frames = {}
    for k, v in raw.get("frames", {}).items():
        if k.startswith("_"):
            continue
        if not (k.isdigit() and 0 <= int(k) < FRAMES):
            raise ConfigError(f'frames key "{k}" must be a frame number 0..15')
        if isinstance(v, dict) and v.get("skip"):
            frames[int(k)] = {"skip": True}
            continue
        if not (isinstance(v, dict) and isinstance(v.get("file"), str)):
            raise ConfigError(f'frames."{k}": use {{"file": "picture/props/x.png", "tint": "name"}} or {{"skip": true}}')
        t = v.get("tint")
        if t is not None and t not in tints:
            raise ConfigError(f'frames."{k}".tint = "{t}" is not defined in "tints"')
        cut = v.get("cut", [])
        if not (isinstance(cut, list) and all(isinstance(c, list) and len(c) == 3 and
                                              all(isinstance(q, int) and not isinstance(q, bool) and 0 <= q <= 255 for q in c) for c in cut)):
            raise ConfigError(f'frames."{k}".cut must be a list of [r,g,b] colours (0-255) that become see-through')
        frames[int(k)] = {"file": v["file"], "tint": t, "cut": [tuple(c) for c in cut]}
    cfg["frames"] = frames
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
        raise ConfigError(f"{path}: has {len(words)} words, expected {TOTAL} ({FRAMES} frames x {FW})")
    return words, nl


class Build:
    pass


def make_frame(spec, root, cfg):
    """-> (words|None, stats|None, label|None, reason|None, unreadable_msg|None)"""
    if spec is None:
        return None, None, None, "frame not configured", None
    if spec.get("skip"):
        return None, None, None, "config skip", None
    path = os.path.join(root, spec["file"])
    if not os.path.isfile(path):
        return None, None, None, f"file missing: {P.shortpath(path)}", None
    try:
        with Image.open(path) as im:
            im.load()
            im = im.convert("RGBA")
    except Exception as e:
        msg = f"cannot read {P.shortpath(path)}: {e}"
        return None, None, None, msg, msg
    if spec.get("cut"):                                        # exact background colours -> see-through (floor shows through)
        px = im.load()
        cut = set(spec["cut"])
        for y in range(im.height):
            for x in range(im.width):
                if px[x, y][:3] in cut:
                    px[x, y] = (0, 0, 0, 0)
    if spec.get("tint"):
        im = P.apply_tint(im, cfg["tints"][spec["tint"]])
    sc = cfg["scale"]
    w, h = im.size
    if w * sc > 32 or h * sc > 32:
        return None, None, None, f"{os.path.basename(path)} is {w}x{h}: x{sc} = {w * sc}x{h * sc} does not fit the 32x32 frame", None
    big = im.resize((w * sc, h * sc), Image.NEAREST)          # exact integer upscale
    cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    cell.paste(big, ((32 - w * sc) // 2, (32 - h * sc) // 2))
    words, stats = P.convert_cell(cell, cfg["key"], cfg["alpha"], 1)
    if stats["opaque"] == 0:
        return None, None, None, f"{os.path.basename(path)} fully transparent", None
    label = os.path.basename(path) + (f" ({spec['tint']})" if spec.get("tint") else "") + f" x{sc}"
    return words, stats, label, None, None


def build(cfg, root):
    b = Build()
    b.fallback, b.nl = read_fallback(cfg["fallback"])
    P._ROOT[0] = root
    b.out = list(b.fallback)
    b.result, b.unreadable = [], []
    for i in range(FRAMES):
        spec = cfg["frames"].get(i)
        info = {"idx": i, "name": NAMES[i], "source": None, "fallback": None, "stats": None}
        if spec is None and i >= 10:
            info["fallback"] = "spare frame (kept as old art)"
            b.result.append(info)
            continue
        w, st, label, why, bad = make_frame(spec, root, cfg)
        if bad:
            b.unreadable.append(bad)
        if w is None:
            info["fallback"] = why
        else:
            b.out[i * FW:(i + 1) * FW] = w
            info["source"], info["stats"] = label, st
        b.result.append(info)
    return b


def report(b, previous):
    for r in b.result:
        if r["fallback"] and r["idx"] < 10:
            print(f"WARNING: puzzle frame {r['idx']} ({r['name']}) -> FALLBACK old art: {r['fallback']}")
    print(f"\n{'idx':>3}  {'name':<14} {'source':<32} status")
    for r in b.result:
        if r["idx"] >= 10:
            continue
        if r["fallback"]:
            print(f"{r['idx']:>3}  {r['name']:<14} {'old art (puzzle_v1)':<32} FALLBACK ({r['fallback']})")
        else:
            note = []
            if r["stats"]["nudged"]:
                note.append(f"{r['stats']['nudged']} px nudged off key colour")
            if r["stats"]["semi"]:
                note.append(f"{r['stats']['semi']} semi-transparent px")
            print(f"{r['idx']:>3}  {r['name']:<14} {r['source']:<32} ok" + (f"  [{'; '.join(note)}]" if note else ""))
    nfb = sum(1 for r in b.result[:10] if r["fallback"])
    print(f"\nSummary: {10 - nfb} new-art frames, {nfb} fallback frames (old art); frames 10-15 unchanged")
    if previous is not None and len(previous) == TOTAL:
        ch = [NAMES[i] for i in range(10) if previous[i * FW:(i + 1) * FW] != b.out[i * FW:(i + 1) * FW]]
        print("Changed since previous mem/puzzle.mem: " + (", ".join(ch) if ch else "nothing"))


def frame_img(words, i, key, zoom):
    from sprite_preview import _checker
    im = _checker(32 * zoom, 32 * zoom, max(2, zoom))
    d = ImageDraw.Draw(im)
    for y in range(32):
        for x in range(32):
            c = words[i * FW + y * 32 + x]
            if c != key:
                d.rectangle([x * zoom, y * zoom, x * zoom + zoom - 1, y * zoom + zoom - 1],
                            fill=(((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return im


def make_previews(cfg, b, root):
    pdir = os.path.join(root, "preview")
    os.makedirs(pdir, exist_ok=True)
    z, pad = 4, 8
    cw = 32 * z
    W = pad + 10 * (cw + pad)
    H = 20 + 2 * (cw + 18 + pad)
    im = Image.new("RGB", (W, H), (30, 30, 30))
    d = ImageDraw.Draw(im)
    d.text((pad, 4), "puzzle.mem: NEW (top) vs OLD puzzle_v1.mem (bottom); red border = fallback", fill=(255, 255, 255))
    for i in range(10):
        x = pad + i * (cw + pad)
        fb = b.result[i]["fallback"]
        im.paste(frame_img(b.out, i, cfg["key"], z), (x, 20))
        d.text((x, 20 + cw + 2), f"{i} {NAMES[i]}", fill=(255, 120, 120) if fb else (220, 220, 220))
        if fb:
            d.rectangle([x - 2, 18, x + cw + 1, 20 + cw + 1], outline=(255, 0, 0), width=3)
        y2 = 20 + cw + 18 + pad
        im.paste(frame_img(b.fallback, i, cfg["key"], z), (x, y2))
        d.text((x, y2 + cw + 2), f"{i} old", fill=(180, 180, 180))
    im.save(os.path.join(pdir, "puzzle_contact.png"))
    print(f"Puzzle previews written to {pdir}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Build mem/puzzle.mem from single sprite PNGs.")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--root", default=ROOT_DEFAULT)
    ap.add_argument("--config", default=None)
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)
    try:
        cfg = load_config(a.config or os.path.join(root, "sprites", "puzzle.json"), root)
        b = build(cfg, root)
    except ConfigError as e:
        print(f"ERROR: {e}")
        return 2
    for u in b.unreadable:
        print(f"ERROR: {u}  (that frame uses old art)")
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
