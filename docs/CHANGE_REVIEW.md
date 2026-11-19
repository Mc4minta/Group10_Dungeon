# Change review - everything on branch `sprite-zip` compared with `main`

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
| SW14 up = facing locked all the time | `rtl/top.v` | - |
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
| Verilator full game to WIN | last passed on the commit before the tuning / face lock / SW14 / music RTL changes (screenshots in `preview/game`); NOT repeated on the newest RTL because Verilator cannot be rebuilt on the build machine |
| Vivado synthesis and board run | pending: the owner builds in the GUI (`docs/BOARD_TEST_STEPS.md`); Block RAM and WNS numbers are still to be recorded |

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
