"""Preview images for scripts/build_player_mem.py (imported by it with --preview).

Writes into preview/ :
  form<N>_contact.png     the 12 game frames of a form, labelled, fallback = red border
  form<N>_<dir>_walk.gif  walk cycle idle,A,idle,B at 8x (red border = fallback)
  all_forms.png           forms 1-4 side by side
  source_form<N>_<sheet>.png  every source sheet with row/col numbers (confirm the row convention)
  colour_form<N>.png      original vs RGB444 side by side (walk sheet)
  colour_report.txt / bbox_report.txt   numbers (also printed)
  layout_guide.png        the 4x4 sheet layout with the current mapping
"""
import os

from PIL import Image, ImageDraw

import build_player_mem as B

RED = (255, 0, 0)


def _checker(w, h, s=4):
    im = Image.new("RGB", (w, h), (70, 70, 70))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=(100, 100, 100))
    return im


def frame_image(words, i, key, zoom):
    """frame i of the ROM -> RGB image zoomed (nearest), key colour shown as checkerboard"""
    base = i * B.FRAME_WORDS
    im = _checker(B.FRAME_PX * zoom, B.FRAME_PX * zoom, max(2, zoom // 2))
    d = ImageDraw.Draw(im)
    for y in range(B.FRAME_PX):
        for x in range(B.FRAME_PX):
            c = words[base + y * B.FRAME_PX + x]
            if c == key:
                continue
            col = (((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17)
            d.rectangle([x * zoom, y * zoom, x * zoom + zoom - 1, y * zoom + zoom - 1], fill=col)
    return im


def contact_sheets(b, cfg, pdir):
    key = cfg["key"]
    zoom = 4
    cw, ch = B.FRAME_PX * zoom, B.FRAME_PX * zoom + 14
    pad = 6
    sheets = []
    for n in range(1, B.FORMS + 1):
        W = pad + 3 * (cw + pad)
        H = 18 + pad + 4 * (ch + pad)
        sheet = Image.new("RGB", (W, H), (30, 30, 30))
        d = ImageDraw.Draw(sheet)
        nfb = sum(1 for r in b.result if r["form"] == n and r["fallback"])
        d.text((pad, 4), f"form{n}  ({12 - nfb}/12 new art)", fill=(255, 255, 255))
        for dd in range(4):
            for p in range(3):
                i = B.fidx(n, dd, p)
                x = pad + p * (cw + pad)
                y = 18 + pad + dd * (ch + pad)
                sheet.paste(frame_image(b.main, i, key, zoom), (x, y))
                r = b.result[i]
                lab = f"f{n} {B.DIRS[dd]} {B.POSES[p]}"
                if not r["fallback"]:
                    lab += f"  r{r['src'][1]}c{r['src'][2]}"
                d.text((x + 1, y + B.FRAME_PX * zoom + 2), lab,
                       fill=(255, 120, 120) if r["fallback"] else (220, 220, 220))
                if r["fallback"]:
                    d.rectangle([x - 2, y - 2, x + cw + 1, y + B.FRAME_PX * zoom + 1], outline=RED, width=3)
        sheet.save(os.path.join(pdir, f"form{n}_contact.png"))
        sheets.append(sheet)
    W = sum(s.width for s in sheets)
    H = max(s.height for s in sheets)
    allim = Image.new("RGB", (W, H), (30, 30, 30))
    x = 0
    for s in sheets:
        allim.paste(s, (x, 0))
        x += s.width
    allim.save(os.path.join(pdir, "all_forms.png"))


def walk_gifs(b, cfg, pdir):
    key = cfg["key"]
    for n in range(1, B.FORMS + 1):
        for dd in range(4):
            frames = []
            for p in B.WALK_ORDER:
                i = B.fidx(n, dd, p)
                fr = frame_image(b.main, i, key, 8)
                if b.result[i]["fallback"]:
                    ImageDraw.Draw(fr).rectangle([0, 0, fr.width - 1, fr.height - 1], outline=RED, width=4)
                frames.append(fr)
            frames[0].save(os.path.join(pdir, f"form{n}_{B.DIRS[dd]}_walk.gif"), save_all=True,
                           append_images=frames[1:], duration=200, loop=0, disposal=2)


def source_sheets(b, pdir):
    """every source sheet, zoomed, with row (1-based) and column (0-based) numbers"""
    out = []
    for n in range(1, B.FORMS + 1):
        for name, sh in b.sheets[n].items():
            if sh.status != "ok":
                continue
            w, h = sh.size
            zoom = max(1, min(6, 1100 // w))
            cz = B.FRAME_PX * zoom
            L, T = 34, 34
            im = Image.new("RGB", (L + w * zoom + 4, T + h * zoom + 4), (245, 245, 245))
            bg = _checker(w * zoom, h * zoom, max(2, zoom * 2))
            art = sh.im.resize((w * zoom, h * zoom), Image.NEAREST)
            bg.paste(art, (0, 0), art)
            im.paste(bg, (L, T))
            d = ImageDraw.Draw(im)
            d.text((4, 4), f"form{n} / {name}: {sh.label}  {w}x{h}  ({w // 32} cols x {h // 32} rows)", fill=(0, 0, 0))
            for c in range(w // 32):
                d.text((L + c * cz + 4, T - 14), f"c{c}", fill=(0, 0, 160))
            for r in range(h // 32):
                d.text((4, T + r * cz + cz // 2 - 5), f"r{r + 1}", fill=(0, 0, 160))
            for c in range(w // 32 + 1):
                d.line([L + c * cz, T, L + c * cz, T + h * zoom], fill=(0, 160, 0))
            for r in range(h // 32 + 1):
                d.line([L, T + r * cz, L + w * zoom, T + r * cz], fill=(0, 160, 0))
            fn = f"source_form{n}_{name}.png"
            im.save(os.path.join(pdir, fn))
            out.append(fn)
    return out


def quantize_image(im, key, alpha):
    q = Image.new("RGBA", im.size, (0, 0, 0, 0))
    src, dst = im.load(), q.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, bl, a = src[x, y]
            if a >= alpha:
                c = B.to_rgb444(r, g, bl)
                dst[x, y] = (((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17, 255)
    return q


def colour_report(b, cfg, pdir):
    lines = ["Colour report (opaque pixels only; alpha threshold %d)" % cfg["alpha"],
             f"{'form':<5}{'sheet':<10}{'file':<26}{'8-bit colours':>14}{'RGB444 colours':>16}{'merged':>8}{'semi-px':>9}"]
    for n in range(1, B.FORMS + 1):
        for name, sh in b.sheets[n].items():
            if sh.status != "ok":
                continue
            cols = set()
            semi = 0
            for cnt, (r, g, bl, a) in sh.im.getcolors(maxcolors=1 << 24):
                if a >= cfg["alpha"]:
                    cols.add((r, g, bl))
                    if a < 255:
                        semi += cnt
            q = {B.to_rgb444(*c) for c in cols}
            lines.append(f"{n:<5}{name:<10}{sh.label:<26}{len(cols):>14}{len(q):>16}{len(cols) - len(q):>8}{semi:>9}")
        sh = b.sheets[n].get("walk")
        if sh is not None and sh.status == "ok":
            qi = quantize_image(sh.im, cfg["key"], cfg["alpha"])
            z = 3
            w, h = sh.size
            im = Image.new("RGB", (w * z * 2 + 30, h * z + 24), (30, 30, 30))
            d = ImageDraw.Draw(im)
            d.text((6, 4), f"form{n} walk: original (left)   RGB444 (right)", fill=(255, 255, 255))
            for k, src in enumerate((sh.im, qi)):
                bg = _checker(w * z, h * z, 6)
                a = src.resize((w * z, h * z), Image.NEAREST)
                bg.paste(a, (0, 0), a)
                im.paste(bg, (k * (w * z + 30), 22))
            im.save(os.path.join(pdir, f"colour_form{n}.png"))
    txt = "\n".join(lines)
    with open(os.path.join(pdir, "colour_report.txt"), "w", encoding="utf-8") as f:
        f.write(txt + "\n")
    return txt


def bbox_report(b, cfg, pdir):
    """opaque bounding box per sheet and per cell (cell coordinates 0..31), flags art outside pixels 4-27"""
    lines = [f"Opaque bounding boxes (alpha >= {cfg['alpha']}); hitbox area = pixels {B.HIT_LO}-{B.HIT_HI} of each 32x32 cell"]
    for n in range(1, B.FORMS + 1):
        for name, sh in b.sheets[n].items():
            if sh.status != "ok":
                continue
            w, h = sh.size
            a = sh.im.getchannel("A").point(lambda v: 255 if v >= cfg["alpha"] else 0)
            sb = a.getbbox()
            x0 = y0 = 99
            x1 = y1 = -1
            ncell = nout = 0
            for r in range(h // 32):
                for c in range(w // 32):
                    cb = a.crop((c * 32, r * 32, c * 32 + 32, r * 32 + 32)).getbbox()
                    if cb is None:
                        continue
                    ncell += 1
                    x0, y0, x1, y1 = min(x0, cb[0]), min(y0, cb[1]), max(x1, cb[2] - 1), max(y1, cb[3] - 1)
                    if cb[0] < B.HIT_LO or cb[1] < B.HIT_LO or cb[2] - 1 > B.HIT_HI or cb[3] - 1 > B.HIT_HI:
                        nout += 1
            verdict = "inside hitbox area" if nout == 0 else f"{nout}/{ncell} cells have art outside 4-27"
            lines.append(f"form{n} {name:<9} sheet bbox (x0,y0,x1,y1)={sb}  in-cell extent x {x0}-{x1}, y {y0}-{y1}  -> {verdict}")
    txt = "\n".join(lines)
    with open(os.path.join(pdir, "bbox_report.txt"), "w", encoding="utf-8") as f:
        f.write(txt + "\n")
    return txt


def layout_guide(cfg, pdir):
    cs, left, top = 120, 150, 70
    im = Image.new("RGB", (left + 4 * cs + 20, top + 4 * cs + 150), (245, 245, 245))
    d = ImageDraw.Draw(im)
    d.text((10, 8), "Sheet layout: 128x128 PNG = 4x4 cells of 32x32 (rows 1-4, columns 0-3)", fill=(0, 0, 0))
    d.text((10, 24), "Blue cells are USED by the game (walk sheet). Grey cells are ignored.", fill=(0, 0, 0))
    tags = {}
    for dname, r in cfg["dir_row"].items():
        for pname, cands in cfg["pose"].items():
            for sname, c in cands[-1:]:         # last candidate = the walk sheet column
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
            d.rectangle([x0 + 44, y0 + 44, x0 + 75, y0 + 75], outline=(150, 150, 150))
            d.text((x0 + 4, y0 + 4), f"row{r} col{c}", fill=(0, 0, 0))
            for k, t in enumerate(tags.get((r, c), [])):
                d.text((x0 + 4, y0 + 18 + k * 12), t, fill=(0, 0, 160))
    y = top + 4 * cs + 10
    for ln in ("Game frames: dir = down/up/left/right, pose = idle/A/B. Walk cycle = idle, A, idle, B.",
               "Form 1 idle pose comes from Idle.png column 0 of the same row (16 columns, only column 0 is used).",
               "Edit sprites/sprites.json -> mapping to change which cell is used.",
               "Missing/empty cell = old art (player_v1.mem). Keep art inside pixels 4-27 (hitbox area).",
               "Transparent PNG pixels become key colour F0F."):
        d.text((10, y), ln, fill=(0, 0, 0))
        y += 14
    im.save(os.path.join(pdir, "layout_guide.png"))


def make_previews(b, cfg, root):
    pdir = os.path.join(root, "preview")
    os.makedirs(pdir, exist_ok=True)
    contact_sheets(b, cfg, pdir)
    walk_gifs(b, cfg, pdir)
    srcs = source_sheets(b, pdir)
    print("\n" + colour_report(b, cfg, pdir))
    print("\n" + bbox_report(b, cfg, pdir))
    layout_guide(cfg, pdir)
    print(f"\nPreviews written to {pdir}  ({len(srcs)} labelled source sheets, 4 contact sheets, 16 GIFs, all_forms.png)")
