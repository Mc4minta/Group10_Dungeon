# Change review - branch `sprite-zip` (review before the next push / any merge)

Generated while work is in progress. Nothing is merged to `main`. Remote branches already pushed: `sprite-pipeline` (up to `372da50`),
`sprite-zip` (up to `6263b47`). **Uncommitted work (section 3) is NOT on GitHub yet.**

Rules that every change below follows: Rule 1 (the game always builds; missing/invalid art falls back to the old art with a warning),
no game-logic change (no Verilog edited at all), `*_v1` backups never edited, `mem/*.mem` are generated from config + art.

---

## 1. What changed, in one table

| Area | Source of truth (you edit) | Generated (do not edit) | Old art backup | Build command |
|---|---|---|---|---|
| Player (forms 1-3 new art, form 4 old) | `my_asset/Character/*`, `sprites/sprites.json` | `mem/player.mem` | `mem/player_v1.mem` | `python scripts/build_player_mem.py` |
| Map tiles | `my_asset/tileset/Dungeon_Tileset.png`, `sprites/tileset.json` | `mem/tileset.mem` | `mem/tileset_v1.mem` | `python scripts/build_tileset_mem.py` |
| Enemies (A skeleton1, B vampire) | `my_asset/enemies/*`, `sprites/monsters.json` | `mem/monster.mem` | `mem/monster_v1.mem` | `python scripts/build_monster_mem.py` |
| Bosses (2x exact scale) | `my_asset/enemies/*`, `sprites/bosses.json` | `mem/boss.mem` | `mem/boss_v1.mem` | `python scripts/build_boss_mem.py` |
| Map decoration (uncommitted) | `maps/*.txt`, `scripts/build_maps.py` | `mem/tilemap.mem` (+ unchanged objects/monsters/puzzle layout) | `maps_v1/` | `python scripts/build_maps.py` |

All of it in one go: `scripts/update_sprites.sh` (Windows: `scripts\update_sprites.bat`) = build + previews + iverilog ROM checks + python tests.
Every builder has `--check` (validate only) and `--preview` (writes `preview/`).

---

## 2. Commits already pushed (oldest first)

| Commit | What |
|---|---|
| `8485fca` | Player pipeline v1: config, build script, fallbacks, tests, `tb_sprites.v`, helpers, README, plan doc |
| `372da50` | Art added to the repo: `my_asset/Character/*`, earlier `form1-3.png`, the two asset zips (unused originals) |
| `40b27c3` | Player pipeline v2: multi-sheet config, idle chain (`Idle.png` col 0, else Walk col 0), labelled source sheets, colour + bounding-box reports, 24 tests |
| `a209e29` | Tileset pipeline (16x16 cells scaled exactly 2x), previews, 19 tests, `tb_tileset.v` |
| `786521d` | Monster pipeline (A = skeleton1 move cols 1,4; B = vampire idle cols 0,3), 17 tests, `tb_monster.v` |
| `6263b47` | Boss pipeline (32x32 -> 64x64 exact 2x; boss1 skeleton2, boss2 skeleton1 + damage frame as stunned, boss3 vampire attack), 17 tests, `tb_bosssprites.v` |

Not changed anywhere: `rtl/*.v` (no Verilog), `constraints/`, game parameters, FSM, timing.
Only existing file touched outside art/pipeline: `scripts/run_sim.sh` (new targets `sprites`, `tileset`, `monster`, `bosssprites`; `all` unchanged), `.gitignore`, `README.md` (one pointer line).

---

## 3. Uncommitted work in the working tree (review this before it is committed)

| File | Change |
|---|---|
| `maps/00,03,04,05,06,07,08_*.txt` | Decoration characters added in place of plain floor: `,` crack, `;` bones, `:` skull, `` ` `` rubble (75 tiles in total). No wall, door, spawn, enemy, puzzle object or exit moved. |
| `scripts/build_maps.py` | New decoration characters map to tile ids 12-15 (C-F). Refuses decoration in rooms where it is unsafe (see below). Rest unchanged. |
| `mem/tilemap.mem` | Regenerated (differs from the old file only at the 75 decoration tiles, each was plain floor `1`). |
| `scripts/build_tileset_mem.py` | New per-floor `gain` (brightness) and per-tile `recolor`/`gain`; preview draws each room with its own floor art. |
| `sprites/tileset.json` | Floor tile now the plain cell (r2 c3, the old one had a dark stripe on top); floors 1/2/3 `gain 1.7`, recolor `rgb` / `gbr` / `brg`; decoration art for ids 12-15 on floors 1-2 (`f1.t12`..`f2.t15`); Simon plates on floor 3 keep their real colours. |
| `mem/tileset.mem` | Regenerated from the above. |
| `tests/test_maps.py` (new) | 7 tests: objects.txt, monsters.mem, puzzle_layout.vh byte-identical to `maps_v1/`; tilemap equals the old one except plain-floor -> decoration; decoration only in allowed rooms; Sokoban room untouched and solvable; `build_maps.py` reproducible. |
| `tests/test_tileset_pipeline.py` | Updated for gain/recolor per tile and for floor 3 Simon plates. |
| `maps_v1/`, `scripts/build_maps_v1.py` (new) | Backups of the 13 maps, the old generated files and the old build script. |
| `scripts/vivado_synth.tcl` (new) | Batch synthesis + utilization/timing report. Not run yet (planned after the 22:00 freeze). |
| `sprites/README.md` | Sections for map look, enemies, bosses. |

### Why decoration uses tile ids 12-15 and why only some rooms
The tilemap stores a 4-bit id and all 16 ids are in use. Ids 12-15 are the Simon plates, but the game treats them exactly like floor
(player `pass()`, monster `mpass()`, bullet `bpass()`) except inside the Simon puzzle. So on floors 1-2 they can carry decoration art with no Verilog change.
They are NOT allowed in: rooms 01 / 10 / 11 (floor 3 art = Simon plates), room 02 (boss room used on floors 1 and 3), room 09 (Sokoban: boxes only push onto floor/plate tiles),
room 12 (Simon). `build_maps.py` raises an error if a decoration character appears there, and `tests/test_maps.py` checks it.
Walls have a single id, so wall variety / torches on walls would need a Verilog (renderer) change: not done.

---

## 4. Verification status

| Check | Result |
|---|---|
| All existing iverilog testbenches (`run_sim.sh all`), player art only | ALL OK (same as the baseline with the old art) |
| `run_sim.sh all` with player + tileset + monsters + bosses | ALL OK |
| Verilator full game to WIN, player art only | WIN (state 5, 9900 frames) |
| Verilator full game to WIN, new tileset (+ player art) | WIN ("YOU WIN 02:43" on the last screenshot) |
| Python tests: player 24, tileset 19, monsters 17, bosses 17, maps 7 | all pass |
| Fallback drill on the real tree (`tests/fallback_drill.sh`: sheet renamed, transparent cell, wrong-size 100x100, too-small sheet) | PASS: build exit 0 with warnings each time, 49152 lines, iverilog sprite test PASS, headless game ran 120 frames; art and `mem/player.mem` restored byte-identical |
| `run_sim.sh all` with decorated maps + all new art | ALL OK |
| Full WIN with decorated maps + ALL new art (player, tiles, enemies, bosses) | PASS: final state 5 (WIN) at frame 9899, exit 0; screenshots in `preview/game/after_montage.png` |
| `solve_sokoban.py` after the map change | solvable, 24 pushes (room unchanged) |
| Combined WIN run with ALL art, old maps | PASS: `preview/game/all_win.png` shows YOU WIN 02:43 |
| Vivado 2024.2 synthesis (BRAM, WNS) | planned after the 22:00 freeze |
| Merge test into `board-prep`, tag `pre-sprite-zip` | not done (only just before a merge you approve) |

---

## 5. Things I saw in the screenshots (honest notes)

1. **The new player sprites are small**: the drawn character is about 8x8 pixels inside the 32x32 cell (bounding box x 12-19, y 11-18 for the Human), the old placeholders were about 20 px.
   They are correct, just small on the 640x480 screen. Angel is wider (wings, x 5-26) but still inside the hitbox area 4-27. Nothing was changed.
2. **Row convention**: rows 3-4 (back) are clearly plain, rows 1-2 (front) have the face, so front/back is right. Right vs left cannot be judged at 8 px; please check the 4 facings in `preview/game/montage.png`.
   Row 4 (back facing Left) is not used by the default mapping (the game has no separate back-left).
3. **Bosses are drawn smaller** inside the 64x64 box (about 40x40 px of art) than the old blobs; boss 2 "stunned" = the skeleton damage frame (less obvious than the old grey X-eyes).
4. **Colour**: RGB444 merges no colours in any player/enemy/boss sheet (6-13 colours each), so no banding. SoulDie (unused) would merge 32 -> 21.
5. Floor 1/2/3 were recoloured (purple / teal / olive) and brightened (gain 1.7) so rooms read clearly. Doors are bright orange/violet on purpose (high contrast).
6. Decoration is subtle by design (cracks very faint, bones/skull/rubble small in corners and beside pillars).
7. Pressure-plate tile (7) is a flat brown square (the pack has no detailed plate); tb_tileset reports it as a NOTE.
8. Form 4 still uses the old placeholder art (no art yet): it falls back, with a single warning line.

Nothing fell back to old art except form 4 (no art configured). Monsters, bosses, tiles and forms 1-3 are 100% new art.

---

## 6. Risks / what to look at when reviewing

- `mem/*.mem` diffs are huge (generated). Review the configs and scripts, not the .mem lines. Regenerate to confirm: `python scripts/build_player_mem.py && python scripts/build_tileset_mem.py && python scripts/build_monster_mem.py && python scripts/build_boss_mem.py && python scripts/build_maps.py && git status` should show no change.
- `scripts/make_placeholders.py` still overwrites `player.mem`, `tileset.mem`, `monster.mem`, `boss.mem`: do not run it (rebuild fixes it).
- Line endings: the repo uses autocrlf, files in the working tree are CRLF; mem files keep the CRLF/LF style of their `*_v1` copy.
- Vivado: `create_project.tcl` globs `rtl/*.v` and `mem/*.mem`, so new/changed mem files are picked up automatically. BRAM is unchanged by design (same sizes: player 49152, tileset 49152, monster 4096, boss 32768 words).
- The two asset zips (about 300 KB) are committed under `my_asset/` for later use; remove them if you do not want binaries in the repo.

## 7. How to review quickly

    git log --oneline origin/board-prep..HEAD
    git diff --stat origin/board-prep..HEAD -- . ':!mem' ':!picture' ':!preview'
    python tests/test_sprite_pipeline.py && python tests/test_tileset_pipeline.py && python tests/test_monster_pipeline.py && python tests/test_boss_pipeline.py && python tests/test_maps.py
    scripts/update_sprites.sh                      # builds everything + previews + ROM checks
    # then look at: preview/all_forms.png  preview/tileset_all_floors.png  preview/tileset_rooms.png  preview/monster_contact.png  preview/boss_contact.png  preview/game/montage.png

## 8. Rollback

| Want to undo | Command |
|---|---|
| All new art at once | `cp mem/player_v1.mem mem/player.mem; cp mem/tileset_v1.mem mem/tileset.mem; cp mem/monster_v1.mem mem/monster.mem; cp mem/boss_v1.mem mem/boss.mem` |
| Map decoration only | `cp maps_v1/[0-9]*.txt maps/ && cp scripts/build_maps_v1.py scripts/build_maps.py && python scripts/build_maps.py` (and set floor `gain` to 1.0 in `sprites/tileset.json`) |
| One form / floor / monster / boss | set `"enabled": false` in its config and rebuild |
| Whole branch | `git checkout board-prep` (nothing was merged) |

## 9. Board steps (once approved)

1. `git checkout sprite-zip` and run `python scripts/build_player_mem.py && python scripts/build_tileset_mem.py && python scripts/build_monster_mem.py && python scripts/build_boss_mem.py && python scripts/build_maps.py` (should change nothing).
2. `vivado -mode batch -source scripts/create_project.tcl -tclargs build` (or open the project and run synthesis/implementation/bitstream; the .mem files are picked up from `mem/`).
3. Program the Nexys A7-100T. On the VGA screen look for: title screen; floor 1 purple with bones/skulls in corners; skeleton (A) walking at you and vampire (B) turret; evolve to the green Orc, then the winged Angel; floor 2 teal; floor 3 olive with coloured Simon plates; bosses (skeleton2, skeleton1, vampire); form 4 still the old gold placeholder.
4. If anything looks wrong: use the rollback table above, rebuild, resynthesize.

---

## 10. UPDATE - later commits (all local, not pushed; `origin/sprite-zip` is still at `6263b47`)

| Commit | What |
|---|---|
| `7999012` | Map decoration, per-floor brightness/recolor, `maps_v1/` backup, `tests/test_maps.py` |
| `5f3f917` | Face lock: after tapping BTNC the facing is locked for `FACE_LOCK_FRAMES` (24) frames, so you can attack and step back one-handed. New `rtl/face_lock.v` (+ `sim/tb_facelock.v`), `top.v` drives `hold_facing` with `bc | face_lock`. This is the ONLY RTL change in the whole branch. 0 turns it off. |
| `5ea54da` | Per-form exact integer `scale`: Human and Orc 2x, Angel 1x (wings would be cut off at 2x) |
| `f82ce7b` | Form 4 = Human sheets recoloured gold (luminance `tint`) at 2x; puzzle-room objects pipeline (`sprites/puzzle.json`, `mem/puzzle.mem`): torch bulbs, chest levers, crate, spikes gate, keys/shield items |

Tag `board-test-1` = `f82ce7b` (the version to put on the board; known good).

Verification of `f82ce7b`: `run_sim.sh all` ALL OK; full WIN run with all art: PASS (state 5 at frame 9899). Python tests: player 29, tileset 19, monsters 17, bosses 17, puzzle 15, maps 7.
Caveat: the Verilator binary used for the WIN run is the prebuilt one (old RTL, reads the new `mem/*.mem` at start); the face-lock RTL is covered by `iverilog` (`tb_facelock`, `tb_top`, `all`) but not by Verilator.
Bullets (`bullet.mem`) and the melee slash (`effect.mem`) keep the old art: the pack has nothing that fits an 8x8 bullet hitbox or a directional slash.
Backlog: `docs/NEXT_STEPS.md`.
