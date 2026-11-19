# Player sprites - how to change the art

**Source of truth:** `picture/form1.png ... form4.png` and `sprites/sprites.json`.
**Generated (do not edit by hand):** `mem/player.mem`.
**Old art, never touched:** `mem/player_v1.mem` (used for anything that is missing).

## Rebuild with one command

    python scripts/build_player_mem.py              # rebuild mem/player.mem
    python scripts/build_player_mem.py --preview    # rebuild + pictures in preview/
    python scripts/build_player_mem.py --check      # only check, write nothing
    scripts/update_sprites.sh                       # (Windows: scripts\update_sprites.bat)
                                                    #  build + preview + iverilog sprite test + summary

The game **always** builds. Art that is missing, empty or the wrong size is replaced by the
old art and a `WARNING ... FALLBACK` line is printed (also in the table, and with a red border in the previews).
Only a broken config file or an unreadable PNG gives a non-zero exit code.

## Where to put the PNGs

Drop them in `picture/` with these names (overwrite the old file):

| form | file |
|------|------|
| 1 | `picture/form1.png` |
| 2 | `picture/form2.png` |
| 3 | `picture/form3.png` |
| 4 | `picture/form4.png` (does not exist yet = form 4 uses old art) |

Transparent PNG pixels (alpha < 128) become the "see-through" colour `F0F`. No resizing is ever done:
one cell = exactly 32x32 pixels. Colours are rounded to the nearest of 16 levels per channel (RGB444).

## Sheet layout (see `preview/layout_guide.png`)

A sheet is 4 columns x 4 rows of 32x32 cells = **128x128**. Each row is one walk cycle of 4 frames (left to right):

| row | what |
|-----|------|
| 1 | front, facing Right |
| 2 | front, facing Left |
| 3 | back, facing Right |
| 4 | back, facing Left |

Rows are counted **1-4**, columns **0-3**.
The game has 3 poses per direction. By default: idle = column 0, step A = column 1, step B = column 3
(column 2 is the second "idle" of the walk cycle and is not used yet).
Game direction -> row: down = row 1, up = row 3, left = row 2, right = row 1.

A bigger sheet (any multiple of 32) is fine, extra cells are ignored. A smaller sheet is fine too:
only the cells that do not exist fall back. A size that is not a multiple of 32 makes the whole form fall back.

## Things you edit (all in `sprites/sprites.json`)

* **Turn a form off / on:** `"forms"` -> `"2"` -> `"enabled": false` (whole form uses old art).
* **Another file name for a form:** change its `"png"` path.
* **Frame looks in the wrong direction:** change `"mapping"` -> `"dir_row"`, e.g. swap `"left": 2` and `"right": 1` ...
  or fix just one frame with an override.
* **Use another column for a pose:** `"mapping"` -> `"pose_col"`, e.g. `"B": 2`.
* **Fix one frame only** (row, column): `"overrides": { "form2.left.A": [2, 2] }`
* **Use old art for one frame:** `"overrides": { "form3.up.B": { "skip": true } }`
  (names are `form1-4 . down/up/left/right . idle/A/B`).

## Check for fallbacks

Run `python scripts/build_player_mem.py --check`. Every frame is listed:
`form2.left.A   form2.png row2 col1   ok` or `FALLBACK (reason)`.
Reasons: file missing, wrong size (it tells you the size it found), cell fully transparent, config skip, form disabled.
The last lines show per form: all new art / all OLD art / n of 12.

## Roll back to the old art

* Whole game: `cp mem/player_v1.mem mem/player.mem` (or set every form to `"enabled": false` and rebuild).
* One form: set its `"enabled": false` and rebuild.
* An earlier version of your art/config: `git checkout <commit> -- picture sprites/sprites.json` then rebuild.

## Git note

`mem/player.mem` is **generated**: commit it (the FPGA flow reads it) but never edit it by hand - run the build.
`picture/*.png` and `sprites/sprites.json` are the source of truth. A pre-commit hook may run
`python scripts/build_player_mem.py --check` and `python tests/test_sprite_pipeline.py` to catch a stale `mem/player.mem`
(the test `test_mem_is_up_to_date` fails if you changed art and forgot to rebuild).
Do not run `scripts/make_placeholders.py` after this: it rewrites `mem/player.mem` with placeholder art
(just run the build again to fix it; `mem/player_v1.mem` is unaffected).

## Good to know

* RGB444 has only 16 levels per colour: smooth gradients show banding. Use flat colours.
* The hitbox is pixels 4-27 of the 32x32 frame. Art outside that area is allowed (the table prints a note), but it
  does not count for collisions.
* Nothing here changes the frame count (still 48 x 1024 words), so BRAM use and the Verilog are unchanged.
