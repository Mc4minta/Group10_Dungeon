#!/usr/bin/env python3
"""Build mem/tileset.mem (map tiles) from a sprite sheet (config: sprites/tileset.json).

    python scripts/build_tileset_mem.py              build mem/tileset.mem
    python scripts/build_tileset_mem.py --check      validate only, write nothing
    python scripts/build_tileset_mem.py --preview    build + preview/tileset_*.png

Layout (unchanged, no Verilog change): 3 floors x 16 tile ids x 32x32 RGB444 words,
address = (floor*16 + tile)*1024 + y*32 + x  ->  exactly 49152 words.
Sheet cells (default 16x16) are scaled by an exact integer factor (nearest neighbour, never smoothed).
Per floor: "gain" (brightness) and "recolor" (channel permutation); a tile spec may carry its own gain/recolor.
Rule 1: anything missing / skipped / transparent / outside the sheet falls back to the old art
(mem/tileset_v1.mem) with a warning. The build never fails because art is missing.

Exit code: 0 ok | 1 unreadable sheet (build still written, old art) | 2 bad config / bad fallback file.
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

FLOORS, TILES = 3, 16
TILE_PX = 32
TILE_WORDS = TILE_PX * TILE_PX
TOTAL_TILES = FLOORS * TILES
VARIANTS = ["top", "bottom", "left", "right", "torch"]      # wall variants (tile ids 48 + floor*5 + index)
VAR_BASE = TOTAL_TILES                                       # first variant tile index (48)
OUT_TILES_ON = 64                                            # tileset.mem tiles when wall variants are enabled (63 used + 1 spare)


def wall_variant(tx, ty, torch_xs):
    """Which wall picture a plain wall tile (id 0) at tile column tx (0..19) / row ty (0..14) uses.
    MUST match rtl/renderer.v: top row, bottom row, left column, right column; a torch on the top row at the torch columns. None = normal wall."""
    if ty == 0:
        return "torch" if tx in torch_xs else "top"
    if ty == 14:
        return "bottom"
    if tx == 0:
        return "left"
    if tx == 19:
        return "right"
    return None


def variant_tile_index(floor, name):
    return VAR_BASE + (floor - 1) * len(VARIANTS) + VARIANTS.index(name)


ROOT_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ROOT = [os.getcwd()]


class ConfigError(Exception):
    pass


def shortpath(p):
    try:
        r = os.path.relpath(p, _ROOT[0])
        return r if not r.startswith("..") else p
    except ValueError:
        return p


def tidx(floor, tile):
    """floor 1..3, tile 0..15 -> 0..47"""
    return (floor - 1) * TILES + tile


def to_rgb444(r, g, b):
    return (((r * 15 + 127) // 255) << 8) | (((g * 15 + 127) // 255) << 4) | ((b * 15 + 127) // 255)


def _int(v, lo, hi, what):
    if not isinstance(v, int) or isinstance(v, bool) or not lo <= v <= hi:
        raise ConfigError(f"{what} must be an integer {lo}..{hi}, got {v!r}")
    return v


def _spec(v, what):
    """tile spec -> dict(cell=(r,c) | skip, base=int|None)"""
    if not isinstance(v, dict):
        raise ConfigError(f'{what}: use {{"cell": [row, col], "base": 1}} or {{"skip": true}}')
    if v.get("skip"):
        return {"skip": True}
    c = v.get("cell")
    if not (isinstance(c, list) and len(c) == 2):
        raise ConfigError(f"{what}: cell must be [row, col]")
    spec = {"cell": (_int(c[0], 0, 255, f"{what} row"), _int(c[1], 0, 255, f"{what} col")), "base": None}
    if "recolor" in v:
        rc = v["recolor"]
        if not (isinstance(rc, str) and len(rc) == 3 and sorted(rc) == ["b", "g", "r"]):
            raise ConfigError(f'{what}: recolor must be a permutation of "rgb", got {rc!r}')
        spec["recolor"] = rc
    if "gain" in v:
        g = v["gain"]
        if isinstance(g, bool) or not isinstance(g, (int, float)) or not 0.25 <= g <= 4.0:
            raise ConfigError(f"{what}: gain must be a number 0.25..4.0, got {g!r}")
        spec["gain"] = float(g)
    if v.get("base") is not None:
        spec["base"] = _int(v["base"], 0, TILES - 1, f"{what} base")
    return spec


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
    cfg = {"alpha": _int(raw.get("alpha_threshold", 128), 1, 255, "alpha_threshold"),
           "fallback": os.path.join(root, raw.get("fallback_mem", "mem/tileset_v1.mem")),
           "output": os.path.join(root, raw.get("output_mem", "mem/tileset.mem")),
           "sheet": raw.get("sheet", "my_asset/tileset/Dungeon_Tileset.png")}
    cfg["cell"] = _int(raw.get("cell", 16), 1, 32, "cell")
    if TILE_PX % cfg["cell"]:
        raise ConfigError(f"cell = {cfg['cell']}: must divide 32 so the scale factor is a whole number "
                          f"(no smoothing/resizing)")
    cfg["scale"] = TILE_PX // cfg["cell"]
    if raw.get("scale", cfg["scale"]) != cfg["scale"]:
        raise ConfigError(f"scale must be {cfg['scale']} for cell {cfg['cell']} (32 / cell)")
    fl = raw.get("floors", {})
    cfg["floors"] = {}
    for k in fl:
        if k not in ("1", "2", "3"):
            raise ConfigError(f'unknown floor "{k}" (valid: 1,2,3)')
    for n in range(1, FLOORS + 1):
        e = fl.get(str(n), {})
        if not isinstance(e, dict):
            raise ConfigError(f'floors."{n}" must be an object')
        rc = e.get("recolor", "rgb")
        if not (isinstance(rc, str) and len(rc) == 3 and sorted(rc) == ["b", "g", "r"]):
            raise ConfigError(f'floors."{n}".recolor must be a permutation of "rgb" (e.g. "rgb", "bgr", "gbr"), got {rc!r}')
        en = e.get("enabled", True)
        if not isinstance(en, bool):
            raise ConfigError(f'floors."{n}".enabled must be true or false')
        gain = e.get("gain", 1.0)
        if isinstance(gain, bool) or not isinstance(gain, (int, float)) or not 0.25 <= gain <= 4.0:
            raise ConfigError(f'floors."{n}".gain must be a number 0.25..4.0 (1.0 = unchanged), got {gain!r}')
        cfg["floors"][n] = {"enabled": en, "recolor": rc, "gain": float(gain), "sheet": e.get("sheet", cfg["sheet"])}
    tiles = {}
    for k, v in raw.get("tiles", {}).items():
        if k.startswith("_"):
            continue
        if not (k.isdigit() and 0 <= int(k) < TILES):
            raise ConfigError(f'tiles key "{k}" must be a tile id 0..15')
        tiles[int(k)] = _spec(v, f'tiles."{k}"')
    cfg["tiles"] = tiles
    ov = {}
    for k, v in raw.get("overrides", {}).items():
        if k.startswith("_"):
            continue
        import re
        m = re.fullmatch(r"f([1-3])\.t(\d{1,2})", k)
        if not m or int(m.group(2)) >= TILES:
            raise ConfigError(f'override key "{k}" must look like f2.t5 (floor 1-3, tile 0-15)')
        ov[(int(m.group(1)), int(m.group(2)))] = _spec(v, f'override "{k}"')
    cfg["overrides"] = ov
    cfg["names"] = {int(k): v for k, v in raw.get("tile_names", {}).items() if k.isdigit()}
    wv = raw.get("wall_variants", {})
    if not isinstance(wv, dict):
        raise ConfigError('"wall_variants" must be an object')
    en = wv.get("enabled", False)
    if not isinstance(en, bool):
        raise ConfigError("wall_variants.enabled must be true or false")
    tx = wv.get("torch_x", [4, 15])
    if not (isinstance(tx, list) and all(isinstance(q, int) and not isinstance(q, bool) and 0 <= q <= 19 for q in tx)):
        raise ConfigError("wall_variants.torch_x must be a list of tile columns 0..19")
    vt = {}
    for name, v in wv.get("tiles", {}).items():
        if name.startswith("_"):
            continue
        if name not in VARIANTS:
            raise ConfigError(f'wall_variants.tiles: unknown variant "{name}" (valid: {", ".join(VARIANTS)})')
        bname = None
        if isinstance(v, dict) and isinstance(v.get("base"), str):
            bname = v["base"]
            if bname not in VARIANTS or bname == name:
                raise ConfigError(f'wall_variants.tiles."{name}".base must be another variant name or a tile id')
            v = {k: q for k, q in v.items() if k != "base"}
        sp = _spec(v, f'wall_variants.tiles."{name}"')
        sp["base_name"] = bname
        vt[name] = sp
    cfg["wall_var"] = {"enabled": en, "torch_x": tx, "tiles": vt}
    cfg["cfg_vh"] = os.path.join(root, raw.get("verilog_cfg", "rtl/tileset_cfg.vh"))
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
    if len(words) != TOTAL_TILES * TILE_WORDS:
        raise ConfigError(f"{path}: has {len(words)} words, expected {TOTAL_TILES * TILE_WORDS}")
    return words, nl


class SheetFile:
    def __init__(self, path):
        self.path, self.im, self.status, self.detail = path, None, "ok", ""
        self.label = os.path.basename(path)
        if not os.path.isfile(path):
            self.status, self.detail = "missing", f"file missing: {shortpath(path)}"
            return
        try:
            with Image.open(path) as im:
                im.load()
                self.im = im.convert("RGBA")
        except Exception as e:
            self.status, self.detail = "unreadable", f"cannot read {shortpath(path)}: {e}"

    def cell(self, row, col, cs):
        if self.status != "ok":
            return None, self.detail
        w, h = self.im.size
        x, y = col * cs, row * cs
        if x + cs > w or y + cs > h:
            return None, f"{self.label} is {w}x{h}, cell row{row} col{col} ({cs}x{cs}) is outside it"
        return self.im.crop((x, y, x + cs, y + cs)), None


def cell_words(cell, scale, recolor, alpha, base_words, gain=1.0):
    """RGBA cell -> 1024 RGB444 words (exact integer upscale). Transparent pixels show base_words.
    -> (words | None if fully transparent, opaque pixel count)"""
    cs = cell.width
    px = cell.load()
    idx = {"r": 0, "g": 1, "b": 2}
    perm = [idx[c] for c in recolor]
    out = list(base_words) if base_words is not None else [None] * TILE_WORDS
    opaque = 0
    for y in range(cs):
        for x in range(cs):
            r, g, b, a = px[x, y]
            if a < alpha:
                continue
            opaque += 1
            ch = tuple(min(255, int(v * gain + 0.5)) for v in (r, g, b))
            c = to_rgb444(ch[perm[0]], ch[perm[1]], ch[perm[2]])
            for dy in range(scale):
                for dx in range(scale):
                    out[(y * scale + dy) * TILE_PX + x * scale + dx] = c
    if opaque == 0:
        return None, 0
    return out, opaque


class Build:
    pass


def build(cfg, root):
    b = Build()
    b.fallback, b.nl = read_fallback(cfg["fallback"])
    b.sheets, b.unreadable = {}, []
    for n in range(1, FLOORS + 1):
        fc = cfg["floors"][n]
        p = os.path.join(root, fc["sheet"])
        if p not in b.sheets:
            sh = SheetFile(p)
            b.sheets[p] = sh
            if sh.status == "unreadable":
                b.unreadable.append(sh.detail)
    out_tiles = OUT_TILES_ON if cfg["wall_var"]["enabled"] else TOTAL_TILES
    b.out = [0] * (out_tiles * TILE_WORDS)
    b.result = {}
    for n in range(1, FLOORS + 1):
        fc = cfg["floors"][n]
        sheet = b.sheets[os.path.join(root, fc["sheet"])]
        done = {}

        def resolve(t, stack=()):
            if t in done:
                return done[t]
            info = {"floor": n, "tile": t, "source": None, "fallback": None, "words": None}
            i = tidx(n, t)
            old = b.fallback[i * TILE_WORDS:(i + 1) * TILE_WORDS]
            spec = cfg["overrides"].get((n, t)) or cfg["tiles"].get(t)
            if not fc["enabled"]:
                info["fallback"] = "floor disabled in config"
            elif spec is None:
                info["fallback"] = "tile not configured"
            elif spec.get("skip"):
                info["fallback"] = "config skip"
            else:
                base = None
                bt = spec["base"]
                if bt is not None and bt != t and bt not in stack:
                    base = resolve(bt, stack + (t,))["words"]
                elif bt is not None:
                    info["fallback"] = f"base tile {bt} loops back to tile {t}"
                if info["fallback"] is None:
                    cell, why = sheet.cell(spec["cell"][0], spec["cell"][1], cfg["cell"])
                    if cell is None:
                        info["fallback"] = why
                    else:
                        w, opq = cell_words(cell, cfg["scale"], spec.get("recolor", fc["recolor"]), cfg["alpha"], base, spec.get("gain", fc["gain"]))
                        if w is None:
                            info["fallback"] = f"{sheet.label} row{spec['cell'][0]} col{spec['cell'][1]} fully transparent"
                        elif any(v is None for v in w):
                            info["fallback"] = (f"{sheet.label} row{spec['cell'][0]} col{spec['cell'][1]} has see-through "
                                                f"pixels but no \"base\" tile (set \"base\": 1)")
                        else:
                            info["words"] = w
                            info["source"] = f"r{spec['cell'][0]} c{spec['cell'][1]}" + (f" + base {bt}" if bt is not None else "")
            if info["words"] is None:
                info["words"] = old
            done[t] = info
            b.out[i * TILE_WORDS:(i + 1) * TILE_WORDS] = info["words"]
            b.result[(n, t)] = info
            return info

        for t in range(TILES):
            resolve(t)
    b.var_result = {}
    if cfg["wall_var"]["enabled"]:
        for n in range(1, FLOORS + 1):
            fc = cfg["floors"][n]
            sheet = b.sheets[os.path.join(root, fc["sheet"])]
            wall = b.out[tidx(n, 0) * TILE_WORDS:(tidx(n, 0) + 1) * TILE_WORDS]
            made = {}
            for name in VARIANTS:                            # "top" must come before "torch" (torch sits on the top wall)
                spec = cfg["wall_var"]["tiles"].get(name)
                info = {"floor": n, "name": name, "source": None, "fallback": None}
                words = None
                if not fc["enabled"]:
                    info["fallback"] = "floor disabled in config"
                elif spec is None:
                    info["fallback"] = "variant not configured"
                elif spec.get("skip"):
                    info["fallback"] = "config skip"
                else:
                    base = None
                    if spec.get("base_name"):
                        base = made.get(spec["base_name"])
                    elif spec.get("base") is not None:
                        base = b.out[tidx(n, spec["base"]) * TILE_WORDS:(tidx(n, spec["base"]) + 1) * TILE_WORDS]
                    cell, why = sheet.cell(spec["cell"][0], spec["cell"][1], cfg["cell"])
                    if cell is None:
                        info["fallback"] = why
                    else:
                        w, _ = cell_words(cell, cfg["scale"], spec.get("recolor", fc["recolor"]), cfg["alpha"], base, spec.get("gain", fc["gain"]))
                        if w is None:
                            info["fallback"] = f"{sheet.label} row{spec['cell'][0]} col{spec['cell'][1]} fully transparent"
                        elif any(v is None for v in w):
                            info["fallback"] = (f"{sheet.label} row{spec['cell'][0]} col{spec['cell'][1]} has see-through pixels but no \"base\"")
                        else:
                            words = w
                            info["source"] = f"r{spec['cell'][0]} c{spec['cell'][1]}"
                if words is None:
                    words = wall                              # fallback = the plain wall of that floor (same as before)
                made[name] = words
                i = variant_tile_index(n, name)
                b.out[i * TILE_WORDS:(i + 1) * TILE_WORDS] = words
                b.var_result[(n, name)] = info
        spare = OUT_TILES_ON - 1
        b.out[spare * TILE_WORDS:(spare + 1) * TILE_WORDS] = b.out[0:TILE_WORDS]
    return b


def make_cfg_vh(cfg):
    wv = cfg["wall_var"]
    tx = (wv["torch_x"] + [31, 31])[:2]                      # renderer supports 2 torch columns (31 = none)
    return "\n".join([
        "// GENERATED by scripts/build_tileset_mem.py from sprites/tileset.json - do not edit by hand.",
        "// Wall variants are chosen by tile position in rtl/renderer.v (top / bottom / left / right edge + torches on the top row).",
        "localparam WALL_VAR_EN    = " + ("1" if wv["enabled"] else "0") + ";",
        "localparam TILESET_WORDS  = " + str((OUT_TILES_ON if wv["enabled"] else TOTAL_TILES) * TILE_WORDS) + ";",
        "localparam [4:0] TORCH_X0 = 5'd" + str(tx[0]) + ";",
        "localparam [4:0] TORCH_X1 = 5'd" + str(tx[1]) + ";",
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
        with open(path) as f:
            return [int(x, 16) for x in f.read().split()]
    except (OSError, ValueError):
        return None


def report(cfg, b, previous):
    names = cfg["names"]
    for n in range(1, FLOORS + 1):
        fb = [b.result[(n, t)] for t in range(TILES) if b.result[(n, t)]["fallback"]]
        if len(fb) == TILES and len({r["fallback"] for r in fb}) == 1:
            print(f"WARNING: floor {n}: all 16 tiles -> FALLBACK old art: {fb[0]['fallback']}")
        else:
            for r in fb:
                print(f"WARNING: floor {n} tile {r['tile']} ({names.get(r['tile'], '?')}) -> FALLBACK old art: {r['fallback']}")
    print(f"\n{'idx':>3} {'floor':>5} {'tile':>4}  {'name':<20} {'source':<18} status")
    for n in range(1, FLOORS + 1):
        for t in range(TILES):
            r = b.result[(n, t)]
            st = f"FALLBACK ({r['fallback']})" if r["fallback"] else "ok"
            print(f"{tidx(n, t):>3} {n:>5} {t:>4}  {names.get(t, ''):<20} {(r['source'] or 'old art (tileset_v1)'):<18} {st}")
    for (n, name), r in b.var_result.items():
        if r["fallback"]:
            print(f"WARNING: wall variant '{name}' floor {n} -> FALLBACK plain wall: {r['fallback']}")
    if b.var_result:
        print("\nWall variants (chosen by tile position in the renderer): " + ", ".join(
            f"floor{n}.{name}={'ok' if not r['fallback'] else 'FALLBACK'}" for (n, name), r in b.var_result.items()))
    nfb = sum(1 for r in b.result.values() if r["fallback"])
    print(f"\nSummary: {TOTAL_TILES - nfb} new-art tiles, {nfb} fallback tiles (old art)")
    for n in range(1, FLOORS + 1):
        k = sum(1 for t in range(TILES) if b.result[(n, t)]["fallback"])
        print(f"  floor {n}: " + ("all new art" if k == 0 else "all OLD art" if k == TILES else f"{TILES - k}/16 new art, {k} old"))
    if previous is not None and len(previous) == len(b.out):
        ch = [i for i in range(TOTAL_TILES) if previous[i * TILE_WORDS:(i + 1) * TILE_WORDS] != b.out[i * TILE_WORDS:(i + 1) * TILE_WORDS]]
        print(f"Changed since previous mem/tileset.mem: {len(ch)} tile(s)" if ch else "Changed since previous mem/tileset.mem: nothing")


# ---------------------------------------------------------------- previews
def tile_img(words, i, zoom=2):
    im = Image.new("RGB", (TILE_PX, TILE_PX))
    px = im.load()
    base = i * TILE_WORDS
    for y in range(TILE_PX):
        for x in range(TILE_PX):
            c = words[base + y * TILE_PX + x]
            px[x, y] = (((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17)
    return im.resize((TILE_PX * zoom, TILE_PX * zoom), Image.NEAREST)


# floor whose art is used to draw each room (grid 0 = floors 1+2, grid 2 = floors 1+3: drawn with floor 1)
ROOM_FLOOR = [1, 3, 1, 2, 1, 1, 1, 2, 2, 2, 3, 3, 3]


def make_previews(cfg, b, root):
    pdir = os.path.join(root, "preview")
    os.makedirs(pdir, exist_ok=True)
    zoom, pad = 3, 6
    cw = TILE_PX * zoom
    names = cfg["names"]
    # (1) tileset sheet per floor: 16 tiles in 4x4, labelled, fallback = red border
    W = pad + 4 * (cw + pad)
    H = 18 + pad + 4 * (cw + 14 + pad)
    all_ = Image.new("RGB", (W * FLOORS, H), (30, 30, 30))
    for n in range(1, FLOORS + 1):
        sheet = Image.new("RGB", (W, H), (30, 30, 30))
        d = ImageDraw.Draw(sheet)
        k = sum(1 for t in range(TILES) if b.result[(n, t)]["fallback"])
        d.text((pad, 4), f"floor {n}  ({TILES - k}/16 new art)  recolor={cfg['floors'][n]['recolor']}", fill=(255, 255, 255))
        for t in range(TILES):
            x = pad + (t % 4) * (cw + pad)
            y = 18 + pad + (t // 4) * (cw + 14 + pad)
            sheet.paste(tile_img(b.out, tidx(n, t), zoom), (x, y))
            fb = b.result[(n, t)]["fallback"]
            d.text((x, y + cw + 1), f"{t} {names.get(t, '')}", fill=(255, 120, 120) if fb else (220, 220, 220))
            if fb:
                d.rectangle([x - 2, y - 2, x + cw + 1, y + cw + 1], outline=(255, 0, 0), width=3)
        sheet.save(os.path.join(pdir, f"tileset_floor{n}.png"))
        all_.paste(sheet, ((n - 1) * W, 0))
    all_.save(os.path.join(pdir, "tileset_all_floors.png"))
    # (2) old vs new
    old = Image.new("RGB", (W, H), (30, 30, 30))
    d = ImageDraw.Draw(old)
    d.text((pad, 4), "OLD art (tileset_v1.mem), floor 1", fill=(255, 255, 255))
    for t in range(TILES):
        old.paste(tile_img(b.fallback, tidx(1, t), zoom), (pad + (t % 4) * (cw + pad), 18 + pad + (t // 4) * (cw + 14 + pad)))
    cmp_ = Image.new("RGB", (W * 2, H), (30, 30, 30))
    cmp_.paste(old, (0, 0))
    cmp_.paste(Image.open(os.path.join(pdir, "tileset_floor1.png")), (W, 0))
    cmp_.save(os.path.join(pdir, "tileset_old_vs_new.png"))
    # (3) sheet with grid, row/col labelled (to pick cells)
    first = next(iter(b.sheets.values()))
    if first.status == "ok":
        z = 6
        cs = cfg["cell"]
        w, h = first.im.size
        L = T = 22
        im = Image.new("RGB", (L + w * z + 2, T + h * z + 2), (240, 240, 240))
        bg = Image.new("RGB", (w * z, h * z), (90, 90, 90))
        a = first.im.resize((w * z, h * z), Image.NEAREST)
        bg.paste(a, (0, 0), a)
        im.paste(bg, (L, T))
        d = ImageDraw.Draw(im)
        for c in range(w // cs):
            d.text((L + c * cs * z + 4, 4), f"c{c}", fill=(0, 0, 160))
            d.line([L + c * cs * z, T, L + c * cs * z, T + h * z], fill=(0, 200, 0))
        for r in range(h // cs):
            d.text((2, T + r * cs * z + 4), f"r{r}", fill=(0, 0, 160))
            d.line([L, T + r * cs * z, L + w * z, T + r * cs * z], fill=(0, 200, 0))
        im.save(os.path.join(pdir, "tileset_source_grid.png"))
    # (4) rooms drawn from mem/tilemap.mem with the new tiles (floor 1 art for rooms 0-3, 4-8 floor 2, 9-12 floor 3 if so mapped)
    try:
        with open(os.path.join(root, "mem", "tilemap.mem")) as f:
            tm = [int(x, 16) for x in f.read().split()]
    except (OSError, ValueError):
        tm = None
    if tm and len(tm) >= 13 * 300:
        zz = 1
        rooms = Image.new("RGB", (4 * (640 + 8), 4 * (480 + 8)), (30, 30, 30))
        cache = {}
        for g in range(13):
            floor = ROOM_FLOOR[g]
            room = Image.new("RGB", (640, 480))
            for ty in range(15):
                for tx in range(20):
                    t = tm[g * 300 + ty * 20 + tx]
                    vname = wall_variant(tx, ty, cfg["wall_var"]["torch_x"]) if (cfg["wall_var"]["enabled"] and t == 0) else None
                    k = (floor, t, vname)
                    if k not in cache:
                        cache[k] = tile_img(b.out, variant_tile_index(floor, vname) if vname else tidx(floor, t), 1)
                    room.paste(cache[k], (tx * 32, ty * 32))
            rooms.paste(room, ((g % 4) * 648, (g // 4) * 488))
        rooms.resize((rooms.width // 2, rooms.height // 2), Image.NEAREST).save(os.path.join(pdir, "tileset_rooms.png"))
    print(f"Tileset previews written to {pdir}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Build mem/tileset.mem from a tile sheet.")
    ap.add_argument("--check", action="store_true", help="validate only, write nothing")
    ap.add_argument("--preview", action="store_true", help="also write preview/tileset_*.png")
    ap.add_argument("--root", default=ROOT_DEFAULT)
    ap.add_argument("--config", default=None)
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)
    _ROOT[0] = root
    try:
        cfg = load_config(a.config or os.path.join(root, "sprites", "tileset.json"), root)
        b = build(cfg, root)
    except ConfigError as e:
        print(f"ERROR: {e}")
        return 2
    for u in b.unreadable:
        print(f"ERROR: {u}  (its tiles use old art)")
    previous = read_words_quiet(cfg["output"])
    report(cfg, b, previous)
    assert len(b.out) == (OUT_TILES_ON if cfg["wall_var"]["enabled"] else TOTAL_TILES) * TILE_WORDS
    if a.check:
        print("\n--check: nothing written.")
    else:
        write_mem(cfg["output"], b.out, b.nl)
        print(f"\nWrote {shortpath(cfg['output'])}  ({len(b.out)} words)")
        if write_text_if_changed(cfg["cfg_vh"], make_cfg_vh(cfg)):
            print(f"Wrote {shortpath(cfg['cfg_vh'])}  (wall variant switch changed)")
    if a.preview:
        make_previews(cfg, b, root)
    return 1 if b.unreadable else 0


if __name__ == "__main__":
    sys.exit(main())
