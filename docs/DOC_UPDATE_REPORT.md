# Documentation update report - 23/11/2026

Scope: bring README.md and docs/ in line with the code of `main` = `dev` (`3e908a3`). Code is the source of truth. Nothing committed or pushed. Fact sheet (scratch, not in the repo): the facts below were taken from `rtl/params.vh`, `game_fsm.v`, `top.v`, `boss.v`, `world.v`, `hud.v`, `renderer.v`, `ps2_kbd.v`, `audio.v`, `maps/`, `sim/verilator/Makefile`, `scripts/run_sim.sh`, `scripts/check_all.sh`, and the local Vivado reports.

## 1. Files changed

| File | Summary |
|---|---|
| `README.md` | fully rewritten: real status, Known gaps, controls table (board + keyboard), DEBUG warning, per-form table (HP 4/4/4/4), combat numbers, boss table with rage values, rooms (15 in play / 13 maps), ESCAPE maze, mic, 13 SFX, folder layout, Verilator and Icarus commands, testbench table |
| `docs/README.md` | HP / facing-lock / room statements fixed, `report_shots/` added, new section 6 listing every file in docs/ |
| `docs/CONTROLS.md` | DEBUG default note, boss 3 = 9 hits |
| `docs/FEATURES.md` | header state, rooms row, BTNC on GAME OVER, 13 SFX, 51 boxes / 37 events, boss 3 kill count row, DEBUG default, section 14 rewritten (nothing listed there is "planned" any more) |
| `docs/NEXT_STEPS.md` | status banner (timing, board), HP / SW12 / SFX fixes, design-plan items ticked done (sim), merge item done, P1.1 timing note, planned-names note |
| `docs/PROGRESS.md` | status banner + inline "now" notes where the old checklist is wrong (sprint SW14, invuln 90, clap boss 1, ESCAPE 60 s maze, SFX 13, boss HP, form HP); history kept |
| `docs/CHANGE_REVIEW.md` | new top entry (23/11) with known gaps; old sections marked historical, obsolete `tb_puzzles` note flagged |
| `docs/BOARD_TEST_STEPS.md` | status banner (branch, timing, DEBUG, what is board-confirmed) |
| `docs/BOARD_DAY.md` | status banner, HP 4 LEDs / `1-4-00.00`, boss 1 clap, mic test default note |
| `docs/GAMEPLAY_REVIEW.md` | code counts for dialogue entries |
| `docs/MAP_DESIGN.md` | room / grid reminder |
| `docs/SOUND_PLAN.md` | checked vs code (13 effects), planned-script note |
| `docs/SOUND_PIPELINE_PLAN.md` | marked PLANNED ONLY (no tools exist) |
| `docs/STORY.md` | two design-table lines about boss 3 (HP 3 / 2 s charge -> HP 9 / 4 s charge + storm); no message rows touched; `build_story.py` and `tests/test_story.py` rerun, generated files unchanged |
| `docs/DESIGN_PLAN.md` | doc-check line, status line under each non-item section, note on file names that were never created |
| `docs/SPRITE_STATUS.md` | read, no statement found that contradicts the code; not edited |
| `docs/DOC_UPDATE_REPORT.md` | this file |

## 2. Comment-only edits in rtl/ (no value, port or logic changed)

| File:line | Old | New |
|---|---|---|
| `rtl/params.vh:23` | `// SW15: +px/เฟรม` | `// SW14 (or Shift key): +px/เฟรม` |
| `rtl/params.vh:72` | `// W12: 3 ปล่อยชาร์จที่โดน = ตาย (แถบ HP 3 ช่อง)   // บอส 3 (ชั้น 3)` | `// W44: boss 3 needs 9 accepted hits (1 HP each: a charged shot, or any hit while it rests); HUD bar = hp / 9` |
| `rtl/game_fsm.v:1` | `// Game FSM (P2): TITLE / PLAY / EVOLVE / FLOOR_CLEAR / ESCAPE / WIN / GAME_OVER` | `... TITLE / PROLOGUE / PLAY / EVOLVE / FLOOR_CLEAR / ESCAPE (maze) / WIN / GAME_OVER (pause is not a state: see top.v)` |
| `rtl/game_fsm.v:13` | `sprint level: ... SPRINT_BONUS (SW15)` | `... SPRINT_BONUS (SW14 / Shift key)` |
| `rtl/boss.v:6` | `บอส 3 (ชั้น 3): HP 3, เกราะ: รับเฉพาะกระสุนชาร์จ (ทีละ 1)` | `บอส 3 (ชั้น 3): HP 9 (BOSS3_HP), เกราะ: รับเฉพาะกระสุนชาร์จ (ทีละ 1; ช่วงพักรับทุกแบบ)` |
| `rtl/top.v:6` | `/ กลับ TITLE (WIN, GAME_OVER)` | `/ กลับ TITLE (WIN) / retry ชั้นปัจจุบัน (GAME_OVER; BTNL = กลับ TITLE)` |
| `rtl/audio.v:3` | `SFX 10 แบบ: ev[1..10] เป็น pulse 1 clock;` | `SFX 13 แบบ: ev[1..13] เป็น pulse 1 clock (11 boss appears, 12 door, 13 boss-3 charge beep);` |

Other stale comments left alone (not on the line next to a contradicting value, or ambiguous): `boss.v` header lines 4-5 (boss 2 "wait 120 frames" vs `BOSS2_REST` = 75, W17/W42 history), `renderer.v` header "boss/ObjLine" layers order wording, `mic_test_top.v` `TH_DEFAULT` comment "same as MIC_TH in the game" (game is 448, mic test is 600), `top.v` line 2 "P5 status" banner, `audio.v` `AUD_SD` note.

## 3. Facts that were wrong and what they are now

| Old statement (where) | Now | Source |
|---|---|---|
| Max HP 3/3/4/4 (old README table, PROGRESS) | 4/4/4/4; hearts drawn = 4 | `params.vh:11-14`, `hud.v:65-67` (up to 6 hearts) |
| README: boss HP 10/16/24, boss 2 bounces + clap stuns boss 2, boss 3 chases fast | 10 / 16 / **9**; boss 2 stationary in a fence box, clap stuns **boss 1** | `params.vh:70-72`, `boss.v` `stunnable = (kind==0)` |
| README: ESCAPE 30 s run-back, WIN by door E with form 4 | ESCAPE = 60 s Ball in a Maze after boss 3 drops the key | `params.vh:113`, `game_fsm.v:132,157` |
| README: mic `MIC_TH` 600, edge-based window count | 448 (title menu 192/320/448/704/1024), peak of \|block-DC\| | `params.vh:132`, `top.v:275` |
| README: invulnerable 60 frames / "68" | `INV_FRAMES` = 90 | `params.vh:51` |
| README: renderer 3 clock | 4 clock | `renderer.v:1`, `top.v:584` |
| README: SFX 10 | 13 (ev[13:1]) | `audio.v:46-58` |
| README: BGM per floor | floors 1-3 all use track 6, ESCAPE 3, WIN 4, OVER 5 | `rtl/bgm_cfg.vh` |
| README: states list without PROLOGUE, no pause | PROLOGUE exists; pause is `paused` gate in `top.v`, not a state | `game_fsm.v:64-65`, `top.v:128` |
| README / docs: "3 floors x 5 rooms" vs "13 rooms" | both true: 15 rooms in play, 13 map files (grid 0..12) | `world.v:36-40` |
| README: SW14 = pause? / SW15 = sprint (comments in `params.vh`, `game_fsm.v`) | SW15 = PAUSE, SW14 = SPRINT (also Shift) | `top.v:111-115`, `top.v:128` |
| `params.vh` BOSS3_HP comment: "3 charged hits = death, 3-slot bar" | 9 accepted hits; bar = hp/9 | `boss.v:141-142,296-301`, `hud.v:28` |
| STORY.md tables: boss 3 HP 3, charge 2 s | HP 9, charge 4 s then 2 s storm | `params.vh:72,110` |
| FEATURES / GAMEPLAY_REVIEW: 49-50 dialogue boxes, 36 events, 12 SFX | 67 dialogue entries (= 51 boxes + 16 hints), 37 events, 13 SFX | `rtl/dlg_cfg.vh` (`NDLG`, `NEV`), `audio.v` |
| BOARD_DAY: HP 3 / LED8-10, "boss 2 clap", `MIC_TH` 600 | HP 4, boss 1 clap, game `MIC_TH` 448 (mic test project still 600) | params / `mic_test_top.v:12` |
| NEXT_STEPS: W1-W46 items unchecked, merge pending | all done (sim), merged 21/11 | git log |
| CHANGE_REVIEW / NEXT_STEPS: `tb_puzzles` lever-XOR fails | passes: 42 checks, errors = 0 (Icarus 13.0 in WSL, 23/11) | run log |
| README "SW14 facing lock", docs/README "SW14 facing lock" | SW12 | `top.v:116` |
| Form speed / damage tables | were already right (2/2/3/3, 1/1/2/2); README HP column was the only wrong one | `params.vh` |
| Vivado numbers "not recorded" / "WNS should be >= 0" | **recorded locally: Block RAM 103.5 / 135, WNS -4.045 ns (not met)** (see below) | `vivado/Group10_Dungeon.runs/impl_1/*.rpt` |

Vivado reports (found in the working tree, **git-ignored**, run 22/11/2026 21:30-21:43, Vivado 2024.2): Block RAM Tile 103.5 (RAMB36 101, RAMB18 5) of 135; Slice LUT 18,182 of 63,400; registers 4,163; DSP 1; Design Timing Summary WNS -4.045 ns, TNS -2904.290 ns, 1853 failing endpoints of 9926, WHS +0.046 ns, "Timing constraints are not met"; worst path `pz/b0x_reg[1]` -> `rnd/a_bb_reg[11]`. Which commit produced this run is not recorded.

## 4. Needs a human decision

1. **Timing fails** (WNS -4.045 ns at 100 MHz in the 22/11 local run). Decide whether to fix (the worst path is puzzle coordinates -> text address in `renderer.v`) or run at a lower clock; docs now state the failure plainly. Also confirm the run came from the current code.
2. **`DEBUG` default is 1** in `rtl/top.v`, and `create_project.tcl` sets no generic, so a default build has the cheat switches SW0-SW4 on. Docs say the hand-in build must use 0; nothing in the repo enforces it.
3. **`sim/verilator/Makefile`** passes `-GPROLOGUE=$(PROLOGUE_V)` but never defines `PROLOGUE_V` (`make -n -B seeded` shows `-GPROLOGUE=`). Whether Verilator accepts it was not run. The local seeded binary was built by `report_shots/_build.sh` with `-GPROLOGUE=0`. The scripts in `sim/verilator/scripts/` (e.g. `full_game.txt` starts with one BTNC for TITLE -> PLAY) assume PROLOGUE = 0. Decide the intended default and the right fix (the README suggests `PROLOGUE_V=0`, **not run**).
3b. `scripts/run_full_game.sh` therefore only works with such a build; the last full WIN run on current code is not known.
4. **Mic test project vs game:** `mic_test_top` still uses `TH_DEFAULT` = 600 and the old detector scale while the game uses `MIC_TH` = 448 with the W4 detector; BOARD_DAY step 5 tells you to copy the mic-test threshold into `MIC_TH`. Decide whether the mic test should be updated.
5. **Boss 3 rest rule:** the charged-shot-only armour has an exception (`acc` is true for any hit while `s3 == 2`, the 2 s rest). Docs describe this as the behaviour; confirm it is intended (the old `params.vh` text said only charged shots count).
6. **`kill` path:** `boss.v` no longer pulses `kill` (boss 3 storm replaced the instant kill), but `game_fsm.v` and `top.v` still wire it; harmless but dead.
7. **Dialogue counts:** STORY.md / GAMEPLAY_REVIEW say "50 story boxes (12 blocking, 38 timed)", `dlg_cfg.vh` has 67 entries; the 51 + 16 split is derived from the docs, not recounted from the ROM.
8. `AUD_SD_ON` polarity, mic edge (`M_LRSEL`), maze axes: unchanged "not confirmed on the board".

## 5. Not verified

- Anything on the real board except what the owner's notes already say (USB keyboard works).
- Verilator builds and runs (Verilator was not rebuilt; commands in README are copied from the Makefile / scripts / `main.cpp`, not executed).
- `./scripts/check_all.sh` was **not** run (it rewrites generated files and takes about 12 minutes); instead `build_story.py` + `tests/test_story.py` were run (no generated file changed). `tb_top`, `topanim`, `player`, `orb`, `simonplate`, `ovrender`, `text`, `debug` suites were not run.
- Dialogue split (blocking / timed), SFX frequency numbers beyond what `params.vh` states, PNG pictures in `docs/` (several predate W19-W46 and were not regenerated).
- Link check: every relative link and every backticked repo path in README.md and docs/*.md was checked; remaining non-existing paths are planned or historical names listed in the docs themselves (`scripts/audio_to_sfx.py`, `rtl/sample_player.v`, `docs/wip/README.md` (exists only in git tag `archive/wip-wall-variants`), `docs/HITBOXES.md`, etc.).

## 6. Regression check for the comment edits

iverilog (Icarus 13.0 in WSL kali), targets `world fsm hud dialog ps2 mic audio puzzles boss objects` run before and after: see section 7 for the final numbers.

## 7. Results

Before edits (the `puzzles`, `boss`, `objects` runs of the "before" batch started while the first comment edits were being made; comment-only, so equivalent): world 52 checks, fsm 67, hud 126369 pixels, dialog 22, ps2 30, mic 6, audio 64, puzzles 42, boss 73, objects 118 - all errors = 0.
After edits: all ten targets exit 0 with identical check / error lines to the before run (world 52, fsm 67, hud 126369 pixels, dialog 22, ps2 30, mic 6, audio 64, puzzles 42, boss 73, objects 118; errors = 0). No edit was reverted.
