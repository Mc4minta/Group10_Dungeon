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

---

# Map tiles (tileset) - same idea

**Source of truth:** `picture/tileset/Dungeon_Tileset.png` (copy of the pack sheet, 160x160 = 10x10 cells of 16x16)
and `sprites/tileset.json`. **Generated:** `mem/tileset.mem`. **Old art, never touched:** `mem/tileset_v1.mem`.

    python scripts/build_tileset_mem.py              # rebuild mem/tileset.mem
    python scripts/build_tileset_mem.py --preview    # + preview/tileset_*.png
    python scripts/build_tileset_mem.py --check      # only check

* The game has 3 floors x 16 tile ids (0 wall, 1 floor, 2 door, 3 boss door, 4 exit, 5 hole, 6 fence, 7 plate,
  8-10 open versions, 11 plate with box, 12-15 Simon plates). `tile_names` in the JSON lists them.
* Every 16x16 cell is scaled by exactly 2 (each pixel becomes 2x2, nearest neighbour, no smoothing) to 32x32.
* `"tiles": { "2": { "cell": [3, 6], "base": 1 } }` = tile 2 uses sheet row 3, column 6 (counted from 0). `base` = another tile id drawn
  first, so see-through pixels show the floor. A see-through cell **without** a base falls back to old art (never a hole).
* Per floor: `"floors": { "2": { "recolor": "gbr" } }` swaps colour channels so floors 2 and 3 look different
  from floor 1 (any permutation of `rgb`). `"enabled": false` = that floor uses old art. A floor may also have its own `"sheet"`.
* One tile only: `"overrides": { "f2.t5": { "cell": [7, 8] } }` or `{ "skip": true }` (old art).
* `preview/tileset_source_grid.png` = the sheet with row/column numbers (to pick cells), `preview/tileset_all_floors.png`,
  `preview/tileset_old_vs_new.png`, `preview/tileset_rooms.png` = all 13 rooms drawn with the new tiles.
* Roll back: `cp mem/tileset_v1.mem mem/tileset.mem` (or disable the floors and rebuild).
* The map layouts (`maps/*.txt`) and tile ids are not changed, only how tiles look. Rooms/doors/puzzles behave exactly as before.
* `scripts/make_placeholders.py` also rewrites `mem/tileset.mem`: do not run it any more (or rebuild afterwards).

---

# Enemies (monster.mem)

**Source of truth:** `picture/enemies/*.png` (from Enemy_Animations_Set.zip) and `sprites/monsters.json`.
**Generated:** `mem/monster.mem` (4 frames of 32x32: A0 A1 = monster A the chaser, B0 B1 = monster B the turret).
**Old art, never touched:** `mem/monster_v1.mem`.

    python scripts/build_monster_mem.py              # rebuild   (--check / --preview as before)

* Chosen: **A = skeleton1 movement, columns 1 and 4**; **B = vampire idle, columns 0 and 3** (most different skeleton from the
  player's bone-coloured ... see `preview/monster_contact.png` and `preview/monster_options.png` for the other pairings).
  A (a walker) and B (a stationary shooter) look clearly different from each other. No scaling, cells are already 32x32.
* Change a frame: edit `"monsters"` -> `"A"`/`"B"` -> `"frames"` in `monsters.json`, e.g. `{ "sheet": "skeleton2_move", "col": 3 }`
  (col counted from 0, row from 1, default row 1). Sheets are listed under `"sheets"`;
  `preview/monster_source_<name>.png` shows every sheet with row/column numbers.
* `"enabled": false` or `{ "skip": true }` = old art. Missing sheet / empty or outside cell = old art with a warning.
* Roll back: `cp mem/monster_v1.mem mem/monster.mem`. `scripts/make_placeholders.py` rewrites `mem/monster.mem`: do not run it.

---

# Bosses (boss.mem)

**Source of truth:** `picture/enemies/*.png` and `sprites/bosses.json`. **Generated:** `mem/boss.mem`
(3 bosses x 2 frames of 64x64; 8 slots, 6 used). **Old art, never touched:** `mem/boss_v1.mem`.

    python scripts/build_boss_mem.py              # rebuild   (--check / --preview as before)

* Each source cell is 32x32 and is scaled **exactly 2x** (every pixel becomes a 2x2 block, no smoothing) to 64x64.
* Chosen: boss 1 = skeleton2 idle (cols 0, 3); boss 2 = skeleton1 idle col 0, **stunned** picture = skeleton1 take_damage col 2;
  boss 3 = vampire attack (cols 4, 7). Boss 2 frame 1 is the "stunned" picture the game shows when the boss is stunned.
* The table prints colour counts per frame (8-bit -> RGB444): no colours merge, so no banding.
* The new bosses are drawn smaller inside the 64x64 box than the old placeholder blobs (about 40x40 px of art). Nothing else changes (hitbox/HP/timing untouched).
* Edit frames/`enabled`/`skip` in `bosses.json` exactly like for monsters. Roll back: `cp mem/boss_v1.mem mem/boss.mem`.
