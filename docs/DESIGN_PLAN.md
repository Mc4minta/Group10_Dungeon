# Design implementation plan (from the "Group 10 - Design Notes", 19/11/2026)

**Status: implementation in progress.** Done: W8 hearts, W2 plates, W3 charged shot stops on hit. Everything else below is still plan.
Source: the owner's design notes of 19/11/2026 (the master design for the Progress 20/11). Where they disagree with the code or with
`Group10_Dungeon_DEVELOPER_GUIDE.md`, the design notes win (section 3 lists every conflict, checked against the code on branch `sprite-zip`).
How to use this file: read section 1 (what is feasible when), pick items, answer the open questions in section 6, then I implement item by item
(each on its own branch from `sprite-zip`, merged only after `scripts/check_all.sh` + the item's own test).

---

## Change log
* 19/11: **Boss 2 rule corrected** - hurt only when ALL minions are dead (VULNERABLE state), shielded while any minion lives; was wrongly written as "hurt only while minions live". Sections 1, 3, W11, 6 (question 4) updated.

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
| **A - before the demo** (small, no big Verilog) | W15 switches (pause/sprint), W1 all doors = spike traps + maze door = vanishing wall, W2 pressure plate art (**started**, picture received), W3 charged shot stops on hit, W4 mic debug on the board, W6 new start screen (text + colours), W9a prologue screen (text only) | low | start-screen wording, prologue text | 19-20/11 |
| **A - switches** (new 19/11) | W15 SW15 = pause, SW14 = sprint, facing lock moves to a free switch | low-medium | confirm the facing-lock switch (default SW12) | with phase A |
| **A2 - new form 2 / form 3 animations** (art received 19/11, **waiting for your approval**) | W14 Orc + Angel attack and hurt animations | medium (BRAM) | your choice of option in W14 | after A |
| **B - boss rework** (one branch per boss, own tests) | W10 boss 1 (fast + clap stun), W11 boss 2 (summon + vulnerable only when all minions are dead), W12 boss 3 (armour + charge + big attack), W13 form 3 AOE split | medium-high | the numbers in section 6 | after demo, ~1 week |
| **C - map elements** | W5 breakable block, trap, solid decoration (overlay layer), new maps | medium | map ideas / art | ~3 days |
| **D - endgame** | W7 key drop -> unlock start door -> Ball in a Maze (accelerometer) -> WIN | high (new hardware) | board time for the accelerometer | ~1 week |
| **E - story** | W9b story screens + title | low-medium | story script | with phase A / after |

Dependencies: W3 before W12 (charged shot rules). W13 before W11 (the AOE shot clears the minions quickly; only then is the boss hit, in its VULNERABLE state). W5 uses the overlay-layer decision of section 5.1. W7 needs W12 (boss 3 drops the key).
Already done: **W8 hearts + boss health bar** (`rtl/hud.v`, merged in `sprite-zip`), Angel at 2x, player hurt box 16x16 (`HURT_BOX`). In progress: W2 plates (`feature/plates`). Boss bar needs no change when boss HP changes.

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
| Boss 2 | HP 16, bounces inside the F fence, shoots 4 ways | summons minions, **hurt ONLY when all minions are dead** (shielded while any minion lives) | new FSM + spawn into `objects.v` |
| Boss 3 | HP 24, chases 2 px/frame, shoots 4 ways | armour (only charged shot hurts), charges a big attack that kills instantly | new FSM + telegraph |
| Form 3 shot | kind 1 = 3-way spread | bullet that hits a monster splits into 4 directions | new split logic (bullet slots) |
| Form 4 big ball | pierces (`big_mask` in `objects.v`, each monster hit once) | **stops on hit** | remove piercing |
| Endgame | `S_ESCAPE` 30 s timer -> door E -> WIN | key -> door -> Ball in a Maze -> WIN | new FSM states + modules |
| Prologue | none | black screen + text | new FSM state |
| HUD | **done**: hearts + boss bar | | - |
| Tile ids | 4 bit, ids 0-15 all used (8-11 renderer-chosen, 12-15 Simon plates / decoration) | + breakable, trap, solid decoration | see 5.1 |
| Plates | flat grey placeholder (tile 7 / 11) and colour tiles (12-15) | your plate picture: raised / pressed, Simon = 4 big tinted plates | **in progress (W2)** |
| Animations | Human only (form 1): idle / attack / hurt / death built, all OFF | Orc + Angel attack and hurt received | W14 |
| Slots | 6 monsters, 6 player bullets, 16 enemy bullets | summons, AOE split | see 5.2 |
| Mic | `pdm_mic.v` + `MIC_TH` tuned in simulation only | clap must work on the board | W4 |
| Controls | SW15 sprint, SW14 facing lock | SW15 pause, SW14 sprint (facing lock moves) | W15 |
| Accelerometer | no module, no pins in `constraints/nexys_a7.xdc` | board tilt controls the maze | W7 |

Open contradictions inside the notes (decide or accept my default, section 6): boss 3 "interrupted: reduce armour / HP" is not specific (how many charged hits kill it?);
the "big attack" range is not defined (whole room, a line, a radius?); timeout in the maze (GAME OVER or retry).

---

## 4. Work items

Format: **what changes - how - tests - needs - risk / effort**. Effort = my working time, not including your board tests.

### W1 Door sprites: every world door = spike trap, the maze door = solid wall  (Phase A, updated 19/11)
Rule from the owner: **every door in the world is a spike trap, except the winning door (the Ball in a Maze door), which stays a solid wall that disappears when it opens.**

| Door | Tile ids (closed / open) | Look | Opens when (logic today) |
|---|---|---|---|
| `D` combat / room doors | 2 / 8 | **spike trap**: spikes up = closed (blocks, like a wall), spikes collapsed flat on the floor = open (walkable) | room cleared (`doors_open`) |
| `L` boss door | 3 / 9 | **spike trap**, same art | floor item collected (`open_L`) |
| `E` exit = the winning door at floor 3 START | 4 / 10 | **solid wall picture** (same wall art as `#` or a heavier gate wall); when it opens it **disappears**: the open tile is plain floor, no frame, no collapsed spikes | today: form 4 (`tvis` 4 -> A when `form == 3`); new (W7): the player carries the boss-3 key, then it opens and the maze starts |

* Logic is unchanged for `D` and `L` (`doors_open`, `open_L`); only the pictures change. `E` gets the new key rule in W7 (`has_key` instead of `form == 3`; renderer line `4'h4: tvis = ...` and `player.v pass()` for tile 4).
* How (art only for the pictures): `sprites/tileset.json` per-tile overrides. Spike art = `my_asset/props/peaks_1..4.png` (the asset pack has 4 spike frames; peaks 1 = up and peaks 3 = down is what the Sokoban gate uses now): tiles 2 and 3 = spikes up, tiles 8 and 9 = spikes down, each 16x16 scaled 2x onto the floor colour (use the `cut` colour option so the floor shows through, same as the gate frames in `puzzle.json`). Tile 4 = the wall cell of the tileset (same cell as tile 0, optionally a darker tint with `"tint"`), tile 10 (`E` open) = the plain floor cell (same as tile 1) so it looks like the wall vanished.
* Optional polish (needs Verilog, not in Phase A): a 4-frame spike animation (up -> down) when a door opens, a short "dust" effect when the maze door disappears.
* Tests: `tests/test_tileset_pipeline.py` (overrides for tiles 2, 3, 4, 8, 9, 10: spikes use the cut colour, tile 10 equals tile 1, tile 4 equals the wall art), `run_sim.sh tileset`, preview `preview/tileset_rooms.png`. `SPRITE_STATUS.md` section 3 (tileset) updated in the same commit.
* Risk low, effort ~1.5 h. Needs: nothing (peaks already in `my_asset/props`). Watch out: the 12 rooms use `D` in many places; check each room preview so a spike door never looks like a floor hazard (spikes are only for doors; the future trap tiles of W5 need a different look, e.g. spikes with a red base).

### W2 Pressure plate art  (Phase A) - IN PROGRESS on branch `feature/plates` (your picture arrived 19/11)
Your picture `my_asset/props/plate.png` = 32x64: cell row 0 = **raised** plate, row 1 = **pressed** plate (grey 180 with shading).
* **Sokoban** (floor 2, 2 plates `O`): tile 7 = raised plate while no box is on it, tile 11 = pressed plate when a box rests on it (the box sprite is still drawn on top by the puzzle layer). Logic unchanged (`pbox_en`).
* **Simon** (floor 3, plates `q w e r`): each plate is a **big plate = the 2x2-tile block** already in the map. The 32x32 art sits in tile slots 12-15 and the renderer samples it at **half size** per quadrant (tile column / row parity), so the 4 tiles of a block form ONE 64x64 plate, no extra ROM. The 4 plates are told apart by a **colour tint** (red, blue, green, yellow; `"tint"` in `sprites/tileset.json`). Lit / wrong behaviour unchanged (brightened / red).
* Needed changes: tile pipeline got per-tile `file` + `cell_size` + `tint` (`scripts/build_tileset_mem.py`); `renderer.v` one condition in stage 1 (Simon room, floor 3, tile ids 12-15); the Simon map moved the two bottom plates one row up so every block starts on an even row (`maps/12_f3_puzzle_simon.txt`; tests in `tests/test_maps.py` check "even 2x2 blocks, nothing else changed").
* Known limit: the lit Simon plate is the raised plate brightened (not the pressed art; there is no free tile slot). If you want pressed art for "lit", it needs the overlay layer of 5.1.
* Tests: `tests/test_tileset_pipeline.py` (new file/tint cases), `tests/test_maps.py`, `sim/tb_simonplate.v` (renderer pixels vs `tileset.mem`).

### W14 Orc (form 2) and Angel (form 3) attack + hurt animations  (Phase A2, art received, NOT started - waiting for your approval)
Received 19/11 (uploads `Angel-...zip`, `ORc-...zip`, nothing copied into the repo yet):

| File | Size | Content (looked at) |
|---|---|---|
| `Angel/Angel_Attack.png` | 128x128 = 4x4 cells of 32 | 4 pictures per direction, same row order as the walk sheet; white slash arc around the body |
| `Angel/Angel_Dmg.png` | 128x128 | 4 pictures per direction: red flash / sparks (hurt) |
| `ORc/Form 2 Attack.png` | 128x128 | 4 pictures per direction with a white slash arc |
| `ORc/Form 2 Dmg.png` | 128x128 | 4 pictures per direction: red flash |
| `Angel/Angel_walk.c.c` | 197 KB, not an image | ignored (a stray file; the real walk sheet is already in `my_asset/Character/Angel/`) |

How they fit: the Human attack / hurt sheets have exactly this layout and are already built into `mem/player_attack.mem` / `player_hurt.mem` (16 pictures each, **flags OFF**, only form 1). The plan extends that machinery to forms 2 and 3:
* `scripts/build_player_mem.py` + `sprites/sprites.json` (`animations`): per-form sheets (`animations.forms."2".attack`, `"dmg"`, same for form 3), same scale rule as the walk sheet (form 2 and 3 = 2x), Rule 1 fallback = the normal walking picture (flag stays off for that form, warning printed).
* ROM layout: today `{melee_dir/facing, k[1:0]}` = 16 pictures. New address `{form_sel, dir, k}` with `form_sel` 0 = Human, 1 = Orc, 2 = Angel = 48 pictures = 49152 words per animation ROM.
* `player_frame.v`: today only the Human (form 0, melee). New: for forms 2-3 the **attack animation plays when a shot is fired** (`ev_shoot`), the hurt animation plays on every hit (same `invuln` trigger as the Human). Visual only, no game state changes.
* `renderer.v`: `p_aframe` / `r1_aaddr` get 2 more bits (stage 1 only), animation ROM instances become 3x deeper.
* Angel wings: the attack / hurt cells are as wide as 117 px of the 128 sheet, at 2x the wing tips are cut at the 32 px frame edge (same limit as the Angel walk pictures).
* **Block RAM options (needs your decision, the real number from your board build comes first):**

| Option | What | Extra RAMB36 (estimate, on top of the Human ones) |
|---|---|---|
| A | attack + hurt for forms 2 and 3, all 4 pictures | about +24 (attack 16 + hurt 16 for 3 forms = 32, minus the 12 already planned for Human) |
| B | same but only 2 pictures per direction (frames 1 and 3) | about +6 |
| **C (recommended for the demo)** | attack animation for forms 2 and 3 only (shows the shot), hurt = a red tint flash done in `renderer.v` (no ROM) | about +12 |
| D | wait until the board build confirms free Block RAM, then choose | 0 now |

* Tests: `tests/test_sprite_pipeline.py` (per-form animation sheets, fallback), `tb_anim_roms.v` (3x ROMs load), `tb_player_frame.v` (form 2/3 shot triggers attack, hit triggers hurt, priority death > hurt > attack), `topanim` (flags ON), `scripts/check_all.sh`.
* Docs: `docs/SPRITE_STATUS.md` section 2b (animations table) and `sprites/README.md` (Human animations section becomes "Form 1-3 animations").
* Risk medium (BRAM + renderer address width), effort ~0.5 day for option C, ~1 day for A. Needs: your option choice + approval.

### W15 Switch changes: SW15 = PAUSE, SW14 = SPRINT  (Phase A, requested 19/11, NOT started)
Today (`rtl/top.v`): SW15 = sprint (`.sprint(sw15)`, LED14 shows it), **SW14 = facing lock** (`hold_facing = bc | face_lock | sw14`), SW13 = Sokoban box reset, SW0-4 = debug (only when `DEBUG = 1`).
Requested: **SW15 = pause**, **SW14 = sprint**. This takes SW14 away from the facing lock, so the facing lock needs a new switch.

Final switch map (default; tell me if you want another):

| Switch | Function | Change |
|---|---|---|
| SW15 | **PAUSE** (up = game frozen) | new |
| SW14 | **sprint** (+1 px/frame, `SPRINT_BONUS`) | was SW15 |
| SW13 | Sokoban box reset | unchanged |
| SW12 | **facing lock** (hold direction while moving) | was SW14 (**needs your OK**) |
| SW11 | stun pulse for boss 1 if the mic fails (W4 fallback) | new, optional |
| SW10 | maze: buttons instead of accelerometer (W7 fallback) | new, optional |
| SW0-SW4 | debug (only `DEBUG = 1`, off in the hand-in build) | unchanged |

**Pause design**
* Works in `S_PLAY` (and later the maze state `S_MAZE`); ignored on TITLE, GAME OVER, WIN and in the short EVOLVE / FLOOR CLEAR cut-scenes (they are not controllable anyway).
* Implementation: in `top.v` a `paused = sw15 && state in {PLAY, MAZE}` gate **removes `frame_tick`** from `player`, `objects`, `puzzles`, `boss` and the game timer (`timer_run` in `game_fsm.v`), so positions, monsters, bullets, invulnerability, stun, Simon sequence and the mm.ss timer all stop and continue exactly where they were. The mic clap and the buttons are ignored while paused (no queued attack on resume: `atk_req` cleared).
* Display: the frozen game stays on screen, plus the text "PAUSED" in the middle (new `txt_scr` code, 2 lines max, same font; `text_layout.vh` / `text.mem`), hearts stay visible. Screen shake and the evolve blink freeze too.
* Sound: music and effects are muted while paused (a `pause` input to `audio.v` that holds the BGM position and silences the PWM) and resume from the same note.
* LEDs: LED14 now follows **sprint (SW14)** as before; LED15 stays WIN. Pause is shown on the screen and the 7-segment colon blinks.
* Files: `rtl/top.v` (switch wiring, `paused`, comments), `rtl/game_fsm.v` (timer gate input), `rtl/audio.v` (pause), `rtl/renderer.v` + `rtl/text_layout.vh` / `mem/text.mem` via `scripts/make_font.py` (PAUSED text), `constraints/nexys_a7.xdc` (no change, SW pins exist), docs: `docs/BOARD_TEST_STEPS.md` (controls row), `README.md` (control table), `docs/BOARD_DAY.md` (checklist line 5), `docs/CHANGE_REVIEW.md`.
* Tests: `tb_game_fsm.v` (timer does not advance while paused), `tb_top.v` pause case (positions / monsters / timer unchanged for N frames with SW15 up, same after release), `tb_audio.v` (BGM position held), `tb_player.v` sprint test uses SW14 now, `scripts/run_sim.sh all`.
* Risk low-medium (one gate on `frame_tick`; check timing: `frame_tick` is generated once, so it is a single AND). Effort ~2 h.

### W3 Charged shot stops on hit  (Phase A, tiny Verilog) - DONE 20/11 on dev (tb_objects + tb_boss green; enemy-bullet clash unchanged)
* Today: kind 3 (16x16 big ball) pierces; `big_mask` stops double hits and enemy bullets are destroyed when it overlaps them (`S_CPE`).
* Change in `objects.v` `S_CPB`: when kind 3 hits a monster, clear `p_act` of that bullet after applying `BIG_DMG`; drop `big_mask`. Keep "destroys enemy bullets" only if you still want it (decide: it must not delete the boss-3 big attack, see W12).
* Boss hit: the boss takes damage (`boss_dmg` with amount) and the ball disappears.
* Tests: update `tb_objects.v` (the "ลูกใหญ่ทะลุ" case becomes "stops, damages one monster once"), `run_sim.sh objects`, `boss`.
* Risk low, effort ~1 h.

### W4 Clap does not work on the board  (Phase A, mostly your hardware time)
* The microphone was only tested in simulation. Steps (no design change): 1) run the stand-alone mic test top (`scripts/create_mic_project.tcl`, `constraints/mic_test.xdc`: bar = amplitude, BTNC clears the peak, SW sets `MIC_TH`); 2) read the printed amplitude for a clap and for silence, pick `MIC_TH` / `MIC_WINDOW` / `MIC_HOLDOFF` in `rtl/params.vh`; 3) check pins J5 `M_CLK`, H5 `M_DATA`, F5 `M_LRSEL` against the Digilent master XDC (the note in `mic_test.xdc` says they were **not verified**); 4) check the PDM sampling edge (`pdm_mic.v`, left vs right channel via `M_LRSEL`).
* Fallback (Rule 1): if the mic cannot be fixed by Friday, a button/switch also triggers the stun pulse (one-line OR in `top.v`, switch **SW11** in the switch map of W15), documented as "mic or switch".
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
2. **Unlock the start door.** The door at floor 3 START (tile `E`) is a **solid wall** (see W1) until the player has the key; with the key it **disappears** (becomes floor) and walking through starts the minigame (a new `maze` trigger instead of the current `escape_start` / `S_ESCAPE`). The back-track route to START stays the same as the old ESCAPE route (`06_...`/`10_...` maps unchanged).
3. **New FSM state `S_MAZE`** in `game_fsm.v` (`localparam` list: TITLE, PLAY, EVOLVE, FLOOR_CLEAR, ESCAPE(removed), WIN, GAME_OVER + PROLOGUE + MAZE). Timer: reuse the seg7 mm.ss counter as a countdown (`ESCAPE_*` parameters become `MAZE_TIME`).
4. **`maze.v`**: a ball (fixed-point position and velocity), walls from a maze map (a 20x15 room grid: grids 13-15 are free, generated by `build_maps.py` from `maps/13_maze.txt`), goal tile, collision with wall tiles, friction, speed clamp, frame-based update at the 60 Hz `frame_tick`. Drawing: ball sprite 16x16 (one more frame in `puzzle.mem`), maze walls from the tileset, text "TIME" via the existing digits.
5. **`adxl362.v`** (accelerometer): the Nexys A7 has an ADXL362 on SPI (pins `ACL_MISO`, `ACL_MOSI`, `ACL_SCLK`, `ACL_CSN`; **take the exact pin names and locations from the Digilent Nexys A7-100T master XDC and add them to `constraints/nexys_a7.xdc`; I have not verified them**). Init sequence: soft reset (reg 0x1F = 0x52), measurement mode (reg 0x2D = 0x02), then read X/Y 8-bit (reg 0x08 / 0x09) about 100 times per second, SPI mode 0, <= 1 MHz (divider from 100 MHz). Output: signed `ax, ay`, with an automatic **offset calibration** (average of the first 32 samples when the maze starts) and a **dead zone** so a flat board does not drift.
6. **Fallback (Rule 1):** if the sensor does not answer (no data valid within 0.5 s) or **SW10** is up (switch map in W15), the 4 direction buttons push the ball, so the game can always be finished.
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

### W11 Boss 2 - summons minions, hurt ONLY when all minions are dead  (Phase B)  [rule corrected 19/11]
Rule (owner): **the boss is NOT damageable while any minion is alive (shielded); it is damageable ONLY when ALL minions are dead.** (An earlier version of this plan had the opposite rule; that was wrong.)
* States (state machine; damage is accepted **only in VULNERABLE**):
  ```
  IDLE -> SUMMON (spawn 3 minions)
       -> MINIONS_ALIVE   (boss takes NO damage, shield tint)
       -> (all minions dead) -> VULNERABLE (boss takes damage, normal sprite)
       -> (VULN window over) -> SUMMON (new round)
  HP = 0 -> DEAD
  ```
* How:
  * `boss.v` applies damage **only in state VULNERABLE** (new flag `vuln`, derived from the state, **not** from `minions_alive == 0`, so the boss cannot be hit in IDLE before the first summon). All `boss_dmg` pulses in the other states are ignored (shield "clink" feedback / flash is optional).
  * `boss.v` outputs `summon` (pulse) + `summon_n`; `objects.v` gets an input `summon` and spawns minion type A at free slots in a ring around the boss (the room has 6 monster slots; **default: 3 minions**, so 3 slots stay free), and still outputs `minions_alive` (count of active minion slots, boss room only). `boss.v` moves `MINIONS_ALIVE -> VULNERABLE` when `minions_alive` reaches 0 after a summon.
  * Visual cue: **SHIELD tint** while IDLE / SUMMON / MINIONS_ALIVE, **normal sprite in VULNERABLE** (this replaces the old tint logic; use a `boss_flash`-style tint path in `objline.v`).
  * The VULNERABLE window length is a parameter `BOSS2_VULN_FRAMES` (replaces the old "invulnerable time" parameter), default 2 s = 120 frames, then the next SUMMON starts.
* Boss 2 stops bouncing/firing in the fence (new movement: slow drift or stationary; default **stationary**).
* Form 3 AOE (W13) stays the intended weapon, but its job is to **clear the minions fast**; the boss itself is only hurt afterwards, during VULNERABLE (any form can hit it then, the AOE split bullets included).
* Tests: `tb_boss.v` extended: summon spawns N; **damage is rejected while any minion is alive and in IDLE**; damage is accepted in VULNERABLE; the state returns to SUMMON after `BOSS2_VULN_FRAMES`; HP 0 -> DEAD. `tb_objects.v` (spawn on `summon`, slot limit, `minions_alive` count).
* Risk medium-high (boss <-> objects handshake), effort ~1 day. Needs: numbers (minions, VULN window; 2 s may be too short for boss HP 16, tune in playtest).

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
3. Docs updated in the same commit: **`docs/FEATURES.md` (always)**, `docs/SPRITE_STATUS.md` (art), `docs/SOUND_PLAN.md` (sound), this file (status), `docs/NEXT_STEPS.md`.
   Standing rule: **every new idea from the owner is first written into this file as a plan item** (next W number, "waiting for approval"); implementation starts only after approval.
4. Board test with `docs/BOARD_TEST_STEPS.md`; I add a "what to check" paragraph for every item that touches the board (clap, accelerometer, boss feel).
5. Branch per item (`feature/boss1` ...), merge into `sprite-zip` only after 1-3; `main` only when you say "merge".

### 5.4 Sound / art needs created by the plan
* Sounds (using the existing SFX pipeline): boss summon, shield hit ("clink"), boss-3 charging, big attack, trap trigger, breakable block break, key pickup, maze tick / win. (Details in `docs/SOUND_PLAN.md` once you approve.)
* Art: maze ball, key (reuse `keys_*_1.png` from the pack), trap and breakable box art (peaks for spike traps, `box_*_1.png` for breakables are already in `my_asset/props`), boss 3 telegraph tint (no art).

---

## 6. Open questions and my default answers

Reply with changes only; otherwise the defaults are used.

| # | Question | Default |
|---|---|---|
| 1 | Maze time | 60 s |
| 2 | Maze timeout | GAME OVER (restart the whole game); a softer option is "restart the maze 2 times" |
| 3 | Boss 1 stun / clap cooldown | 3 s / 4 s |
| 4 | Boss 2 minions / vulnerable window | 3 minions / boss vulnerable 2 s after the last minion dies, then it summons again (2 s may be too short for boss HP 16, tune in playtest) |
| 5 | Boss 3 charge time / charged hits to kill / big attack | 2 s / 3 hits / room-wide lethal hit |
| 6 | Charged shot destroys enemy bullets when it stops? | no |
| 7 | Trap kinds first | spike (static, 1 damage) only; timed spikes later |
| 8 | Breakable block hits | 1 hit (any bullet or melee) |
| 9 | Accelerometer fallback | direction buttons when no sensor data or when a switch is up |
| 10 | Prologue advance | any button, or 6 s |
| 11 | Mic fallback | SW11 also gives the stun pulse (documented) |
| 12 | Facing lock switch (SW14 is sprint now) | SW12 |
| 13 | Pause shows | the frozen game + "PAUSED", music muted, timer stopped |

---

## 7. Effort summary

| Phase | Items | Estimate |
|---|---|---|
| A | W1 W2 W3 W4 W6 W9a W15 | ~10 h (W2 already started, W4 needs the board) |
| B | W10 W11 W12 W13 | ~3.5 days |
| C | W5 | ~3 days |
| D | W7 | ~5-6 days |
| E | W9b | ~3 h once the script exists |
| Sum | | ~2.5 weeks of focused work; **not possible before 20/11**; Phase A is the realistic part |

## 8. What I need from you (in order)
1. Confirm / change the defaults in section 6 (a one-line answer is enough).
2. The start-screen / prologue wording (W6, W9a), the story script (W9b). (The plate picture is already received.)
3. Board time for W4 (mic) and later W7 (accelerometer), and the Block RAM / WNS numbers from the current build.
