#!/usr/bin/env python3
"""Build mem/player.mem from sprite sheets (config: sprites/sprites.json).

    python scripts/build_player_mem.py              build mem/player.mem
    python scripts/build_player_mem.py --check      validate only, write nothing
    python scripts/build_player_mem.py --preview    build + write preview/*.png / *.gif

Rule: the build never fails because art is missing. Any frame whose source is missing,
fully transparent, too small, skipped or unreadable is copied from the old art
(mem/player_v1.mem) and a warning is printed. Output is always exactly
48 frames x 1024 words (frame = form*12 + dir*3 + pose), so no Verilog change is needed.

Exit code: 0 ok (fallbacks are fine) | 1 unreadable art file (build still written) |
           2 bad config / bad fallback file (nothing written).
"""
import argparse
import json
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    print("ERROR: Pillow is required (pip install pillow)")
    sys.exit(2)

FORMS = 4
DIRS = ["down", "up", "left", "right"]          # game dir index 0..3
POSES = ["idle", "A", "B"]                       # game pose index 0..2
FRAME_PX = 32
FRAME_WORDS = FRAME_PX * FRAME_PX
TOTAL_FRAMES = FORMS * len(DIRS) * len(POSES)    # 48
HIT_LO, HIT_HI = 4, 27                           # hitbox area (inclusive)
WALK_ORDER = [0, 1, 0, 2]                        # idle, A, idle, B

ROOT_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class ConfigError(Exception):
    pass


def shortpath(p):
    """path relative to the project root when possible (never raises, e.g. other drive)"""
    try:
        r = os.path.relpath(p, _ROOT[0])
        return r if not r.startswith("..") else p
    except ValueError:
        return p


_ROOT = [os.getcwd()]


def fidx(form, d, pose):
    """form 1..4, d 0..3, pose 0..2 -> frame number 0..47"""
    return (form - 1) * 12 + d * 3 + pose


def fname(form, d, pose):
    return f"form{form}.{DIRS[d]}.{POSES[pose]}"


# ---------------------------------------------------------------- config
def parse_color(s):
    s = str(s).strip().lstrip("#")
    if len(s) != 3:
        raise ConfigError(f"key_color must be 3 hex digits like F0F, got {s!r}")
    try:
        return int(s, 16)
    except ValueError:
        raise ConfigError(f"key_color is not hex: {s!r}")


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

    cfg = {"key": parse_color(raw.get("key_color", "F0F"))}
    a = raw.get("alpha_threshold", 128)
    if not isinstance(a, int) or not 1 <= a <= 255:
        raise ConfigError("alpha_threshold must be an integer 1..255")
    cfg["alpha"] = a
    cfg["fallback"] = os.path.join(root, raw.get("fallback_mem", "mem/player_v1.mem"))
    cfg["output"] = os.path.join(root, raw.get("output_mem", "mem/player.mem"))

    forms = {}
    fr = raw.get("forms", {})
    if not isinstance(fr, dict):
        raise ConfigError('"forms" must be an object')
    for k in fr:
        if k not in ("1", "2", "3", "4"):
            raise ConfigError(f'unknown form "{k}" (valid: 1,2,3,4)')
    for n in range(1, FORMS + 1):
        e = fr.get(str(n), {})
        if not isinstance(e, dict):
            raise ConfigError(f'forms."{n}" must be an object')
        cell = e.get("cell", 32)
        if cell != FRAME_PX:
            raise ConfigError(
                f'forms."{n}".cell = {cell!r}: only 32 is supported (game frames are 32x32 and '
                f"nearest-neighbour only, no silent resize)")
        enabled = e.get("enabled", True)
        if not isinstance(enabled, bool):
            raise ConfigError(f'forms."{n}".enabled must be true or false')
        forms[n] = {"png": e.get("png", f"picture/form{n}.png"), "cell": cell, "enabled": enabled}
    cfg["forms"] = forms

    m = raw.get("mapping", {})
    dir_row = {"down": 1, "up": 3, "left": 2, "right": 1}
    pose_col = {"idle": 0, "A": 1, "B": 3}
    for key, default, names, lo, hi in (("dir_row", dir_row, DIRS, 1, 4), ("pose_col", pose_col, POSES, 0, 3)):
        got = dict(default)
        got.update(m.get(key, {}))
        for nm in got:
            if nm not in names:
                raise ConfigError(f'mapping.{key}: unknown name "{nm}" (valid: {", ".join(names)})')
            v = got[nm]
            if not isinstance(v, int) or isinstance(v, bool) or not lo <= v <= hi:
                raise ConfigError(f"mapping.{key}.{nm} must be an integer {lo}..{hi}, got {v!r}")
        cfg[key] = got

    ov = {}
    for k, v in raw.get("overrides", {}).items():
        if k.startswith("_"):
            continue
        parts = k.split(".")
        if len(parts) != 3 or not parts[0].startswith("form") or parts[0][4:] not in ("1", "2", "3", "4") \
                or parts[1] not in DIRS or parts[2] not in POSES:
            raise ConfigError(f'override key "{k}" must look like form2.left.A '
                              f"(form1-4 . {'/'.join(DIRS)} . {'/'.join(POSES)})")
        key = (int(parts[0][4:]), DIRS.index(parts[1]), POSES.index(parts[2]))
        if isinstance(v, list):
            v = {"row": v[0], "col": v[1]} if len(v) == 2 else None
        if not isinstance(v, dict) or (not v.get("skip") and not ("row" in v and "col" in v)):
            raise ConfigError(f'override "{k}": use [row, col] or {{"skip": true}}')
        if v.get("skip"):
            ov[key] = {"skip": True}
        else:
            r, c = v["row"], v["col"]
            if not (isinstance(r, int) and isinstance(c, int) and r >= 1 and c >= 0):
                raise ConfigError(f'override "{k}": row must be >= 1 and col >= 0, got [{r}, {c}]')
            ov[key] = {"row": r, "col": c}
    cfg["overrides"] = ov
    return cfg


# ---------------------------------------------------------------- fallback ROM
def read_fallback(path):
    """-> (list of 49152 ints, newline string). Raises ConfigError if unusable."""
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
    if len(words) != TOTAL_FRAMES * FRAME_WORDS:
        raise ConfigError(f"{path}: has {len(words)} words, expected {TOTAL_FRAMES * FRAME_WORDS} "
                          f"({TOTAL_FRAMES} frames x {FRAME_WORDS})")
    return words, nl


# ---------------------------------------------------------------- sheets
class Sheet:
    """Loaded PNG. status: 'ok' | 'missing' | 'unreadable' | 'badsize'"""

    def __init__(self, path):
        self.path = path
        self.im = None
        self.size = None
        self.status = "ok"
        self.detail = ""
        if not os.path.isfile(path):
            self.status, self.detail = "missing", f"file missing: {shortpath(path)}"
            return
        try:
            with Image.open(path) as im:
                im.load()
                self.im = im.convert("RGBA")
        except Exception as e:  # corrupt / not an image
            self.status, self.detail = "unreadable", f"cannot read {shortpath(path)}: {e}"
            return
        self.size = self.im.size
        w, h = self.size
        if w % FRAME_PX or h % FRAME_PX or w < FRAME_PX or h < FRAME_PX:
            self.status = "badsize"
            self.detail = (f"wrong size {w}x{h}: must be a multiple of {FRAME_PX} "
                           f"(expected 128x128 = 4x4 cells of 32x32)")

    def cell(self, row1, col):
        """-> ('ok', cell_image) or ('fail', reason)"""
        if self.status != "ok":
            return "fail", self.detail
        w, h = self.size
        x, y = col * FRAME_PX, (row1 - 1) * FRAME_PX
        if x + FRAME_PX > w or y + FRAME_PX > h:
            return "fail", (f"sheet is {w}x{h} (expected 128x128), cell row{row1} col{col} "
                            f"is outside it")
        return "ok", self.im.crop((x, y, x + FRAME_PX, y + FRAME_PX))


def convert_cell(cell, key, alpha_thr):
    """RGBA 32x32 -> (list of 1024 RGB444 ints, stats). Nearest colour, no resize."""
    px = cell.load()
    out = []
    opaque = outside = nudged = semi = 0
    for y in range(FRAME_PX):
        for x in range(FRAME_PX):
            r, g, b, a = px[x, y]
            if a < alpha_thr:
                out.append(key)
                continue
            if a < 255:
                semi += 1
            c = (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)
            if c == key:                       # real art must not turn into the key colour
                c = key ^ 0x001
                nudged += 1
            out.append(c)
            opaque += 1
            if not (HIT_LO <= x <= HIT_HI and HIT_LO <= y <= HIT_HI):
                outside += 1
    return out, {"opaque": opaque, "outside": outside, "nudged": nudged, "semi": semi}


# ---------------------------------------------------------------- build
def build(cfg, root):
    fallback, nl = read_fallback(cfg["fallback"])
    sheets = {}
    result = []          # per frame dict
    out = [0] * (TOTAL_FRAMES * FRAME_WORDS)
    unreadable = []
    extra_notes = []

    for n in range(1, FORMS + 1):
        fc = cfg["forms"][n]
        if fc["enabled"]:
            sh = Sheet(os.path.join(root, fc["png"]))
            sheets[n] = sh
            if sh.status == "unreadable":
                unreadable.append(sh.detail)
            elif sh.status == "ok":
                w, h = sh.size
                if (w, h) != (128, 128):
                    extra_notes.append(
                        f"form{n}: sheet is {w}x{h} (expected 128x128); "
                        f"{'cells outside 4x4 are ignored' if w >= 128 and h >= 128 else 'missing cells fall back'}")

    for n in range(1, FORMS + 1):
        for d in range(4):
            for p in range(3):
                i = fidx(n, d, p)
                name = fname(n, d, p)
                base = i * FRAME_WORDS
                ov = cfg["overrides"].get((n, d, p))
                row = cfg["dir_row"][DIRS[d]]
                col = cfg["pose_col"][POSES[p]]
                if ov and not ov.get("skip"):
                    row, col = ov["row"], ov["col"]
                info = {"idx": i, "name": name, "form": n, "dir": d, "pose": p,
                        "source": None, "fallback": None, "stats": None}
                reason = None
                words = None
                if not cfg["forms"][n]["enabled"]:
                    reason = "form disabled in config"
                elif ov and ov.get("skip"):
                    reason = "config skip"
                else:
                    st, res = sheets[n].cell(row, col)
                    if st == "fail":
                        reason = res
                    else:
                        words, stats = convert_cell(res, cfg["key"], cfg["alpha"])
                        if stats["opaque"] == 0:
                            reason, words = f"cell row{row} col{col} fully transparent", None
                        else:
                            info["stats"] = stats
                            info["source"] = f"{os.path.basename(cfg['forms'][n]['png'])} row{row} col{col}"
                if words is None:
                    words = fallback[base:base + FRAME_WORDS]
                    info["fallback"] = reason
                out[base:base + FRAME_WORDS] = words
                result.append(info)
    return out, result, nl, unreadable, extra_notes, fallback


def write_mem(path, words, nl):
    tmp = path + ".tmp"
    with open(tmp, "w", newline="") as f:
        f.write("".join(f"{w:03x}{nl}" for w in words))
    os.replace(tmp, path)


def read_words_quiet(path):
    try:
        with open(path, "r") as f:
            return [int(x, 16) for x in f.read().split()]
    except (OSError, ValueError):
        return None


# ---------------------------------------------------------------- reporting
def print_table(result, out_words, previous):
    print(f"{'frame':>5}  {'name':<18} {'source':<28} status")
    for r in result:
        if r["fallback"]:
            print(f"{r['idx']:>5}  {r['name']:<18} {'old art (player_v1)':<28} FALLBACK ({r['fallback']})")
        else:
            s = r["stats"]
            note = []
            if s["outside"]:
                note.append(f"{s['outside']} px outside hitbox area {HIT_LO}-{HIT_HI}")
            if s["nudged"]:
                note.append(f"{s['nudged']} px nudged off key colour")
            if s["semi"]:
                note.append(f"{s['semi']} semi-transparent px")
            print(f"{r['idx']:>5}  {r['name']:<18} {r['source']:<28} ok" + (f"  [{'; '.join(note)}]" if note else ""))
    nfb = sum(1 for r in result if r["fallback"])
    print(f"\nSummary: {TOTAL_FRAMES - nfb} new-art frames, {nfb} fallback frames (old art)")
    for n in range(1, FORMS + 1):
        fr = [r for r in result if r["form"] == n]
        k = sum(1 for r in fr if r["fallback"])
        state = "all new art" if k == 0 else ("all OLD art" if k == 12 else f"{12 - k}/12 new art, {k} old")
        print(f"  form{n}: {state}")
    if previous is not None and len(previous) == len(out_words):
        changed = [i for i in range(TOTAL_FRAMES)
                   if previous[i * FRAME_WORDS:(i + 1) * FRAME_WORDS] != out_words[i * FRAME_WORDS:(i + 1) * FRAME_WORDS]]
        if changed:
            print(f"Changed since previous mem/player.mem: {len(changed)} frame(s): "
                  + ", ".join(result[i]["name"] for i in changed))
        else:
            print("Changed since previous mem/player.mem: nothing")
    return nfb


def warn_fallbacks(result):
    for r in result:
        if r["fallback"]:
            print(f"WARNING: {r['name']} (frame {r['idx']}) -> FALLBACK old art: {r['fallback']}")


# ---------------------------------------------------------------- previews
def _checker(w, h, s=4):
    im = Image.new("RGB", (w, h), (70, 70, 70))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=(100, 100, 100))
    return im


def frame_image(words, i, key, zoom):
    """frame i -> RGB image zoomed (nearest), key colour shown as checkerboard"""
    base = i * FRAME_WORDS
    im = _checker(FRAME_PX * zoom, FRAME_PX * zoom, max(2, zoom // 2))
    d = ImageDraw.Draw(im)
    for y in range(FRAME_PX):
        for x in range(FRAME_PX):
            c = words[base + y * FRAME_PX + x]
            if c == key:
                continue
            col = (((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17)
            d.rectangle([x * zoom, y * zoom, x * zoom + zoom - 1, y * zoom + zoom - 1], fill=col)
    return im


def make_previews(words, result, cfg, root):
    pdir = os.path.join(root, "preview")
    os.makedirs(pdir, exist_ok=True)
    key = cfg["key"]
    zoom = 4
    cw, ch = FRAME_PX * zoom, FRAME_PX * zoom + 14
    pad = 6
    sheets = []
    for n in range(1, FORMS + 1):
        W = pad + 3 * (cw + pad)
        H = 18 + pad + 4 * (ch + pad)
        sheet = Image.new("RGB", (W, H), (30, 30, 30))
        d = ImageDraw.Draw(sheet)
        nfb = sum(1 for r in result if r["form"] == n and r["fallback"])
        d.text((pad, 4), f"form{n}  ({12 - nfb}/12 new art)", fill=(255, 255, 255))
        for dd in range(4):
            for p in range(3):
                i = fidx(n, dd, p)
                x = pad + p * (cw + pad)
                y = 18 + pad + dd * (ch + pad)
                sheet.paste(frame_image(words, i, key, zoom), (x, y))
                fb = result[i]["fallback"]
                d.text((x + 1, y + FRAME_PX * zoom + 2), f"f{n} {DIRS[dd]} {POSES[p]}",
                       fill=(255, 120, 120) if fb else (220, 220, 220))
                if fb:
                    d.rectangle([x - 2, y - 2, x + cw + 1, y + FRAME_PX * zoom + 1], outline=(255, 0, 0), width=3)
        sheet.save(os.path.join(pdir, f"form{n}_contact.png"))
        sheets.append(sheet)
    # all forms side by side
    W = sum(s.width for s in sheets)
    H = max(s.height for s in sheets)
    allim = Image.new("RGB", (W, H), (30, 30, 30))
    x = 0
    for s in sheets:
        allim.paste(s, (x, 0))
        x += s.width
    allim.save(os.path.join(pdir, "all_forms.png"))
    # walk GIFs (idle, A, idle, B), 8x
    for n in range(1, FORMS + 1):
        for dd in range(4):
            frames = []
            for p in WALK_ORDER:
                i = fidx(n, dd, p)
                fr = frame_image(words, i, key, 8)
                if result[i]["fallback"]:
                    ImageDraw.Draw(fr).rectangle([0, 0, fr.width - 1, fr.height - 1], outline=(255, 0, 0), width=4)
                frames.append(fr)
            frames[0].save(os.path.join(pdir, f"form{n}_{DIRS[dd]}_walk.gif"), save_all=True,
                           append_images=frames[1:], duration=200, loop=0, disposal=2)
    make_layout_guide(cfg, root)
    print(f"Previews written to {pdir}")


def make_layout_guide(cfg, root):
    pdir = os.path.join(root, "preview")
    os.makedirs(pdir, exist_ok=True)
    cs, left, top = 120, 150, 70
    im = Image.new("RGB", (left + 4 * cs + 20, top + 4 * cs + 150), (245, 245, 245))
    d = ImageDraw.Draw(im)
    d.text((10, 8), "Sheet layout: 128x128 PNG = 4x4 cells of 32x32 (rows 1-4, columns 0-3)", fill=(0, 0, 0))
    d.text((10, 24), "Cells with a coloured tag are USED by the game. Grey cells are ignored.", fill=(0, 0, 0))
    tags = {}
    for dname, r in cfg["dir_row"].items():
        for pname, c in cfg["pose_col"].items():
            tags.setdefault((r, c), []).append(f"{dname}/{pname}")
    rowdesc = {1: "row 1: front, facing RIGHT", 2: "row 2: front, facing LEFT",
               3: "row 3: back, facing RIGHT", 4: "row 4: back, facing LEFT"}
    for c in range(4):
        d.text((left + c * cs + 8, top - 18), f"col {c}  (walk {c + 1})", fill=(0, 0, 0))
    for r in range(1, 5):
        d.text((6, top + (r - 1) * cs + 50), rowdesc[r], fill=(0, 0, 0))
        for c in range(4):
            x0, y0 = left + c * cs, top + (r - 1) * cs
            used = (r, c) in tags
            d.rectangle([x0, y0, x0 + cs - 1, y0 + cs - 1], fill=(200, 230, 255) if used else (215, 215, 215),
                        outline=(0, 0, 0))
            d.rectangle([x0 + 44, y0 + 44, x0 + 75, y0 + 75], outline=(150, 150, 150))   # a 32x32 cell
            d.text((x0 + 4, y0 + 4), f"row{r} col{c}", fill=(0, 0, 0))
            for k, t in enumerate(tags.get((r, c), [])):
                d.text((x0 + 4, y0 + 18 + k * 12), t, fill=(0, 0, 160))
    y = top + 4 * cs + 10
    for ln in ("Game frames: dir = down/up/left/right, pose = idle/A/B. Walk cycle = idle, A, idle, B.",
               "Edit sprites/sprites.json -> mapping to change which cell is used.",
               "Form 1-4 = picture/form1.png ... form4.png.  Missing/empty cell = old art (player_v1.mem).",
               "Keep art inside pixels 4-27 of each cell (that is the hitbox area).",
               "Transparent background = transparent PNG pixels (they become key colour F0F)."):
        d.text((10, y), ln, fill=(0, 0, 0))
        y += 14
    im.save(os.path.join(pdir, "layout_guide.png"))


# ---------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description="Build mem/player.mem from sprite sheets.")
    ap.add_argument("--check", action="store_true", help="validate only, do not write mem/player.mem")
    ap.add_argument("--preview", action="store_true", help="also write preview/ images and GIFs")
    ap.add_argument("--root", default=ROOT_DEFAULT, help="project root (default: repo root)")
    ap.add_argument("--config", default=None, help="config file (default: <root>/sprites/sprites.json)")
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)
    _ROOT[0] = root
    cfg_path = a.config or os.path.join(root, "sprites", "sprites.json")
    try:
        cfg = load_config(cfg_path, root)
        out, result, nl, unreadable, notes, _ = build(cfg, root)
    except ConfigError as e:
        print(f"ERROR: {e}")
        return 2

    previous = read_words_quiet(cfg["output"])
    for u in unreadable:
        print(f"ERROR: {u}  (its frames use old art)")
    for n_ in notes:
        print(f"NOTE: {n_}")
    warn_fallbacks(result)
    print()
    print_table(result, out, previous)
    assert len(out) == TOTAL_FRAMES * FRAME_WORDS

    if a.check:
        print("\n--check: nothing written.")
    else:
        write_mem(cfg["output"], out, nl)
        print(f"\nWrote {cfg['output']}  ({len(out)} words)")
    if a.preview:
        make_previews(out, result, cfg, root)
    return 1 if unreadable else 0


if __name__ == "__main__":
    sys.exit(main())
