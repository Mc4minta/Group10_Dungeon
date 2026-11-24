# Change review

## Update 23/11/2026 - documentation refresh (no behaviour change)

All documents were checked against the code (`main` = `dev` = `3e908a3`). Full list of wrong facts, comment-only code edits and open questions: `docs/DOC_UPDATE_REPORT.md`.

| Area | What changed | Verified |
|---|---|---|
| Docs | README rewritten (status, controls, per-form table, bosses, rooms, build + simulation commands, folder list, Known gaps); docs index lists every file; FEATURES / CONTROLS / NEXT_STEPS / PROGRESS / STORY / BOARD_* / SOUND_* / DESIGN_PLAN corrected | links and paths grep-checked |
| Code comments | 6 comment-only edits in `rtl/` (sprint is SW14, boss 3 has 9 HP, SFX count 13, FSM states, BTNC on GAME OVER) | iverilog `world fsm hud dialog ps2 mic audio puzzles boss objects`: results equal to the run before the edits (sim) |

Known gaps (23/11): nothing is board-tested except the USB keyboard; the local Vivado run of 22/11 reports **WNS -4.045 ns, TNS -2904.290 ns, 1853 failing endpoints of 9926 (timing not met at 100 MHz; hold met, WHS +0.046 ns)**, Block RAM 103.5 / 135, Slice LUT 18,182 / 63,400 (git-ignored reports, source commit unknown); `DEBUG` defaults to 0 in `rtl/top.v` (hand-in build); the Verilator Makefile passes an undefined `PROLOGUE_V`; `tb_puzzles` passes (42 checks) so the old "lever-XOR fails" note is obsolete; the full-system `tb_top` and the Verilator full-game run were not repeated in this refresh.

---

## Update 20-21/11/2026 (branches `dev` = `main`)

Everything below is committed on `dev` and merged into `main`. "sim" = verified with a testbench / Python test, "board" = not yet tried on the board.

| Area | What changed (design item) | Verified |
|---|---|---|
| Traps | timed floor-2 spikes (W19), every form is hurt, 5-tile hurt-box check (W39) | `tb_objects` sim, board open |
| Bosses | bullet patterns + slow chase (W20), boss 3 charge bar / colour / beep (W21), storm instead of instant death (W24), boss 2 rework (W42), boss 3 HP 9 (W44), second phase (W43) | `tb_boss` sim, board open |
| Input | USB keyboard (W22, **board confirmed**), edge cases (W34), SW8 / H hitbox overlay | `tb_ps2` sim |
| Combat | charge ball (W25), auto aim on by default + free angle + marker (W18 / W46), smarter chasers and aimed turret (W45), waves (W43), retry current floor (W43) | `tb_objects`, `tb_game_fsm` sim |
| Microphone | detector rewritten for an AC signal (W4), meter + title SETTINGS page (W27 / W30 / W36) | `tb_pdm_mic`, `tb_hud` sim, board open |
| Story / help | story boxes freeze the game (W31), hint strip + tutorial (W28 / W32), title pages (W29), intro once (W33), text never covers doors (W38) | `tb_dialog`, `tb_top` (older run), `test_story` |
| Maps | combat / start 1 / boss rooms redrawn with a purpose per object (W23), light puzzle at the bottom (W26-related), Sokoban reset hint (W41) | `test_maps` |
| Art | plate with box (W26), Human attack animation ON (W35), clearer lever art, flickering torch bulbs | `test_tileset_pipeline`, `test_sprite_pipeline` |
| Fixed in synthesis | `ORB_DIST` wiped from a generated file; `dlg_ev` bit bound and `lock_seen` multi-driver (Vivado kept constant 0: the intro-again box and the room-cleared boxes never fired) | Vivado synth warnings, rerun pending |

Known gaps (as written 21/11; the `tb_puzzles` note is obsolete, it passes on 23/11): `tb_puzzles` lever-XOR check fails (unexplained, same before the changes); the full-system `tb_top` was not rerun on the last commit; nothing from W19 onwards is board-tested.

---

# Change review (older text, 19/11)

## Everything on branch `sprite-zip` compared with `main` (19/11) - HISTORICAL: merged long ago; HP is 4 on all forms now, SW15 = pause, SW14 = sprint

Branch `sprite-zip`, tag `board-test-2`. Nothing of this is in `main` yet (main waits for an explicit "merge"). All feature branches that existed during development are merged into `sprite-zip` and deleted
(history is kept in `sprite-zip`; the old phase branches are kept as tags `archive/p2-game-fsm` ... `archive/p6-tweaks`; unfinished work is on `wip/wall-variants`).

Rules that every change follows: Rule 1 (the game always builds; missing or invalid art / sound falls back to the original with a printed warning), `mem/*.mem` are generated from source files and settings,
`*_v1.mem` are the untouched originals, every pipeline has tests, nothing is merged to `main` without the owner's word.

---

## 1. What changed, by feature

### 1.1 Art pipeline (no Verilog)

| Group | Source of truth (you edit) | Generated (do not edit) | Original backup | Build |
|---|---|---|---|---|
| Player (48 frames) | `my_asset/Character/*`, `sprites/sprites.json` | `mem/player.mem` | `mem/player_v1.mem` | `python scripts/build_player_mem.py` |
| Tiles (3 floors x 16) | `my_asset/tileset/Dungeon_Tileset.png`, `sprites/tileset.json` | `mem/tileset.mem` | `mem/tileset_v1.mem` | `python scripts/build_tileset_mem.py` |
| Enemies (A skeleton, B vampire) | `my_asset/enemies/*`, `sprites/monsters.json` | `mem/monster.mem` | `mem/monster_v1.mem` | `python scripts/build_monster_mem.py` |
| Bosses (2x exact scale) | `my_asset/enemies/*`, `sprites/bosses.json` | `mem/boss.mem` | `mem/boss_v1.mem` | `python scripts/build_boss_mem.py` |
| Puzzle objects (torch bulbs, lever, crate, spikes gate, keys, shield) | `my_asset/props/*`, `my_asset/new_switch.png`, `sprites/puzzle.json` | `mem/puzzle.mem` | `mem/puzzle_v1.mem` | `python scripts/build_puzzle_mem.py` |
| Room layouts + decoration | `maps/*.txt`, `scripts/build_maps.py` | `mem/tilemap.mem` (objects, monsters, puzzle layout unchanged) | `maps_v1/` | `python scripts/build_maps.py` |

Features of the player builder: several sheets per form (walk, idle, ...), fallback chains per pose, per-form exact integer `scale` (Human, Orc and Angel 2x; the Angel wing tips are cut flat at the 32 px frame edge),
luminance `tint` (form 4 = Human sheets recoloured gold), labelled previews, colour and bounding-box reports, a clean copy of the oddly named `Angel_walk.png.png`.
Features of the tile builder: 16x16 cells scaled exactly 2x, `base` tiles (see-through cells show the floor), per-floor `recolor` and `gain` (floor 1 purple, 2 teal, 3 olive), per-tile overrides.
Floor decoration (`, ; : \`` = crack, bones, skull, rubble) uses tile ids 12-15, which the game treats like floor everywhere except inside the Simon puzzle, so they are only allowed in rooms 00, 03-08 (`build_maps.py` refuses them elsewhere).
Everything is documented in `sprites/README.md`; what is final / placeholder is in `docs/SPRITE_STATUS.md`.

### 1.2 Gameplay and controls (RTL changes)

| Change | Where | Setting |
|---|---|---|
| Easier: start HP 4 for forms 1-2 (was 3), invulnerable 90 frames after a hit (was 60), the chasing monster moves every 2nd frame (half speed) | `rtl/params.vh`, `rtl/objects.v` | `HP1`, `HP2`, `INV_FRAMES`, `MON_A_MOVE_EVERY` |
| After tapping BTNC the facing stays locked for 24 frames (attack and step back with one hand) | new `rtl/face_lock.v`, `rtl/top.v` | `FACE_LOCK_FRAMES` (0 = off) |
| SW12 up = facing locked all the time (was SW14); SW15 = pause, SW14 = sprint (W15) | `rtl/top.v` | - |
| Screen shake for 12 frames after being hit | `rtl/top.v` | `HURT_SHAKE_FRAMES` (0 = off) |
| Two new sound effects: boss appears (11), room change (12) | `rtl/audio.v`, `rtl/params.vh`, `rtl/top.v` | `SFX_BOSS_*`, `SFX_DOOR_*` |
| Music ROM has 8 tracks; track 6 is a custom track that loops; which track plays where comes from `sprites/music.json` | `rtl/audio.v`, `scripts/make_music.py`, generated `rtl/bgm_cfg.vh` | `sprites/music.json` |

The existing tests that hard-coded the old numbers (HP 3, 60 invulnerable frames, 20 frames to reach the player) now read the parameters (`tb_game_fsm`, `tb_objects`, `tb_top`), so they follow the tuning instead of being weakened.

### 1.3 Sound and music

`docs/SOUND_PLAN.md` lists all 12 sound effects (all placeholder tones), the 7 music tracks and how to change them. Track 6 is the melody of the song "Connect" extracted by `scripts/audio_to_music.py` from `my_audio/connect_preview.wav`
(45 s, 89 notes, square-wave version; the original files are not in the repository). `docs/SOUND_PIPELINE_PLAN.md` is the plan for using other sounds (SFX fit, MIDI, samples in block RAM).

### 1.4 Human animations (built, OFF)

Idle loop, attack, hurt and death pictures for the Human, in four extra ROMs, chosen by the new `rtl/player_frame.v`, drawn by `rtl/renderer.v`, configured by the generated `rtl/sprite_cfg.vh`.
All four flags are `false` in `sprites/sprites.json`, so the build is exactly the old behaviour and uses no extra Block RAM. See `sprites/README.md` ("Human animations") and `docs/NEXT_STEPS.md` P3.1.

### 1.5 Tooling and tests

| Item | Purpose |
|---|---|
| `scripts/check_all.sh` | rebuild all generated files, verify nothing is stale, run all Python tests and the iverilog suite |
| `scripts/update_sprites.sh` / `.bat` | rebuild + previews + ROM checks for all art |
| `tests/test_*_pipeline.py`, `tests/test_maps.py`, `tests/test_music_pipeline.py` | 7 Python suites, about 125 tests (fallbacks, exactness, bad config, tools) |
| `tests/fallback_drill.sh` | breaks the art on purpose (missing, transparent, wrong size) and shows the build still succeeds |
| `sim/tb_*.v`, `scripts/run_sim.sh` | new targets: `sprites`, `tileset`, `monster`, `bosssprites`, `puzzleart`, `facelock`, `playerframe`, `animroms`, `topanim` |
| `scripts/make_placeholders.py` | legacy; now refuses to run without `--force` (it would overwrite the real ROMs) |

---

## 2. Verification (state of `board-test-2`)

| Check | Result |
|---|---|
| `scripts/check_all.sh` (generated files current, all Python tests, `run_sim.sh all`) | PASS (`run_sim.sh all` = ALL OK) |
| Whole-system test with all four animation flags forced ON (`run_sim.sh topanim`) | PASS |
| Fallback drill on the real tree (4 scenarios) | PASS |
| Verilator `full_game.txt` script | NOT valid any more after the W7 maze: the run used to end with the ESCAPE dash to door E; now boss 3 gives a key and door E starts the tilt maze (the script has no maze solution; extend it with button moves or use `SW10`) |
| Verilator full game to WIN | last passed on the commit before the tuning / face lock / SW14 / music RTL changes (screenshots in `preview/game`); NOT repeated on the newest RTL because Verilator cannot be rebuilt on the build machine |
| Vivado synthesis and board run | local run of 22/11: **timing not met** (WNS -4.045 ns, TNS -2904.290 ns, 1853 of 9926 endpoints failing, WHS +0.046 ns), Block RAM 103.5 / 135, Slice LUT 18,182 / 63,400 (reports git-ignored, source commit unknown). The project team reports that the full game ran on the board; no per-item board results beyond the USB keyboard are recorded in this repository |

## 3. Things to know (honest notes)

1. The new player sprites are small: the drawn hero is about 8x8 px inside the 32x32 cell (16 px after 2x). Angel is now 2x like the others (wing tips cut at the frame edge). Bosses are drawn smaller than the old blobs.
2. The two lever states differ by only 12 pixels in `new_switch.png` (a 2 px shift), so they are hard to tell apart on screen.
3. Row 4 of each walk sheet (back facing left) is unused: the game has only 4 directions.
4. Bullets, the melee slash, text and the title / win / game over screens still use the original placeholders (no fitting art yet).
5. The song is a commercial one: the melody is in `sprites/music/connect.txt` and `mem/music.mem`; check the repository visibility before sharing.
6. `main` is still the old version.

## 4. Rollback

| Want to undo | Command |
|---|---|
| All new art at once | `cp mem/player_v1.mem mem/player.mem; cp mem/tileset_v1.mem mem/tileset.mem; cp mem/monster_v1.mem mem/monster.mem; cp mem/boss_v1.mem mem/boss.mem; cp mem/puzzle_v1.mem mem/puzzle.mem` |
| Map decoration only | `cp maps_v1/[0-9]*.txt maps/ && cp scripts/build_maps_v1.py scripts/build_maps.py && python scripts/build_maps.py` (and set the floor `gain` values to 1.0 in `sprites/tileset.json`) |
| The song | set `play` entries to `"default"` in `sprites/music.json`, run `python scripts/make_music.py` |
| Difficulty / controls | `rtl/params.vh`: `HP1` / `HP2` 3, `INV_FRAMES` 60, `MON_A_MOVE_EVERY` 1, `FACE_LOCK_FRAMES` 0, `HURT_SHAKE_FRAMES` 0 |
| One form / floor / monster / boss | `"enabled": false` in its settings file, rebuild |
| The whole branch | `git checkout board-test-1` (earlier known-good) or `main` (original) |

Board steps: `docs/BOARD_TEST_STEPS.md`. Backlog: `docs/NEXT_STEPS.md`. Index: `docs/README.md`.
