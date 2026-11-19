# Player sprites - how to change the art

**Source of truth:** the PNGs in `picture/` and `sprites/sprites.json`.
**Generated (do not edit by hand):** `mem/player.mem`.
**Old art, never touched:** `mem/player_v1.mem` (used for anything missing).

## Rebuild with one command

    python scripts/build_player_mem.py              # rebuild mem/player.mem
    python scripts/build_player_mem.py --preview    # rebuild + pictures in preview/
    python scripts/build_player_mem.py --check      # only check, write nothing
    scripts/update_sprites.sh                       # (Windows: scripts\update_sprites.bat)
                                                    #  build + preview + iverilog sprite test + python tests

The game **always** builds. Art that is missing, empty or the wrong size is replaced by the old art and a
`WARNING ... FALLBACK` line is printed (also in the table, and with a red border in the previews).
Only a broken config file or an unreadable PNG gives a non-zero exit code
(config/old-art file broken: exit 2, nothing written; unreadable PNG: exit 1, still builds with old art).

## Where the PNGs are (current)

| form | walk sheet | idle sheet |
|------|-----------|-----------|
| 1 Human | `picture/Character/Human/Walk.png` | `.../Human/Idle.png` (16 columns, only column 0 is used) |
| 2 Orc | `picture/Character/ORc/form2_Walk.png` | - (uses walk column 0) |
| 3 Angel | `picture/Character/Angel/Angel_walk.png.png` (build also writes a clean copy `picture/_clean/form3_walk.png`) | - |
| 4 | none yet = whole form uses old art | - |

Human also has Attack, Dmg, Jump, ChargedAttack, SoulDie, SpinDie sheets listed in `sprites.json`. They are checked and
previewed but **not used by the game yet** (they need Verilog changes - see docs/SPRITE_PLAN.md, Phase B).

Transparent PNG pixels (alpha < 128) become the see-through colour `F0F`. No resizing is ever done:
one cell = exactly 32x32 pixels. Colours are rounded to the nearest of 16 levels per channel (RGB444).

## Sheet layout (see `preview/layout_guide.png`)

A walk sheet is 4 columns x 4 rows of 32x32 cells = **128x128**. Each row is one walk cycle (left to right):

| row | what |
|-----|------|
| 1 | front, facing Right |
| 2 | front, facing Left |
| 3 | back, facing Right |
| 4 | back, facing Left (not used by the game: it has no separate "back-left") |

Rows are counted **1-4**, columns **0-3** (Idle sheet: columns 0-15).
Default mapping: game direction down = row 1, up = row 3, left = row 2, right = row 1.
Poses: idle = `Idle.png` column 0 (form 1) else Walk column 0; step A = Walk column 1; step B = Walk column 3.

A bigger sheet (any multiple of 32) is fine, extra cells are ignored. A smaller sheet is fine too: only the cells that
do not exist fall back. A size that is not a multiple of 32 makes the whole sheet unusable (its frames fall back).

## Things you edit (all in `sprites/sprites.json`)

* **Redraw a frame:** replace the PNG (same name), run the build.
* **Add form 4 art:** copy sheets into `picture/`, then put them under `"forms"` -> `"4"` -> `"sheets"`:
  `{ "walk": "picture/form4_walk.png" }` (optionally `"idle"`), run the build.
* **Turn a form off / on:** `"forms"` -> `"2"` -> `"enabled": false` (whole form uses old art).
* **Frame looks in the wrong direction:** change `"mapping"` -> `"dir_row"` (rows 1-4), e.g. swap `"left": 2` and `"right": 1`,
  or fix just one frame with an override.
* **Use another column for a pose:** `"mapping"` -> `"pose"`, a list tried in order, e.g.
  `"idle": [["idle", 0], ["walk", 0]]` means "Idle sheet column 0, else Walk column 0".
* **Fix one frame only** (row, column of the walk sheet): `"overrides": { "form2.left.A": [2, 2] }`
* **Use old art for one frame:** `"overrides": { "form3.up.B": { "skip": true } }`
  (names are `form1-4 . down/up/left/right . idle/A/B`).

## Check for fallbacks

Run `python scripts/build_player_mem.py --check`. Every frame is listed:
`form2.left.A   form2_Walk.png r2 c1   ok` or `FALLBACK (reason)`.
Reasons: file missing, wrong size (it tells you the size it found and expected), cell outside the sheet, cell fully
transparent, config skip, form disabled, no art configured. The last lines show per form: all new art / all OLD art / n of 12.
`preview/*_contact.png` shows the same with red borders; `preview/source_form*_*.png` shows every sheet with row/column numbers.

## Roll back to the old art

* Whole game: `cp mem/player_v1.mem mem/player.mem` (or set every form to `"enabled": false` and rebuild).
* One form: set its `"enabled": false` and rebuild.
* An earlier version of your art/config: `git checkout <commit> -- picture sprites/sprites.json` then rebuild.

## Git note

`mem/player.mem` is **generated**: commit it (the FPGA flow reads it) but never edit it by hand - run the build.
`picture/*.png` and `sprites/sprites.json` are the source of truth. A pre-commit hook may run
`python tests/test_sprite_pipeline.py` to catch a stale `mem/player.mem` (`test_mem_is_up_to_date` fails if you changed
art and forgot to rebuild). Do not run `scripts/make_placeholders.py` after this: it rewrites `mem/player.mem` with
placeholder art (run the build again to fix; `mem/player_v1.mem` is unaffected).

## Good to know

* RGB444 has only 16 levels per colour: gradients band. The current sheets have 6-13 colours, no merging (see `preview/colour_report.txt`).
* The hitbox is pixels 4-27 of the 32x32 frame. The table prints a note when art goes outside it (`preview/bbox_report.txt`).
* Nothing here changes the frame count (still 48 x 1024 words), so BRAM use and the Verilog are unchanged.
