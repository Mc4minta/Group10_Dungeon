> **Archived reference.** This is the previous root `README.md` (state of 23/11/2026), kept for its detailed tables (combat values, sound list, simulator options).
> The root `README.md` is the current overview; where the two differ, the code and the root README take precedence.

# Group10_Dungeon — THE CHOSEN ONE (game name on screen; folder = Group10_Dungeon)

A dungeon crawler with puzzle rooms for the Digilent Nexys A7-100T, VGA 640×480 @ 60 Hz, Verilog (Vivado 2024.2)
This document was updated from the real code on 23/11/2026 (branch `dev` = `main` at commit `3e908a3`). Documentation update report: `docs/DOC_UPDATE_REPORT.md`

Status words: **sim** = verified with a testbench / script · **board** = tried on the real Nexys A7 board · **board: not tested** = not tried yet

## Current status — read this first

The game can be played from TITLE to WIN **in simulation (sim)**. What is confirmed on the real board (board) is only what is recorded in `docs/BOARD_TEST_STEPS.md`: **the USB keyboard works** (notes of the project owner, 20-21/11). Everything else is **board: not tested**.

What the game has (details: `docs/FEATURES.md`, how to play: `docs/CONTROLS.md`):

* **Game states** (`rtl/game_fsm.v`): TITLE → PROLOGUE (4 black-screen pages, BTNC = next page, or 6 s per page) → PLAY → EVOLVE (60 frames) → FLOOR_CLEAR (120 frames) → … → ESCAPE (= Ball in a Maze 60 s, tilt the board (ADXL362) or use the buttons) → WIN · death or time out = GAME_OVER (BTNC = retry the floor where the hero died, BTNL = TITLE) · **PAUSE is not a state**: SW15 or the P/Esc key gates the frame tick during PLAY/ESCAPE
* **Map:** 3 floors × 5 room roles (START, Combat 1, Combat 2, Puzzle, Boss) = **15 rooms visited in play**, using **13 ASCII map files** (`maps/00..12`; START of floors 1+2 uses the same map, and BOSS of floors 1+3 uses the same map)
* **4 forms** (melee swing / shot / 3-way spread that splits on hit / fast shot + charged big ball), auto aim (on by default), timed spike traps, breakable crates, pits, hint strip + tutorial, story boxes that pause the game, title pages (SETTINGS / CONTROLS / CREDITS)
* **3 bosses with a second phase ("rage" at low HP):** boss 1 (HP 10, clap/SW11/key C = stunned for 3 s), boss 2 (HP 16, stands in the middle of a fence box, summons minions, can be hit when all minions are dead), boss 3 (HP 9, armour: hurt only by the charged shot of form 4 except while it rests, charges for 4 s, then a 2 s bullet storm) — boss 3 dead = get the key → door E at START of floor 3 → ESCAPE
* **Inputs:** board buttons/switches **and** a USB keyboard (PS/2 through USB-HID) at the same time · PDM microphone (clap) · ADXL362 accelerometer (maze)
* **Sound:** 13 SFX + Simon notes + BGM (floors 1-3 use the same track 6, ESCAPE, WIN / GAME OVER jingles) — output on `AUD_PWM`; **board: not tested** (the `AUD_SD` level is not confirmed against the manual)
* **Real build:** local Vivado run of 22/11/2026 (`vivado/` is git-ignored, not in git). Report: Block RAM Tile **103.5 / 135**, Slice LUT 18,182 / 63,400, **WNS −4.045 ns (timing not met at 100 MHz, 1853 failing endpoints)**, see "Known gaps" — it is not known which commit that run came from

**Branch:** `main` and `dev` = the same commit (`3e908a3`) · new work goes to `dev` first, to `main` when the owner says "merge" · tag `board-test-2` = an older board build

## Known gaps (not done / not confirmed)

1. **Not tested on the board** except the USB keyboard: screen/picture does not shift, sound, microphone (clap), tilt maze (axis direction), all buttons/switches after W19 — checklist in `docs/BOARD_TEST_STEPS.md` (items 6b–6f, 7)
2. **Timing is not met in the latest run whose files are on this machine:** `vivado/Group10_Dungeon.runs/impl_1/top_timing_summary_routed.rpt` (22/11) WNS −4.045 ns, TNS −2904.290 ns; worst path `pz/b0x_reg[1]` → `rnd/a_bb_reg[11]` (the text address in `renderer.v`) · this file is not in git, so it must be run again after any fix. Timing has not been fixed yet
3. `tb_puzzles`: the old documents recorded that the lever-XOR check fails, but a rerun on 23/11 (Icarus 13.0, WSL) gave 42 checks, errors = 0 and the line "16 lever subsets give 16 different XOR results" = PASS — it currently **does not fail** (sim)
4. `DEBUG` in `rtl/top.v` has the default value **1** (SW0–SW4 are cheat switches) — **the hand-in build must set `DEBUG = 0`**; at the moment `create_project.tcl` does not set the generic
5. The Verilator `sim/verilator/Makefile` passes `-GPROLOGUE=$(PROLOGUE_V)` but `PROLOGUE_V` is never defined (empty value), and `sim/verilator/scripts/full_game.txt` was written for `PROLOGUE=0` — see "Needs a human decision" in `docs/DOC_UPDATE_REPORT.md`; the latest full-game run (to WIN) was not rerun on the latest code in this documentation pass
6. Story/credits text on screen is partly placeholder; art that is not final: see `docs/SPRITE_STATUS.md`; wall variants / sample playback are not done (planned)
7. Most `docs/*.png` pictures were taken before the W19–W46 work (for example `p5_*.png`, `p4_*.png`) and may not match the current look of the game — they were not regenerated
8. The song "Connect" is a copyrighted song (the melody is in `mem/music.mem`, `sprites/music/connect.txt`) — check whether the repo is public before sharing

## Quick start for the art / map / sound pipelines (English)

The sprites, tiles, enemies, bosses, puzzle objects, maps and music are generated from files you edit (`my_asset/`, `my_audio/` (not committed), `sprites/*.json`, `maps/*.txt`).
**Start with `docs/README.md`** (index, folder map, workflow, branches). Handy commands:

| What | Command |
|---|---|
| Rebuild all art + previews | `scripts/update_sprites.sh` (Windows: `scripts\update_sprites.bat`) |
| Check everything before a commit | `scripts/check_all.sh` (`--fast` = no iverilog suite) |
| Build and test on the board | `docs/BOARD_TEST_STEPS.md`, `docs/BOARD_DAY.md` |
| Which sprites are final / still needed | `docs/SPRITE_STATUS.md` |
| Sounds and music | `docs/SOUND_PLAN.md` |
| What to do next | `docs/NEXT_STEPS.md` |

## Getting started (build for the board)

1. Install Vivado 2024.2, then open a terminal in this folder
2. Create the project:
   ```
   vivado -mode batch -source scripts/create_project.tcl
   ```
   or in the Vivado GUI: **Tools → Run Tcl Script…** and choose `scripts/create_project.tcl`
3. Open `vivado/Group10_Dungeon.xpr` → Generate Bitstream → Program Device
   (or build in one step: `vivado -mode batch -source scripts/create_project.tcl -tclargs build`)
4. Connect a VGA monitor and speakers/headphones to the AUDIO OUT jack, then play
5. **Before the hand-in build:** set `parameter DEBUG = 0` in `rtl/top.v` (the default is currently 1)

Board day: [`docs/BOARD_DAY.md`](docs/BOARD_DAY.md) (separate microphone test: `scripts/create_mic_project.tcl`) · before the first build, compare the pins in `constraints/nexys_a7.xdc` with Digilent's Master XDC once more

## Buttons / switches / keyboard (according to the code `rtl/top.v`, `rtl/ps2_kbd.v`)

Full player guide: **`docs/CONTROLS.md`**

| Device | Keyboard | What it does |
| --- | --- | --- |
| BTNU/D/L/R | Arrow keys / WASD | Walk (2 buttons = diagonal; opposite directions cancel) |
| BTNC | Space / J / Enter | Start the game (TITLE) · attack (PLAY) · close a story box · WIN = back to TITLE · GAME OVER = retry the floor where the hero died |
| BTNL (during GAME OVER) | Left arrow | Back to TITLE |
| BTNR / BTNL (during TITLE) | → / ← (D / A) | Next / previous page: 0 TITLE, 1 SETTINGS, 2–6 CONTROLS, 7–9 CREDITS |
| BTNU / BTND (SETTINGS) | ↑ / ↓ (W / S) | Clap level, 5 steps (default MID = 448) |
| **SW15** | **P or Esc** (toggle) | **PAUSE** — works during PLAY / ESCAPE (PAUSED screen, sound muted) |
| **SW14** | **Shift** | **sprint** +1 px/frame (`SPRINT_BONUS`), LED14 |
| SW12 | — | Hold the facing direction (strafe / step back without turning) · tapping BTNC already locks the facing for 24 frames |
| SW13 (flip up) | R | Reset the Sokoban boxes (floor 2) |
| SW9 | L (toggle) | auto aim: **on by default**, SW9 up / L = off |
| SW10 | — | Maze: use the buttons instead of the tilt sensor (automatic if the ADXL does not answer) |
| SW11 (flip up) | C | Backup clap (stun boss 1) |
| SW5–SW7 | — | Adjust the clap level (0 = use the value from the SETTINGS page, otherwise 128 × the 3-bit value) |
| SW8 | H (toggle) | Show the hit boxes (green = hero, red = monsters, orange = boss, yellow = bullets) |
| CPU_RESETN | — | Reset everything (back to TITLE, resets the clap level, full intro again) |
| PDM microphone | — | Clap = stun boss 1 (see the "microphone" item below) |
| ADXL362 | — | Tilt the board = roll the ball in ESCAPE |

The **debug** switches work only when `top.v` has `DEBUG = 1` (**default = 1** in both Vivado and Verilator) — the hand-in build must set it to 0:

| Switch | What it does (DEBUG = 1) |
| --- | --- |
| SW0 | Open the boss door L on every floor and door E (no key needed) |
| SW1 flip up | `floor_done` → FLOOR_CLEAR · during PLAY, walking into door E without the key = WIN immediately |
| SW2 flip up | Remove all monsters in the room |
| SW3 flip up | `got_item` → EVOLVE |
| SW4 flip up | `take_hit` → HP −1 (no knockback) |

### Puzzles and items

| Floor | Puzzle room | How to solve it | Item |
| --- | --- | --- | --- |
| 1 | Light Bulb | Swing at / shoot levers a–d (bottom row of the room) to toggle the 4 bulbs by the mask a = 0111, b = 1011, c = 1101, d = 1110 (bit 3 = bulb 1) until all are lit · the start pattern is random each game (SEED = 0) | Appears when solved |
| 2 | Sokoban | Walk straight into a box to push it 1 tile · boxes on both plates (2) = gate opens · if stuck, press SW13 / R · the shortest solution is 24 pushes (`scripts/solve_sokoban.py`) | Behind the gate |
| 3 | Simon | Watch the plates light up in order, then step on them in the same order, 3 rounds of length 3 / 4 / 5 · a mistake = HP −1 and the round is shown again | Appears after all 3 rounds |

Walking over the item → EVOLVE (next form, full HP) + the boss door `L` of that floor opens (LED13) · a solved puzzle / taken item stays that way after leaving the room · starting a new game from TITLE = reset everything

### Screen and LEDs

| Device | Shows |
| --- | --- |
| 7-seg | `floor - HP - mm.ss` (TITLE / PROLOGUE = `--------`); ESCAPE: the 4 right digits = countdown `ss.ff`; during PAUSE the decimal point blinks |
| LED0–3 | Direction buttons · Light Bulb room = bulbs · Simon room = rounds passed |
| LED4–7 | Monsters left (bar: ≥1 … ≥4) · boss room: LED0–7 = boss HP (8 LEDs in proportion) |
| LED8–11 | HP (one LED per HP; max 4 for every form) |
| LED12 / 13 | Room door locked / floor item taken |
| LED14 / 15 | sprint (SW14) / WIN |
| ESCAPE | All 16 LEDs blink at 4 Hz |
| RGB LED16 | Form colour green / cyan / purple / gold · white during EVOLVE |
| RGB LED17 | Red = hit (knockback + invulnerable) · **blue** blinks = the PS2_CLK line moves, **green** blinks = a keyboard byte was decoded (for checking the keyboard) |
| VGA screen | Player hearts (top left, 4 hearts), boss HP bar (top right, boss room) + boss 3 charge bar + microphone meter (boss 1 / SETTINGS page) |

### Values per form (`rtl/params.vh`)

| Form | Speed px/frame | Max HP | Damage | RGB16 | Weapon |
| --- | --- | --- | --- | --- | --- |
| 1 Human | 2 | 4 | 1 | green | Melee swing |
| 2 Orc | 2 | 4 | 1 | cyan | Fires 1 shot |
| 3 Angel | 3 | 4 | 2 | purple | 3-way spread shot (a shot that hits a monster splits into 4) |
| 4 Gold | 3 | 4 | 2 | gold | Fast shot / hold 45 frames = big ball (damage 4) |

sprint +1 px/frame for every form · invulnerable after a hit `INV_FRAMES` = 90 frames (after the knockback of 8 frames × 2 px) · hurt box 16×16 (`HURT_BOX`)

### Combat

| Item | Value (`params.vh`) |
| --- | --- |
| Melee swing | hit box 24×16 in front of the hero for 8 frames, cooldown 20 · every form can swing when an enemy is inside the box in front of the hero |
| Form 2 shot | 8×8, 4 px/frame, cooldown 15 (hold to repeat) |
| Form 3 spread | 3 shots (straight + diagonals 3 px/axis), cooldown 20, split bullets last 24 frames |
| Form 4 | tap = 6 px/frame cooldown 15 · hold 45 frames and release = big ball 16×16, 4 px/frame, damage 4, stops on hit; a growing ball appears in front of the hero while charging |
| Monster A (`S`) | HP 2, moves every 2 frames (half speed), slides along walls |
| Monster B (`T`, turret) | HP 3, fires 4 directions + 1 shot aimed at the player every 120 frames (first shot at 60, each next turret offset by 30), bullet 3 px/frame |
| Combat rooms | the doors close on entry until all monsters are dead; rooms 4, 5, 8 have 2 waves, rooms 10, 11 have 3 waves (the next wave appears 1 s after the last monster dies), room 7 has a single wave |
| Traps | floor 2: timed spikes 90 normal / 30 warning / 60 up (damage 2), safe for 60 frames after entering the room · floor 3: permanent spikes `X` (1 HP) · form 3 flies over pits/spikes |
| All numbers | `rtl/params.vh` |

### Bosses (`rtl/boss.v`, `rtl/params.vh`)

| Boss | HP | Movement | Attack | Phase 2 (rage) |
| --- | --- | --- | --- | --- |
| 1 (floor 1) | 10 | chases 1 px every 2 frames | bullet pattern every 90 frames (blinks as a warning for 20 frames); clap / SW11 / C = stunned for 180 frames, then cooldown 240 | HP ≤ 5: fires every 55 frames, moves every frame |
| 2 (floor 2) | 16 | stays in place inside the fence box | cross / X bullets every 90 frames · summons 3 minions per round · **invulnerable until all minions are dead**, then can be hit for 240 frames, then rests 75 | HP ≤ 8: fires every 60, can be hit for 180, rests 45 |
| 3 (floor 3) | **9** | chases 1 px every 2 frames | armour: hurt only by the charged shot of form 4 (1 HP per shot); chase 180 frames → charge 240 frames (a charged shot can interrupt it) → heavy bullet storm 120 frames (2 HP per bullet) → rest 120 frames (any kind of hit hurts it) | HP ≤ 3: chase 120, rest 90, denser storm (period 18) |

Boss 3 must be hit **9 times** (HP 9 drops by 1 each time); the HP bar on screen = hp / 9 in proportion, not 3 slots · touching a boss = HP −1 · sprite 64×64, hitbox 48×48 · after you enter the boss room the door closes until the boss is dead · a dead boss stays dead until a new game starts · bosses 1, 2 dead → FLOOR CLEAR; boss 3 dead → key on the room floor (walk over it to pick it up) → door E → ESCAPE

### ESCAPE (Ball in a Maze) and the microphone

* ESCAPE = a 20×15 maze (`maps/maze/maze.txt` → `mem/maze.mem`), 60 s (`ESCAPE_SECONDS`), reaching the goal = WIN, time out = GAME OVER · ADXL362 sensor over SPI (deadzone 3, `MAZE_SIGN_X/Y` = 0 after the axes were flipped in W37) — **the axis direction on the board is not confirmed (board: not tested)**
* PDM microphone: `M_CLK` 2.5 MHz, count every 4096 samples, check the peak of |block − DC| (W4) > `MIC_TH` = **448** (adjustable from the SETTINGS page 192 / 320 / 448 / 704 / 1024 or SW5–SW7), then a holdoff of 200 ms · clap = **stun boss 1** (not boss 2) · **board: not tested**
* The game name on screen: edit `docs/STORY.md`, then run `python scripts/build_story.py` (font/text are generated by `scripts/make_font.py`)

## Sound

- `AUD_PWM` outputs 8-bit PWM (carrier 100 MHz / 256) · `AUD_SD` drives 1 = amplifier on (`AUD_SD_ON`; **not confirmed against the manual / board: not tested**)
- `rtl/audio.v`: one SFX at a time with priority (a lower number is more important; a lower-priority sound requested while one is playing is dropped) + BGM that is quieter (SFX ±48, BGM ±18)

| # | Event | Frequency | Length (frames) |
| --- | --- | --- | --- |
| 1 | Player hit | 330 → 110 Hz | 18 |
| 2 | Boss 1 stunned (clap) | 1200 → 600 Hz | 24 |
| 3 | Monster / boss dies | 500 → 120 Hz | 14 |
| 4 | Item pickup / evolve | 800 → 2000 Hz | 28 |
| 5 | Room cleared / gate opens | 600 → 1000 Hz | 20 |
| 6 | Wrong puzzle step | 200 → 170 Hz | 24 |
| 7 | Correct puzzle step | 1500 Hz | 5 |
| 8 | Enemy hit | 900 → 700 Hz | 4 |
| 9 | Shot (form 2 / spread / fast shot / big ball) | 1800→1200 / 1400→1000 / 2400→1600 / 600→250 Hz | 5 / 6 / 4 / 16 |
| 10 | Melee swing | 450 → 250 Hz | 7 |
| 11 | Boss appears | 250 → 204 Hz | 30 |
| 12 | Going through a door | 1000 Hz | 4 |
| 13 | Boss 3 charge (a beep at every step) | 600 → ~1000 Hz | 12 |
| — | Simon notes | C5 E5 G5 C6 (523 / 659 / 784 / 1047 Hz) play over every SFX while the plate is lit | per plate |

- **BGM** (`mem/music.mem` from `scripts/make_music.py`, settings in `sprites/music.json`): floors 1–3 use the same track 6 (the Connect melody) · ESCAPE track 3 (loops) · WIN track 4, GAME OVER track 5 (play once) · TITLE / PROLOGUE are silent
- Sound in Verilator: played live through SDL at 12,207 Hz (4 times slower than real) · `AUDIO_RATE=<Hz>`, `NOAUDIO=1`, key **M** = mute / unmute · record with `--wav out.wav` / `--wav-seg A:B:out.wav` · samples in `docs/audio/`

## Folder structure

```
rtl/            Verilog (+ *.vh)  [*_cfg.vh, puzzle_layout.vh, text_layout.vh, text_select.vh, tilebase.vh are generated by scripts — do not edit by hand]
  top.v           connects every module: input, pause, 7-seg, LED, sound, tutorial/hint, dialogue event
  params.vh       all game values (`include in the modules)
  game_fsm.v      states TITLE/PROLOGUE/PLAY/EVOLVE/FLOOR_CLEAR/ESCAPE/WIN/GAME_OVER, form, HP, timer
  world.v         floor / room / grid / doors / spawn points · player.v movement+collision+knockback · player_frame.v picks the animation · face_lock.v
  objects.v       monsters 6 / player bullets 6 / enemy bullets 16 / boss, AABB, wave, locked rooms, auto aim
  boss.v          3 bosses (boss_rom + FSM, rage) · keyitem.v key · maze.v + adxl362.v maze
  puzzles.v       Light Bulb / Sokoban / Simon + item · overlay.v state of breakable crates
  renderer.v      4-clock pipeline · objline.v object line buffer · hud.v hearts/boss bar/meter · roms.v all ROMs · vga_sync.v
  dialog.v        story box + hint strip · dlg_cfg.vh, text_*.vh (generated from docs/STORY.md)
  audio.v         PWM, SFX 13, BGM · pdm_mic.v microphone · ps2_kbd.v keyboard · debounce.v · seg7.v · bin2bcd.v
  mic_test_top.v  separate microphone test (docs/BOARD_DAY.md)
constraints/    nexys_a7.xdc, mic_test.xdc
maps/           13 ASCII maps of 20×15 + maps/maze/maze.txt (edit here) · maps_v1/ = originals
mem/            .mem files / objects.txt generated by scripts (do not edit by hand) · *_v1.mem = originals
sprites/        JSON settings for art/music (sprites.json, tileset.json, monsters.json, bosses.json, puzzle.json, hud.json, overlay.json, music.json, music/) + README.md
my_asset/       source art · my_audio/ source audio (not committed)
scripts/        build_*_mem.py, build_maps.py, build_story.py, make_*.py, audio_to_music.py, solve_sokoban.py, update_sprites.*,
                check_all.sh/.bat, run_sim.sh, run_full_game.sh, run_sprite_shots.sh, make_shots.sh, create_project.tcl, create_mic_project.tcl,
                vivado_synth.tcl, vivado_update_project.tcl
tests/          Python tests (10 test_*.py files) + fallback_drill.sh
sim/            testbenches tb_*.v (iverilog), sim/verilator (Makefile, main.cpp, scripts/*.txt), sim/anim_on/, sim/vig.vh, sokoban_solution.vh
report_shots/   (untracked) WSL scripts that take Verilator screenshots: env.sh, _build.sh, run.sh, convert.py, scripts/t1.txt
preview/        generated preview pictures (git-ignored except layout_guide.png)
docs/           documents (see docs/README.md) + pictures *.png + docs/audio/*.wav + docs/archive/
vivado/         Vivado project (git-ignored, created by create_project.tcl)
```

## Editing maps / sprites

- Edit maps: edit `maps/*.txt`, then run `python3 scripts/build_maps.py` (creates `mem/tilemap.mem`, `monsters.mem`, `objects.txt`, `overlay.mem`, `rtl/puzzle_layout.vh`) — details in `docs/MAP_DESIGN.md`
- All art: edit `my_asset/` + `sprites/*.json`, then run `scripts/update_sprites.sh` · read `sprites/README.md`
- On-screen text: edit `docs/STORY.md`, then `python scripts/build_story.py`
- After a .mem file changes, Vivado needs to re-run synthesis · before a commit run `scripts/check_all.sh`

## Play on a computer screen (no board needed) — Verilator + SDL2

Verilator converts the same Verilog as the board into a program and shows the VGA picture in an SDL2 window with a 7-seg / LED / switch panel (Verilator 5.x; tested with 5.054 in the conda env `dungeon` on WSL, see `report_shots/env.sh`)

```
cd sim/verilator
make run        # build + open the window
```

> **Warning:** the current `Makefile` passes `-GPROLOGUE=$(PROLOGUE_V)` while `PROLOGUE_V` is not defined (empty value) — it is not confirmed whether a plain `make run` / `make seeded` builds successfully · a way that probably works (**not run**): `make seeded PROLOGUE_V=0` (for the `scripts/*.txt` scripts, which were written for runs without the PROLOGUE pages) or `PROLOGUE_V=1` for normal play · the seeded binary on this machine was built with `report_shots/_build.sh` (`-GPROLOGUE=0`)

| Key in the simulator | Board equivalent |
| --- | --- |
| Arrow keys | BTNU / BTND / BTNL / BTNR |
| Space | BTNC |
| 0–9 | Toggle SW0–SW9 |
| F1–F6 | Toggle SW10–SW15 (F5 = SW14 sprint, F6 = SW15 pause) |
| Backspace | CPU_RESETN |
| C | Simulated clap 100 ms |
| M | Mute / unmute |
| [ / ] | Decrease / increase frame skip |
| Esc | Quit |

(Verilator has no PS/2 keyboard model — the keys P / L / H / R / WASD work only on the board and in `tb_ps2`)

Windows: use WSL2 + Ubuntu / Kali (`sudo apt install -y build-essential verilator libsdl2-dev`; Verilator must be 5.x — apt on Ubuntu 22.04 gives 4.x, which is too old) · macOS: `brew install verilator sdl2`

The simulator sets `CE_DIV=1`, `DEBOUNCE=2000` (real board `CE_DIV=4`, `DEBOUNCE=1_000_000` = 10 ms); the logic is the same as the board · `DEBUG` has its default value (=1)

Build options (`sim/verilator`): `make` / `make run` (PGO g++, random puzzles → `obj_dir/Vtop`) · `make seeded` (SEED=0x1234 → `obj_dir_seeded/Vtop`) · `make SEED=0x5678` · `make PGO=0` · `make FAST_CLOCK=0`

Test without opening a window:
```
cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir/Vtop --frames 300 --script "R:5:200,C:60:62" --shot shot.bmp
```
`Vtop` options: `--frames N`, `--shot f.bmp`, `--shot-at N:f.bmp`, `--script "..."` / `--script-file f`, `--wav f`, `--wav-seg A:B:f`, `--headless`, env `LOG=N` (print the state every N frames), `HEADLESS=1`, `AUDIO_RATE`, `NOAUDIO` · script format: `button:start_frame:end_frame` (buttons `U D L R C`, switches `0-9 a-f` = SW0–SW15, `K` = clap, `#` = comment)

Scripts in `sim/verilator/scripts/` (**they need a seeded build** and were written for runs without the PROLOGUE pages):

| Script | What it does |
| --- | --- |
| `full_game.txt` (196 lines) | TITLE → floors 1–3 (combat rooms cleared with debug SW2, bosses fought for real) → key → ESCAPE → WIN (it passes when it ends at WIN; not rerun on the latest code in this documentation pass) |
| `floor1.txt` / `floor2.txt` / `floor3.txt` | Puzzle of floor 1 / 2 (Sokoban 24 pushes, generated by `scripts/make_floor2_script.py`) / 3 (Simon) |
| `weapons_demo.txt` | Form 1→4 weapon demo (uses debug SW3 / SW2) |
| `sprite_check.txt` | Pictures of the sprite of every form/direction (used by `scripts/run_sprite_shots.sh`) |

```
./scripts/run_full_game.sh            # play the full game without a window, passes when it ends at WIN (~10 minutes; builds seeded itself if missing)
SHOTS=1 ./scripts/run_full_game.sh    # + save docs/p5_*.png
WAVS=1 ./scripts/run_full_game.sh     # + save docs/audio/*.wav
./scripts/run_sprite_shots.sh         # pictures of every form → preview/game/
./scripts/make_shots.sh               # render the renderer only (iverilog) → preview/shots/
```
`report_shots/` (untracked): a set of scripts that take Verilator screenshots in WSL (`_build.sh` builds seeded with `-GPROLOGUE=0`, `run.sh <script> <frames> [--shot-at ...]`, `convert.py` converts BMP → PNG)

## Simulation (testbench, Icarus Verilog)

Icarus Verilog is required (`sudo apt install iverilog`; tested with 13.0 in WSL) · run from the root folder:

```
./scripts/run_sim.sh <target>     # targets below; passes when there is no FAIL and "errors = 0"
./scripts/run_sim.sh all          # player world fsm objects puzzles mic mictop audio boss hud simonplate dialog ovrender text ps2 orb debug top
./scripts/check_all.sh [--fast]   # rebuild generated files + check nothing is stale + Python tests + (without --fast) run_sim.sh all (~12 minutes; --fast ~1 minute)
```

| target | testbench | What it checks |
| --- | --- | --- |
| `player` / `playerframe` / `facelock` | tb_player, tb_player_frame, tb_facelock | walk, collide, slide, doors · animation selection · facing lock |
| `world` | tb_world | doors/grid/spawn points/restart/retry/next_floor (52 checks) |
| `fsm` | tb_game_fsm | states, EVOLVE, HP, GAME OVER, FLOOR_CLEAR, timer, sprint (67 checks) |
| `objects` / `orb` | tb_objects, tb_orb | AABB, weapons, monsters, wave, traps, overlay · charge ball |
| `puzzles` | tb_puzzles | Light Bulb / Sokoban (played with the solver's answer) / Simon / item |
| `boss` | tb_boss | 3 bosses, stun, FLOOR_CLEAR, key, ESCAPE |
| `hud`, `dialog`, `text`, `ovrender`, `simonplate` | tb_hud, tb_dialog, tb_text, tb_ovrender, tb_simonplate | HUD (compared with mem pixel by pixel), story box, text, overlay, Simon plates |
| `audio` / `mic` / `mictop` / `ps2` / `adxl` / `maze` | tb_audio, tb_pdm_mic, tb_mic_test_top, tb_ps2, tb_adxl362, tb_maze | sound (64 checks) · microphone · separate microphone test · keyboard (30) · ADXL · maze |
| `sprites` `tileset` `monster` `bosssprites` `puzzleart` `animroms` | tb_sprites … | art ROM matches the `.mem` |
| `debug` | tb_debug | the `DEBUG` parameter (SW0–SW4 work only when DEBUG = 1) |
| `top` / `topanim` | tb_top | whole-system simulation (`topanim` = animation flags ON) |

`tb_shot.v` is used by `scripts/make_shots.sh` and is not a target of `run_sim.sh`

## Next steps

See `docs/NEXT_STEPS.md` and the FUTURE BACKLOG table in `docs/DESIGN_PLAN.md`: board test (picture, sound, microphone, maze) → fix timing (WNS −4.045 ns) → set `DEBUG = 0` → video + hand-in report
