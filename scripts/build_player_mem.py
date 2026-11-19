#!/usr/bin/env python3
"""Build mem/player.mem from sprite sheets (config: sprites/sprites.json).

    python scripts/build_player_mem.py              build mem/player.mem
    python scripts/build_player_mem.py --check      validate only, write nothing
    python scripts/build_player_mem.py --preview    build + write preview/*.png / *.gif

Rule 1: the build never fails because art is missing. Any frame whose source is missing,
fully transparent, too small, skipped or unreadable is copied from the old art
(mem/player_v1.mem) and a warning is printed. Output is always exactly
48 frames x 1024 words (frame = form*12 + dir*3 + pose), so no Verilog change is needed.

Exit code: 0 ok (fallbacks are fine) | 1 unreadable art file (build still written) |
           2 bad config / bad fallback file (nothing written).
"""
import argparse
import json
import os
import re
import shutil
import sys

try:
    from PIL import Image
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

# expected sheet sizes (pixels) per sheet kind. Other sizes only give a NOTE
# (or a per-cell fallback if a needed cell lies outside the sheet).
EXPECTED = {"walk": (128, 128), "attack": (128, 128), "dmg": (128, 128), "jump": (128, 128),
            "idle": (512, 128), "charged": (192, 96), "soul_die": (384, 32), "spin_die": (384, 32)}

# animation ROMs (Phase B, form 1 only): sheet kind, per direction?, columns used, frames reserved per direction (stride), file
ANIMS = {
    "idle":   {"sheet": "idle",   "per_dir": True,  "cols": 16, "stride": 16, "file": "player_idle.mem"},
    "attack": {"sheet": "attack", "per_dir": True,  "cols": 4,  "stride": 4,  "file": "player_attack.mem"},
    "hurt":   {"sheet": "dmg",    "per_dir": True,  "cols": 4,  "stride": 4,  "file": "player_hurt.mem"},
    "die":    {"sheet": None,     "per_dir": False, "cols": 12, "stride": 16, "file": "player_die.mem"},
}

ROOT_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class ConfigError(Exception):
    pass


_ROOT = [os.getcwd()]


def shortpath(p):
    """path relative to the project root when possible (never raises, e.g. other drive)"""
    try:
        r = os.path.relpath(p, _ROOT[0])
        return r if not r.startswith("..") else p
    except ValueError:
        return p


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


def _int(v, lo, hi, what):
    if not isinstance(v, int) or isinstance(v, bool) or not lo <= v <= hi:
        raise ConfigError(f"{what} must be an integer {lo}..{hi}, got {v!r}")
    return v


def _candidates(v, what):
    """[["idle",0],["walk",0]] -> [("idle",0),("walk",0)]"""
    if not isinstance(v, list) or not v:
        raise ConfigError(f'{what} must be a list like [["walk", 1]]')
    out = []
    for c in v:
        if not (isinstance(c, list) and len(c) == 2 and isinstance(c[0], str)):
            raise ConfigError(f"{what}: each entry must be [sheet_name, column], got {c!r}")
        out.append((c[0], _int(c[1], 0, 63, f"{what} column")))
    return out


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
    cfg["alpha"] = _int(raw.get("alpha_threshold", 128), 1, 255, "alpha_threshold")
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
        sheets = e.get("sheets", {})
        if not isinstance(sheets, dict) or not all(isinstance(v, str) for v in sheets.values()):
            raise ConfigError(f'forms."{n}".sheets must map a sheet name to a PNG path')
        enabled = e.get("enabled", True)
        if not isinstance(enabled, bool):
            raise ConfigError(f'forms."{n}".enabled must be true or false')
        scale = _int(e.get("scale", 1), 1, 4, f'forms."{n}".scale')
        tint = e.get("tint")
        if tint is not None and not isinstance(tint, str):
            raise ConfigError(f'forms."{n}".tint must be the name of an entry in "tints"')
        forms[n] = {"cell": cell, "enabled": enabled, "scale": scale, "tint": tint,
                    "sheets": {k: v for k, v in sheets.items() if not k.startswith("_")}}
    cfg["forms"] = forms
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
    for n in forms:
        if forms[n]["tint"] is not None and forms[n]["tint"] not in tints:
            raise ConfigError(f'forms."{n}".tint = "{forms[n]["tint"]}" is not defined in "tints"')

    m = raw.get("mapping", {})
    dir_row = {"down": 1, "up": 3, "left": 2, "right": 1}
    dir_row.update(m.get("dir_row", {}))
    for nm, v in dir_row.items():
        if nm not in DIRS:
            raise ConfigError(f'mapping.dir_row: unknown direction "{nm}" (valid: {", ".join(DIRS)})')
        _int(v, 1, 64, f"mapping.dir_row.{nm}")
    pose = {"idle": [["idle", 0], ["walk", 0]], "A": [["walk", 1]], "B": [["walk", 3]]}
    pose.update(m.get("pose", {}))
    cfg["dir_row"] = dir_row
    cfg["pose"] = {}
    for nm, v in pose.items():
        if nm not in POSES:
            raise ConfigError(f'mapping.pose: unknown pose "{nm}" (valid: {", ".join(POSES)})')
        cfg["pose"][nm] = _candidates(v, f"mapping.pose.{nm}")

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
        if isinstance(v, list) and len(v) == 2:
            v = {"row": v[0], "col": v[1]}
        if not isinstance(v, dict) or (not v.get("skip") and not ("row" in v and "col" in v)):
            raise ConfigError(f'override "{k}": use [row, col], {{"sheet":"walk","row":2,"col":1}} or {{"skip": true}}')
        if v.get("skip"):
            ov[key] = {"skip": True}
        else:
            ov[key] = {"sheet": v.get("sheet", "walk"), "row": _int(v["row"], 1, 64, f'override "{k}" row'),
                       "col": _int(v["col"], 0, 63, f'override "{k}" col')}
    cfg["overrides"] = ov

    an = raw.get("animations", {})
    if not isinstance(an, dict):
        raise ConfigError('"animations" must be an object')
    a = {}
    for fl in ("idle_anim", "attack_anim", "hurt_anim", "death_anim"):
        v = an.get(fl, False)
        if not isinstance(v, bool):
            raise ConfigError(f"animations.{fl} must be true or false, got {v!r}")
        a[fl] = v
    ds = an.get("death_sheet", "soul_die")
    if ds not in ("soul_die", "spin_die"):
        raise ConfigError('animations.death_sheet must be "soul_die" or "spin_die"')
    a["death_sheet"] = ds
    a["idle_step"] = _int(an.get("idle_step_frames", 6), 1, 60, "animations.idle_step_frames")
    a["hurt_step"] = _int(an.get("hurt_step_frames", 4), 1, 16, "animations.hurt_step_frames")
    a["death_step"] = _int(an.get("death_step_frames", 6), 1, 30, "animations.death_step_frames")
    cfg["anim"] = a
    cfg["cfg_vh"] = os.path.join(root, raw.get("verilog_cfg", "rtl/sprite_cfg.vh"))
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

    def __init__(self, kind, path):
        self.kind = kind
        self.path = path
        self.im = None
        self.size = None
        self.status = "ok"
        self.detail = ""
        self.label = os.path.basename(path)
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
        exp = EXPECTED.get(kind)
        exps = f"{exp[0]}x{exp[1]}" if exp else "a multiple of 32"
        if w % FRAME_PX or h % FRAME_PX or w < FRAME_PX or h < FRAME_PX:
            self.status = "badsize"
            self.detail = f"wrong size {w}x{h} ({self.label}): must be a multiple of {FRAME_PX}, expected {exps}"

    def cell(self, row1, col):
        """-> ('ok', cell_image) or ('fail', reason)"""
        if self.status != "ok":
            return "fail", self.detail
        w, h = self.size
        x, y = col * FRAME_PX, (row1 - 1) * FRAME_PX
        if x + FRAME_PX > w or y + FRAME_PX > h:
            exp = EXPECTED.get(self.kind)
            return "fail", (f"{self.label} is {w}x{h}" + (f" (expected {exp[0]}x{exp[1]})" if exp else "")
                            + f", cell row{row1} col{col} is outside it")
        return "ok", self.im.crop((x, y, x + FRAME_PX, y + FRAME_PX))


def apply_tint(im, tint, black_keep=40):
    """Recolour an RGBA image by luminance: near-black outlines stay dark, everything else is a ramp from tint["dark"]
    to tint["light"]. Alpha is untouched, so the shape / transparency never changes."""
    out = im.copy()
    px = out.load()
    d, l = tint["dark"], tint["light"]
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if lum < black_keep:
                px[x, y] = (int(d[0] * 0.25), int(d[1] * 0.25), int(d[2] * 0.25), a)
            else:
                t = (lum - black_keep) / (255 - black_keep)
                px[x, y] = (int(d[0] + (l[0] - d[0]) * t + 0.5), int(d[1] + (l[1] - d[1]) * t + 0.5),
                            int(d[2] + (l[2] - d[2]) * t + 0.5), a)
    return out


def to_rgb444(r, g, b):
    return (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)


def convert_cell(cell, key, alpha_thr, scale=1):
    """RGBA 32x32 -> (list of 1024 RGB444 ints, stats). Nearest colour, no smoothing.
    scale > 1: exact integer upscale about the cell centre (each source pixel becomes scale x scale pixels,
    destination = scale*(p - 16) + 16). Pixels that would land outside the 32x32 frame are cut off and counted in stats["clipped"]."""
    px = cell.load()
    out = [key] * FRAME_WORDS
    opaque = outside = nudged = semi = clipped = 0
    for y in range(FRAME_PX):
        for x in range(FRAME_PX):
            r, g, b, a = px[x, y]
            if a < alpha_thr:
                continue
            if a < 255:
                semi += 1
            c = to_rgb444(r, g, b)
            if c == key:                       # real art must not turn into the key colour
                c = key ^ 0x001
                nudged += 1
            opaque += 1
            for dy in range(scale):
                for dx in range(scale):
                    X = scale * (x - 16) + 16 + dx
                    Y = scale * (y - 16) + 16 + dy
                    if not (0 <= X < FRAME_PX and 0 <= Y < FRAME_PX):
                        clipped += 1
                        continue
                    out[Y * FRAME_PX + X] = c
                    if not (HIT_LO <= X <= HIT_HI and HIT_LO <= Y <= HIT_HI):
                        outside += 1
    return out, {"opaque": opaque, "outside": outside, "nudged": nudged, "semi": semi, "clipped": clipped}


def get_cell_words(sheet, row, col, cfg, scale=1):
    """-> (words|None, stats|None, reason|None)"""
    st, res = sheet.cell(row, col)
    if st == "fail":
        return None, None, res
    words, stats = convert_cell(res, cfg["key"], cfg["alpha"], scale)
    if stats["opaque"] == 0:
        return None, None, f"{sheet.label} row{row} col{col} fully transparent"
    return words, stats, None


# ---------------------------------------------------------------- build
class Build:
    pass


def load_sheets(cfg, root):
    """-> sheets[form][name] = Sheet, unreadable list, NOTE lines"""
    sheets, unreadable, notes = {}, [], []
    clean_dir = os.path.join(root, "picture", "_clean")
    for n in range(1, FORMS + 1):
        fc = cfg["forms"][n]
        sheets[n] = {}
        if not fc["enabled"]:
            continue
        for name, rel in fc["sheets"].items():
            p = os.path.join(root, rel)
            sh = Sheet(name, p)
            if fc.get("tint") and sh.status == "ok":
                sh.im = apply_tint(sh.im, cfg["tints"][fc["tint"]])
                sh.label += f" ({fc['tint']})"
            sheets[n][name] = sh
            if sh.status == "unreadable":
                unreadable.append(sh.detail)
            elif sh.status == "ok":
                w, h = sh.size
                exp = EXPECTED.get(name)
                if exp and (w, h) != exp:
                    notes.append(f"form{n} {name}: {sh.label} is {w}x{h} (expected {exp[0]}x{exp[1]})")
                base = os.path.basename(rel)
                if re.search(r"\.png\.[A-Za-z]+$", base, re.I):
                    # odd double extension: write a clean copy (original is never renamed)
                    try:
                        os.makedirs(clean_dir, exist_ok=True)
                        dst = os.path.join(clean_dir, f"form{n}_{name}.png")
                        shutil.copyfile(p, dst)
                        notes.append(f"form{n} {name}: odd file name {base} -> clean copy "
                                     f"picture/_clean/form{n}_{name}.png (original untouched)")
                    except OSError:
                        pass
    return sheets, unreadable, notes


def build_main(cfg, sheets, fallback):
    """48-frame main ROM. -> (words, result list)"""
    out = [0] * (TOTAL_FRAMES * FRAME_WORDS)
    result = []
    for n in range(1, FORMS + 1):
        fc = cfg["forms"][n]
        for d in range(4):
            for p in range(3):
                i = fidx(n, d, p)
                base = i * FRAME_WORDS
                info = {"idx": i, "name": fname(n, d, p), "form": n, "dir": d, "pose": p,
                        "source": None, "fallback": None, "stats": None, "notes": [], "src": None}
                ov = cfg["overrides"].get((n, d, p))
                words = None
                if not fc["enabled"]:
                    info["fallback"] = "form disabled in config"
                elif not fc["sheets"]:
                    info["fallback"] = "no art configured for this form"
                elif ov and ov.get("skip"):
                    info["fallback"] = "config skip"
                else:
                    if ov:
                        cands, row = [(ov["sheet"], ov["col"])], ov["row"]
                    else:
                        cands, row = cfg["pose"][POSES[p]], cfg["dir_row"][DIRS[d]]
                    reasons, unconf = [], []
                    for sname, col in cands:
                        sh = sheets[n].get(sname)
                        if sh is None:                       # sheet not listed for this form: just try the next candidate
                            unconf.append(f"sheet '{sname}' not configured for form{n}")
                            continue
                        w, stats, why = get_cell_words(sh, row, col, cfg, fc["scale"])
                        if w is None:
                            reasons.append(why)
                            continue
                        words = w
                        info["stats"] = stats
                        info["source"] = f"{sh.label} r{row} c{col}" + (f" x{fc['scale']}" if fc["scale"] > 1 else "")
                        info["src"] = (sname, row, col)
                        if reasons:
                            info["notes"].append("used after: " + "; ".join(reasons))
                        break
                    if words is None:
                        info["fallback"] = "; ".join(dict.fromkeys(reasons or unconf))
                if words is None:
                    words = fallback[base:base + FRAME_WORDS]
                out[base:base + FRAME_WORDS] = words
                result.append(info)
    return out, result


def build_anim(name, cfg, sheets, main_words):
    """Animation ROM for FORM 1 (Human). Layout: per-direction ROMs = ((dir * stride) + k) frames, die ROM = k frames (16 reserved).
    Missing / empty / outside cells fall back to the form-1 walk-idle frame of that direction (main ROM).
    -> (words, result list of dict(dir, k, fallback|None))"""
    a = ANIMS[name]
    fc = cfg["forms"][1]
    kind = cfg["anim"]["death_sheet"] if name == "die" else a["sheet"]
    sh = sheets[1].get(kind) if fc["enabled"] else None
    words, res = [], []
    for d in range(4 if a["per_dir"] else 1):
        row = cfg["dir_row"][DIRS[d]] if a["per_dir"] else 1
        fb = main_words[fidx(1, d, 0) * FRAME_WORDS:(fidx(1, d, 0) + 1) * FRAME_WORDS]
        for k in range(a["stride"]):
            if k >= a["cols"]:
                words.extend([cfg["key"]] * FRAME_WORDS)          # reserved, never shown
                continue
            if not fc["enabled"]:
                w, why = None, "form disabled in config"
            elif sh is None:
                w, why = None, "no '" + kind + "' sheet configured for form 1"
            else:
                w, _, why = get_cell_words(sh, row, k, cfg, fc["scale"])
                if w is None and name == "die" and why and why.endswith("fully transparent"):
                    w, why = [cfg["key"]] * FRAME_WORDS, None        # an empty frame is a valid death frame (the soul has left)
            if w is None:
                w = fb
            words.extend(w)
            res.append({"dir": d, "k": k, "fallback": why})
    return words, res


def make_cfg_vh(cfg):
    a = cfg["anim"]

    def b(v):
        return "1" if v else "0"

    return "\n".join([
        "// GENERATED by scripts/build_player_mem.py from sprites/sprites.json - do not edit by hand.",
        "// Visual-only animation switches (all 0 = exactly the 48-frame main ROM behaviour, no extra BRAM).",
        "localparam IDLE_ANIM_EN   = " + b(a["idle_anim"]) + ";",
        "localparam ATTACK_ANIM_EN = " + b(a["attack_anim"]) + ";",
        "localparam HURT_ANIM_EN   = " + b(a["hurt_anim"]) + ";",
        "localparam DEATH_ANIM_EN  = " + b(a["death_anim"]) + ";",
        "localparam IDLE_STEP      = " + str(a["idle_step"]) + ";     // game frames per idle animation step (16 frames per loop)",
        "localparam HURT_STEP      = " + str(a["hurt_step"]) + ";     // game frames per hurt picture (4 pictures)",
        "localparam DEATH_STEP     = " + str(a["death_step"]) + ";     // game frames per death picture (12 pictures, last one is held)",
        ""])


def write_text_if_changed(path, text):
    try:
        with open(path, "r", encoding="utf-8", newline="") as f:
            if f.read() == text:
                return False
    except OSError:
        pass
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return True


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
            note = list(r["notes"])
            if s["outside"]:
                note.append(f"{s['outside']} px outside hitbox area {HIT_LO}-{HIT_HI}")
            if s["clipped"]:
                note.append(f"WARNING {s['clipped']} px CUT OFF at the frame edge (scale too big for this art)")
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
    byform = {}
    for r in result:
        if r["fallback"]:
            byform.setdefault(r["form"], []).append(r)
    for n, lst in byform.items():
        if len(lst) == 12 and len({r["fallback"] for r in lst}) == 1:
            print(f"WARNING: form{n}: all 12 frames -> FALLBACK old art: {lst[0]['fallback']}")
        else:
            for r in lst:
                print(f"WARNING: {r['name']} (frame {r['idx']}) -> FALLBACK old art: {r['fallback']}")


# ---------------------------------------------------------------- main
def run(cfg, root):
    b = Build()
    b.fallback, b.nl = read_fallback(cfg["fallback"])
    b.sheets, b.unreadable, b.notes = load_sheets(cfg, root)
    b.main, b.result = build_main(cfg, b.sheets, b.fallback)
    b.anims = {name: build_anim(name, cfg, b.sheets, b.main) for name in ANIMS}
    return b


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
        b = run(cfg, root)
    except ConfigError as e:
        print(f"ERROR: {e}")
        return 2

    previous = read_words_quiet(cfg["output"])
    for u in b.unreadable:
        print(f"ERROR: {u}  (its frames use old art)")
    for n_ in b.notes:
        print(f"NOTE: {n_}")
    warn_fallbacks(b.result)
    print()
    print_table(b.result, b.main, previous)
    assert len(b.main) == TOTAL_FRAMES * FRAME_WORDS

    flags = ", ".join(k + "=" + ("ON" if v else "off") for k, v in cfg["anim"].items() if k.endswith("_anim"))
    print("\nAnimation ROMs for form 1 (used only when the flag in sprites.json -> animations is true; now: " + flags + ")")
    for name in ANIMS:
        _, res = b.anims[name]
        bad = [r for r in res if r["fallback"]]
        state = "all new art" if not bad else (str(len(res) - len(bad)) + "/" + str(len(res)) + " new art")
        print("  mem/" + ANIMS[name]["file"] + ": " + state)
        for why in dict.fromkeys(r["fallback"] for r in bad):
            cnt = sum(1 for r in bad if r["fallback"] == why)
            print("WARNING: " + ANIMS[name]["file"] + ": " + str(cnt) + " frame(s) -> FALLBACK walk-idle frame: " + why)

    if a.check:
        print("\n--check: nothing written.")
    else:
        write_mem(cfg["output"], b.main, b.nl)
        print(f"\nWrote {shortpath(cfg['output'])}  ({len(b.main)} words)")
        mem_dir = os.path.dirname(cfg["output"])
        for name, d in ANIMS.items():
            write_mem(os.path.join(mem_dir, d["file"]), b.anims[name][0], b.nl)
            print("Wrote mem/" + d["file"] + "  (" + str(len(b.anims[name][0])) + " words)")
        if write_text_if_changed(cfg["cfg_vh"], make_cfg_vh(cfg)):
            print("Wrote " + shortpath(cfg["cfg_vh"]) + "  (animation switches changed)")
    if a.preview:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import sprite_preview
        sprite_preview.make_previews(b, cfg, root)
    return 1 if b.unreadable else 0


if __name__ == "__main__":
    sys.exit(main())
