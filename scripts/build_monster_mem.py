#!/usr/bin/env python3
"""Build mem/monster.mem (enemy sprites) from sprite strips (config: sprites/monsters.json).

    python scripts/build_monster_mem.py              build mem/monster.mem
    python scripts/build_monster_mem.py --check      validate only, write nothing
    python scripts/build_monster_mem.py --preview    build + preview/monster_*.png

Layout (unchanged, no Verilog change): 4 frames x 32x32 RGB444 = 4096 words, frame = type*2 + anim:
    0 = A0, 1 = A1  (monster A, the chaser)      2 = B0, 3 = B1  (monster B, the turret)
Source cells are 32x32 (no scaling at all). Transparent pixels -> key colour F0F.
Rule 1: anything missing / skipped / transparent / outside the sheet falls back to the old art
(mem/monster_v1.mem) with a warning; the build never fails because art is missing.

Exit code: 0 ok | 1 unreadable sheet (still builds, old art) | 2 bad config / bad fallback file.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_player_mem as P  # noqa: E402  (reuses Sheet, convert_cell, to_rgb444)

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    print("ERROR: Pillow is required (pip install pillow)")
    sys.exit(2)

FRAMES = 4
FRAME_WORDS = P.FRAME_WORDS
TOTAL = FRAMES * FRAME_WORDS
NAMES = ["A0", "A1", "B0", "B1"]
ROOT_DEFAULT = P.ROOT_DEFAULT
ConfigError = P.ConfigError


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
           "fallback": os.path.join(root, raw.get("fallback_mem", "mem/monster_v1.mem")),
           "output": os.path.join(root, raw.get("output_mem", "mem/monster.mem"))}
    sheets = raw.get("sheets", {})
    if not isinstance(sheets, dict) or not all(isinstance(v, str) for v in sheets.values()):
        raise ConfigError('"sheets" must map a sheet name to a PNG path')
    cfg["sheets"] = {k: v for k, v in sheets.items() if not k.startswith("_")}

    def frame_spec(v, what):
        if isinstance(v, dict) and v.get("skip"):
            return {"skip": True}
        if not (isinstance(v, dict) and isinstance(v.get("sheet"), str) and "col" in v):
            raise ConfigError(f'{what}: use {{"sheet": "name", "col": 1}} (optional "row", default 1) or {{"skip": true}}')
        return {"sheet": v["sheet"], "col": P._int(v["col"], 0, 255, f"{what} col"),
                "row": P._int(v.get("row", 1), 1, 64, f"{what} row")}

    mons = raw.get("monsters", {})
    if not isinstance(mons, dict):
        raise ConfigError('"monsters" must be an object')
    for k in mons:
        if k not in ("A", "B"):
            raise ConfigError(f'unknown monster "{k}" (valid: A, B)')
    cfg["monsters"] = {}
    for k in ("A", "B"):
        e = mons.get(k, {})
        if not isinstance(e, dict):
            raise ConfigError(f'monsters."{k}" must be an object')
        en = e.get("enabled", True)
        if not isinstance(en, bool):
            raise ConfigError(f'monsters."{k}".enabled must be true or false')
        fr = e.get("frames", [])
        if not isinstance(fr, list) or len(fr) > 2:
            raise ConfigError(f'monsters."{k}".frames must be a list of at most 2 entries (anim 0 and 1)')
        sc = e.get("scale", 1)
        if isinstance(sc, bool) or sc not in (1, 2):
            raise ConfigError(f'monsters."{k}".scale must be 1 or 2, got {sc!r}')
        cfg["monsters"][k] = {"enabled": en, "scale": sc, "frames": [frame_spec(v, f'monsters."{k}".frames[{i}]') for i, v in enumerate(fr)]}
    cfg["alternatives"] = {}
    for name, lst in raw.get("alternatives", {}).items():
        if name.startswith("_"):
            continue
        if not isinstance(lst, list) or len(lst) != 2:
            raise ConfigError(f'alternatives."{name}" must be a list of 2 frames (for anim 0 and 1)')
        cfg["alternatives"][name] = [frame_spec(v, f'alternatives."{name}"') for v in lst]
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
        raise ConfigError(f"{path}: has {len(words)} words, expected {TOTAL} ({FRAMES} frames x {FRAME_WORDS})")
    return words, nl


class Build:
    pass


def resolve_frame(spec, sheets, cfg):
    """-> (words|None, stats|None, source|None, reason|None)"""
    if spec.get("skip"):
        return None, None, None, "config skip"
    sh = sheets.get(spec["sheet"])
    if sh is None:
        return None, None, None, f"sheet '{spec['sheet']}' not configured"
    w, st, why = P.get_cell_words(sh, spec["row"], spec["col"], cfg)
    if w is None:
        return None, None, None, why
    return w, st, f"{sh.label} r{spec['row']} c{spec['col']}", None


def art_bbox(words32, key):
    xs = [i % 32 for i, w in enumerate(words32) if w != key]
    ys = [i // 32 for i, w in enumerate(words32) if w != key]
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1) if xs else None


def scale2_window(words32, anchor, key):
    """32x32 -> 32x32 at 2x: the 16x16 source window centred on the art (anchor = art centre) is doubled, so the monster is drawn as big as the hero
    (art at most 16x16 px, bigger art is cut)"""
    cx, cy = anchor
    x0 = min(max(int(round(cx - 8)), 0), 16)
    y0 = min(max(int(round(cy - 8)), 0), 16)
    return [words32[(y0 + y // 2) * 32 + x0 + x // 2] for y in range(32) for x in range(32)]


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
    b.out = [0] * TOTAL
    b.result = []
    for k, mi in (("A", 0), ("B", 1)):
        mc = cfg["monsters"][k]
        anchor = None
        if mc["enabled"] and mc["scale"] == 2:                          # one anchor per monster (union of its frames): the animation must not jump
            boxes = []
            for sp in mc["frames"][:2]:
                w0 = resolve_frame(sp, b.sheets, cfg)[0]
                bb = art_bbox(w0, cfg["key"]) if w0 is not None else None
                if bb:
                    boxes.append(bb)
            if boxes:
                anchor = ((min(x[0] for x in boxes) + max(x[2] for x in boxes)) / 2.0, (min(x[1] for x in boxes) + max(x[3] for x in boxes)) / 2.0)
        for anim in range(2):
            i = mi * 2 + anim
            info = {"idx": i, "name": NAMES[i], "source": None, "fallback": None, "stats": None}
            words = None
            if not mc["enabled"]:
                info["fallback"] = "monster disabled in config"
            elif anim >= len(mc["frames"]):
                info["fallback"] = "frame not configured"
            else:
                words, info["stats"], info["source"], info["fallback"] = resolve_frame(mc["frames"][anim], b.sheets, cfg)
                if words is not None and mc["scale"] == 2 and anchor is not None:
                    words = scale2_window(words, anchor, cfg["key"])
                    info["source"] = str(info["source"]) + " x2"
            if words is None:
                words = b.fallback[i * FRAME_WORDS:(i + 1) * FRAME_WORDS]
            b.out[i * FRAME_WORDS:(i + 1) * FRAME_WORDS] = words
            b.result.append(info)
    return b


def report(b, previous):
    byk = {"A": b.result[0:2], "B": b.result[2:4]}
    for k, lst in byk.items():
        fb = [r for r in lst if r["fallback"]]
        if len(fb) == 2 and fb[0]["fallback"] == fb[1]["fallback"]:
            print(f"WARNING: monster {k}: both frames -> FALLBACK old art: {fb[0]['fallback']}")
        else:
            for r in fb:
                print(f"WARNING: monster frame {r['name']} -> FALLBACK old art: {r['fallback']}")
    print(f"\n{'idx':>3}  {'name':<5} {'source':<32} status")
    for r in b.result:
        if r["fallback"]:
            print(f"{r['idx']:>3}  {r['name']:<5} {'old art (monster_v1)':<32} FALLBACK ({r['fallback']})")
        else:
            s = r["stats"]
            note = []
            if s["outside"]:
                note.append(f"{s['outside']} px outside {P.HIT_LO}-{P.HIT_HI}")
            if s["nudged"]:
                note.append(f"{s['nudged']} px nudged off key colour")
            if s["semi"]:
                note.append(f"{s['semi']} semi-transparent px")
            print(f"{r['idx']:>3}  {r['name']:<5} {r['source']:<32} ok" + (f"  [{'; '.join(note)}]" if note else ""))
    nfb = sum(1 for r in b.result if r["fallback"])
    print(f"\nSummary: {FRAMES - nfb} new-art frames, {nfb} fallback frames (old art)")
    if previous is not None and len(previous) == TOTAL:
        ch = [NAMES[i] for i in range(FRAMES) if previous[i * FRAME_WORDS:(i + 1) * FRAME_WORDS] != b.out[i * FRAME_WORDS:(i + 1) * FRAME_WORDS]]
        print("Changed since previous mem/monster.mem: " + (", ".join(ch) if ch else "nothing"))


def frame_img(words, i, key, zoom):
    from sprite_preview import _checker
    im = _checker(32 * zoom, 32 * zoom, max(2, zoom // 2))
    d = ImageDraw.Draw(im)
    for y in range(32):
        for x in range(32):
            c = words[i * FRAME_WORDS + y * 32 + x]
            if c != key:
                d.rectangle([x * zoom, y * zoom, x * zoom + zoom - 1, y * zoom + zoom - 1],
                            fill=(((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return im


def make_previews(cfg, b, root):
    pdir = os.path.join(root, "preview")
    os.makedirs(pdir, exist_ok=True)
    z, pad = 6, 8
    cw = 32 * z
    # contact sheet: new (top) and old art (bottom), red border = fallback
    W = pad + FRAMES * (cw + pad)
    H = 20 + 2 * (cw + 18 + pad)
    im = Image.new("RGB", (W, H), (30, 30, 30))
    d = ImageDraw.Draw(im)
    d.text((pad, 4), "monster.mem: NEW (top)  vs  OLD monster_v1.mem (bottom)", fill=(255, 255, 255))
    for i in range(FRAMES):
        x = pad + i * (cw + pad)
        fb = b.result[i]["fallback"]
        im.paste(frame_img(b.out, i, cfg["key"], z), (x, 20))
        d.text((x, 20 + cw + 2), f"{NAMES[i]}  " + ("FALLBACK" if fb else b.result[i]["source"]), fill=(255, 120, 120) if fb else (220, 220, 220))
        if fb:
            d.rectangle([x - 2, 18, x + cw + 1, 20 + cw + 1], outline=(255, 0, 0), width=3)
        y2 = 20 + cw + 18 + pad
        im.paste(frame_img(b.fallback, i, cfg["key"], z), (x, y2))
        d.text((x, y2 + cw + 2), f"{NAMES[i]} old", fill=(180, 180, 180))
    im.save(os.path.join(pdir, "monster_contact.png"))
    # walk-ish GIFs
    for k, mi in (("A", 0), ("B", 1)):
        fr = [frame_img(b.out, mi * 2 + a, cfg["key"], 8) for a in (0, 1)]
        fr[0].save(os.path.join(pdir, f"monster_{k}.gif"), save_all=True, append_images=fr[1:], duration=300, loop=0)
    # source sheets with row/col numbers
    from sprite_preview import _checker
    for name, sh in b.sheets.items():
        if sh.status != "ok":
            continue
        w, h = sh.size
        zz = max(1, min(6, 1500 // w))
        L, T = 30, 30
        s = Image.new("RGB", (L + w * zz + 2, T + h * zz + 2), (245, 245, 245))
        bg = _checker(w * zz, h * zz, max(2, zz * 2))
        a = sh.im.resize((w * zz, h * zz), Image.NEAREST)
        bg.paste(a, (0, 0), a)
        s.paste(bg, (L, T))
        dd = ImageDraw.Draw(s)
        dd.text((4, 4), f"{name}: {sh.label}  {w}x{h}  ({w // 32} cols x {h // 32} rows)", fill=(0, 0, 0))
        for c in range(w // 32):
            dd.text((L + c * 32 * zz + 3, T - 13), f"c{c}", fill=(0, 0, 160))
            dd.line([L + c * 32 * zz, T, L + c * 32 * zz, T + h * zz], fill=(0, 160, 0))
        for r in range(h // 32):
            dd.text((2, T + r * 32 * zz + 14), f"r{r + 1}", fill=(0, 0, 160))
        s.save(os.path.join(pdir, f"monster_source_{name}.png"))
    # alternatives (pairings to choose from)
    if cfg["alternatives"]:
        items = [("CHOSEN B", [cfg["monsters"]["B"]["frames"][i] if i < len(cfg["monsters"]["B"]["frames"]) else {"skip": True} for i in range(2)])]
        items += list(cfg["alternatives"].items())
        W2 = pad + 2 * (cw + pad) + 260
        al = Image.new("RGB", (W2, 20 + len(items) * (cw + pad)), (30, 30, 30))
        dd = ImageDraw.Draw(al)
        dd.text((pad, 4), "pairing options (anim 0, anim 1)", fill=(255, 255, 255))
        for n, (name, specs) in enumerate(items):
            y = 20 + n * (cw + pad)
            for a, sp in enumerate(specs):
                w_, st, src, why = resolve_frame(sp, b.sheets, cfg)
                if w_ is not None:
                    al.paste(frame_img(w_, 0, cfg["key"], z), (pad + a * (cw + pad), y))
            dd.text((pad + 2 * (cw + pad) + 6, y + 10), name, fill=(255, 255, 0))
        al.save(os.path.join(pdir, "monster_options.png"))
    print(f"Monster previews written to {pdir}")


def write_mem(path, words, nl):
    P.write_mem(path, words, nl)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Build mem/monster.mem from enemy sprite strips.")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--root", default=ROOT_DEFAULT)
    ap.add_argument("--config", default=None)
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)
    try:
        cfg = load_config(a.config or os.path.join(root, "sprites", "monsters.json"), root)
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
        write_mem(cfg["output"], b.out, b.nl)
        print(f"\nWrote {P.shortpath(cfg['output'])}  ({len(b.out)} words)")
    if a.preview:
        make_previews(cfg, b, root)
    return 1 if b.unreadable else 0


if __name__ == "__main__":
    sys.exit(main())
