# Project guide - start here

Group 10 Dungeon: a VGA dungeon game in Verilog for the Nexys A7-100T (Vivado 2024.2), with a Python pipeline that builds all art, map and music ROMs from files you edit.
This page is the index. Last full refresh: 23/11/2026 against the code of `main` = `dev` (`3e908a3`); see `docs/DOC_UPDATE_REPORT.md`.

## 1. Which document do I read?

| I want to... | Read |
|---|---|
| **Build and test on the board** (exact Vivado steps, what to check, rollback) | `docs/BOARD_TEST_STEPS.md` |
| **See which sprites are final / placeholder / missing** and what I still have to draw or find | `docs/SPRITE_STATUS.md` |
| **Change a sprite, tile, enemy, boss, map decoration** | `sprites/README.md` |
| **See every sound and the music**, change them, or learn how to use an MP3 | `docs/SOUND_PLAN.md`, `docs/SOUND_PIPELINE_PLAN.md` |
| **See what changed on this branch** (all features, how they were verified, risks) | `docs/CHANGE_REVIEW.md` |
| **Every feature that exists today, by category** (flow, player, combat, bosses, puzzles, map, art pipelines, HUD, audio, controls, tools) | `docs/FEATURES.md` |
| **Edit the story / any on-screen text** (title, prologue, dialogue boxes, game name) | `docs/STORY.md` (the source of truth), then `python scripts/build_story.py` |
| **Know what to do next** (backlog by priority) | `docs/NEXT_STEPS.md`, and the FUTURE BACKLOG table in `docs/DESIGN_PLAN.md` |
| **How to play: every button, switch and key** (board + keyboard, what each form does, bosses, puzzles) | `docs/CONTROLS.md` |
| **What every object of a redrawn room is for** (map design rules, waves) | `docs/MAP_DESIGN.md` |
| **Story / gameplay review** (story boxes, hint strip, edge cases) | `docs/GAMEPLAY_REVIEW.md` |
| **The master design and the status of every item W1-W46** (implemented items keep their original text) | `docs/DESIGN_PLAN.md` |
| **Overview, build, tests, known limitations** (English) | `README.md` (root) |
| **Original design checklists** (Thai) | `docs/PROGRESS.md`, `docs/BOARD_DAY.md` |
| **Old plan documents** (history only) | `docs/archive/` |

## 2. Folder map

| Folder | What is in it | Edit it? |
|---|---|---|
| `rtl/` | the game in Verilog (`top.v`, `player.v`, `objects.v`, `renderer.v`, `audio.v`, ...). Files ending `_cfg.vh` and `bgm_cfg.vh` are **generated** | yes, but every change needs `scripts/check_all.sh` |
| `my_asset/` | your art: `Character/`, `enemies/`, `props/`, `tileset/`, `new_switch.png`, the two asset zips | **yes** (source of truth) |
| `my_audio/` | your source audio (mp3 / wav). **Not committed** (ignored) | yes |
| `sprites/` | the settings: `sprites.json` (player), `tileset.json`, `monsters.json`, `bosses.json`, `puzzle.json`, `music.json`, `music/*.txt` | **yes** |
| `maps/` | the 13 room layouts (text; 3 floors x 5 room roles = 15 rooms in play, START of floors 1+2 and BOSS of floors 1+3 share a map) + `maps/maze/maze.txt`. `maps_v1/` = untouched originals | yes (carefully, see sprites/README.md) |
| `mem/` | **generated** ROM files (`player.mem`, `tileset.mem`, `music.mem`, ...) and the `*_v1.mem` backups of the original art (never edit) | **no** |
| `scripts/` | the builders (`build_*_mem.py`, `make_music.py`, `audio_to_music.py`, `build_maps.py`), `check_all.sh`, `run_sim.sh`, Vivado Tcl | run them |
| `report_shots/` | (untracked) WSL helper scripts that take Verilator screenshots (`env.sh`, `_build.sh`, `run.sh`, `convert.py`) | no |
| `tests/` | Python tests (one per pipeline) and the fallback drill | add tests with every change |
| `sim/` | iverilog testbenches (`tb_*.v`) and the Verilator player (`sim/verilator`) | add tests with every change |
| `preview/` | generated pictures (contact sheets, screenshots). Git-ignored except `layout_guide.png` | no |
| `docs/` | documents (this folder) | yes |
| `vivado/` | your Vivado project (git-ignored, re-create with `scripts/create_project.tcl`) | no |

## 3. The daily workflow (art / map / sound change)

1. Edit a source file (`my_asset/...`, `sprites/*.json`, `maps/*.txt`, `sprites/music/*.txt`).
2. One command rebuilds everything and shows pictures: `scripts/update_sprites.sh` (Windows: `scripts\update_sprites.bat`). Look at `preview/` and the fallback table it prints.
3. Before you commit: `scripts/check_all.sh` (about 12 min; `--fast` = about 1 min without the iverilog suite). It rebuilds every generated file, checks nothing is stale, runs all Python tests and the iverilog suite.
4. Commit the source **and** the generated files together (the FPGA flow reads `mem/*.mem`).
5. Board: close the Vivado project, `source scripts/create_project.tcl` in the Tcl Console, Generate Bitstream, program the device (`docs/BOARD_TEST_STEPS.md`).

Golden rules: Rule 1 (any missing or invalid art / sound falls back to the original with a printed warning, the game always builds); `mem/*.mem` are generated, never hand-edited;
`*_v1.mem` are the untouched originals (rollback = copy back); no merge to `main` without an explicit "merge".

## 4. Branches and tags

| Name | What it is |
|---|---|
| **`main`** | **the merged version** = `dev` at the last merge (21/11, everything up to W46). Only changes when the owner says "merge" |
| **`dev`** | **the development line**: all new work. Committed after every batch; the merge into `main` is a separate step the owner asks for |
| tag `board-test-2` | the build for the board (older); tag `board-test-1` = the earlier known-good build (rollback target) |
| tag `archive/wip-wall-variants` | the unfinished room-border wall pictures (was branch `wip/wall-variants`; read `docs/wip/README.md` inside that tag to resume: `git checkout -b feature/walls archive/wip-wall-variants`) |
| tag `archive/board-prep` | the version before the sprite work |
| tags `archive/p2-game-fsm` ... `archive/p6-tweaks` | the old phase branches of the first version (all merged) |

Rule for new work: `git checkout dev && git checkout -b feature/<name>`, keep it small, merge it back into `dev` after `scripts/check_all.sh` passes, then delete the branch.

## 5. What exists / what does not (one line each)

- Art: player forms 1-3 real, form 4 = gold recolour of the Human (placeholder), tiles, 2 enemies, 3 bosses, puzzle objects: see `docs/SPRITE_STATUS.md`.
- Gameplay changes from the original: HP 4 (all four forms), invulnerable 90 frames, chasing monster at half speed, BTNC face lock, SW12 facing lock (SW15 = pause, SW14 = sprint), screen shake when hit, two new sound effects, Connect melody as BGM on floors 1-3.
- Human **attack** animation is ON since 21/11 (W35); still OFF (need Block RAM, flags in `sprites/sprites.json` -> `animations`): Human idle / hurt / death animations.
- Not built: wall variants (WIP branch), sample playback, ranged / charger enemy types, a path-finding distance field, bullet / slash art. Story screens, dialogue boxes, hint strip and title pages DO exist now (`docs/STORY.md`).
- `docs/CONTROLS.md` - the player's control guide (board buttons / switches and keyboard)
- `docs/MAP_DESIGN.md` - what every object of a redrawn room is for
- `docs/GAMEPLAY_REVIEW.md` - story / gameplay review (W31-W34)

## 6. Every file in docs/ (one line each)

| File | What it is |
|---|---|
| `README.md` | this index |
| `CONTROLS.md` | player guide: every button, switch and key (English) |
| `FEATURES.md` | catalogue of what the game does today (English) |
| `GAMEPLAY_REVIEW.md` | story / hint / input review of 20/11 (W28-W34), all approved and built |
| `MAP_DESIGN.md` | purpose of every object in the redrawn rooms, waves |
| `STORY.md` | source of truth for all on-screen text (Thai notes); `scripts/build_story.py` builds the ROMs from it |
| `SPRITE_STATUS.md` | which sprites are final / placeholder / missing |
| `SOUND_PLAN.md` | every sound effect and music track (13 effects, tracks, how to change them) |
| `SOUND_PIPELINE_PLAN.md` | PLAN ONLY: routes for using other sounds (none of the new tools exist yet) |
| `BOARD_TEST_STEPS.md` | exact Vivado + board steps and the numbered board checks (none confirmed except the USB keyboard) |
| `BOARD_DAY.md` | Thai board-day checklist (build, timing, mic test project, what to send back) |
| `NEXT_STEPS.md` | backlog by priority |
| `PROGRESS.md` | original Thai P0-P7 phase checklist (historical, with a 23/11 status note) |
| `CHANGE_REVIEW.md` | what changed and how it was verified (newest entry first) |
| `DESIGN_PLAN.md` | master design W1-W46 + FUTURE BACKLOG (original text kept, status per section) |
| `DOC_UPDATE_REPORT.md` | report of the 23/11 documentation refresh: wrong facts, comment edits, open decisions |
| `archive/SPRITE_PLAN.md` | old sprite plan (history only) |
| `audio/*.wav` | sample recordings from the Verilator run (`WAVS=1 ./scripts/run_full_game.sh`) |
| `*.png` | pictures from simulation (`p2_` .. `p6t_`, `*_preview`, `verilator_screen`); most were taken before W19-W46 and may not match the current look |
