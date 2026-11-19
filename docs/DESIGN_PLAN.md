# Design implementation plan (from the "Group 10 - Design Notes", 19/11/2026)

**Status: PLAN ONLY. Nothing in this file is implemented yet** (except the on-screen hearts, item W8, already merged).
Source: the owner's design notes of 19/11/2026 (the master design for the Progress 20/11). Where they disagree with the code or with
`Group10_Dungeon_DEVELOPER_GUIDE.md`, the design notes win (section 3 lists every conflict, checked against the code on branch `sprite-zip`).
How to use this file: read section 1 (what is feasible when), pick items, answer the open questions in section 6, then I implement item by item
(each on its own branch from `sprite-zip`, merged only after `scripts/check_all.sh` + the item's own test).

---

## 0. Honest scope statement

* The notes contain about **3 weeks of work** (3 boss rewrites, new tile layer, accelerometer minigame, story). The Progress is Friday 20/11 and the
  feature freeze was 22:00 on 19/11. **Everything below except Phase A is therefore "after the demo" work.**
* For the demo the notes themselves are the deliverable: the talking points in section 9 of the notes (4 evolutions, one mechanic per boss, extra I/O) can be presented as
  **design + state diagrams** with the already-working parts shown live (hearts, 4 forms, mic clap exists in code, HUD).
* Rule 1 still applies to every item: if a new art / sound / sensor is missing or broken, the game falls back (old art, button control instead of accelerometer, ...) and still builds.

---

## 1. Phases (recommended order, risk first, value first)

| Phase | Items | Risk | Needs from you | Target |
|---|---|---|---|---|
| **A - before the demo** (small, no big Verilog) | W1 door = spike trap, W2 pressure plate art, W3 charged shot stops on hit, W4 mic debug on the board, W6 new start screen (text + colours), W9a prologue screen (text only) | low | tulip plate picture, start-screen wording, prologue text | 19-20/11 |
| **B - boss rework** (one branch per boss, own tests) | W10 boss 1 (fast + clap stun), W11 boss 2 (summon + vulnerable only with minions), W12 boss 3 (armour + charge + big attack), W13 form 3 AOE split | medium-high | the numbers in section 6 | after demo, ~1 week |
| **C - map elements** | W5 breakable block, trap, solid decoration (overlay layer), new maps | medium | map ideas / art | ~3 days |
| **D - endgame** | W7 key drop -> unlock start door -> Ball in a Maze (accelerometer) -> WIN | high (new hardware) | board time for the accelerometer | ~1 week |
| **E - story** | W9b story screens + title | low-medium | story script | with phase A / after |

Dependencies: W3 before W12 (charged shot rules). W13 before W11 (AOE is how boss 2 is beaten). W5 uses the overlay-layer decision of section 5.1. W7 needs W12 (boss 3 drops the key).
Already done: **W8 hearts + boss health bar** (`rtl/hud.v`, merged in `sprite-zip`). Boss bar needs no change when boss HP changes.

---

## 2. Game flow (target)

```
TITLE (new) -> PROLOGUE (black screen + centred text) -> PLAY
FLOOR 1: Form 1 (Human, melee) -> Stage 1 -> Puzzle light bulb -> Form 2 (Orc, shot) -> Boss 1
FLOOR 2: Stage 2 -> Puzzle sokoban -> Form 3 (AOE shot) -> Boss 2
FLOOR 3: Stage 3 -> Puzzle Simon  -> Form 4 (charged shot) -> Boss 3
         -> key drops -> unlock the start door (floor 3 START, tile E) -> Ball in a Maze (timed, accelerometer) -> WIN
FLOOR CLEAR (2 s) between floors, GAME OVER whenever HP = 0.
```

---

## 3. Gap analysis: design vs. the code today (verified on `sprite-zip`)

| Topic | Code today | Design | Change |
|---|---|---|---|
| Clap stun | boss.v `stunnable` = boss 2 | boss 1 | move to boss 1 |
| Boss 1 | HP 10, 1 px per 2 frames, no shot | very fast, takes damage always, stunned by clap | rewrite parameters |
| Boss 2 | HP 16, bounces inside the F fence, shoots 4 ways | summons minions, **hurt only while minions live** | new FSM + spawn into `objects.v` |
| Boss 3 | HP 24, chases 2 px/frame, shoots 4 ways | armour (only charged shot hurts), charges a big attack that kills instantly | new FSM + telegraph |
| Form 3 shot | kind 1 = 3-way spread | bullet that hits a monster splits into 4 directions | new split logic (bullet slots) |
| Form 4 big ball | pierces (`big_mask` in `objects.v`, each monster hit once) | **stops on hit** | remove piercing |
| Endgame | `S_ESCAPE` 30 s timer -> door E -> WIN | key -> door -> Ball in a Maze -> WIN | new FSM states + modules |
| Prologue | none | black screen + text | new FSM state |
| HUD | **done**: hearts + boss bar | | - |
| Tile ids | 4 bit, ids 0-15 all used (8-11 renderer-chosen, 12-15 Simon plates / decoration) | + breakable, trap, solid decoration | see 5.1 |
| Slots | 6 monsters, 6 player bullets, 16 enemy bullets | summons, AOE split | see 5.2 |
| Mic | `pdm_mic.v` + `MIC_TH` tuned in simulation only | clap must work on the board | W4 |
| Accelerometer | no module, no pins in `constraints/nexys_a7.xdc` | board tilt controls the maze | W7 |

Open contradictions inside the notes (decide or accept my default, section 6): boss 3 "interrupted: reduce armour / HP" is not specific (how many charged hits kill it?);
the "big attack" range is not defined (whole room, a line, a radius?); timeout in the maze (GAME OVER or retry).

---

## 4. Work items

Format: **what changes - how - tests - needs - risk / effort**. Effort = my working time, not including your board tests.

### W1 Door sprite = spike trap  (Phase A)
* The tile that is the door today (`D` combat doors, `L` boss door, `E` exit) is drawn as **spikes up = closed, collapsed spikes = open**. Logic is unchanged (`doors_open`, `open_L`).
* How: art only. `sprites/tileset.json` already has per-tile overrides; use `my_asset/props/peaks_1..4.png` (the asset pack has 4 spike frames; peaks 1 = up, 3 = down is what the puzzle gate uses now) on tile slots 2/8 (D closed/open), 3/9 (L), 4/A (E). Each is 16x16 scaled 2x onto the floor colour (use the `cut` colour option so the floor shows through, same as the gate frames in `puzzle.json`).
* Tests: `tests/test_tileset_pipeline.py` (add cases for the new overrides), `run_sim.sh tileset`, preview `preview/tileset_rooms.png`.
* Risk low, effort ~1 h. Needs: nothing (peaks already in `my_asset/props`).

### W2 Pressure plate = tulip plate  (Phase A)
* Plates: sokoban target `O` (tile 7, pressed look = tile 11) and the 4 Simon plates (12-15). Replace the art by the tulip plate picture.
* Needs: **the tulip plate PNG** (not in the asset packs I searched: `Dungeon_Tileset.png` and the 3 zips contain no file named tulip/plate/pressure). Send the file or the sheet name.
* How: `tileset.json` overrides for tiles 7, 11 (pressed) and Simon plates 12-15 (lit versions are produced by the renderer by brightening).
* Risk low, effort ~1 h after the art arrives.

### W3 Charged shot stops on hit  (Phase A, tiny Verilog)
* Today: kind 3 (16x16 big ball) pierces; `big_mask` stops double hits and enemy bullets are destroyed when it overlaps them (`S_CPE`).
* Change in `objects.v` `S_CPB`: when kind 3 hits a monster, clear `p_act` of that bullet after applying `BIG_DMG`; drop `big_mask`. Keep "destroys enemy bullets" only if you still want it (decide: it must not delete the boss-3 big attack, see W12).
* Boss hit: the boss takes damage (`boss_dmg` with amount) and the ball disappears.
* Tests: update `tb_objects.v` (the "ลูกใหญ่ทะลุ" case becomes "stops, damages one monster once"), `run_sim.sh objects`, `boss`.
* Risk low, effort ~1 h.

### W4 Clap does not work on the board  (Phase A, mostly your hardware time)
* The microphone was only tested in simulation. Steps (no design change): 1) run the stand-alone mic test top (`scripts/create_mic_project.tcl`, `constraints/mic_test.xdc`: bar = amplitude, BTNC clears the peak, SW sets `MIC_TH`); 2) read the printed amplitude for a clap and for silence, pick `MIC_TH` / `MIC_WINDOW` / `MIC_HOLDOFF` in `rtl/params.vh`; 3) check pins J5 `M_CLK`, H5 `M_DATA`, F5 `M_LRSEL` against the Digilent master XDC (the note in `mic_test.xdc` says they were **not verified**); 4) check the PDM sampling edge (`pdm_mic.v`, left vs right channel via `M_LRSEL`).
* Fallback (Rule 1): if the mic cannot be fixed by Friday, a button/switch also triggers the stun pulse (one-line OR in `top.v`), documented as "mic or switch".
* Risk medium (hardware), effort 1-2 h with you at the board.

### W5 Map elements: breakable block, trap, solid decoration  (Phase C)
* **Breakable block**: blocks movement until hit by a bullet / melee, then becomes floor; state per tile must survive leaving and re-entering the room and reset on new game. Plan: a small `breakable` state memory = one bit per breakable (at most 8 per room x 13 rooms = 104 flops/LUTs), indexed by the room's breakable list generated by `build_maps.py` (like `objects.txt`).
* **Trap** (several kinds allowed): kinds = spike (damage 1 + knockback when stepped on, always on or timed 1 s on / 1 s off), maybe arrow shooter later. Rules: form 3 flies over (it already crosses holes `H`), damage uses the existing `take_hit` + invulnerable frames so it cannot chain-hit.
* **Solid decoration**: a wall-like tile that only changes the look (pillar, statue). Free for the player (collision = like `#`), free for bullets (stops them) - easiest to treat as a wall tile with another picture.
* How: add an **overlay layer** (decision in 5.1) instead of widening the tile id: `mem/overlay.mem` (13 rooms x 300 x 4 bit: 0 none, 1 breakable, 2 spike trap, 3 solid deco, ...), read by `player.v`, `objects.v`, `boss.v` (collision) and `renderer.v` (drawing). Art slots are added to the tileset ROM as extra tiles per floor (+3..4 tiles x 3 floors = +4 BRAM) or drawn from `puzzle.mem` frames 10-15 (free).
* Maps per floor (from the notes): floor 1 breakable boxes + decoration + elements; floors 2-3 traps + breakable boxes + decoration + elements. The current decoration characters (`, ; : `` ` ``) keep working.
* Tests: `tests/test_maps.py` (overlay validity, counts per room), new `tb_overlay.v` (breaks after N hits, persists, reset on new game, trap damage once per invulnerability window), Verilator/iverilog top.
* Risk medium-high (touches collision in 3 modules), effort ~3 days.

### W6 New start screen  (Phase A)
* Today: navy background + two text lines (`text_layout.vh`, 8x8 font, A-Z 0-9 space `- : ! .`, 2 lines max, no Thai).
* Plan: better background colour/gradient, bigger title text (scale 4 already exists for line 0), the hero sprite is drawn by `top.v` at `px,py` on the title screen; optionally `my_asset/ui/MediavelFree.png` panel / candle / sword as decoration (needs a small `ui` ROM: wood panel 16x? chunks; about 1-2 BRAM).
* Game name: **not needed yet** (design notes) - use a placeholder line ("GROUP 10 DUNGEON" is the current text).
* Needs: wording + which decoration you like. Risk low, effort 1-2 h.

### W7 Endgame: key -> door -> Ball in a Maze  (Phase D)
Replaces the 30 s ESCAPE.
1. **Boss 3 dies -> key drop.** `boss.v` raises `died` (exists). New: a key item appears where the boss died (reuse the puzzle item mechanism, `puzzle.mem` frame 10 = gold key = one of the 6 free frames, `build_puzzle_mem.py` frame config) and "got key" is stored (`has_key`).
2. **Unlock the start door.** The door at floor 3 START (tile `E`) is locked until `has_key`; walking into it with the key opens it and starts the minigame (a new `maze` trigger instead of the current `escape_start` / `S_ESCAPE`). The back-track route to START stays the same as the old ESCAPE route (`06_...`/`10_...` maps unchanged).
3. **New FSM state `S_MAZE`** in `game_fsm.v` (`localparam` list: TITLE, PLAY, EVOLVE, FLOOR_CLEAR, ESCAPE(removed), WIN, GAME_OVER + PROLOGUE + MAZE). Timer: reuse the seg7 mm.ss counter as a countdown (`ESCAPE_*` parameters become `MAZE_TIME`).
4. **`maze.v`**: a ball (fixed-point position and velocity), walls from a maze map (a 20x15 room grid: grids 13-15 are free, generated by `build_maps.py` from `maps/13_maze.txt`), goal tile, collision with wall tiles, friction, speed clamp, frame-based update at the 60 Hz `frame_tick`. Drawing: ball sprite 16x16 (one more frame in `puzzle.mem`), maze walls from the tileset, text "TIME" via the existing digits.
5. **`adxl362.v`** (accelerometer): the Nexys A7 has an ADXL362 on SPI (pins `ACL_MISO`, `ACL_MOSI`, `ACL_SCLK`, `ACL_CSN`; **take the exact pin names and locations from the Digilent Nexys A7-100T master XDC and add them to `constraints/nexys_a7.xdc`; I have not verified them**). Init sequence: soft reset (reg 0x1F = 0x52), measurement mode (reg 0x2D = 0x02), then read X/Y 8-bit (reg 0x08 / 0x09) about 100 times per second, SPI mode 0, <= 1 MHz (divider from 100 MHz). Output: signed `ax, ay`, with an automatic **offset calibration** (average of the first 32 samples when the maze starts) and a **dead zone** so a flat board does not drift.
6. **Fallback (Rule 1):** if the sensor does not answer (no data valid within 0.5 s) or a switch is up, the 4 direction buttons push the ball, so the game can always be finished.
7. End: reach the goal = `S_WIN` (existing WIN screen / music), time out = see section 6 (my default: **GAME OVER**, the simplest and consistent with "die = game over").
* Tests: `tb_adxl362.v` with a behavioural ADXL362 slave model (SPI protocol, offset), `tb_maze.v` (ball stops at walls, reaches goal, timeout), updated `tb_game_fsm.v`, `tb_top.v` WIN path; **board test is mandatory** (accelerometer axis directions and offset).
* Risk high (new I/O device + new modules + new states), effort ~5-6 days. Show an honest status on 20/11: "design + SPI model tested in simulation".

### W8 Hearts + boss bar  (DONE)
`rtl/hud.v`, `mem/hud.mem`, `sprites/hud.json`, `scripts/build_hud_mem.py`. The boss bar already scales with whatever HP the boss has (`BOSSn_HP` in `params.vh`).

### W9 Story: prologue now, story later  (Phase A / E)
* **W9a Prologue** (Phase A): new state `S_PROLOGUE` between TITLE and PLAY: black screen + text in the middle of the screen, advances on a button (or after N seconds). Text limit: 2 lines per screen, 20 characters per line at scale 2 (A-Z, 0-9, space, `- : ! .`), no Thai. Add screen code 6 in `renderer.v` (`txt_scr`) and a layout in `text_layout.vh` / `text.mem` (generated by `make_font.py`). Several pages = a page counter in the FSM (page n shows text n).
* **W9b Story** (Phase E): where else text appears (floor clear, win, boss intro) - needs your script (P1.3). Long story: tell it in the video / report, not on the board.
* Tests: extend `tb_game_fsm.v` (TITLE -> PROLOGUE -> PLAY), `tb_top.v`. Risk low-medium, effort ~3 h.

### W10 Boss 1 - fast, stunned by clap  (Phase B)
* Values (defaults, change in `params.vh`): HP 10 (unchanged), speed 2 px/frame every frame (today 1 px per 2 frames), no shot, takes damage at all times.
* States: `CHASE -> (clap) STUNNED (STUN_FRAMES) -> CHASE`, clap cooldown `STUN_COOLDOWN` after the stun (exists: `STUN_FRAMES`, `STUN_COOLDOWN`).
* How: `boss_rom` parameters (`speed`, `every`, `fire = 0`, `stunnable = (kind == 0)`) - small change; the speed uses the same wall-collision routine as boss 3 today.
* Fairness: with HP 10 and damage 1 per hit the player must hit while it is stunned - tune `STUN_FRAMES` (default 3 s = 180 frames) and cooldown (default 4 s).
* Tests: `tb_boss.v` (speed, stun on clap, no stun during cooldown, HP bar).
* Risk low, effort ~2 h.

### W11 Boss 2 - summons minions, hurt only while minions live  (Phase B)
* States: `IDLE -> SUMMON (spawn N minions) -> MINIONS_ALIVE (boss takes damage) -> INVULNERABLE (all minions dead; boss takes no damage, short pause) -> SUMMON ...`, `HP = 0 -> DEAD`.
* How: `boss.v` outputs `summon` (pulse) + `summon_n`; `objects.v` gets an input `summon` and spawns minion type A at free slots in a ring around the boss (the room has 6 monster slots; **default: 3 minions**, so 3 slots stay free), and outputs `minions_alive` (count of active slots, boss room only) back to `boss.v`. `boss.v` applies damage only if `minions_alive != 0` (new input `vuln`); otherwise `boss_dmg` is ignored and a "shield" flash is shown. Visual cue for vulnerable: boss sprite normal; invulnerable: tinted (use `boss_flash`-style tint in `objline.v`).
* Boss 2 stops bouncing/firing in the fence (new movement: slow drift or stationary; default **stationary** so the AOE form can reach it).
* Form 3 AOE (W13) is the intended weapon: the split bullets hit the minions and the boss.
* Tests: `tb_boss.v` extended (summon spawns N, damage rejected when no minions, accepted with minions, re-summon after INVULNERABLE_FRAMES), `tb_objects.v` (spawn on `summon`, slot limit).
* Risk medium-high (boss <-> objects handshake), effort ~1 day. Needs: numbers (minions, invulnerable time).

### W12 Boss 3 - armour + charge + big attack  (Phase B)
* States: `CHASE (armoured)` -> `CHARGING (telegraph)` -> `BIG ATTACK` / `INTERRUPTED`. Armour: all normal damage ignored; only **charged shot** (kind 3, form 4) damages. A charged shot that hits during `CHARGING` interrupts the attack.
* `BIG ATTACK` effect (decision needed, my default): the screen flashes and **every player inside the room not behind cover** is hit for lethal damage = set HP 0 (use `take_hit` repeated / a new `kill` input to `game_fsm.v` -> GAME OVER). Simple and clearly telegraphed; the alternative is a line / radius attack (more visual work).
* Telegraph: boss tint flashing + a sound (reuse `SFX_BOSS`), duration default 2 s (120 frames) so the player has time to charge (form 4 `CHARGE_FRAMES`) and shoot.
* Needed signals: `objects.v` exposes `boss_dmg_kind` (kind of the bullet that hit; today it only passes `boss_dmg_amt`) so `boss.v` can accept only kind 3. Charged shot stops on hit (W3).
* HP / hits: default boss 3 HP 3 charged hits (`BOSS3_HP = 3`, `BDMG_CHARGED = 1`) so the existing health bar shows 3 steps; each hit also interrupts and resets the cycle.
* On death: key drop (W7).
* Tests: `tb_boss.v` (armour: normal bullet no damage; charged bullet damage; CHARGING -> BIG ATTACK kills; interrupt resets), `tb_game_fsm.v` (kill input), `tb_top`.
* Risk high, effort ~1.5 days.

### W13 Form 3 AOE  (Phase B)
* New behaviour: a form 3 bullet that hits a monster **splits into 4 bullets** (up / down / left / right from the hit point) that fly a short distance (default 3 tiles) and deal the same damage.
* Slots: `objects.v` has 6 player-bullet slots (`NP = 6`). The split needs up to 4 free slots at once. Plan: raise `NP` to 8, limit to 2 parent bullets in flight for form 3 (`pk_kind = 1` fire rate), spawn the 4 children in the same `S_CPB` pass using a small "split request" (position + damage) register, and mark the children as kind 1 with the flag `child` so they do not split again (needs 1 more bit per bullet).
* Art: kind 1 child bullet uses the same 8x8 bullet art (`bullet.mem`).
* Tests: `tb_objects.v` (split on monster hit, no recursive split, slot exhaustion does not crash).
* Risk medium, effort ~1 day.

---

## 5. Cross-cutting decisions

### 5.1 Tile id strategy (needed by W1, W5)
| Option | Cost | Verdict |
|---|---|---|
| A. Widen the tile id to 5 bit | `tilemap.mem` + all collision functions + tileset ROM 2x (3 floors x 32 tiles: +16 RAMB36); touches `roms.v`, `build_maps.py`, `world.v`, `player.v`, `objects.v`, `boss.v`, `renderer.v` | **no** (BRAM, risk) |
| B. Re-use ids per room kind (ids 12-15 are Simon plates only in the Simon room, floor elsewhere) | no ROM change but the meaning depends on the room, easy to break | only for decoration (already done) |
| C. **Overlay layer** (separate 4-bit map `overlay.mem`, drawn above the base tile, own collision rules, own state) | small distributed ROM + a few extra tiles of art | **recommended** |

### 5.2 Resource budget (check after each item with the Vivado utilization report)
* Block RAM: 135 RAMB36 available. Hearts +3 (done), Human animations +34 if all ON (off), overlay art +4, ui panel +2, maze/ball art +1, wall variants +6. Send me the real number from the board build before enabling more.
* Slots: monsters 6 per room, player bullets 6 (->8 with W13), enemy bullets 16. Boss 2 summon uses 3 monster slots.
* Timing: all new logic is registered; the renderer pipeline (4 stages) is not changed except the overlay read (added into stage 1).

### 5.3 Verification policy (every item)
1. Own iverilog testbench or new cases (`scripts/run_sim.sh <name>`, added to `all`).
2. Python tests for any new generator (`tests/test_*.py`), generated files never hand-edited, `scripts/check_all.sh` green.
3. Docs updated in the same commit: `docs/SPRITE_STATUS.md` (art), `docs/SOUND_PLAN.md` (sound), this file (status), `docs/NEXT_STEPS.md`.
4. Board test with `docs/BOARD_TEST_STEPS.md`; I add a "what to check" paragraph for every item that touches the board (clap, accelerometer, boss feel).
5. Branch per item (`feature/boss1` ...), merge into `sprite-zip` only after 1-3; `main` only when you say "merge".

### 5.4 Sound / art needs created by the plan
* Sounds (using the existing SFX pipeline): boss summon, shield hit ("clink"), boss-3 charging, big attack, trap trigger, breakable block break, key pickup, maze tick / win. (Details in `docs/SOUND_PLAN.md` once you approve.)
* Art: tulip plate (W2), maze ball, key (reuse `keys_*_1.png` from the pack), trap and breakable box art (peaks for spike traps, `box_*_1.png` for breakables are already in `my_asset/props`), boss 3 telegraph tint (no art).

---

## 6. Open questions and my default answers

Reply with changes only; otherwise the defaults are used.

| # | Question | Default |
|---|---|---|
| 1 | Maze time | 60 s |
| 2 | Maze timeout | GAME OVER (restart the whole game); a softer option is "restart the maze 2 times" |
| 3 | Boss 1 stun / clap cooldown | 3 s / 4 s |
| 4 | Boss 2 minions / invulnerable time / new summon after | 3 minions / until the last one dies + 1 s / 2 s |
| 5 | Boss 3 charge time / charged hits to kill / big attack | 2 s / 3 hits / room-wide lethal hit |
| 6 | Charged shot destroys enemy bullets when it stops? | no |
| 7 | Trap kinds first | spike (static, 1 damage) only; timed spikes later |
| 8 | Breakable block hits | 1 hit (any bullet or melee) |
| 9 | Accelerometer fallback | direction buttons when no sensor data or when a switch is up |
| 10 | Prologue advance | any button, or 6 s |
| 11 | Mic fallback | a switch also gives the stun pulse (documented) |

---

## 7. Effort summary

| Phase | Items | Estimate |
|---|---|---|
| A | W1 W2 W3 W4 W6 W9a | ~8 h (W2 waits for the tulip picture, W4 needs the board) |
| B | W10 W11 W12 W13 | ~3.5 days |
| C | W5 | ~3 days |
| D | W7 | ~5-6 days |
| E | W9b | ~3 h once the script exists |
| Sum | | ~2.5 weeks of focused work; **not possible before 20/11**; Phase A is the realistic part |

## 8. What I need from you (in order)
1. Confirm / change the defaults in section 6 (a one-line answer is enough).
2. The tulip plate picture (W2), the start-screen / prologue wording (W6, W9a), the story script (W9b).
3. Board time for W4 (mic) and later W7 (accelerometer), and the Block RAM / WNS numbers from the current build.
