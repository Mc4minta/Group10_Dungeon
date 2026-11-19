# Project guide - start here

Group 10 Dungeon: a VGA dungeon game in Verilog for the Nexys A7-100T (Vivado 2024.2), with a Python pipeline that builds all art, map and music ROMs from files you edit.
This page is the index. Last full refresh: branch `sprite-zip`, tag `board-test-2`.

## 1. Which document do I read?

| I want to... | Read |
|---|---|
| **Build and test on the board** (exact Vivado steps, what to check, rollback) | `docs/BOARD_TEST_STEPS.md` |
| **See which sprites are final / placeholder / missing** and what I still have to draw or find | `docs/SPRITE_STATUS.md` |
| **Change a sprite, tile, enemy, boss, map decoration** | `sprites/README.md` |
| **See every sound and the music**, change them, or learn how to use an MP3 | `docs/SOUND_PLAN.md`, `docs/SOUND_PIPELINE_PLAN.md` |
| **See what changed on this branch** (all features, how they were verified, risks) | `docs/CHANGE_REVIEW.md` |
| **Know what to do next** (backlog by priority) | `docs/NEXT_STEPS.md` |
| **The master design (bosses, forms, endgame) and the plan to implement it** (not implemented yet) | `docs/DESIGN_PLAN.md` |
| **Game rules, buttons, simulation, original design** (Thai) | `README.md` (root), `docs/PROGRESS.md`, `docs/BOARD_DAY.md` |
| **Old plan documents** (history only) | `docs/archive/` |

## 2. Folder map

| Folder | What is in it | Edit it? |
|---|---|---|
| `rtl/` | the game in Verilog (`top.v`, `player.v`, `objects.v`, `renderer.v`, `audio.v`, ...). Files ending `_cfg.vh` and `bgm_cfg.vh` are **generated** | yes, but every change needs `scripts/check_all.sh` |
| `my_asset/` | your art: `Character/`, `enemies/`, `props/`, `tileset/`, `new_switch.png`, the two asset zips | **yes** (source of truth) |
| `my_audio/` | your source audio (mp3 / wav). **Not committed** (ignored) | yes |
| `sprites/` | the settings: `sprites.json` (player), `tileset.json`, `monsters.json`, `bosses.json`, `puzzle.json`, `music.json`, `music/*.txt` | **yes** |
| `maps/` | the 13 room layouts (text). `maps_v1/` = untouched originals | yes (carefully, see sprites/README.md) |
| `mem/` | **generated** ROM files (`player.mem`, `tileset.mem`, `music.mem`, ...) and the `*_v1.mem` backups of the original art (never edit) | **no** |
| `scripts/` | the builders (`build_*_mem.py`, `make_music.py`, `audio_to_music.py`, `build_maps.py`), `check_all.sh`, `run_sim.sh`, Vivado Tcl | run them |
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
| `main` | the last team-approved version (before the art / sound work). Not updated yet: merge only when the owner says so |
| `board-prep` | the version before the sprite work (base of everything below) |
| **`sprite-zip`** | **the development line: everything finished and tested is here (art, map, enemies, bosses, puzzle, difficulty, controls, sound, music, animations OFF)** |
| `wip/wall-variants` | unfinished work kept on purpose: room-border wall pictures. Read `docs/wip/README.md` on that branch to resume |
| tag `board-test-2` | the build for the board: RTL, `mem/` and art are identical to `sprite-zip`; commits after the tag only change docs and helper scripts |
| tag `board-test-1` | the earlier known-good build (rollback target) |
| tags `archive/p2-game-fsm` ... `archive/p6-tweaks` | the old phase branches of the first version, kept as tags (all merged) |

Rule for new work: branch from `sprite-zip` (`git checkout -b feature/<name>`), keep the branch small, merge it back into `sprite-zip` after `scripts/check_all.sh` passes, then delete the branch.

## 5. What exists / what does not (one line each)

- Art: player forms 1-3 real, form 4 = gold recolour of the Human (placeholder), tiles, 2 enemies, 3 bosses, puzzle objects: see `docs/SPRITE_STATUS.md`.
- Gameplay changes from the original: HP 4 (forms 1-2), invulnerable 90 frames, chasing monster at half speed, BTNC face lock, SW14 facing lock, screen shake when hit, two new sound effects, Connect melody as BGM on floors 1-3.
- Built but switched OFF (need Block RAM, flags in `sprites/sprites.json` -> `animations`): Human idle / attack / hurt / death animations.
- Not built: wall variants (WIP branch), sample playback, story screens, third enemy type, bullet / slash art.
