# Sprite Pipeline - Implementation Plan (DRAFT, for your edit + approval)

How to use this file: edit anything, tick `[x]` on items you approve, change the **Decision** lines, then tell me "approved".
Nothing below is merged to `main`. Work happens on branches `sprite-pipeline` (done, uncommitted) and `sprite-zip` (next).

Status legend: DONE = exists in working tree, TODO = not started, ASK = needs your decision.

---

## 0. Ground rules (apply to every phase)

- [ ] **Rule 1** - the game must ALWAYS build and run. Missing / transparent / invalid / wrong-size art falls back to old art with a printed WARNING. Never crash, never scramble, never smooth-resize.
- [ ] **No game-logic change**: stats, hitbox, speed, HP, weapons, timing, FSM transitions stay as they are. Only what is drawn changes.
- [ ] `mem/player_v1.mem` (copy of the original `player.mem`) is never edited. `my_asset/*` originals are never overwritten or renamed.
- [ ] `mem/*.mem` and `rtl/sprite_cfg.vh` are **generated**. Source of truth = PNGs + `sprites/sprites.json`.
- [ ] Do not merge to `main`. Tag `main` as `pre-sprite-zip` before any merge. I wait for your "merge".

---

## 1. Inputs received

| Input | Where | What it is | Use for |
|---|---|---|---|
| `Character.zip` (extracted to `my_asset/Character/`) | Human/, ORc/, Angel/ | Player art, 32x32 cells | Forms 1-3 (the player) |
| `Enemy_Animations_Set.zip` | `my_asset/` | skeleton1, skeleton2, vampire strips, 32x32 frames, 1 row each | Monsters (and maybe bosses) |
| `2D Pixel Dungeon Asset Pack v2.0.zip` | `my_asset/` | 16x16 tileset, items, traps, arrow, UI | Bullet, puzzle items, tileset (optional) |

Sheet facts verified by loading the PNGs (all match your description):

| File | Size | Grid | Colours (8-bit, opaque) |
|---|---|---|---|
| Human/Walk.png | 128x128 | 4x4 | 7 |
| Human/Attack.png | 128x128 | 4x4 | 10 |
| Human/Dmg.png | 128x128 | 4x4 | 10 |
| Human/Jump.png | 128x128 | 4x4 | 6 |
| Human/Idle.png | 512x128 | 16x4 | 6 |
| Human/ChargedAttack.png | 192x96 | 6x3 | 13 |
| Human/SoulDie.png | 384x32 | 12x1 | 38 (379 semi-transparent px) |
| Human/SpinDie.png | 384x32 | 12x1 | 9 |
| ORc/form2_Walk.png | 128x128 | 4x4 | 7 |
| Angel/Angel_walk.png.png | 128x128 | 4x4 | 9 |

Notes
- `Angel_walk.c.c` is a Piskel C export: ignored.
- `Angel_walk.png.png`: build reads it in place and writes a clean copy `my_asset/_clean/form3_walk.png` (original untouched).
- `SoulDie.png` has semi-transparent pixels. Plan: alpha < 128 = transparent, otherwise opaque (alpha threshold is in config). Possible fringe, will be checked in screenshots.
- Row convention (your guess): row1 front-Right, row2 front-Left, row3 back-Right, row4 back-Left. **Not verified yet** - Phase A produces labelled sheets so you can confirm.

---

## 2. Phase A - Player: walk + idle, no Verilog change (mandatory)

### 2.1 Deliverables
| # | Item | Status |
|---|---|---|
| A1 | `sprites/sprites.json` (per-form sheets, cell size, enabled, mapping, overrides, key colour F0F) | v1 DONE, **needs v2 rewrite for multi-sheet** |
| A2 | `scripts/build_player_mem.py` (`--check`, `--preview`, `--verbose`) writes `mem/player.mem`: exactly 48 x 1024 words | v1 DONE, **v2 rewrite TODO** |
| A3 | `scripts/sprite_preview.py`: previews | TODO (v1 previews exist inside the build script) |
| A4 | `mem/player_v1.mem` backup | DONE |
| A5 | `scripts/update_sprites.sh` / `.bat` | DONE (will extend) |
| A6 | `sprites/README.md` plain-words guide + `preview/layout_guide.png` | DONE (will update) |
| A7 | `tests/test_sprite_pipeline.py` + `sim/tb_sprites.v` (+ `run_sim.sh sprites`) | DONE (will update to v2 config) |

### 2.2 Config shape (sprites.json v2) - edit freely
```json
"forms": {
  "1": { "enabled": true,  "sheets": { "walk": "my_asset/Character/Human/Walk.png",
                                       "idle": "my_asset/Character/Human/Idle.png",
                                       "attack": ".../Attack.png", "dmg": ".../Dmg.png",
                                       "soul_die": ".../SoulDie.png", "spin_die": ".../SpinDie.png",
                                       "jump": ".../Jump.png", "charged": ".../ChargedAttack.png" } },
  "2": { "enabled": true,  "sheets": { "walk": "my_asset/Character/ORc/form2_Walk.png" } },
  "3": { "enabled": true,  "sheets": { "walk": "my_asset/Character/Angel/Angel_walk.png.png" } },
  "4": { "enabled": true,  "sheets": { } }          // no art yet -> whole form = old art
},
"mapping": {
  "dir_row": { "down": 1, "up": 3, "left": 2, "right": 1 },       // rows 1-4
  "pose": { "idle": [["idle",0],["walk",0]],                      // try Idle.png col 0, else Walk col 0
            "A":    [["walk",1]],
            "B":    [["walk",3]] }
},
"overrides": { "form2.left.A": {"sheet":"walk","row":2,"col":1},  "form3.up.B": {"skip": true} }
```
- Candidate lists give the fallback chain per pose (new idle -> walk col 0 -> old art).
- Cell size must be 32 (config error otherwise: no silent resize).
- Sheet of any size multiple of 32: extra cells ignored, missing cells fall back individually. Not a multiple of 32: that sheet is unusable, its frames fall back (message shows found vs expected size).

### 2.3 Fallback table (printed by the build and by `--check`)
Per form/dir/pose: source cell (`Walk.png r1 c1`) or `FALLBACK (reason)`.
Reasons: file missing, wrong size (found vs expected), cell outside sheet, cell fully transparent, config skip, form disabled, no art configured.
Exit codes: 0 ok (fallbacks are fine), 1 unreadable PNG (still builds, uses old art), 2 bad config / bad `player_v1.mem` (nothing written).

### 2.4 Previews (`preview/`)
- [ ] `form1..4_contact.png` - 12 game frames, labelled form/dir/pose, fallback = red border
- [ ] `form<N>_<dir>_walk.gif` - idle,A,idle,B at 8x (16 GIFs)
- [ ] `all_forms.png` - forms 1-4 side by side
- [ ] `source_<form>_<sheet>.png` - **every source sheet with row/col numbers** (to confirm the row convention)
- [ ] `colour_form<N>.png` - original vs RGB444 side by side; colour count per sheet printed (before / after quantizing)
- [ ] Angel report: opaque bounding box, per-cell min/max x,y, and whether it leaves hitbox area pixels 4-27 (art is not changed)

Decision A-1 (pose columns): idle <- Idle.png col 0 (form 1) else Walk col 0; A <- Walk col 1; B <- Walk col 3 (Walk col 2 unused).
Your choice: ______ (keep / change)

Decision A-2 (row 4 "back facing Left"): game has only 4 directions, so row 4 is **unused** by the default mapping (up uses row 3). Alternatives: keep unused / swap up to row 4 / mirror in a later Verilog change.
Your choice: ______

---

## 3. Phase B - extra animations (default OFF)

Only starts after Phase A passes every check. Four flags in `sprites.json -> animations`, all default `false`:
`idle_anim`, `attack_anim`, `hurt_anim`, `death_anim` (+ `death_sheet`: `soul_die` | `spin_die`).
Flag off = exactly Phase A (generated `rtl/sprite_cfg.vh` sets `*_ANIM_EN = 0`, and ROMs are not even instantiated, so zero BRAM).

### 3.1 Where each state is known (from reading the RTL; I will re-verify before editing)
| State | Signal | Where | Notes |
|---|---|---|---|
| frame picked today | `pframe = form*12 + facing*3 + pose` | `top.v:267` -> `renderer.v` stage 1 `r1_paddr`, ROM `player_rom` stage 2 | 4-clock renderer pipeline |
| moving / idle | `moving = dxs[1] \| dys[1]` (internal) | `player.v:85` | I add an **output port** only, no logic change |
| melee swing | `melee_on`, `melee_dir` | `objects.v:621` (`melee_cnt`, `MELEE_FRAMES = 8`, cooldown 20) | form 1 always, forms 2-4 only if an enemy is in the box |
| hurt | `invuln` (`hurt_cnt != 0`, `KB_FRAMES 8 + INV_FRAMES 60`), blink via `obj_blink` | `objects.v:606-607` | blink + knockback unchanged |
| game over | `state == S_GAME_OVER` | `game_fsm.v`, `top.v` | `renderer.v` stage 3 paints a **solid colour over the sprite** on the GAME OVER screen |

**Finding that needs your decision:** on GAME OVER the renderer covers the whole screen with `C_OVER`, so a death animation would be invisible.
Decision B-1: with `death_anim` ON, draw the player sprite above the GAME OVER background (visual only, FSM untouched; text stays on top).
Your choice: ______ (draw over background / skip death anim)

### 3.2 New hardware (all gated by the flags)
- `rtl/sprite_cfg.vh` - generated switches + step intervals (localparams): `IDLE_STEP` (default 6 game frames), `HURT_STEP`, `DEATH_STEP`, frame counts, `ANIM_FORMS`.
- `rtl/player_frame.v` - pure frame-select module: inputs `form, facing, pose, moving, melee_on, melee_dir, invuln, state==GAME_OVER, frame_tick`; outputs `anim_sel (0 main, 1 idle, 2 attack, 3 hurt, 4 die)` and `anim_frame`. Priority: die > hurt > attack > idle-loop > walk.
- `roms.v` - 4 new ROM modules, instantiated with `generate if (FLAG)`.
- `renderer.v` - new ports `p_anim`, `p_aframe`; one mux at stage 3. With all flags 0 the output is bit-identical to today.
- `player.v` - one added output `moving`.
- `top.v` - wire the above.

### 3.3 ROM files (separate, main ROM stays 48 frames)
| File | Content | Layout (word address / 1024) | Size with 1 form |
|---|---|---|---|
| `mem/player_idle.mem` | Idle.png 16 frames x 4 dirs | `((form-1)*4 + dir)*16 + k` | 64 frames = 65,536 words |
| `mem/player_attack.mem` | Attack.png 4 frames x 4 dirs | `((form-1)*4 + dir)*4 + k` | 16 frames |
| `mem/player_hurt.mem` | Dmg.png 4 frames x 4 dirs | same | 16 frames |
| `mem/player_die.mem` | SoulDie or SpinDie, 12 frames | `(form-1)*12 + k` | 12 frames |

Per-frame fallback in these ROMs = that form/dir walk-idle frame of the main ROM (so forms 2 and 3 look normal).
`anim_forms` (config, default 1): ROMs hold forms 1..N only, to save BRAM. Forms above N use the walk frame. The build warns if a form above N has art, and tells you to raise `anim_forms` (BRAM grows).

Estimated BRAM (to be measured, not guessed): 1 form of everything = about 108 frames x 1024 x 12 bit = 1.3 Mbit (about 37 RAMB36). All 4 forms of idle alone would be about 3.1 Mbit.
Decision B-2: `anim_forms = 1` now (Human only, since only Human has these sheets). Your choice: ______

### 3.4 Behaviour choices (edit the numbers)
| Animation | Rule | Default |
|---|---|---|
| idle | 16-frame loop, one step every `IDLE_STEP` game frames when not moving, not attacking, not hurt | 6 frames/step (full loop 96 frames = 1.6 s) |
| attack | Attack.png 4 frames stretched over the 8 melee-active frames, facing direction | 2 game frames per sprite frame |
| hurt | Dmg.png 4 frames from the start of hurt, then back to normal; blink and knockback unchanged | 4 game frames per sprite frame (16 frames of the 68) |
| death | SoulDie (or SpinDie) 12 frames once on GAME OVER, hold last frame | 6 game frames per step |

Your edits: idle step ____ , hurt step ____ , death step ____ , death sheet soul_die / spin_die ____

### 3.5 Not wired now
- `Jump.png` (no jump in the game).
- `ChargedAttack.png` (charge belongs to form 4). Later use: rows 1-2 (6 frames each) as a looping charge-up while `chg < CHARGE_FRAMES` is counting, row 3 as the release flash on the big shot (`chg >= CHARGE_FRAMES`). Needs the same ROM + select pattern; will be described in the final report only.

### 3.6 STOP conditions
If BRAM does not fit the Nexys A7-100T (xc7a100t: 135 RAMB36) or timing fails after synthesis, I stop and report numbers. I do not cut your art.

---

## 4. Enemies and world art (NEW - from the two extra zips) - needs your scope decision

| Target ROM | Format today | Proposed source | Scaling |
|---|---|---|---|
| `monster.mem` | 4 frames 32x32 (A0 A1 B0 B1) | A = skeleton1 movement (2 frames), B = skeleton2 or vampire (2 frames) | none (32x32) |
| `bullet.mem` | 8 frames 16x16 | arrow (4 directions) from the pack | none (16x16) |
| `puzzle.mem` | 16 frames 32x32 | chest, keys, flasks, box, torch, peaks | 2x nearest-neighbour |
| `tileset.mem` | 3 floors x 16 tiles, 32x32 | `Dungeon_Tileset.png` (10x10 tiles of 16x16) | 2x nearest-neighbour |
| `boss.mem` | 6 frames 64x64 | vampire / skeleton | 2x nearest-neighbour |

Same pipeline pattern for each: `<name>_v1.mem` backup, config section, per-frame fallback, table, previews, tests.

Decision E-1 - scope (tick one):
- [ ] Monsters only
- [ ] Monsters + arrow bullet
- [ ] Monsters + bullet + puzzle items
- [ ] Everything incl. tileset and bosses
- [ ] Player only for now

Decision E-2 - 2x nearest-neighbour scaling of 16x16 art is exact (integer, no smoothing, no blur). Allowed? [ ] yes  [ ] no, 16x16 art stays unused

Default if you say nothing: player (Phase A, then B), then monsters + arrow bullet, then ask before tileset/bosses.

---

## 5. Checks (all must pass before I ask to merge)

| # | Check | Tool | Status |
|---|---|---|---|
| a1 | All existing iverilog testbenches pass as before | `scripts/run_sim.sh all` (WSL kali) | baseline ALL OK (old art); run with new art in progress |
| a2 | `mem/player.mem` = 49152 lines; disabled-form frames byte-identical to `player_v1.mem`; no shifted frame; key colour in every frame | `tests/test_sprite_pipeline.py` | DONE for v1 (20 tests) |
| a3 | Frame-select logic returns the right frame for idle/walk/attack/hurt/death per form | new `sim/tb_player_frame.v` | TODO (Phase B) |
| b | Verilator/SDL2 sim reaches WIN as before; screenshots of each form x 4 facings (idle + moving), plus attack/hurt/death if Phase B on; report clipping, shifts, flips, banding, fringe | prebuilt `sim/verilator/obj_dir_seeded/Vtop` via `scripts/run_full_game.sh` | **RISK**: Verilator and SDL2 dev files are not installed in WSL and I have no sudo. I will try the prebuilt binary (reads `mem/*.mem` at run time). If it does not run, I report it and you run `make seeded` yourself. |
| c | Deliberate fallback tests: rename a sheet, transparent cell, wrong-size sheet; build succeeds with warnings, game runs; everything restored afterwards | unit tests (temp dirs) + one live drill on the real tree | unit DONE; live drill TODO |
| d | Board readiness: Vivado 2024.2 synthesis (BRAM, timing); `.mem` files are picked up (`create_project.tcl` globs `mem/*.mem`, `rtl/*.v`); `sprite_cfg.vh` is found through include dirs (to confirm) | `E:\Xilinx\Vivado\2024.2` batch mode | TODO (baseline synth first for before/after BRAM) |
| e | Branch merges cleanly into `board-prep` | scratch branch merge, then deleted | TODO |

---

## 6. Execution order and commits (small commits)

1. [ ] Finish current iverilog run (new art) -> commit `sprite-pipeline` (build script v1, config, tests, tb, README, helpers).
2. [ ] Branch `sprite-zip` from it.
3. [ ] Rewrite build script + config to v2 (multi-sheet, candidate chains) + `sprite_preview.py` (source sheets, colour report, Angel bbox) -> commit.
4. [ ] Run on real art; **you confirm row convention and look at previews**.
5. [ ] Phase A checks a1, a2, b, c -> commit.
6. [ ] Baseline Vivado synthesis (before numbers).
7. [ ] Phase B: `player_frame.v` + tb, ROM modules, renderer/top/player edits, flags default OFF -> prove flags-off equals Phase A (same screenshots / same test results) -> commit.
8. [ ] Turn flags ON in a scratch run, screenshots, Vivado synth (after numbers) -> commit config choice only if you approve.
9. [ ] Enemies/world per section 4 decision.
10. [ ] Dev guide section 1.3 update, scratch merge test into `board-prep`, tag `main` as `pre-sprite-zip` (only just before a merge you approve).
11. [ ] Final report: files changed, one-line commands, what to edit when, rollback, board steps.

---

## 7. Commands (final shape)

- Rebuild: `python scripts/build_player_mem.py`
- Preview: `python scripts/build_player_mem.py --preview`
- Validate only: `python scripts/build_player_mem.py --check`
- Everything (build, preview, iverilog sprite test, python tests): `scripts/update_sprites.sh` (Windows: `scripts\update_sprites.bat`)

## 8. What you edit when

| You want to... | Edit |
|---|---|
| Redraw a frame | Replace the PNG (same name), run the build |
| Add form 4 art | Put sheets in `my_asset/`, add paths to `forms."4".sheets` in `sprites.json`, run the build |
| Direction looks wrong | `mapping.dir_row` (whole direction) or one `overrides` entry (one frame) |
| Use old art for something | `"enabled": false` (form) or `{"skip": true}` override (one frame) |
| Turn an animation on | `animations.<name>_anim: true`, rebuild (regenerates `rtl/sprite_cfg.vh`), re-synthesize |
| Roll back | `cp mem/player_v1.mem mem/player.mem` and set animation flags false, or `git checkout` the earlier commit |

## 9. Risks (will be measured and reported)

- RGB444 banding: 16 levels per channel; SoulDie has 38 colours and semi-transparent pixels, others 6-13 colours (low risk).
- Art outside the hitbox area (pixels 4-27): Angel/Orc/Human bounding boxes are wide (e.g. Angel x 6-123 over the sheet). Per-cell numbers will be reported; hitbox is not changed.
- Main ROM stays 48 x 1024 x 12 bit, so BRAM for it is unchanged. Phase B ROMs add BRAM only when their flag is on.
- `scripts/make_placeholders.py` would overwrite `mem/player.mem` with placeholder art if run (rebuild fixes it).
- Verilator/SDL2 not installed in this WSL (see check b).
- Renderer pipeline timing: the new mux is one extra stage-3 select; will check WNS in synthesis.

---

## 10. Your notes / changes

(write here)
