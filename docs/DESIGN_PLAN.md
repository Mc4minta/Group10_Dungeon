# Design implementation plan (from the "Group 10 - Design Notes", 19/11/2026)

**Status (21/11/2026): every item W1-W46 is implemented except the parts listed in the FUTURE BACKLOG table (below W45); the items marked "not tested on the board" need the owner's board test.** Section 6 "Open questions" and the older status text below are history. New ideas: write them here first (next W number), implement after the owner's approval.
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

### W1 Door sprites: every world door = spike trap, the maze door = solid wall  (Phase A, updated 19/11) - DONE 20/11 on dev (tileset.json overrides + new `cut` option in build_tileset_mem.py; tests in test_tileset_pipeline.py; no Verilog change)
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

### W2 Pressure plate art  (Phase A) - DONE 20/11 on dev (art + tile pipeline + Simon big plates verified: `test_tileset_pipeline`, `test_maps`, `tb_simonplate` 18688 pixels green; known limit below stays; the box-on-plate look is the separate item W26)
Your picture `my_asset/props/plate.png` = 32x64: cell row 0 = **raised** plate, row 1 = **pressed** plate (grey 180 with shading).
* **Sokoban** (floor 2, 2 plates `O`): tile 7 = raised plate while no box is on it, tile 11 = pressed plate when a box rests on it (the box sprite is still drawn on top by the puzzle layer). Logic unchanged (`pbox_en`).
* **Simon** (floor 3, plates `q w e r`): each plate is a **big plate = the 2x2-tile block** already in the map. The 32x32 art sits in tile slots 12-15 and the renderer samples it at **half size** per quadrant (tile column / row parity), so the 4 tiles of a block form ONE 64x64 plate, no extra ROM. The 4 plates are told apart by a **colour tint** (red, blue, green, yellow; `"tint"` in `sprites/tileset.json`). Lit / wrong behaviour unchanged (brightened / red).
* Needed changes: tile pipeline got per-tile `file` + `cell_size` + `tint` (`scripts/build_tileset_mem.py`); `renderer.v` one condition in stage 1 (Simon room, floor 3, tile ids 12-15); the Simon map moved the two bottom plates one row up so every block starts on an even row (`maps/12_f3_puzzle_simon.txt`; tests in `tests/test_maps.py` check "even 2x2 blocks, nothing else changed").
* Known limit: the lit Simon plate is the raised plate brightened (not the pressed art; there is no free tile slot). If you want pressed art for "lit", it needs the overlay layer of 5.1.
* Tests: `tests/test_tileset_pipeline.py` (new file/tint cases), `tests/test_maps.py`, `sim/tb_simonplate.v` (renderer pixels vs `tileset.mem`).

### W14 Orc (form 2) and Angel (form 3) attack + hurt animations  (Phase A2) - DONE 20/11 on dev, **option C chosen**: attack ROM for Human + Orc + Angel (48 pictures, address {form, dir, k}), `player_frame.v` takes a `shoot` pulse, hurt = red flash in `renderer.v` (`p_hurt`); flags in `sprites.json`; the board build must confirm the Block RAM (about +16 RAMB36 for the attack ROM)
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

### W15 Switch changes: SW15 = PAUSE, SW14 = SPRINT  (Phase A, requested 19/11) - DONE 20/11 on dev (SW12 = facing lock; SW10 / SW11 fallbacks stay with W4 / W7)
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

### W4 Clap does not work on the board  (Phase A, mostly your hardware time) - ROOT CAUSE FOUND 20/11 and fixed in code (needs a board check): the detector measured the DC level of the PDM stream (`|ones - 2048|` over 1.64 ms), but a real microphone signal is AC, so the average over the window is about 0 for ANY sound and it could never fire; the simulation fed a DC-biased stream, which hid it. `pdm_mic.v` now removes the DC per 64-sample block and takes the peak loudness (see its header); the testbenches use a sigma-delta model of a 2 kHz tone; the threshold can be changed with SW5-SW8 and is visible on the screen (W27)
(20/11: the mic pins J5 / H5 / F5 in `constraints/nexys_a7.xdc` match the Digilent Nexys-A7-100T master XDC, so step 3 below is done; the amplitude / threshold tuning still needs the board. Boss 1 is now the clap boss, SW11 = backup pulse.)
* The microphone was only tested in simulation. Steps (no design change): 1) run the stand-alone mic test top (`scripts/create_mic_project.tcl`, `constraints/mic_test.xdc`: bar = amplitude, BTNC clears the peak, SW sets `MIC_TH`); 2) read the printed amplitude for a clap and for silence, pick `MIC_TH` / `MIC_WINDOW` / `MIC_HOLDOFF` in `rtl/params.vh`; 3) check pins J5 `M_CLK`, H5 `M_DATA`, F5 `M_LRSEL` against the Digilent master XDC (the note in `mic_test.xdc` says they were **not verified**); 4) check the PDM sampling edge (`pdm_mic.v`, left vs right channel via `M_LRSEL`).
* Fallback (Rule 1): if the mic cannot be fixed by Friday, a button/switch also triggers the stun pulse (one-line OR in `top.v`, switch **SW11** in the switch map of W15), documented as "mic or switch".
* Risk medium (hardware), effort 1-2 h with you at the board.

### W27 On-screen microphone meter for the clap boss fight  (requested 20/11) - DONE 20/11 on dev (approved with "implement all of it"; default numbers; not tested on the board)
Owner request: during the clap boss fight (boss 1) the screen shows a mic meter with the threshold so the player sees whether a clap is detected.
* **What is drawn**: under the boss bar (below the W21 charge-bar slot), only while boss 1 is alive: a 128 x 8 px box; the fill is the sound level (green; turns red when it passes the threshold), a white line marks the threshold, the whole box background flashes yellow for 0.5 s when a clap (or SW11 / key C) is registered. The level has a quick rise and a slow fall (about 0.5 s) so it can be read.
* **Threshold**: default `MIC_TH` = 448; SW5-SW8 as a 4 bit number choose 128 x n (0 = default) so you can tune it on the board without a rebuild; the white line follows the switches.
* **Files**: `rtl/hud.v` (meter box), `rtl/renderer.v`, `rtl/top.v` (level register, flash counter, switch threshold), `rtl/pdm_mic.v` (new detector, W4), `sim/tb_pdm_mic.v` / `tb_mic_test_top.v` (AC microphone model), FEATURES, BOARD_TEST_STEPS.

### W5 Map elements: breakable block, trap, solid decoration  (Phase C) - DONE 20/11 on dev (overlay layer 5.1 option C: `overlay.mem` + `ovtile.mem` + `overlay.v`; `tilemap_rom` folds the overlay into the collision view so player / monsters / bullets / boss / puzzles needed only a `brk` port; traps = spikes only, 1 damage; all 7 rooms listed in FEATURES; board check still to do)
* **Breakable block**: blocks movement until hit by a bullet / melee, then becomes floor; state per tile must survive leaving and re-entering the room and reset on new game. Plan: a small `breakable` state memory = one bit per breakable (at most 8 per room x 13 rooms = 104 flops/LUTs), indexed by the room's breakable list generated by `build_maps.py` (like `objects.txt`).
* **Trap** (several kinds allowed): kinds = spike (damage 1 + knockback when stepped on, always on or timed 1 s on / 1 s off), maybe arrow shooter later. Rules: form 3 flies over (it already crosses holes `H`), damage uses the existing `take_hit` + invulnerable frames so it cannot chain-hit.
* **Solid decoration**: a wall-like tile that only changes the look (pillar, statue). Free for the player (collision = like `#`), free for bullets (stops them) - easiest to treat as a wall tile with another picture.
* How: add an **overlay layer** (decision in 5.1) instead of widening the tile id: `mem/overlay.mem` (13 rooms x 300 x 4 bit: 0 none, 1 breakable, 2 spike trap, 3 solid deco, ...), read by `player.v`, `objects.v`, `boss.v` (collision) and `renderer.v` (drawing). Art slots are added to the tileset ROM as extra tiles per floor (+3..4 tiles x 3 floors = +4 BRAM) or drawn from `puzzle.mem` frames 10-15 (free).
* Maps per floor (from the notes): floor 1 breakable boxes + decoration + elements; floors 2-3 traps + breakable boxes + decoration + elements. The current decoration characters (`, ; : `` ` ``) keep working.
* Tests: `tests/test_maps.py` (overlay validity, counts per room), new `tb_overlay.v` (breaks after N hits, persists, reset on new game, trap damage once per invulnerability window), Verilator/iverilog top.
* Risk medium-high (touches collision in 3 modules), effort ~3 days.

### W6 New start screen  (Phase A) - DONE 20/11 except the optional decoration panel (gradient background; **game name = THE CHOSEN ONE**, from `docs/STORY.md` TITLE-01 via `scripts/story.py`, 13 letters at scale 4 fit the 640 px screen)
* Today: navy background + two text lines (`text_layout.vh`, 8x8 font, A-Z 0-9 space `- : ! .`, 2 lines max, no Thai).
* Plan: better background colour/gradient, bigger title text (scale 4 already exists for line 0), the hero sprite is drawn by `top.v` at `px,py` on the title screen; optionally `my_asset/ui/MediavelFree.png` panel / candle / sword as decoration (needs a small `ui` ROM: wood panel 16x? chunks; about 1-2 BRAM).
* Game name: **not needed yet** (design notes) - **decided 20/11: the game name is THE CHOSEN ONE** (title line 0, "PRESS BTNC" blinks on line 1).
* Needs: wording + which decoration you like. Risk low, effort 1-2 h.

### W7 Endgame: key -> door -> Ball in a Maze  (Phase D) - IMPLEMENTED 20/11 in simulation only (board test of the accelerometer axes / offset / gain still mandatory; pins checked against the Digilent master XDC: ACL_MISO E15, MOSI F14, SCLK F15, CSN D15). Simplifications: the key is picked up automatically when boss 3 dies (no key sprite), the maze reuses the ESCAPE state and the 60 s countdown, the maze map is a separate 20x15 ROM (`maze_rom`) instead of a 14th room, the ball is puzzle object frame 10 (coin art)
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

### W9 Story: prologue now, story later  (Phase A / E) - W9a DONE 20/11 (4 prologue pages + 3 NEW FORM banners from `docs/STORY.md`; `S_PROLOGUE` = state 7, `PROLOGUE` parameter, `tb_text`). Tier B dialogue = new item W16 below
* **W9a Prologue** (Phase A): new state `S_PROLOGUE` between TITLE and PLAY: black screen + text in the middle of the screen, advances on a button (or after N seconds). Text limit: 2 lines per screen, 20 characters per line at scale 2 (A-Z, 0-9, space, `- : ! .`), no Thai. Add screen code 6 in `renderer.v` (`txt_scr`) and a layout in `text_layout.vh` / `text.mem` (generated by `make_font.py`). Several pages = a page counter in the FSM (page n shows text n).
* **W9b Story** (Phase E): where else text appears (floor clear, win, boss intro) - needs your script (P1.3). Long story: tell it in the video / report, not on the board.
* Tests: extend `tb_game_fsm.v` (TITLE -> PROLOGUE -> PLAY), `tb_top.v`. Risk low-medium, effort ~3 h.

### W10 Boss 1 - fast, stunned by clap  (Phase B) - DONE 20/11 on dev (stun 180 / cooldown 240 frames, SW11 fallback, boss 1 stunned picture = skeleton2 damage frame)
* Values (defaults, change in `params.vh`): HP 10 (unchanged), speed 2 px/frame every frame (today 1 px per 2 frames), no shot, takes damage at all times.
* States: `CHASE -> (clap) STUNNED (STUN_FRAMES) -> CHASE`, clap cooldown `STUN_COOLDOWN` after the stun (exists: `STUN_FRAMES`, `STUN_COOLDOWN`).
* How: `boss_rom` parameters (`speed`, `every`, `fire = 0`, `stunnable = (kind == 0)`) - small change; the speed uses the same wall-collision routine as boss 3 today.
* Fairness: with HP 10 and damage 1 per hit the player must hit while it is stunned - tune `STUN_FRAMES` (default 3 s = 180 frames) and cooldown (default 4 s).
* Tests: `tb_boss.v` (speed, stun on clap, no stun during cooldown, HP bar).
* Risk low, effort ~2 h.

### W11 Boss 2 - summons minions, hurt ONLY when all minions are dead  (Phase B)  [rule corrected 19/11] - DONE 20/11 on dev (states WAIT / MINIONS_ALIVE / VULNERABLE in `boss.v`; `summon` + 3 fixed SUMMON tiles in `objects.v`; shield = white blink)
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

### W12 Boss 3 - armour + charge + big attack  (Phase B) - DONE 20/11 on dev (`boss_dmg_big` from objects, `kill` input in game_fsm; the key drop stays with W7: boss 3 death still starts ESCAPE)
* States: `CHASE (armoured)` -> `CHARGING (telegraph)` -> `BIG ATTACK` / `INTERRUPTED`. Armour: all normal damage ignored; only **charged shot** (kind 3, form 4) damages. A charged shot that hits during `CHARGING` interrupts the attack.
* `BIG ATTACK` effect (decision needed, my default): the screen flashes and **every player inside the room not behind cover** is hit for lethal damage = set HP 0 (use `take_hit` repeated / a new `kill` input to `game_fsm.v` -> GAME OVER). Simple and clearly telegraphed; the alternative is a line / radius attack (more visual work).
* Telegraph: boss tint flashing + a sound (reuse `SFX_BOSS`), duration default 2 s (120 frames) so the player has time to charge (form 4 `CHARGE_FRAMES`) and shoot.
* Needed signals: `objects.v` exposes `boss_dmg_kind` (kind of the bullet that hit; today it only passes `boss_dmg_amt`) so `boss.v` can accept only kind 3. Charged shot stops on hit (W3).
* HP / hits: default boss 3 HP 3 charged hits (`BOSS3_HP = 3`, `BDMG_CHARGED = 1`) so the existing health bar shows 3 steps; each hit also interrupts and resets the cycle.
* On death: key drop (W7).
* Tests: `tb_boss.v` (armour: normal bullet no damage; charged bullet damage; CHARGING -> BIG ATTACK kills; interrupt resets), `tb_game_fsm.v` (kill input), `tb_top`.
* Risk high, effort ~1.5 days.

### W13 Form 3 AOE  (Phase B) - DONE 20/11 on dev (kept NP = 6 and the 3-way spread: a bullet that hits a monster splits into 4 child bullets, `p_child` / `SPLIT_LIFE`; not 8 slots as planned, one split at a time always fits)
* New behaviour: a form 3 bullet that hits a monster **splits into 4 bullets** (up / down / left / right from the hit point) that fly a short distance (default 3 tiles) and deal the same damage.
* Slots: `objects.v` has 6 player-bullet slots (`NP = 6`). The split needs up to 4 free slots at once. Plan: raise `NP` to 8, limit to 2 parent bullets in flight for form 3 (`pk_kind = 1` fire rate), spawn the 4 children in the same `S_CPB` pass using a small "split request" (position + damage) register, and mark the children as kind 1 with the flag `child` so they do not split again (needs 1 more bit per bullet).
* Art: kind 1 child bullet uses the same 8x8 bullet art (`bullet.mem`).
* Tests: `tb_objects.v` (split on monster hit, no recursive split, slot exhaustion does not crash).
* Risk medium, effort ~1 day.

### V1 Visual polish pass (requested 20/11: "make it look nice and feel good")  - DONE 20/11
What changed (all visible with `scripts/make_shots.sh`): palettes (darker floors, brighter walls, 3 distinct floor colours), monsters at hero size, 3x bosses, boss 2 = priest caster, wall torches + shields everywhere (16 overlay pictures), vignette + room fade-in, title scene, dithered title gradient. Tests: `tb_ovrender` / `tb_simonplate` model the vignette pixel by pixel, `test_boss_pipeline` / `test_monster_pipeline` check the 3x / 2x windows, `test_maps` the wall-decoration rules. Not done: drop shadows under sprites, a bigger hero (the hero art is 8x8 px; 3x would cut the attack arcs), hit-stop. Block RAM: +4 RAMB36 (overlay art 16 pictures).

### W16 Dialogue overlay (story Tier B)  (Phase E) - DONE 20/11 on dev (approved by the owner with the whole story). **`docs/STORY.md` is the source of truth** of every on-screen sentence: `scripts/build_story.py` (-> `scripts/story.py` + `make_font.py`) turns its tables into `mem/text.mem`, `mem/dlg.mem`, `rtl/text_layout.vh`, `rtl/text_select.vh`, `rtl/dlg_cfg.vh`; `rtl/dialog.v` shows the boxes (black band at the bottom, colour by speaker, timed 2.5 s or blocking until BTNC); `rtl/top.v` drives the 36 events; `tests/test_story.py`, `tb_dialog`, `tb_text`. Game name = THE CHOSEN ONE (TITLE-01). Original proposal text follows.
`docs/STORY.md` lists ~70 in-game lines (Voice / Player / System) that need a dialogue box on top of the running game: safe-room talk (F1-01..12), room hints (SPIKES ROSE! / DEFEAT ALL ENEMIES!), boss tips, endgame (END-01..05). The renderer can already draw 2 lines of text over the game (the PAUSED / NEW FORM mechanism), so a box is feasible: a small trigger table (room entry, doors closed, boss state change, item taken) selects a text screen, shown for ~2-3 s without freezing the game (or frozen for safe-room dialogue, BTNC = next line). Cost: text ROM grows (about +1 BRAM per ~70 lines at 20 chars), one trigger module (about 1 day), more for dialogue that waits on BTNC. Decide: all lines, or only the hints that teach mechanics (boss tips, F1-13, END-03..05); the rest is told in the video / report.

> 20/11 (owner request, W16 follow-up): the whole safe-room intro now plays at the very start and freezes the game until BTNC, ending with FIGHT. SOLVE. WIN., and only then can the hero move: `docs/STORY.md` F1-02 trigger changed from `first_attack` to `after:F1-01!` (the chain F1-01 .. F1-12 is one blocking run).

### W17 Boss 2 can always be hit, even while minions are alive  (Phase B change, requested 20/11) - DONE 20/11 on dev (approved): `acc` is always true for boss 2, no shield blink; defaults for the open choices: keep the timed wave rhythm (new wave 2 s after the last minion dies), HP stays 16 (tune after a playtest); `STORY.md` F2-11 / F2-12 reworded
Owner request: the second boss takes damage at all times, also while its minions live (this REVERSES the W11 rule "hurt only when all minions are dead").
* What changes: `boss.v` `acc` for kind 1 becomes always true (the IDLE / SUMMON / MINIONS_ALIVE / VULNERABLE states can stay as the summon rhythm: summon, wait, summon again; `shield` blink and `vuln` event are dropped or repurposed), `docs/STORY.md` rows F2-11 / F2-12 and the boss-2 line in the mechanics table, `tb_boss.v` (the "damage rejected" checks become "damage accepted"), FEATURES.
* Open decisions: (a) keep the summon timer (a new round every N s while the boss lives) or summon only once per HP step (e.g. at 75 / 50 / 25 % HP, which gives the fight a shape)? (b) the AOE split shot (W13) was designed to clear minions: still useful, nothing to change. (c) boss HP 16 may now be too low if the player just ignores the minions: tune after a playtest.
* Risk low, effort ~1-2 h.

### W18 Auto-lock attack like Soul Knight  (requested 20/11) - level 1 DONE 20/11 on dev, BEHIND SWITCH SW9 as approved (off = exactly the old behaviour); **level 3 DONE 20/11 (owner: complete the auto aim): the lock is sticky (the current target keeps a 48 px bonus so it does not flip between two close enemies) and a blinking yellow / red corner-bracket marker is drawn on the locked target (`lock_tx / lock_ty`, `renderer.v`); level 2 (free angle) DONE 20/11 on the owner's "complete everything": with SW9 on, form 2 shots, form 4 tap shots and the big ball fly at the locked target at a free angle (per-shot signed velocity, major axis = shot speed, minor axis = round(S x min / max) counted with comparisons, no divider; the 3-way spread of form 3 and the split children keep their 8 directions); `tb_objects` 114 checks green (new: the shot toward (-88, -74) flies (-4, -3))**. Defaults for the design questions: switch SW9; the hero turns to the target for 20 frames after each attack and walking turns it back; range 240 px Manhattan (`LOCK_RANGE`); forms 3 / 4: the spread is centred on the target, the charged ball flies at it; boss 3 armour unchanged. Levels 2 (free angle) and 3 (marker) are still open. Study text follows.
Idea: when the player attacks, the game aims at the nearest enemy automatically instead of firing only in the 4 facing directions.
Findings from the code (what exists today): bullets have 8 directions (`p_dirv` 3 bit: 4 straight + 4 diagonals, already used by the form-3 spread), the hero sprite has 4 facings, `objects.v` already scans all 6 monster slots every frame (`S_NEAR` finds enemies in the melee box), the boss position is an input, no multiplier is needed for a coarse aim.
| Level | What | Cost | Verdict |
|---|---|---|---|
| 1. 8-direction lock | at `S_ATK` find the nearest active monster / boss within `LOCK_RANGE` px (Manhattan distance, 6 + 1 candidates, one extra FSM state `S_LOCK` of ~10 clocks), turn dx / dy into one of 8 directions with two comparisons (2*\|dy\| < \|dx\| -> horizontal, 2*\|dx\| < \|dy\| -> vertical, else diagonal), set `facing` (4-way) from the dominant axis and fire in that direction; melee form 1 turns the swing box the same way | no BRAM, ~100 LUT, objects.v + player facing input, tests in tb_objects | **feasible, recommended first step (about 1 day)** |
| 2. Free angle | bullets with a fixed-point velocity (vx, vy per bullet: +2 x 10 bit x 6 slots), direction from a small lookup / CORDIC-free table (dx, dy -> unit vector by comparing against 16 sectors) | ~+60 flops, bullet move/collision code changes in S_PB, wall tests | feasible, ~2-3 days; looks much better, not needed for the demo |
| 3. Sticky target + indicator | keep the lock until the target dies / leaves range, draw a small marker on the target (objline: one more sprite) | a few flops + one sprite slot | optional polish |
Design questions for the owner: (1) always on, or a switch (default SW9: lock on / off), or only while BTNC is held? (2) does the hero turn toward the target even when walking away (facing lock SW12 conflict)? Default: attacking turns the hero, walking turns it back. (3) range: whole screen or about 6 tiles (default 200 px)? (4) forms 3 / 4: the 3-way spread centres on the target; the charged ball flies at the boss; boss 3 armour is unchanged. (5) does the 8-direction auto-lock make the game too easy? Boss fights (stun / shield / armour / charge timing) stay the skill part.
Recommendation: build level 1 behind a switch after the board test of everything else, because it changes how every fight feels.

### W19 Floor 2 traps: real damage, and they retract / appear on a timer  (Phase C change, requested 20/11) - DONE 20/11 on dev (approved; defaults used: 1.5 s / 0.5 s / 1 s, 2 damage, two phases, floor 2 only; floor 3 traps stay static 1 damage; `tb_objects` 108 checks green, Python tests green, board feel still to check). Original plan text follows
Owner request: the floor-2 traps must really hurt the player, and they must go down and come up again over time (not stay up all the time).
Today (W5): spike trap = overlay code 2, always up, 1 damage + knockback through `trap_under` in `objects.v` (`S_CPM`), the same `hurt_cnt` window as a monster hit. Form 3 flies over. This is the "static spike, 1 damage" default of question 7; W5 listed "timed 1 s on / 1 s off" as a later option, this item is that option, for floor 2.
* **Timed cycle** (what the player sees): spikes flat = safe, a short warning (spikes half up), spikes fully up = dangerous, then back down; repeat. Default numbers (60 fps): down 90 frames (1.5 s), warning 30 (0.5 s), up 60 (1 s) = 180-frame loop. Damage only while fully up. Neighbouring traps can be out of step (phase offset) so a corridor of spikes forms a pattern the player can time.
* **Damage that is felt**: 1 heart per hit today may feel weak with HP 10; default for floor 2 = **2 damage** per hit (floor 1 stays 1, floor 3 has no traps yet), with the knockback and the red hero flash (`p_hurt`) already used for monster hits, plus a "hit" sound. The invulnerable window stays so one stand-still cannot chain-hit. Stepping onto up spikes hurts at once; spikes rising under a standing player also hurt (that is the point of the warning frame).
* **How** (small): one global free-running 8-bit phase counter in `objects.v` (or `world.v`) gives `trap_phase` = down / warn / up for every trap; per-trap offset taken from a spare bit of the overlay code (code 2 = phase A, code 4 = phase B, 4-bit overlay has free codes) so no new memory. `trap_under` becomes `trap_under && trap_up`; the hurt amount comes from a floor-2 flag (`world.v` already knows the floor). Collision for the player stays "floor" in every phase. `renderer.v` picks the picture by phase: 3 spike pictures in `overlay.mem` art slots (flat, half, full: art slots 6-15 are spare; the existing spike picture = full, the other two are cut or recoloured from the same peaks sprite, about +0 BRAM). Pausing freezes the counter; it resets on new game / room entry so a room always starts with the traps safe for about 1 s.
* Files: `rtl/objects.v` (phase, damage amount), `rtl/renderer.v` + `sprites/overlay.json` + `scripts/build_overlay_mem.py` (3 pictures), `maps/*.txt` (which floor-2 traps use phase B), `scripts/build_maps.py` + `tests/test_maps.py` (new overlay code), `sim/tb_objects.v` (no damage while down, damage 2 while up, once per invulnerable window, damage when the spikes rise under a standing hero, no damage for form 3), FEATURES / SPRITE_STATUS.
* Open decisions (defaults will be used unless you say otherwise): (a) timing 1.5 s down / 0.5 s warning / 1 s up, (b) damage 2 on floor 2 only, (c) should floor 3 get timed traps too (not now), (d) should all floor-2 traps share one rhythm or use two alternating phases (default: two phases).
* Risk low-medium (one counter + one damage change + 2 extra pictures), effort ~half a day. Board check: does the 0.5 s warning give enough time to step away at walking speed.

### W20 Bosses: less melee chase, more bullet hell  (Phase B rework, requested 20/11) - DONE 20/11 on dev (approved; defaults used: all 3 bosses, chase 1 px every 2nd frame, bullet speed 3 straight / 2 per axis diagonal, patterns cross / ring / X / aimed fan, 20-frame blink telegraph, boss 3 charge + lethal big attack unchanged until W21 / W24; `tb_boss` 61 checks green; board feel + HP tuning still to do). Original plan text follows
Owner feedback from playtest: the boss walks too fast, the player cannot shoot it in time, and the fight is too hard because the boss mostly hurts by touching the player. Wanted: a bullet-hell style fight (dodge patterns, shoot back), not a melee chase.
Today (code): boss 1 chases at `BOSS1_SPEED` = 2 px every frame (the player walks 2-3 px/frame, the player bullet flies 4 px/frame), no shot, contact = damage, only a clap stuns it; boss 3 chases at `BOSS3_SPEED` = 2 and fires one 4-way volley every `BOSS3_FIRE` = 60 frames; boss 2 is stationary (summons, no shot). Enemy bullets fly `EB_SPEED` = 3 px/frame, max 16 slots.
* **Movement**: boss 1 and boss 3 slow down a lot (default 1 px every 2nd frame = 0.5 px/frame for chase bosses) or stop chasing and drift / hover (patrol along the room, change side every few seconds), so a bullet can reach them. Contact damage stays 1 but the boss no longer homes in on the player.
* **Attacks = patterns of bullets** (the damage source): reuse `boss_fire` + the 16 enemy-bullet slots; add a pattern id per boss: boss 1 = aimed 3-bullet fan every 1.5 s plus a slow ring every 4 s; boss 2 = rotating 8-way spiral (stationary, fits it) while the minion waves stay; boss 3 = 8-way ring, then a gap-ring (one safe gap), then the existing charge + big attack. Bullet speed 2-3 px/frame (slower than the player's 4) so dodging is fair. Every pattern has a visible 20-frame telegraph (boss tint) before it fires.
* **Fairness numbers** (defaults): enemy bullet 1 damage, boss contact damage 1 with the existing invulnerable window, boss HP stays 10 / 16 / (boss 3 unchanged) and is re-tuned after a playtest; clap stun for boss 1 stays (now a bonus, not the only way to win).
* **Files**: `rtl/params.vh` (speeds, fire periods), `rtl/boss.v` (pattern timer, pattern id, telegraph flag, hover motion), `rtl/objects.v` (`boss_fire` becomes `boss_fire` + `boss_pat`: spawn N bullets with a direction table, 8 directions already exist), `rtl/renderer.v` (telegraph tint, optional), `sim/tb_boss.v` (boss speed, pattern bullet count / directions, contact still hurts once per window), FEATURES / STORY boss tips.
* Open decisions: (a) all 3 bosses or only boss 1 + 3, (b) boss 1 keeps a short charge dash (telegraphed) or not, (c) bullet speed 2 or 3 px/frame, (d) boss HP up a little because the player can now hit it more easily.
* Risk medium (bullet slots, FSM timing, difficulty tuning needs the board), effort ~1.5 days. Cheapest first step (about 1 h, can be done before the full rework): only lower `BOSS1_SPEED` / `BOSS3_SPEED` and re-test.

### W24 Boss 3 big attack = all-direction bullet storm, heavy damage, NOT instant death  (requested 20/11) - DONE 20/11 on dev (approved; defaults: storm 2 s = volleys cross / X / ring / X / cross every 24 frames, 2 HP per storm bullet via the double hit pulse, rest 2 s with any hit hurting the boss, `kill` no longer used by boss 3; because only 16 enemy-bullet slots exist the volleys are 4-8 bullets, not three full rings; `tb_boss` green). Original plan text follows
Owner request: at the end of the boss-3 charge the player must not die instantly (today `kill` = HP 0 = GAME OVER in `boss.v` / `game_fsm.v`). Instead the boss releases a bullet hell in every direction that hurts a lot but can be survived (and dodged).
* **Attack**: when the charge reaches 100 % the boss fires a storm from its centre: 3 rings of 8 bullets (16 enemy-bullet slots are the limit, so the rings go out one after another: ring 1 straight + diagonal, ring 2 shifted by 22 degrees is not possible with 8 directions, so ring 2 = a second 8-way ring 20 frames later, ring 3 = 20 frames after that) plus a spinning arm of single bullets for about 2 s; bullet speed 2-3 px/frame so it is dodgeable between the rings; the safe lanes are the gaps between the bullets of one ring (the player squeezes diagonally) and the corners of the room.
* **Damage**: each bullet of the storm does 2 HP (`BOSS3_STORM_DMG`, default 2; normal enemy bullets stay 1). The player has 3-5 HP depending on the form, so one hit hurts a lot, two hits are nearly lethal, and a clean dodge costs nothing. No instant death: `kill` is removed from boss 3 (the pulse and the `game_fsm` input stay for other uses or are removed), the invulnerable window still protects against a chain of hits.
* **Interrupt** stays: a charged shot (form 4) during the charge cancels the storm and restarts the cycle (W12 rule). After the storm the boss rests (stands still, vulnerable, 2 s) so the player has a reward window.
* **How**: `boss.v` new state after the charge: `storm` for N frames, output `fire` with a new pattern id 3b `STORM` plus a rotating start direction; `objects.v` S_BFIRE spawns the ring and marks these bullets as heavy (one bit per enemy-bullet slot, `e_heavy`), `S_CPE` reads the bit for the damage (`hit` pulses twice or `take_hit` with damage 2, same trick as the W19 timed trap: second pulse). Needs the W20 8-direction enemy bullets (done) and W21 charge bar (the storm releases when the bar is full).
* Tests: `tb_boss.v` (charge end spawns bullets in all 8 directions, no GAME OVER when the player stands still with full HP of the form, 2 HP per heavy bullet, charged shot still interrupts, rest window), FEATURES, STORY lines for boss 3.
* Open decisions: (a) heavy damage 2 or 3 (default 2), (b) storm length 2 s, (c) a safe spot in the corner or none (default none, the gaps are the skill), (d) after-storm vulnerability window yes / no (default yes).
* Risk medium (bullet slots, balance), effort ~1 day.

### W21 Boss 3 charge: slower, smooth, readable progression  (Phase B polish, requested 20/11) - DONE 20/11 on dev (approved; 4 s charge `BOSS3_CHARGE` = 240, charge bar 128 x 8 px under the boss bar in `hud.v` (yellow -> orange -> red), blink speed by quarter (`tele_lvl`), blink colour ramp pale blue -> yellow -> orange -> red (`boss_fcol`), rising beep at every step (SFX 13); `tb_boss`, `tb_audio`, `tb_hud`, renderer tbs green; look, sound and timing to check on the board). Original plan text follows
Owner feedback from playtest: the last boss's charge animation is not smooth and the charge is too fast; the player needs a visible progression (a good look) and enough time to react / interrupt with charged shots.
Today (code): `BOSS3_CHARGE` = 120 frames (2 s, `params.vh`); `boss.v` `tele` = 1 for the whole charge and `top.v` only blinks the boss sprite (`boss_flash` = `b_tele & fc[2]`, a plain 4-frame on / off), no progress shown; when it ends `kill` = room-wide lethal hit. A charged hit (form 4) interrupts it (`intr`) and restarts the cycle.
* **Slower**: `BOSS3_CHARGE` 120 -> 240 frames (4 s, default; 3 s is the alternative) so the player can reach the boss and land the charged shots. Chase stays as in W20.
* **Progression you can see** (all cheap, no new art): (1) a **charge bar** under / above the boss that fills from 0 to 100 % over the charge (reuse the boss HP bar drawing in `hud.v`, different colour), (2) the blink gets **faster in steps** (slow at 0-50 %, medium 50-80 %, fast 80-100 %) instead of the constant 4-frame blink, (3) a **growing glow**: a tint that ramps through 3 colours (blue -> yellow -> red) on the sprite as the charge fills (the renderer has the `p_tint` mechanism for the player; the same idea for `boss_flash`), (4) optional dark vignette / screen shake in the last 20 %.
* **Smooth**: `boss.v` exposes `tele_lvl` (0..3 = quarter of the charge, derived from `phase_t`, no division: compare with 3 constants) and `tele_pct` (bar fill, `phase_t` scaled) next to `tele`; `renderer.v` picks tint / blink rate from the level, so the change from one step to the next is gradual instead of a sudden blink.
* **Sound** (needs approval of SOUND_PLAN): a rising pitch during the charge, one low hit at 100 %. Today the dialogue line `EV_CHARGE_F3` is the only cue.
* Files: `rtl/params.vh` (`BOSS3_CHARGE`, quarter thresholds), `rtl/boss.v` (`tele_lvl`, `tele_pct`), `rtl/hud.v` (charge bar), `rtl/renderer.v` + `rtl/top.v` (tint / blink by level), `sim/tb_boss.v` (charge length, level steps 0-3, interrupt still works, kill at the end), `docs/FEATURES.md`.
* Open decisions: (a) charge length 4 s or 3 s, (b) charge bar yes / no (default yes), (c) screen shake in the last 20 % (default no, VGA frame is fixed), (d) rising sound (default yes when the sound plan is approved).
* Risk low-medium, effort ~half a day; tune after the board test.

### W22 Play with a USB keyboard on the Nexys USB-HID port  (Phase A2 input, requested 20/11) - DONE 20/11 on dev (approved; default key map; extra keys L = auto-lock toggle, R = Sokoban reset, C = clap; pause and lock are toggles; `ps2_kbd.v`, `tb_ps2` 30 checks green, pins added to `constraints/nexys_a7.xdc`; BOARD-CONFIRMED 20/11: the owner's keyboard works after the rebuild; RGB LED 17 blue / green show PS/2 clock activity / decoded bytes). Original plan text follows
Owner request: play with a keyboard plugged into the board's USB port (the Nexys A7 USB-HID host port, top right, next to the Ethernet jack), in addition to the buttons.
Facts: the Nexys A7 has a PIC24 that talks to the USB keyboard and presents it to the FPGA as a **PS/2 keyboard** on two pins (`PS2_CLK` = F4, `PS2_DATA` = B2, LVCMOS33, both with pull-ups). So the FPGA needs only a small PS/2 receiver, no USB stack. Keyboards must be USB HID boot-protocol compatible (most simple wired keyboards are; some gaming / wireless dongle keyboards are not). Today the inputs are `BTNU/D/L/R` (walk), `BTNC` (attack / start) + switches, debounced in `top.v`, no PS/2 anywhere in `constraints/nexys_a7.xdc`.
* **Keys (defaults, owner can change)**: arrows or **W A S D** = walk (diagonals when two are held), **Space** (or J) = attack = BTNC, **Enter** = start / next dialogue line (also BTNC), **P** or Esc = pause (same as SW15), **Left Shift** = sprint (like SW14). Keyboard and buttons work at the same time (logical OR), so the board test and the demo can use either.
* **How**: new `rtl/ps2_kbd.v` = synchroniser for `PS2_CLK` / `PS2_DATA` (2-FF + falling-edge detect), 11-bit frame shift register with parity check and a timeout, scan-code decoder: make code, `F0` break prefix, `E0` extended prefix (arrow keys are `E0 75/72/6B/74`; W/A/S/D = `1D/1C/1B/23`; Space = `29`; Enter = `5A`; P = `4D`; Esc = `76`; L-Shift = `12`) -> a held-key bit per action (set on make, clear on break). `top.v` ORs the bits with the debounced buttons before the existing logic (`bu | k_up`, `bc | k_atk`, `sw15 | k_pause`) and the rising-edge pulse for attack is made from the combined level; nothing else in the game changes. Cost: about 60 flops + 100 LUT, no BRAM. A stuck key after unplug: all held bits clear on a 2 s idle timeout only while no key is down, and on reset.
* **Constraints**: add `PS2_CLK`, `PS2_DATA` to `constraints/nexys_a7.xdc` (F4, B2) and the top port list; the sim tops (`tb_top`, Verilator) tie them high (idle).
* **Tests**: new `sim/tb_ps2.v` (send frames bit by bit at ~12 kHz: make / break, E0 arrows, two keys at once, bad parity ignored, key held then released, reset clears), `tests/` unchanged; `scripts/run_sim.sh ps2` added to `all`.
* **Board check** (`docs/BOARD_TEST_STEPS.md`): plug the keyboard before or after power-on (the PIC enumerates it within about 1 s), walk with arrows, attack with Space, pause with P; note which keyboard model worked. Fallback if a keyboard is not recognised: use the buttons (nothing is removed).
* Open decisions: (a) key map above or different (e.g. J / K for attack / sprint), (b) also map the switches that are awkward on a keyboard (SW9 auto-lock = key L, SW13 Sokoban reset = key R, SW11 clap fallback = key C), default yes for L / R, (c) hold-to-sprint or toggle.
* Risk low-medium (hardware: depends on the keyboard model), effort ~half a day + board time.

### W23 Map redesign: less symmetric, less basic  (Phase C, requested 20/11) - DONE 20/11 for the combat rooms (4 5 7 8 10 11), start room 1 and boss rooms 2 / 3 on the owner's "just do it" (no sketch round): every object has a purpose, listed per room in `docs/MAP_DESIGN.md`; NOT redrawn on purpose: start room 0 (tb_objects pins its tiles) and puzzle rooms 6 / 9 / 12 (the walls are the puzzle); `tb_boss` green on the new boss rooms; `tests/test_maps.py` (new `test_redesigned_rooms`) and `tb_objects` green, other sims not re-run, board check of monster paths / doors still to do
Owner feedback: the rooms are too symmetric and too basic (mirrored left / right, the same fence blocks, monsters in neat pairs).
Today: 13 hand-written ASCII maps in `maps/*.txt` (20 x 15 tiles); most combat rooms are mirror images (fence blocks `F`, torches `t` and decoration placed in pairs, 2 doors on opposite walls), few obstacles, decoration is scattered randomly, only 4 traps / 3 breakable blocks in total.
* **Principles** (checked room by room): (1) no left / right mirror, each room gets one clear **theme** (e.g. floor 1 = crypt with broken walls and bone piles, floor 2 = trap corridor / spike garden, floor 3 = ruined hall with pits); (2) **varied shapes**: L-shaped and split rooms, inner walls with gaps, pillars in clusters of 1 / 2 / 3 (not pairs), a pit (`H`) field, a narrow bridge between two areas; (3) **cover and lanes** for shooting: low cover (`F`, breakable `Z`) that bullets cannot cross, long lanes for the form 3 / 4 shots, a hiding corner for the player vs turrets; (4) **monster placement by intent**: turrets cover a lane, chasers start behind a corner so the player sees them late, not a symmetric pair; (5) **traps and breakables with a purpose**: W19 timed spikes guard a doorway or a loot corner, breakable blocks hide a shortcut; (6) **decoration** clustered at walls, corners and under torches (props that tell a story: bones near a dead end, cracks near a breakable wall), more `t` / `[` / `]` / `v` variety, not evenly spaced; (7) **flow**: entry door and exit door not directly opposite, the shortest path crosses the room's feature.
* **Every object has a purpose (owner rule, 20/11)**: nothing is placed only to fill space. Each room gets a short purpose list in its sketch, and each item on it must answer "what does the player do because of this?":
  * **Breakable block `Z`** = blocks a path or hides something: a box in a doorway that must be shot or cut before the way opens, a box over a shortcut, a box in front of a turret's cover; never a loose box in the middle of a floor.
  * **Solid block / pillar `Y`, wall pieces `#`, fence `F`** = cover from turret bullets, a lane that guides the player, or a choke point; `F` lets bullets pass and blocks walking (a window to shoot through).
  * **Pit `H`** = a barrier that form 3 can cross and others cannot, or that stops monsters; guards a side area.
  * **Traps `X` / `W` / `V`** = guard a doorway, a loot corner or the only path to a lever, with a timing the player can learn (W19 phases); never on a tile the player must stand on to fight.
  * **Monsters** = placed to make the room's idea work (turret covers the lane, chasers wait behind a corner); **door `D`** = closes the fight; **lever / plate / Sokoban box** = open a gate.
  * **Decoration** (bones, cracks, torches) = hints: bones near a trap or a dead end, cracks next to a breakable block, a torch beside a door or a special spot.
  * Checked by a review list per room (item -> purpose) in the sketch, and by tests where possible (a breakable that blocks a path must have the other side reachable by the player; a trap must not sit in a corridor that has no way around unless it is timed).
* **Hard rules kept**: 20 x 15, door characters and their rows / columns as `build_maps.py` and the tests expect (doors reachable from each other even when breakables count as walls, `tests/test_maps.py`), puzzle rooms (Sokoban grid 9, Simon grid 12, maze) keep their logic tiles, at most 6 monsters per room, overlay (`Z X Y W V`) only in `OVL_ROOMS` / `TIMED_ROOMS`, boss rooms keep room for the 64 x 64 boss (3x for the big ones) and the chase / pattern space of W20.
* **Process**: sketch each room here first (ASCII draft per room: room, theme, entry / exit, monster list, special element), owner approves or edits the sketches, then `maps/*.txt` is rewritten room by room (one commit per floor), `scripts/build_maps.py` regenerates the mem files, `scripts/make_shots.sh` + the room previews are checked by eye, `tests/test_maps.py` + `check_all.sh` green, board check of the monsters and doors (a new layout can break a monster path or a door check). `maps_v1/` stays as the reference of the first version.
* Order suggestion: floor 1 first (teaches the rules, small risk), then floor 2 (with W19 traps), then floor 3; boss rooms last because they depend on W20 / W21.
* Open decisions: (a) all 13 rooms or only the 6 combat rooms + start rooms (default: combat + start rooms first, bosses after W20), (b) one theme per floor (default yes), (c) do I draw the sketches for you to pick from (default: 2 sketches for room 1 as a style test, then continue).
* Risk low for the code (data only), medium for balance (the monsters and doors must be re-tested), effort ~2 days for all rooms.

### W25 Player charge shot: the ball appears and grows until release  (Phase A2 polish, requested 20/11) - DONE 20/11 on dev (approved; defaults: 4 steps, final size 14-16 px pulsing, yellow-white at full, no sound; `tb_orb` 64 checks + `tb_objects` 112 checks green; the rising sound was left out, say if you want it; look to check on the board). Original plan text follows
Owner request: while the player holds the attack button to charge (form 4), a bullet should emerge at the hero and get bigger and bigger until it is released, so the charge is visible.
Today (code): `objects.v` counts `chg` while BTNC is held (`CHARGE_FRAMES` = 45 = 0.75 s); only when it is full does `charged` go to 1 and the hero blink (`p_tint` = `charged && fc[2]`); nothing is drawn before that. On release a full charge fires the big 16 x 16 ball (`pb_kind` 3, `BIG_SPEED` 4, `BIG_DMG` 4), a short press fires the fast tap shot.
* **Look**: from the first frame of the hold a small ball (4 x 4 px) appears in front of the hero (position by `facing`, offset about 14 px from the hero centre), then grows in 4 steps as `chg` rises: 4 -> 8 -> 12 -> 16 px at 1/4, 1/2, 3/4 and full charge (0 / 11 / 22 / 33 / 45 frames). Colour shifts from the normal bullet colour to white-gold at full; at full charge it pulses (2-frame size wobble) so the player knows it is ready. It follows the hero while walking (strafe is already allowed while charging) and is hidden if the hero is hurt / the charge is cancelled. On release the drawn ball becomes the real 16 x 16 projectile at the same place, so there is no jump.
* **Which forms**: form 4 (charge) as requested; optional later: a tiny ball for form 2 / 3 while the button is held (they fire on every press, so default no).
* **How**: `objects.v` already has `chg` (0..45): export `chg_lvl` (3 bit: 0 none, 1..4 size step, 4 = full) next to `charged`. `renderer.v` / `objline.v` draw a procedural disc (no ROM: a circle test `dx*dx + dy*dy < r*r` with a 4-entry radius table, colour table) at `player + facing offset` as one more sprite slot above the player, below the HUD; a few dozen LUTs, no BRAM. Sound hook (SOUND_PLAN): a rising tone while charging, one click at full (optional, needs approval).
* **Files**: `rtl/objects.v` (`chg_lvl`), `rtl/top.v` (wire to renderer), `rtl/renderer.v` (+ `objline.v` if the sprite slot lives there), `rtl/params.vh` (step frames, radii, colours), `sim/tb_objects.v` (level steps with the hold time, resets on release or hurt), a new render test next to `tb_ovrender` (disc radius per level), FEATURES, SPRITE_STATUS (procedural placeholder, can be replaced by art later).
* Open decisions: (a) 4 size steps or smooth (every 3 frames; default 4 steps, cheaper and reads clearly), (b) final size 16 px = the real projectile (default) or a little smaller, (c) colour (default: yellow-white at full), (d) rising sound yes / no.
* Risk low (render only, no collision change), effort ~half a day. Board check: is the ball readable at VGA scale and does the growth match the 0.75 s charge.

### W26 Sokoban: a pressed plate must show the box on it, not an empty plate  (Phase A2 fix, requested 20/11) - DONE 20/11 on dev (cause: the pressed-plate picture has no box; the owner did not want to redraw it, so `scripts/make_plate_box.py` composes `my_asset/props/plate_box.png` = pressed plate + the box picture, tile 11 uses it; `test_tileset_pipeline` green; the puzzle box object is still drawn on top at the same place; look to check on the board). Original plan text follows
Owner feedback: when a box is pushed onto a Sokoban pressure plate and the plate is pressed, the box should still appear on the plate; today it looks like an empty pressed plate.
Today (code): floor 2 Sokoban (grid 9, 2 plates `O`, 2 boxes). Tile 7 = raised plate, tile 11 = pressed plate (`sprites/tileset.json`: `plate.png` row 1 = the pressed picture, no box drawn in it). The box is a separate puzzle object (`puzzles.v` `blk0` / `blk1`, picture from `mem/puzzle.mem`, drawn by `renderer.v` over the tile). When the box is on the plate the renderer shows tile 11 under the box object, so the box should be visible; the report says it is not, so the first step is to find out why.
* **Step 1 - find the cause (about 1 h)**: render the Sokoban room with a box on each plate (`scripts/make_shots.sh` / `tb_shot` scenario for room 9, or the board) and check: (a) the box object is not drawn while it stands on tile 11 (draw order or a `blk` / `pbox_en` condition hides it when the plate is pressed), (b) the box slide animation ends and the object is cleared, (c) the pressed-plate picture covers the box (tile 11 drawn after the object layer), (d) the box picture is the same colour as the plate so it only looks empty.
* **Fix**: the box sprite is always drawn on top of tile 11 in the settled position (object layer above tiles, no condition on the plate state). Belt-and-braces option: make tile 11 itself = pressed plate **with the box drawn in the picture** (new art cell `plate.png` row 2 = pressed plate + box, same size, then the box object may stay as it is), which also keeps the picture right if the object layer is ever hidden; a small colour change (glow ring or green tint on the plate edge) shows "pressed" while the box covers most of the plate.
* **Files**: `rtl/renderer.v` / `rtl/puzzles.v` (only if the cause is (a) / (b) / (c)), `sprites/tileset.json` + `my_asset/props/plate.png` (only for the baked-box option), `scripts/build_tileset_mem.py` (nothing new), `tests/test_tileset_pipeline.py` (tile 11 differs from tile 7), `sim/tb_puzzles.v` or a render test (the box pixels are on screen when the box is on a plate), FEATURES, SPRITE_STATUS.
* Open decisions: (a) baked box in tile 11 or only fix the draw order (default: fix the cause first, bake the box only if the object layer cannot be made reliable), (b) extra "pressed" cue on the plate edge (default yes, small).
* Risk low, effort ~1-2 h (more if the art cell is added).

### W28 In-game tutorial for keyboard AND buttons  (requested 20/11) - DONE 20/11 on dev (approved; simplified: the tutorial prompts live in the W32 hint strip (top centre, never freezes the game): free-to-move, MOVE, ATTACK, SPRINT, PAUSE, AUTO AIM, one after the other in the floor 1 start room, ends when you leave the room; texts in `docs/STORY.md` H-11..H-16; not tested on the board)
Owner request: the game teaches the controls, for both the keyboard and the board buttons / switches.
Today: the safe-room intro (F1-01 .. F1-12, blocking, ends with FIGHT. SOLVE. WIN.) tells the story only; nothing teaches walk / attack / sprint / pause. The dialogue system (`rtl/dialog.v`, W16) already shows a 2-line box at the bottom, blocking or not, and has event triggers such as `first_attack`.
* **When**: right after the intro, in the floor 1 start room, once per game (a new game after GAME OVER / WIN repeats it). A hold of BTNC for 1.5 s on the first prompt skips the whole tutorial.
* **Steps** (non-blocking boxes: the player keeps control, the box waits for the action, then the next one appears; every line fits 20 characters, charset A-Z 0-9 space - : ! .):
  | # | Box line 1 / line 2 | Done when | New trigger |
  |---|---|---|---|
  | 1 | `MOVE: ARROWS OR WASD` / `OR THE 4 BUTTONS` | the hero has walked 96 px | `tut_move` (distance counter in `top.v`) |
  | 2 | `ATTACK: SPACE J ENTER` / `OR BTNC` | first attack | `first_attack` (exists) |
  | 3 | `HOLD IT DOWN TO CHARGE` / `(LATER FORMS)` | skipped until form 4 is reached, shown at the first EVOLVE to form 4 | `evolved_f4` (exists) |
  | 4 | `SPRINT: SHIFT OR SW14` / `HOLD IT WHILE WALKING` | the hero moves while sprint is held | `tut_sprint` |
  | 5 | `PAUSE: P OR SW15` / `PRESS AGAIN TO GO ON` | the first pause starts | `tut_pause` (paused rising edge) |
  | 6 | `AUTO AIM: L OR SW9` / `HELPS YOU AIM` | shown at the first combat room entry (one time), no wait | `lock_f1c1` (exists) |
  | 7 | `CLAP FOR THE BOSS` / `OR SW11 OR KEY C` | shown on entering the floor 1 boss room | `enter_f1boss` (exists) |
* **Both input types in every box**: the text always names the key AND the button, so it is correct whichever the player uses (no detection of the device is needed). A small hint on the HUD is not needed.
* **How**: `docs/STORY.md` gets a new block "Tutorial" (IDs T-01 ..), `scripts/build_story.py` regenerates the text / dialogue ROMs; `rtl/top.v` gets three small detectors (`tut_move`: walked distance, `tut_sprint`: sprint level while moving, `tut_pause`: paused rising edge) and the events are added to `dlg_ev[]`; `rtl/dialog.v` needs no change (non-blocking boxes already exist, a box that waits for an event is the `after:<ID>` chain with an event as the next trigger: check in `tests/test_story.py` that every event exists in `top.v`). Cost: about 40 flops, text ROM + about 400 characters (now 1727 of 4096).
* **Tests**: `tests/test_story.py` (new rows valid, charset, events driven), `sim/tb_dialog.v` (a waiting box stays until the event), a small `tb_top` check for `tut_move`.
* Open decisions (defaults used when approved): once per game, skip by holding BTNC, box wording as above.
* Risk low, effort ~half a day.

### W29 Title screen: CONTROLS page and CREDITS page  (requested 20/11) - DONE 20/11 on dev (approved; BTNR / right arrow = next page, BTNL / left arrow = previous, BTNC starts from any page; because the text generator draws 2 lines per screen the CONTROLS list is 5 pages and CREDITS 3 pages (`controls1-5`, `credits1-3` in STORY.md) instead of one 9-line table; CREDITS names are placeholders to edit; title line 2 = BTNC PLAY  BTNR HELP; not tested on the board)
Owner request: the start (title) screen gets a credits screen and a key (controls) screen.
Today: TITLE = scene (hero vs vampire between two torches) + 2 text lines (THE CHOSEN ONE / PRESS BTNC); a screen can only have 2 lines (`text_layout.vh`); `screen` 3 bit uses 0..5 (6 and 7 are free); prologue pages use `txt_scr` 7..10.
* **Navigation** (works with keyboard and buttons): on the title, **BTNR / right arrow / D = next page**, **BTNL / left arrow / A = previous page**; pages cycle TITLE -> CONTROLS -> CREDITS -> TITLE; **BTNC / Space / Enter = start the game from any page**. A third small line on the title (blinking, scale 1): `LEFT RIGHT: HOW TO PLAY` (fits 20 chars at scale 2: `RIGHT: CONTROLS` / `LEFT: CREDITS`). The hero / vampire scene stays on the title only; the two extra pages are a plain dark screen like the prologue (black) with a coloured heading.
* **CONTROLS page** (static text, 9 lines at scale 1 = 8 px glyphs doubled = 16 px, 40 characters wide; layout, drawn in this order, heading in yellow):
  ```
  CONTROLS
  MOVE      ARROWS WASD OR BTN UDLR
  ATTACK    SPACE J ENTER OR BTNC
  SPRINT    SHIFT OR SW14
  PAUSE     P ESC OR SW15
  AUTO AIM  L OR SW9
  FACE LOCK SW12
  BOX RESET R OR SW13
  CLAP      CLAP OR C OR SW11
  CLAP BAR  SW5-SW8 SET THE LEVEL
  ```
  (keys come from W22 and the switch table in FEATURES; the page is one STORY.md table so wording is editable.)
* **CREDITS page** (heading + lines, names are PLACEHOLDERS for the owner to fill in `docs/STORY.md`):
  ```
  THE CHOSEN ONE
  GROUP 10  CE KMITL (EDIT)
  DESIGN AND CODE  NAME 1 NAME 2
  ART  2D PIXEL DUNGEON PACK
  MUSIC AND SOUND  NAME 3
  BOARD  DIGILENT NEXYS A7
  THANKS  (EDIT)
  ```
  Asset credits must match the licence of every pack used (`my_asset/`; the owner should check the pack's credit line before the demo).
* **How**: `docs/STORY.md` gets screens `controls` and `credits` with MORE than 2 lines: `scripts/story.py` / `make_font.py` are extended from 2 lines to up to 10 lines per screen (a per-screen line list with position y = 40 + 16 x line, scale 1, x = 40; the existing 2-line screens keep their layout); `text_layout.vh` / `text_select.vh` regenerate; `game_fsm` / `top.v` get a title sub-page register `tpage` (0 title, 1 controls, 2 credits) changed by BTNL / BTNR rising edges while `state == S_TITLE`; `screen` values 6 = controls, 7 = credits (black background, no scene); `renderer.v` selects the text by `txt_scr` (new codes 15, 16). The `tpage` register is cleared on reset and when the game starts. Cost: text ROM + about 700 characters (1727 of 4096 used + W28 400 = about 2800, still fits), no BRAM change.
* **Tests**: `tests/test_story.py` (10-line screens validate: length 40, charset), `sim/tb_text.v` (the new screens draw), `sim/tb_game_fsm.v` or a `tb_top` check (BTNR cycles the pages, BTNC starts from a page).
* Open decisions (defaults used when approved): navigation keys as above, black page background, credits names filled in by the owner.
* Risk low-medium (the 2-line limit of the text generator is the only real change), effort ~1 day.

### W30 Numbers on the clap meter  (requested 20/11) - DONE 20/11 on dev (owner: "on screen"; not tested on the board)
The clap meter (W27) also shows the numbers: `T nnnn` = the threshold, `L nnnn` = the live level, drawn under the meter bar with a 3 x 5 pixel digit font at 2x (white), only during the boss 1 fight. Same scale as the bar (0..4095, a silent mic should read under about 130, default threshold 448). `rtl/hud.v` (glyphs + digit pipeline), `rtl/top.v` (two `bin2bcd` converters), `rtl/renderer.v`. `tb_hud` green (no pixel changes when the meter is off); the digits themselves were not pixel-checked in simulation.

### W31 Story never interrupts play: every story box freezes the game and the input  (requested 20/11) - DONE 20/11 on dev (approved; every story box freezes the game, timed boxes close on a press or after 2.5 s, FIFO arrival order, attack input ignored until released after a box, claps dropped during a box, blinking arrow = press the attack button, PAUSED screen says `P OR SW15 TO GO ON`; `tb_dialog` 22 checks green)
Every story box (all 50, not only the 12 intro boxes) freezes the game (hero, monsters, bullets, boss, timers) and ignores player input except pause. Timed boxes close on a BTNC / Space / Enter press or after 2.5 s of frozen time; blocking boxes wait for the press. After a box closes the attack input stays ignored until the button was released once (no accidental shot / charge); clap pulses during a box are dropped; boxes show in arrival order (FIFO of 8); a small blinking `BTNC` hint shows how to close a box and the PAUSED text says how to go on. Files: `rtl/dialog.v` (FIFO, timed boxes also `block`, frozen-time timer), `rtl/top.v` (`atk_hold` / clap gating, release latch), `docs/STORY.md` (no change in wording), `sim/tb_dialog.v` + `tb_top` checks. Risk low-medium, effort ~half a day.

### W32 Hint strip: objective + tutorial prompts that never freeze the game  (requested 20/11) - DONE 20/11 on dev (approved; objective texts H-01..H-10 + tutorial H-11..H-16 in `docs/STORY.md`, hint strip top centre with a black band, rendered by `renderer.v` text code 24; objective logic in `top.v` from room / doors / alive / boss / key state; not tested on the board; the enemy count `n LEFT` was left out (no live digit slot))
A 2-line strip in the top centre (between hearts and boss bar, about 17 characters at 2x) shows what to do: the room objective (defeat all enemies n LEFT / doors open / puzzle goal / defeat the boss / take the door / go back to the start) and the W28 tutorial prompts that wait for an action. It never freezes the game and never covers playfield tiles. Details and texts: `docs/GAMEPLAY_REVIEW.md` section 3. Files: `rtl/hud.v` (strip text from a small ROM), `rtl/top.v` (objective select from `state / room / doors_open / alive / floor`, tutorial detectors), `scripts/build_story.py` (new `hint` table in `docs/STORY.md`), tests. Risk low-medium, effort ~1 day.

### W33 Intro after GAME OVER: short version and skip  (requested 20/11) - DONE 20/11 on dev (approved; `seen_intro` flag: the full intro only on the first game after power-on / reset, later games get the one box F1-00 `FIGHT. SOLVE. WIN. / ONCE MORE!`; holding the attack button 1.5 s fast-forwards through boxes, one every 8 frames)
First game of a power-on: the full intro (F1-01 .. F1-12). Later games: one box `FIGHT. SOLVE. WIN.`; holding BTNC for 1.5 s on any intro box skips the rest. Files: `rtl/dialog.v` / `rtl/top.v` (a `seen_intro` flag that survives `restart` but not `rst`). Risk low, effort ~1-2 h.

### W34 Input edge cases: stuck keys, opposite directions, pause sources  (requested 20/11) - DONE 20/11 on dev (approved; `ps2_kbd` clears stuck keys after 2 s of silence, opposite directions cancel, pause = SW15 xor key toggle)
Clear all keys when the PS/2 clock has been idle for 2 s while a key is flagged down (unplugged keyboard); opposite directions cancel (check `player.v` first); the pause is `SW15 xor key toggle` and the PAUSED text says `P OR SW15 TO GO ON`. Files: `rtl/ps2_kbd.v`, `rtl/top.v`, `rtl/player.v` if needed, `tb_ps2`. Risk low, effort ~1-2 h.

### W35 Form 1 (Human) melee attack animation is not shown  (requested 20/11) - DONE 20/11 on dev (owner approved: `attack_anim` = true, `build_player_mem.py` regenerated `player_attack.mem` / `sprite_cfg.vh` (`ATK_F1_EN = 1`); `test_sprite_pipeline` 34 tests green; the Block RAM count must be checked in the next Vivado build (about +5 to +6 RAMB36, last build 103.5 of 135 tiles)
Owner report: the form 1 hero shows no attack animation when it swings. The owner also sent `Human-20261120T124353Z-1-001.zip` (Idle, Walk, Attack, ChargedAttack, Dmg, Jump, SoulDie, SpinDie): I compared it file by file with `my_asset/Character/Human/` and it is **identical to what the repo already has**, so no new art is needed.
Cause (found in the code): the pictures and the code exist and were tested (`tb_player_frame`), but the switch is OFF: `sprites/sprites.json` -> `animations.attack_anim` = false, so the generated `rtl/sprite_cfg.vh` has `ATK_F1_EN = 0` (Orc and Angel are ON since W14 `ATK_F2_EN = ATK_F3_EN = 1`). With the switch off the melee swing shows only the white slash arc and the normal walk / idle picture of the hero. It was left off in the Block RAM budget of the first build.
* **Change**: set `attack_anim` to true, run `python scripts/build_player_mem.py` (regenerates the attack ROM with the Human pictures and `rtl/sprite_cfg.vh`), re-synthesise. The Human attack is 4 directions x 4 pictures = 16 pictures of 32x32 x 12 bit (about +5 to +6 RAMB36 on top of today's ROM). Last board build: 103.5 of 135 Block RAM tiles used (76.7 %), so there is room; the new bitstream must be checked again (target below 125 tiles with W25 / hint strip text growth included).
* **Behaviour**: when the hero swings (`melee_on`) the 4 attack pictures play in order for the 8 frames of the swing (about 2 frames each), facing the swing direction; the white slash arc stays on top; Orc / Angel unchanged; the hurt red flash still works.
* **Tests**: `tests/test_player_pipeline.py` (ROM size with the flag on), `tb_player_frame` (the attack picture is selected during `melee_on` for form 1; walk / idle after the swing), `tb_top` smoke; board check: swing next to a skeleton and look at the arm.
* **Optional (owner decides)**: the other Human sheets that are unused today (`Dmg.png` hurt, `SoulDie.png` death, `Idle.png` 16-frame idle loop) cost +6 / +6 / +22 RAMB36: not part of this item.
* Risk low (flag + regenerate), effort ~1 h plus a synthesis run; the only real risk is Block RAM, so the utilisation report decides.

### W36 Clap meter restyle + clap level setting on the title screen  (requested 20/11) - DONE 20/11 on dev (approved; black bar with grey frame, green level (white 0.3 s after a clap), red vertical trigger line full height; title page 1 = SETTINGS with the live meter + numbers, BTNU / BTND (up / down arrow, W / S) change the level in 5 steps VERY LOW 192 .. VERY HIGH 1024, default MID 448, kept until reset, SW5-SW8 still override; the boss fight shows only the bar + red line; page order TITLE, SETTINGS, CONTROLS 1-5, CREDITS 1-3; `tb_hud`, `test_story` green; not tested on the board)
Owner request: the clap meter is a **black bar**, the **green** fill is the current sound level, a **red vertical bar** marks the trigger level, and the player can set the trigger level **high or low in a setting menu on the title screen**.
Today (W27 / W30): dark red-brown box, green fill (turns red above the threshold), a WHITE threshold line, yellow flash on a clap, numbers `T nnnn` / `L nnnn` under it, threshold from the switches SW5-SW8 (0 = default 448).
* **Meter look** (`rtl/hud.v`): black bar 128 x 8 px (a thin grey frame so it shows on dark floors); green fill = live level (quick rise, slow fall, as now); **red vertical line, 2 px wide, the full height of the bar, at the trigger level**; the fill stays green even above the line (the line is what shows the trigger); on a registered clap the fill turns white for 0.3 s (no yellow background any more). Position stays under the boss bar, only while boss 1 is alive.
* **Setting menu**: a new title page **SETTINGS** between the title and CONTROLS (page order: TITLE -> SETTINGS -> CONTROLS 1-5 -> CREDITS 1-3, same BTNR / BTNL paging as W29). It shows `CLAP LEVEL` and the setting by name, and **the live meter with the red line** under it so the player can clap and see at once whether it triggers. **BTNU / up arrow / W = higher trigger** (needs a louder clap), **BTND / down arrow / S = lower trigger**. Five steps: `VERY LOW` 192, `LOW` 320, `MID` 448 (default), `HIGH` 704, `VERY HIGH` 1024 (same units as the meter, 0..2000). The setting survives a new game and GAME OVER, and is reset only by the reset button / power-on. SW5-SW8 stay as an override for tuning (0 = the menu value).
* **Text**: the settings page is 5 static screens (`settings_vlow .. settings_vhigh`) selected by the step, each `CLAP LEVEL` / `LOW (EASY)` ... (`VERY LOW - EASY` is 16 chars; `VERY HIGH - HARD` 16); the numbers `T nnnn L nnnn` are shown only on this page, not in the boss fight (the fight shows just the bar and the red line, less clutter).
* **Files**: `rtl/hud.v` (colours, red line, meter also on the settings page), `rtl/top.v` (`mic_step` register, threshold table, page selection, `mic_on` also for the settings page), `docs/STORY.md` + `scripts/story.py` / `make_font.py` (5 settings screens + code 25..29), `rtl/renderer.v` (nothing new: codes come from `text_select.vh`), tests: `tb_hud` (new colours; meter off = unchanged), `tests/test_story.py`, `tb_top` smoke (BTNR from the title reaches the settings page, BTNU changes the text).
* **Open decisions** (defaults used when approved): five steps as above, higher = louder clap needed, the setting is kept until reset, switches stay as an override.
* Risk low, effort ~half a day.

### W37 Ball in a Maze: both tilt axes were inverted  (reported 20/11) - DONE 20/11 on dev (owner approved the whole backlog: "just do it")
Owner report from the board: the maze axes are inverted (tilting the board rolls the ball the wrong way). Fix: `rtl/params.vh` `MAZE_SIGN_X` and `MAZE_SIGN_Y` changed from 1 to 0 (both axes flipped; `maze.v` already has the sign parameters, the module defaults and `tb_maze` are unchanged). If only ONE axis is wrong on the next board test, set the other sign back to 1 (`params.vh`, rebuild). The accelerometer offset / gain / dead zone are still untested on the board. The buttons (SW10) are not affected.

### W38 Story / hint text never covers a door  (reported 20/11) - DONE 20/11 on dev
Owner report: the text at the top and at the bottom sometimes hides the way through a door. Cause: the hint strip (W32) was drawn in the top centre = exactly over the top doors (cols 9-10), and the story band at the bottom covers the approach of the bottom doors. Fix: (1) the hint strip is now small, at the top LEFT under the hearts (x 8..284, y 42..76, never over a door: top doors are at cols 9-10, side doors at rows 7-8) and drawn 50 % dithered so the room is still visible through it; (2) the story box is drawn at the BOTTOM, except in rooms that have a door in the bottom wall (the C2 rooms: 5, 8, 11) where it is drawn at the TOP (rows 1-2, no door there); story boxes still freeze the game (W31), so nothing is missed behind them. Files: `rtl/renderer.v` (`dlg_top`), `rtl/top.v`.

### W39 Turret enemy: no close-range damage; traps really hurt  (requested 20/11) - DONE 20/11 on dev
(a) A turret (monster type B) never hurts by touch any more, only by its bullets (`objects.v` S_CPM: contact damage only for chasers). (b) Owner report "traps do not hurt": the spike check used only the tile under the CENTRE of the hero, so a hero that visibly stood on the spikes was not hurt when its centre was on the next tile, and the Angel (form 3) flew over every trap. Now the damage check uses the centre tile plus the 4 corners of the 16 x 16 hurt box (5 tiles) and EVERY form is hurt (floor 2 timed spikes 2 HP, floor 3 static spikes 1 HP). `tb_objects` updated (form 3 is hurt too).

### W40 Skeleton turns toward its walking direction  (requested 20/11) - DONE 20/11 on dev
The chaser (monster A) picture is mirrored when it walks to the left (`mon_face` from `objects.v`, `oflip` in `objline.v`; `MON_FACE_LEFT_IS_FLIP` = 1 because the skeleton art faces right; set it to 0 if a different art faces left). Vertical moves keep the last horizontal facing.

### W41 Sokoban: the player is told how to reset and when the room is stuck  (requested 20/11) - DONE 20/11 on dev
The Sokoban hint now always reads `BOXES ONTO PLATES / STUCK: R OR SW13`. `puzzles.v` detects a dead corner (a box that is not on a plate with a wall on one horizontal and one vertical side, 8 neighbour reads) and `top.v` also counts 90 s in the unsolved room: then the hint changes to `BOX STUCK! / PRESS R OR SW13`. The reset itself (SW13 / R) already existed. Not covered: dead positions along a wall without a corner (the 90 s timer catches those).

### W42 Boss 2 rework: boss in the middle in a fence box, summons minions, hit only when they are all dead  (requested 20/11) - DONE 20/11 on dev (reverses W17 on purpose)
Owner: boss 2 stands in the middle of the floor with a box around it, summons minions at the player, and can only be hit when the minions are dead, with sensible cool-downs. Room 3 is redrawn: a 6 x 5 fence box (bullets pass, feet and minions do not) around the stationary priest in the middle; the minions appear on the three summon tiles OUTSIDE the box (the old big ring trapped them) and chase the hero across the open room; cover pillars for the hero. Rules (`boss.v`): immune (white blink, `shield`) until every minion of the wave is dead; then a vulnerable window of `BOSS2_VULN_FRAMES` = 240 (4 s); then a breather `BOSS2_REST` = 75 (1.25 s, immune again); then the next wave of 3; first wave 1.5 s after the fight starts (`BOSS2_FIRST` = 90). Texts F2-10..12 and hint H-07 updated. `tb_boss` updated to the "hit only when all minions are dead" checks with the new timings.

### W44 Boss 3 health raised  (requested 20/11) - DONE 20/11 on dev
Owner: the third boss has too little health (3 charged hits), it is not challenging. `BOSS3_HP` 3 -> 9 (`params.vh`): 9 charged hits, or normal hits during its 2 s rest after the storm; the HP bar scales automatically. Together with the 4 s charge, the storm and the 2 s rest, the fight now lasts several charge cycles. Tune after the board test (suggested range 7-12).

### W43 More waves per combat room + harder bosses + hitbox clarity + retry panel  (requested 20/11) - DONE 20/11 on dev (owner: "implement all"; defaults used: 2 waves on floors 1 / 2, 3 waves on floor 3 (a second monster list per room: map chars `m n` = wave 2, `o p` = wave 3, `monsters.mem` now 4 blocks, `spawn_rom` takes the wave); doors stay shut between waves, next wave 1 s after the last monster dies (rooms 4, 5, 8, 10, 11; room 7 stays a single wave because `tb_objects` pins it); second boss phase (`rage` in `boss.v`: boss 1 / 2 below half HP, boss 3 below a third: faster volleys, boss 1 walks twice as fast, boss 2 shorter vulnerable window + breather, boss 3 shorter chase / rest + faster storm; the boss flashes once); hitbox overlay on SW8 or key H (green hero 16 x 16, red monsters 24 x 24, orange boss 48 x 48, yellow bullets) - SW5-SW7 now override the clap level, SW8 is the overlay; GAME OVER: BTNC = retry the CURRENT floor with full hearts (form = floor), BTNL = title, new panel text `BTNC RETRY FLOOR n`; the 4th minion of boss 2 was NOT added (needs a 4th summon tile); the white outline flash on a hit was NOT added; sprite-based hitbox fitting (`measure_hitboxes.py`) was NOT done. Simulations: `tb_objects`, `tb_boss`, `tb_game_fsm`, `tb_world` green
Four owner requests that need design decisions (details and open questions in `docs/GAMEPLAY_REVIEW.md` section 6):
1. **More than one wave of monsters per combat room**: today a combat room spawns its monsters once and the doors open when they are dead. Proposal: 2 waves (3 on floor 3): when the first wave is dead the doors stay shut, the hint strip shows `WAVE 2!`, and the second wave spawns from a second monster list of the room (up to 6 monsters each, a second block of S / T characters in `maps/` or a `monsters2.mem`); the doors open only after the last wave. A 1 s pause between waves; a wave never spawns within 96 px of the hero.
2. **Harder bosses to be more fun**: boss 1 (clap) gets a second phase below half HP: faster fan bullets (period 90 -> 60 frames) and a short telegraphed dash toward the hero (not a chase); boss 2 (W42) summons 4 minions below half HP and has a shorter vulnerable window (240 -> 180); boss 3 storm gets a second ring and a faster charge below a third of its HP (charge 240 -> 180 frames). All numbers in `params.vh`; a phase change = the boss flashes once and the HP bar changes colour.
3. **Hitbox clarity**: the owner sees objects react before the sprites visibly touch. Today the hero is hurt by a 16 x 16 box in the centre of its 32 x 32 cell, monsters by a 24 x 24 box (pixels 4..27), bullets 8 x 8, the boss 48 x 48, spikes by the 5-tile check (W39). Proposal: (a) measure the visible body of every sprite from its alpha channel (`scripts/measure_hitboxes.py` -> a table in `docs/HITBOXES.md`) and set the boxes to the drawn body, (b) an optional debug overlay on SW8 that draws the hitbox outlines of the hero (green), monsters (red), bullets (yellow) and boss (orange), (c) a short white outline flash on whatever hit you. (a) changes balance a little, so it needs a board playtest.
4. **Retry panel (GAME OVER screen)**: the owner says it is not good. Proposal: dark red background, big `GAME OVER`, the reason line (`NO HEARTS LEFT`, `TIME IS UP`, `THE BIG ATTACK`), the floor reached and the play time, and a clear menu `BTNC RETRY` / `BTNL TITLE` (retry restarts the current floor with full hearts instead of the whole game: a new `restart_floor` path in `game_fsm.v`). Open question: retry the whole game (today) or the current floor?
Effort: 1 about 1 day, 2 about 1 day, 3 about 1 day, 4 about half a day.

### W46 Auto aim is ON by default  (requested 20/11) - DONE 20/11 on dev
Auto aim (W18 levels 1-3) starts ON; SW9 up or the L key turns it OFF (`sw9 = ~(SW9 xor key toggle)` in `top.v`), the tutorial hint says `AUTO AIM IS ON / L OR SW9: OFF`, CONTROLS.md / FEATURES updated. The simulation testbenches drive `auto_lock` directly and are not affected.

### W45 Smarter enemies  (requested 20/11) - DONE 20/11 on dev for steps 1, 2 and 4 (owner: "implement all", start with steering and spreading): chasers slide along walls instead of freezing behind pillars (`m_bx / m_by / m_sdx / m_sdy` in `objects.v`), each chaser aims at the hero plus a personal offset (slot 0 straight, the others flank at +-14 / 20 px) so a pack surrounds the hero, turrets add one aimed bullet (8 directions) to their cross (5 bullets per shot); steps 3 (path distance field) and 5 (ranged / charger types) are NOT done. `tb_objects` updated (the old "stops under the pillar" test became "slides along the pillar")
Owner: the enemies should be smarter. Today (code): the chaser (type A) moves 1 px every 2nd frame along x then y toward the hero and stops when a wall is in the way (it gets stuck behind a pillar: `tb_objects` even tests "monster A stops under pillar"); all chasers take the same line so they stack on one pixel; the turret (type B) fires a fixed cross of 4 bullets every 2 s whatever the hero does.
Design (cheapest first, each step playable on its own):
1. **Wall steering (about 3 h, no new memory)**: when the move along the main axis is blocked, a chaser tries the other axis for 16 frames, then slides along the wall in the direction that has the shorter remaining distance; it no longer freezes behind a pillar.
2. **Spread out (about 3 h)**: every chaser gets a personal offset (index x 16 px) added to its target point and keeps 20 px from the other chasers (`S_MON` check against the 5 others): they surround the hero instead of stacking.
3. **Path distance field (about 1.5 days, +1 small RAM)**: a flood fill from the hero's tile over the 20 x 15 room (300 cells, 5 bit distance, one cell per clock, restarted every 15 frames) lets a chaser step to the neighbouring tile with the smaller distance, so it walks around walls and through doors like a real pathfinder (diagonal steps between pillars are blocked as for the hero). Distance memory 300 x 5 bit in distributed RAM.
4. **Turret smarter (about 4 h)**: instead of a fixed cross, an aimed shot at the hero (8 directions, as the boss fan) every 2 s, plus a cross every 3rd shot; two turrets are phase-shifted (already) so lanes never open at once; a turret stops firing for 1 s after it was hit (stagger).
5. **Behaviours (about 1 day)**: a ranged skeleton (type C, new picture row) that keeps 4 tiles from the hero and shoots slow aimed bullets; a charger (type D) that stops, blinks 20 frames and dashes in a straight line (dash 6 px / frame for 20 frames, then 1 s tired); low-health monsters (HP 1) retreat for 1 s instead of rushing; a wave speeds up by 25 % when only one monster is left.
6. **Rules that keep it fair**: a monster never moves faster than 1 px / 2 frames except the charger dash; the first 1 s after a room load all monsters stand still (as the turrets do); contact damage only for chasers (W39); at most 6 monsters (slots unchanged).
Risks: step 3 is the only large one (BRAM / LUT RAM and the FSM clock budget: `busy` must stay below 36000 clocks, now about 20000); tests `tb_objects` need new cases per step. Order of work: 1, 2, 4, 3, 5.

### FUTURE BACKLOG  (everything discussed on 20/11 that is not finished; the owner asked for ONE list)
Grouped by area, in the order I suggest; "plan" = designed in this file, waiting for approval; "idea" = needs a design first.
| # | Item | Status | Where |
|---|---|---|---|
| 1 | More than one wave per combat room (2 waves, 3 on floor 3, doors open after the last) | DONE (room 7 single wave) | W43 (1) |
| 2 | Harder bosses: second phase below half HP for each boss (faster / more bullets / dash / 4 minions / shorter vulnerable window); boss 3 tuned after a playtest | DONE except the dash and the 4th minion | W43 (2) |
| 3 | Hitbox clarity: measure the drawn body of every sprite, fit the boxes, optional hitbox overlay on SW8, hit-flash outline | overlay DONE (SW8 / H); measuring + fitting the boxes and the hit outline flash still open | W43 (3) |
| 4 | New GAME OVER / retry panel (reason, floor, time, BTNC retry, BTNL title; retry the current floor) | DONE (retry the current floor, text with the floor number; time / reason lines not shown) | W43 (4) |
| 5 | Smarter enemies (wall steering, spread out, path distance field, aimed turrets, ranged / charger types) | steering, spreading, aimed turret DONE; distance field and new types open | W45 |
| 6 | Redraw start room 0 and puzzle rooms 6 / 9 / 12 with a purpose per object (needs the tests `tb_objects` / solver adapted) | idea | W23 follow-up, `docs/MAP_DESIGN.md` |
| 7 | CREDITS names and asset credit lines (owner fills `docs/STORY.md` CRD-01..03) | owner task | W29 |
| 8 | Title decoration panel / candle / sword art | idea, optional | W6 |
| 9 | Rising sound for the player's charge ball (W25) and a sound for the story box / hint (sound plan needs approval) | idea | `docs/SOUND_PLAN.md` |
| 10 | Human `Dmg` (hurt), `SoulDie` (death) and 16-frame `Idle` animations (+6 / +6 / +22 RAMB36) | idea, only if BRAM allows | W35 / W14 |
| 11 | Human melee attack animation switch ON | DONE (check Block RAM in the build) | W35 |
| 12 | Enemy count / wave number in the goal hint for waves (`WAVE 2 OF 3`) | idea, with item 1 | W32 |
| 13 | Board tests of everything marked "not tested on the board": clap meter + settings, story / hint / tutorial, bosses 1-3, timed spikes, new rooms, charge ball, maze axes, free-angle aim | owner task | `docs/BOARD_TEST_STEPS.md` |
| 14 | Tuning after the board test: clap level default, boss HP, spike timing, turret period, auto-aim range | after item 13 | params.vh |
| 15 | Real keyboard on the board for a whole game (keys stuck? Enter / Space in boxes?) | owner task, W22 is confirmed to work | W22 |
| 16 | Merge `dev` into `main` when the owner says so (last merge: the W19-W27 batch) | owner decision | git |
| 17 | Optional: show the hint strip text in both English and Thai? (the story text set is A-Z only) | idea | STORY.md |
| 18 | Save / continue (keep the floor after power-off): needs flash or the SD card, probably out of scope | idea | - |

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
| 6 | Charged shot destroys enemy bullets when it stops? | **yes (decided 20/11: keep it)** |
| 7 | Trap kinds first | spike (static, 1 damage) only; timed spikes later = **W19 (floor 2: timed, 2 damage), waiting for approval** |
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
