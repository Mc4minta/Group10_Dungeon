# Next steps (backlog)

Status 23/11/2026 (docs refreshed against the code): the items under "Design plan items" below are ALL DONE (sim) - see `docs/DESIGN_PLAN.md`; the open work is the P1 list plus timing (local Vivado run of 22/11: WNS -4.045 ns / TNS -2904.290 ns (timing NOT met, 1853 failing endpoints) and Block RAM Tile 103.5 / 135, from the local git-ignored Vivado run of 22/11/2026 (`vivado/Group10_Dungeon.runs/impl_1/top_timing_summary_routed.rpt`, `top_utilization_placed.rpt`; the source commit of that run is not recorded)). Original text follows. (Names such as `scripts/audio_to_sfx.py` and `scripts/midi_to_music.py` are PLANNED, not built; `docs/wip/README.md` exists only inside the git tag `archive/wip-wall-variants`.) Current state (21/11): branches `dev` = `main` (everything up to W46 is merged; W1-W46 in `docs/DESIGN_PLAN.md`), tag `board-test-2` (an older board build). Everything listed under "Done" is merged and tested
(`scripts/check_all.sh`: all Python tests + the full iverilog suite). Board status: the first builds ran on the Nexys A7 (USB keyboard confirmed); everything from W19 onwards still needs the board checks in `docs/BOARD_TEST_STEPS.md` (items 6b-6f). The single list of open work is the **FUTURE BACKLOG** table in `docs/DESIGN_PLAN.md`.
Tick `[x]` when an item is done and update `docs/SPRITE_STATUS.md` / `docs/SOUND_PLAN.md` in the same commit.

---

## Done (for reference)

| Area | What | Where to read |
|---|---|---|
| Art pipeline | player forms 1-3 (Human / Orc / Angel 2x), form 4 = gold Human, tileset (3 floors recoloured), enemies, 3 bosses, puzzle objects, new lever, map decoration | `docs/SPRITE_STATUS.md`, `sprites/README.md` |
| Folder rename | `picture/` is now `my_asset/` (all paths updated) | `docs/README.md` |
| Difficulty (easier) | HP 4 on all four forms, 90 invulnerable frames, chasers at half speed | `docs/BOARD_TEST_STEPS.md` |
| Controls / feel | BTNC face lock, SW12 facing lock (was SW14), screen shake on hit | `docs/BOARD_TEST_STEPS.md` |
| Sound | 13 sound effects, music ROM of 8 tracks (Connect = track 6 on floors 1-3), `audio_to_music.py` | `docs/SOUND_PLAN.md` |
| Hitbox | player can only be HURT inside a centred 16x16 box (`HURT_BOX` in `rtl/params.vh`, was 24x24); walking collision unchanged | `rtl/params.vh` |
| Health display | on-screen hearts (player) + health bar (boss), `hud.v`, `mem/hud.mem`, about +3 Block RAM | `docs/SPRITE_STATUS.md` section 5b |
| Animations | Human idle / attack / hurt / death built, **OFF by default** (flags in `sprites.json`) | item P3.1 below |
| Tooling | `scripts/check_all.sh`, one-command rebuild + preview `scripts/update_sprites.sh`, 8 Python test suites, iverilog suite | `docs/README.md` |

---

## P1 - needs YOU (nothing else can move until these are done)

- [ ] **P1.1 Board test (board: not tested except the USB keyboard).** Timing is a known failure in the 22/11 local run: WNS -4.045 ns / TNS -2904.290 ns (timing NOT met, 1853 failing endpoints) and Block RAM Tile 103.5 / 135, from the local git-ignored Vivado run of 22/11/2026 (`vivado/Group10_Dungeon.runs/impl_1/top_timing_summary_routed.rpt`, `top_utilization_placed.rpt`; the source commit of that run is not recorded).  Follow `docs/BOARD_TEST_STEPS.md`. Send me: Block RAM Tile and WNS from the Vivado reports, and how the game feels (difficulty, the song, the controls, the sprite sizes).
- [ ] **P1.2 Listen to the music.** `preview/sound/connect_chiptune.wav` (made by the tool; I cannot hear it). If the melody is wrong, tell me the problem (too low / noisy / wrong rhythm) and I tune the `scripts/audio_to_music.py` options.
- [ ] **P1.3 Story:** send the script (where text appears, how many lines, language, pictures?). See P2.4.
- [ ] **P1.4 Sound wishes:** answer the questions in `docs/SOUND_PIPELINE_PLAN.md` section 6.
- [ ] **P1.5 Art to find or draw** (full list in `docs/SPRITE_STATUS.md` section 1): real form 4 hero, bullets (8x8), melee slash (4 arcs), a lever pair that is easier to tell apart, optional Angel redraw, optional title / win / game over pictures.
- [ ] **P1.6 Check the GitHub repository visibility** (the Connect melody is in `mem/music.mem` and `sprites/music/connect.txt`).

## P2 - I can do without Verilog (as soon as you send the input)

- [ ] **P2.1 Bullet and slash pipelines** (`bullet.mem` 8x8 art, `effect.mem` 4 arcs): same pattern as the other pipelines (config, backup, fallback, previews, tests). Needs your art.
- [ ] **P2.2 SFX fit tool** (`scripts/audio_to_sfx.py`): a short sound clip becomes the three numbers of a sound effect (`docs/SOUND_PIPELINE_PLAN.md` route 1).
- [ ] **P2.3 More music tools:** `scripts/midi_to_music.py` for MIDI files; more custom tracks need a small ROM change (see P3.5).
- [ ] **P2.4 Story on the existing screens** (title, floor clear, win, game over): text in `mem/text.mem` with the 8x8 font, at most 2 lines per screen (`rtl/text_layout.vh`).
- [ ] **P2.5 Difficulty tuning from your playtest:** `rtl/params.vh` (`HP1`, `HP2`, `INV_FRAMES`, `MON_A_MOVE_EVERY`, `FACE_LOCK_FRAMES`, `HURT_SHAKE_FRAMES`, `MON_A_HP`).
- [ ] **P2.6 Final report for the course** (files, commands, rollback, board steps): `docs/CHANGE_REVIEW.md` is the base.

## P3 - needs Verilog (each on its own branch from `sprite-zip`, merged only after `scripts/check_all.sh` and a Vivado build)

- [ ] **P3.1 Switch the remaining Human animations ON** (the attack animation is already ON since W35; idle / hurt / death still OFF). Set the flags you want in `sprites/sprites.json` -> `animations`, run `python scripts/build_player_mem.py` (regenerates `rtl/sprite_cfg.vh`), synthesise. Block RAM cost about 22 (idle) / 6 (attack) / 6 (hurt) / 6 (death) RAMB36: check the utilization report first (135 available). The frame selection is tested (`./scripts/run_sim.sh playerframe`); the whole system passes with all flags ON (`./scripts/run_sim.sh topanim`).
- [ ] **P3.2 Wall variants** (room-border wall pictures + wall torches): branch `wip/wall-variants`, read `docs/wip/README.md` there; about +6 RAMB36.
- [ ] **P3.3 Sample playback** for short real recordings (voice, roar): sample player + mixer + converter (`docs/SOUND_PIPELINE_PLAN.md` route 3); about 2 RAMB36 per second of sound.
- [ ] **P3.4 Story screens** with their own FSM state (only if the existing screens are not enough).
- [ ] **P3.5 More music tracks:** the ROM has one custom slot (track 6); more need a bigger ROM and a track rule in `top.v`.
- [ ] **P3.6 Feedback polish:** brighter evolve flash. **Third enemy type:** deliberately not done (new state bits in `objects.v`, more monster frames, and it makes the game harder).
- [ ] **P3.7 Form 4 charge shot art** from `ChargedAttack.png` (the charge loop while the button is held).

## Design plan items (19/11 design notes) - status 23/11: ALL DONE (sim), see `docs/DESIGN_PLAN.md`; the old unchecked boxes below are kept as history

- [x] (done, sim) **Was waiting for approval (20/11):** W28 tutorial, W29 title CONTROLS / CREDITS pages, W31 story freezes play, W32 hint strip, W33 intro skip, W34 input edge cases (designed in `docs/DESIGN_PLAN.md`, review table in `docs/GAMEPLAY_REVIEW.md`).
- [x] (done, sim) **Phase A (small):** W15 SW15 = pause / SW14 = sprint / facing lock -> SW12, W1 door = spike trap, W2 pressure plate (DONE), W3 charged shot stops on hit (DONE), W4 clap on the board (mic debug), W6 new start screen, W9a prologue screen.
- [x] (done, sim) **Phase B (bosses):** W10 boss 1 fast + clap stun, W11 boss 2 summon (hurt only when all minions are dead), W12 boss 3 armour + charge + big attack, W13 form 3 AOE split.
- [x] (done, sim) **Phase C:** W5 breakable block, trap, solid decoration (overlay layer). **Phase D:** W7 key -> door -> Ball in a Maze (accelerometer) -> WIN. **Phase E:** W9b story.
- [x] W8 hearts + boss bar (done).
- Answer the defaults in `docs/DESIGN_PLAN.md` section 6 first.

## Housekeeping (small)

- [x] Done 21/11: `dev` merged into `main` (`3e908a3`); branch `sprite-zip` is historical.
- [ ] Keep `docs/SPRITE_STATUS.md` and `docs/SOUND_PLAN.md` current with every art / sound change (a standing rule).
- [ ] Repeat the Verilator full-game run (`scripts/run_full_game.sh`) on a machine that has Verilator and SDL2 (`cd sim/verilator && make seeded`); the machine used so far could not rebuild it, so the last WIN run did not include the newest RTL (face lock, tuning, SW14, music).

## Rules for every item

Rule 1 (the game always builds; missing or invalid art / sound falls back with a warning), `*_v1.mem` backups never edited, `mem/*.mem` are generated, branch from `sprite-zip`,
run `scripts/check_all.sh` before committing, no merge to `main` without an explicit "merge", nothing with a deadline risk goes in after the freeze.

Standing rules (owner, 19/11): **every implementation updates `docs/FEATURES.md` in the same commit**; **every new idea is written into `docs/DESIGN_PLAN.md` first** and implemented only after the owner approves.

- [ ] **FUTURE BACKLOG (20/11):** the single list of everything still open is the table `FUTURE BACKLOG` in `docs/DESIGN_PLAN.md` (waves, harder bosses, hitboxes, retry panel, smarter enemies, room redraws, credits, board tests).
