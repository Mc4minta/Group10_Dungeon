# Next steps - improvement backlog

Tick `[x]` when done. Order inside each group = suggested order. "Needs Verilog" items break the "no RTL change" rule used so far,
so they are marked: re-run `scripts/run_sim.sh all`, a full WIN run and a Vivado build after each.

Deadline: final presentation Fri 20/11. Feature freeze 22:00 Bangkok on Thu 19/11 (after that: bug fixes + report only).

Already done (for reference): player art (forms 1-3), tileset, enemies, bosses, floor decoration, per-floor colours, face-lock control fix
(`FACE_LOCK_FRAMES`). See `docs/CHANGE_REVIEW.md` and `sprites/README.md`.

---

## A. Before the presentation (low risk: config / art / tuning, no Verilog)

- [ ] **A1. Bigger player sprite.** The drawn hero is only about 8x8 px inside the 32x32 cell (Human bbox x 12-19, y 11-18). Options:
  - redraw the sheets at about 16-20 px, or
  - add an exact integer upscale option for the player sheets in `sprites/sprites.json` (e.g. `"scale": 2` = each pixel becomes 2x2, same idea as tiles/bosses; needs the source art to be about 16 px so the result still fits the 24x24 hitbox area).
  Check: art stays inside pixels 4-27 (the build prints a note), re-run `tests/test_sprite_pipeline.py`.
- [ ] **A2. Form 4 art.** Last placeholder (gold box). Put `picture/form4_walk.png` (4x4 sheet, same row convention) and add it under `forms."4".sheets` in `sprites/sprites.json`. Even a recolour of the Angel/Human sheet is fine; the pipeline falls back per frame.
- [ ] **A3. Remaining old-art ROMs.** Same config pattern as monsters (`*_v1.mem` backup, fallback, previews, tests):
  - [ ] `puzzle.mem` (boxes, bulbs, levers, gate, items): chests, keys, flasks from the asset pack (16x16 -> 2x)
  - [ ] `bullet.mem` (player/enemy bullets): arrow sprites from the pack (16x16, no scaling)
  - [ ] `effect.mem` (melee slash)
- [ ] **A4. Difficulty tuning on the board.** Playtest and adjust in `rtl/params.vh` (each change = rebuild bitstream):
  - [ ] `FACE_LOCK_FRAMES` (24 now; 0 = off)
  - [ ] `INV_FRAMES` 60 -> 90 (longer invulnerability after a hit)
  - [ ] `MON_A_HP` 2 -> 1, `HP1/HP2` 3 -> 4
  - [ ] chaser speed (needs a small `objects.v` change: move every 2nd frame via a new `MON_A_SLOW` param, default 1 = today)
- [ ] **A5. Safe state before the demo.** Tag a known-good commit, keep a known-good `top.bit` file, write the rollback commands on a card (`cp mem/*_v1.mem ...`, `git checkout <tag>`).
- [ ] **A6. Re-create the Vivado project** with `scripts/create_project.tcl` (the old project had a stale file list; new file `rtl/face_lock.v` must be included). Record BRAM and WNS in `docs/BOARD_DAY.md`.

## B. Use the art we already have (needs Verilog; = Phase B in `docs/SPRITE_PLAN.md`)

- [ ] **B1. Human idle loop** (`Idle.png`, 16 frames per row) when standing still. Separate ROM `mem/player_idle.mem`, slow step interval as a localparam.
- [ ] **B2. Attack frames** (`Attack.png`) during the melee swing (`melee_on`, 8 frames), in the facing direction.
- [ ] **B3. Damage frames** (`Dmg.png`) during the hurt blink (`invuln`).
- [ ] **B4. Death animation** (`SoulDie.png` or `SpinDie.png`) on GAME OVER. The renderer paints the whole screen over the sprite on that screen, so the sprite must be drawn above the background.
- [ ] **B5. Form 4 charge shot art** (`ChargedAttack.png`: charge loop rows 1-2, release row 3).
  For all of B: flags default OFF in `sprites.json`, `anim_forms` = 1 to save BRAM, measure BRAM in Vivado (135 RAMB36 available), per-frame fallback to the walk-idle frame.

## C. Look of the map (needs Verilog)

- [ ] **C1. Wall autotile.** Today there is one wall id, so all walls look the same. Add top / side / corner variants from the pack: needs renderer work (neighbour lookup or more tile ids).
- [ ] **C2. Decoration beyond floor:** torches on walls, rugs, pillars (same extra tile ids as C1).
- [ ] **C3. Room layout pass** after C1: clearer rooms, still no change to puzzles, spawns, exits, enemy counts (keep `maps_v1/`, run `tests/test_maps.py`, `solve_sokoban.py`, `run_sim.sh all`, full WIN).

## D. Gameplay and feel

- [ ] **D1. Better board controls.** Switch-based facing lock (SW14) as a fallback, or auto-aim to the nearest enemy.
- [ ] **D2. Feedback:** screen shake on player damage, brighter evolve flash.
- [ ] **D3. Enemy variety:** third enemy type with the skeleton2 art (faster/weaker, or one that shoots in line).
- [ ] **D4. More sound effects:** pickup, door open, boss intro.

## E. Polish for the demo

- [ ] **E1. Title and win screens:** real art and the team name instead of plain text / solid colour.
- [ ] **E2. Demo mode:** debug switch to jump straight to a boss room or form 4, so everything can be shown in 3 minutes.
- [ ] **E3. Final report:** files changed, one-line commands, what to edit when, rollback, board steps (`docs/CHANGE_REVIEW.md` is the draft).

---

## Suggested picks for tonight (before the 22:00 freeze)
1. **A1** bigger player sprite
2. **A2** form 4 art
3. **A4** playtest + tune difficulty on the board
4. **A5/A6** safe state + clean Vivado project

## Rules for every item
Rule 1 (the game always builds; missing art falls back to the old art with a warning), `*_v1` backups never edited, `mem/*.mem` are generated,
work on a branch (no merge to `main` until you say so), run `scripts/run_sim.sh all` + a full WIN run before committing anything that touches RTL or maps.
