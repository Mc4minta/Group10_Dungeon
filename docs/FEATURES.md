# Feature catalogue - everything the game does today, by category

State: branch `sprite-zip` + the plates work on `feature/plates` (marked **[plates]**). "OFF" = built but switched off. Planned items are NOT here: see `docs/DESIGN_PLAN.md`.
Where to read more: `docs/README.md` (index), `docs/SPRITE_STATUS.md` (art), `docs/SOUND_PLAN.md` (sound), `docs/CHANGE_REVIEW.md` (what changed vs the first version and how it was verified).

---

## 1. Game flow and rules
| Feature | Details | Code |
|---|---|---|
| States | TITLE -> PROLOGUE (4 black pages of story text, BTNC = next page, 6 s per page) -> PLAY -> EVOLVE (60 frames) -> FLOOR CLEAR (120 frames) -> (boss 3 drops the key) -> door E at floor 3 START -> **MAZE** (state ESCAPE, 60 s) -> WIN; GAME OVER from any HP 0 or maze timeout | `rtl/game_fsm.v` |
| 3 floors, 13 rooms | start, 2 combat rooms, 1 puzzle room, 1 boss room per floor (+ extra start/boss variants) | `maps/*.txt`, `rtl/world.v` |
| 4 forms (evolution) | form 1 Human (melee), 2 Orc (shot), 3 Angel (3-way spread; a bullet that hits a monster splits into 4 short child bullets), 4 gold (fast shot + charged big ball); each puzzle item evolves the hero and opens that floor's boss door | `game_fsm.v`, `objects.v` |
| Health | HP 4 on every form, invulnerable 90 frames after a hit, knockback | `params.vh` (`HP1..4`, `INV_FRAMES`) |
| Timer | mm.ss on the 7-segment display, runs from START | `game_fsm.v`, `seg7.v` |
| Debug shortcuts | SW0-SW4 (open boss door, skip floor, clear room, evolve, hurt) only when `DEBUG = 1`; off in the hand-in build | `top.v` |

## 2. Player
| Feature | Details | Code |
|---|---|---|
| Movement | **8-direction walk** (two buttons = diagonal; x and y are moved separately, so you slide along walls), the sprite faces 4 directions; tile collision with a 24x24 box, sprint, knockback | `rtl/player.v` |
| Face lock | BTNC tap keeps the facing for 0.4 s (step back while swinging); SW12 = facing locked all the time | `rtl/face_lock.v`, `top.v` |
| Hurt box | only a centred 16x16 area can be hit (the drawn body is small) | `params.vh` `HURT_BOX` |
| Hit feedback | screen shake 12 frames, sprite blink, red RGB LED | `top.v`, `objects.v` |
| Sprites | 48 frames (4 forms x 4 directions x 3 poses), your art for forms 1-3 (Human, Orc, Angel all 2x), form 4 = gold Human | `mem/player.mem` |

## 3. Combat
| Feature | Details | Code |
|---|---|---|
| Melee (form 1) | 24x16 swing in front, hits monsters, levers | `objects.v` |
| Shots (forms 2-4) | form 2 normal, form 3 spread + split on hit (AOE), form 4 fast + hold to charge a big ball (stops on the first monster / boss it hits, destroys enemy bullets in its path) | `objects.v` |
| Collision | AABB between player / monsters / bullets / boss, per-pair checks | `objects.v` |
| Limits | 6 monsters, 6 player bullets, 16 enemy bullets at a time | `objects.v` |

## 4. Enemies
| Feature | Details | Code |
|---|---|---|
| Chaser (type A) | walks toward the player at half speed (`MON_A_MOVE_EVERY`) | `objects.v` |
| Turret (type B) | stands still, shoots 4 ways | `objects.v` |
| Spawn lists | per room from the map letters `S` / `T` | `scripts/build_maps.py`, `mem/monsters.mem` |
| Art | your enemy sheets (2 types, 2 frames each) | `mem/monster.mem` |

## 5. Bosses (3, reworked 20/11: DESIGN_PLAN W10-W12)
| Boss | Behaviour | Code |
|---|---|---|
| 1 (floor 1) | HP 10, **slow chase (W20: 1 px every 2nd frame)**, shoots a bullet pattern every 1.5 s (aimed fan of 3, fan, 8-way ring, fan; blinks 20 frames before each volley), always takes damage; **a clap (or SW11) stuns it 3 s**, then 4 s cooldown | `rtl/boss.v`, `rtl/pdm_mic.v` |
| 2 (floor 2) | HP 16, stationary, **shoots alternating 4-way cross / X patterns every 1.5 s (W20, spiral look)**; summons waves of 3 minions; **can be hit at all times, also while its minions live (W17)**; when a wave is dead it waits 2 s and summons the next | `boss.v`, `objects.v` (summon) |
| 3 (floor 3) | HP 3, **armour: only the charged shot (form 4) hurts, 1 per hit**; **chases slowly (W20: 1 px every 2nd frame)** and shoots cross / X / ring / fan volleys every 1.5 s for 3 s, then **charges for 4 s (W21: a bar under the boss bar fills, the blink speeds up in 4 steps)**; at 100 % it releases a **bullet storm (W24, 2 s: cross / X / ring volleys in all 8 directions, every storm bullet takes 2 HP, no instant death)**, then rests 2 s (any hit hurts it) and chases again; a charged hit during the charge interrupts and restarts the cycle; death starts ESCAPE (key + maze come with W7) | `boss.v`, `game_fsm.v` (`kill`) |
| Charge ball (W25) | form 4: while BTNC is held a ball appears in front of the hero (18 px away, follows the drawn facing) and grows in 4 steps at 1/4, 1/2, 3/4 and full charge (radius 2 / 4 / 6 / 7-8, colour orange -> yellow -> pale yellow -> white, bright core + darker rim, pulses at full); gone on release, when the big 16x16 shot leaves | `rtl/objects.v` (`chg_lvl`), `rtl/renderer.v` (procedural disc, no ROM), `sprite_cfg.vh` (`ORB_DIST`), `tb_orb`, `tb_objects` |
| Boss 3 charge (W21) | 4 s charge: HUD bar under the boss bar (yellow / orange / red), the boss blinks faster each quarter **and in a colour that climbs pale blue -> yellow -> orange -> red** (`boss_fcol` in `objline.v`), and a **rising beep at each step** (SFX 13, `SFX_CHG_*`) | `boss.v` (`tele_lvl`, `chg_w`), `hud.v`, `objline.v`, `audio.v`, `top.v` |
| Boss bullet patterns (W20) | enemy bullets fly in 8 directions (3 bit, diagonal = 2 px per axis, straight = 3 px/frame); `fire_pat` 0 cross, 1 ring of 8, 2 X, 3 aimed fan (aim = 8 directions toward the hero, +-45 degrees); `warn` makes the boss blink for `BOSS_WARN` frames before a volley; numbers in `params.vh` (`BOSS*_SPEED / EVERY / FIRE`, `EB_DIAG`) | `rtl/boss.v`, `rtl/objects.v` (`S_BFIRE`), `rtl/top.v`, `tb_boss` |
| Shared | 64x64 sprite, hit flash, boss room locks while alive, boss HP bar on screen (+ LED0-7) | `boss.v`, `hud.v` |

## 6. Puzzles and items
| Puzzle | Details | Code |
|---|---|---|
| Light Bulb (floor 1) | hit 4 levers (melee or bullet) to light 4 torches, random start pattern | `rtl/puzzles.v` |
| Sokoban (floor 2) | push 2 boxes onto 2 plates, gate opens, SW13 resets the boxes; **[plates]** plate = raised / pressed picture | `puzzles.v`, `tileset.json` |
| Simon says (floor 3) | watch 3 / 4 / 5 plates with sound, repeat them; wrong = HP -1; **[plates]** 4 big tinted plates (2x2 tiles each) | `puzzles.v`, `renderer.v` |
| Items | key / key / shield: walk over it -> evolve + opens the boss door | `puzzles.v` |
| Layout | solved state kept when you leave a room | `puzzles.v`, `rtl/puzzle_layout.vh` (generated) |

## 7. Map and world
| Feature | Details | Code |
|---|---|---|
| Room graph | doors between rooms, spawn points, per-floor start/boss rooms | `rtl/world.v` |
| Door types | D combat door (closes while monsters live) and L boss door (needs item) are **spike traps** (spikes up = closed, flat = open); E exit (the maze door: a solid wall until the player carries the boss-3 key, then it vanishes)  | `player.v`, `renderer.v` |
| Tiles | 16 ids: wall, floor, 3 doors + 3 open versions, hole, fence, plate (+ with box), Simon plates 12-15 (decoration on floors 1-2) | `scripts/build_maps.py`, `mem/tilemap.mem` |
| **Key + Ball in a Maze (W7)** | boss 3 dies -> `has_key` (shown by the opened door E); the key lies on the floor where boss 3 died (gold key sprite) and is picked up by **walking over it**; walking into door E starts the maze: a 20x15 maze (`maps/maze/maze.txt` -> `mem/maze.mem`) drawn with the floor-3 wall tiles, a ball (AXIALE orb art, 4 rotation pictures that follow the position: puzzle frames 10-13) controlled by the **board tilt** (ADXL362 over SPI, offset calibrated on the first 32 samples, dead zone) or the buttons; 60 s countdown on the 7-seg, goal = WIN, timeout = GAME OVER. Tilt directions / gain must be checked on the board (`MAZE_SIGN_X/Y`, `MAZE_TILT_SHIFT` in `params.vh`) | `rtl/maze.v`, `rtl/adxl362.v`, `game_fsm.v`, `top.v`, `renderer.v` (screen 5) |
| Holes `H` | only form 3+ crosses | `player.v` |
| Map design (W23) | combat rooms 4, 5, 7, 8, 10, 11, start room 1 and boss rooms 2 / 3 redrawn with a purpose for every object (sealed turret nest behind a crate, fire gallery with cover pillars, timed-spike gate / gauntlet, pit bridges); details `docs/MAP_DESIGN.md`; start room 0 and puzzle rooms unchanged | `maps/*.txt`, `tests/test_maps.py` |
| Sokoban plate with a box (W26) | tile 11 = pressed plate with the box drawn on it (`scripts/make_plate_box.py` -> `my_asset/props/plate_box.png`) | `sprites/tileset.json` |
| Decoration | bones, skull, cracks, rubble in 7 rooms (look only; ids behave as floor) | `maps/*.txt` |
| **Timed spikes (W19)** | floor 2 combat rooms only (`W` / `V` in `maps/07*`, `08*`): spikes cycle 1.5 s flat (safe) -> 0.5 s half up (warning, safe) -> 1 s fully up (**2 HP** + knockback, form 3 flies over); `V` is half a loop behind `W`; safe for 1 s after entering a room; frozen while paused. Floor 3 keeps the static `X` trap (1 HP). Numbers in `params.vh` `TRAP_*` | `rtl/objects.v` (`trap_a` / `trap_b`, second hit pulse = 2 HP), `renderer.v`, `scripts/build_overlay_mem.py` (pictures 10-12), `scripts/build_maps.py`, `tb_objects` section 10b |
| **Overlay layer (W5)** | a second 4-bit map (`mem/overlay.mem`, drawn over the floor from `mem/ovtile.mem`): `Z` **breakable block** (acts as a wall, any bullet or melee swing breaks it in 1 hit, stays broken when you leave and come back, all back on a new game; up to 8 per room), `X` **spike trap** (stand on it = HP -1 + knockback, normal invulnerability so no chain hits; form 3 flies over), `Y` **solid decoration** (candlestick: wall for player, monsters, bullets). Used in start room 1 and the 6 combat rooms (`OVL_ROOMS`) | `rtl/roms.v` (`tilemap_rom` folds the overlay into the collision view), `rtl/overlay.v` (break state), `objects.v`, `renderer.v`, `scripts/build_maps.py`, `scripts/build_overlay_mem.py`, `sprites/overlay.json` |
| Floor tint | 3 floors recoloured (rgb / gbr / brg) | `sprites/tileset.json` |

## 8. Art pipelines (config -> generated ROM, Rule 1 fallback to the old art with a warning)
| Pipeline | Source -> output | Config | Test |
|---|---|---|---|
| Player | `my_asset/Character/*` -> `mem/player.mem` (+ animation ROMs, `rtl/sprite_cfg.vh`) | `sprites/sprites.json` | `tests/test_sprite_pipeline.py` |
| Tileset | `my_asset/tileset/Dungeon_Tileset.png`, **[plates]** `props/plate.png` -> `mem/tileset.mem` | `sprites/tileset.json` | `test_tileset_pipeline.py` |
| Enemies | `my_asset/enemies/*` -> `mem/monster.mem` | `sprites/monsters.json` | `test_monster_pipeline.py` |
| Bosses | -> `mem/boss.mem` | `sprites/bosses.json` | `test_boss_pipeline.py` |
| Puzzle objects | `my_asset/props/*`, `new_switch.png`, `torch.mem` -> `mem/puzzle.mem` | `sprites/puzzle.json` | `test_puzzle_pipeline.py` |
| Health display | `my_asset/ui/Hearts/*` -> `mem/hud.mem` | `sprites/hud.json` | `test_hud_pipeline.py` |
| Maps | `maps/*.txt` -> `mem/tilemap.mem`, `monsters.mem`, `objects.txt`, `puzzle_layout.vh` | `scripts/build_maps.py` | `test_maps.py` |
| Music | `sprites/music/*.txt` -> `mem/music.mem`, `rtl/bgm_cfg.vh` | `sprites/music.json` | `test_music_pipeline.py` |
| One command | `scripts/update_sprites.sh` rebuilds everything + previews; `scripts/check_all.sh` checks everything | | |

## 9. Screen, HUD and text
| Feature | Details | Code |
|---|---|---|
| VGA 640x480 | 4-stage pixel pipeline, 20x15 tiles of 32 px, layers: tile < objects < player < HUD < text | `rtl/renderer.v`, `objline.v`, `vga_sync.v` |
| Player hearts | one heart per max HP (full = HP left), top left, 2x | `rtl/hud.v`, `mem/hud.mem` |
| Boss health bar | top right, boss room only, fill = hp / max hp | `hud.v` |
| **Story text (W16)** | **`docs/STORY.md` is the source of truth** for every sentence (game name THE CHOSEN ONE, prologue, NEW FORM banners, FLOOR CLEAR, maze banner, WIN / timeout / GAME OVER, and 49 dialogue boxes); `python scripts/build_story.py` regenerates the ROMs. Dialogue boxes: black band at the bottom, colour = speaker (Player white, Voice yellow, System cyan), timed 2.5 s or blocking (game frozen) until BTNC; 36 game events trigger them, each shown once per game | `scripts/story.py`, `make_font.py`, `rtl/dialog.v`, `rtl/top.v`, `renderer.v` |
| Text | 8x8 font; screens: TITLE, FLOOR CLEAR, maze banner (TILT THE BOARD TO / ROLL THE BALL OUT!), WIN, GAME OVER, PAUSED, 4 prologue pages, 3 NEW FORM banners (2 lines max, A-Z 0-9 `- : ! .`); wording in `docs/STORY.md` | `renderer.v`, `scripts/make_font.py` -> `text_layout.vh`, `text_select.vh`, `mem/text.mem` |
| Look (20/11) | wall torches (animated flame) + shields in every room, vignette (darker screen edges) + a 6-frame fade-in after each room change, darker floors with brighter walls (maroon / indigo / moss per floor), monsters at hero size, 3x bosses, priest boss 2, title scene (hero vs vampire between two torches) | `rtl/renderer.v`, `maps/*.txt`, `sprites/*.json` |
| Screens | title (navy-to-blue gradient + hero), prologue (black), game over (dark red + death), win (gold) | `renderer.v` |
| Screen shake | on hit, UI does not shake | `top.v` |

## 10. Audio
| Feature | Details | Code |
|---|---|---|
| 12 sound effects | hurt, stun, die, item, clear, wrong, ok, monster hit, 4 shoot sounds, melee, door, boss appear | `rtl/audio.v`, `params.vh` |
| Simon notes | 4 tones played with the sequence | `audio.v` |
| Music | 8-track BGM ROM, floors 1-3 play the Connect melody (melody only, no recording), track 6 loops | `audio.v`, `mem/music.mem` |
| Tools | `audio_to_music.py` (melody from mp3 / wav), `make_music.py` | `scripts/` |
| Output | 1-bit PWM to the board audio jack | `audio.v` |

## 11. Board I/O and controls
| Control | Function |
|---|---|
| BTNU / D / L / R | walk (two together = diagonal) |
| BTNC | start (TITLE) / attack (PLAY) / back to TITLE (WIN, GAME OVER) |
| **USB keyboard (W22)** | plugged into the Nexys USB-HID port (arrives as PS/2 on `PS2_CLK` F4 / `PS2_DATA` B2; `rtl/ps2_kbd.v`, `tb_ps2`), works together with the buttons (logical OR): arrows or **W A S D** = walk, **Space / J / Enter** = attack / start (= BTNC), **Shift** = sprint (= SW14), **P or Esc** = pause toggle (= SW15), **L** = auto-lock toggle (= SW9), **R** = Sokoban box reset (= SW13), **C** = clap fallback (= SW11) |
| SW9 | **auto-lock (W18)**: up = attacks aim at the nearest enemy within 240 px (8 directions, the hero turns that way for a moment); form 3's spread is centred on it, melee swings turn toward it; down = old behaviour (aim = facing) |
| SW10 | maze: use the 4 direction buttons instead of the accelerometer (also automatic when the sensor does not answer) |
| SW15 | **PAUSE** (game frozen, PAUSED text, music + sfx muted; PLAY / ESCAPE only) |
| SW14 | sprint (+1 px/frame) |
| SW11 | clap fallback: up = one stun pulse for boss 1 |
| SW12 | facing lock |
| SW13 | Sokoban box reset |
| SW0-SW4 | debug (only `DEBUG = 1`) |
| Story boxes freeze the game (W31) | every story box (50) freezes the game and the input except pause; timed boxes close on a press or after 2.5 s; boxes show in arrival order (FIFO 8); after a box the attack button must be released once; claps are dropped during a box; a blinking arrow in the box = press the attack button; holding the attack button 1.5 s fast-forwards (W33); the full intro is told once per power-on, later games get one box | `rtl/dialog.v`, `rtl/top.v`, `rtl/renderer.v` |
| Hint strip (W32 / W28) | top centre, never freezes the game: the objective of the room (defeat all enemies / doors open / puzzle goal / defeat the boss / take the door / go back to the start) and the tutorial prompts in the floor 1 start room (move, attack, sprint, pause, auto aim) with keyboard AND button names; texts `docs/STORY.md` H-01..H-16 | `rtl/top.v`, `rtl/renderer.v`, `rtl/dialog.v` (hint ROM read) |
| Title pages (W29) | BTNR / right arrow = next page, BTNL / left arrow = previous: TITLE -> CONTROLS 1-5 -> CREDITS 1-3; BTNC starts from any page; credits names are placeholders | `rtl/top.v` (`tpage`), `docs/STORY.md` |
| Input edge cases (W34) | stuck keyboard keys clear after 2 s of silence, opposite directions cancel, pause = SW15 xor key toggle, PAUSED screen says how to go on | `rtl/ps2_kbd.v`, `rtl/top.v` |
| Auto-lock level 3 (W18) | sticky target + blinking corner-bracket marker on the locked enemy (SW9 / key L) | `rtl/objects.v`, `rtl/renderer.v` |
| Clap meter numbers (W30) | `T nnnn` (threshold) and `L nnnn` (live level) under the meter bar, 3x5 pixel digits at 2x, boss 1 fight only | `rtl/hud.v`, `rtl/top.v` (`bin2bcd`) |
| Microphone (PDM) | clap = stun boss 1; **W4 fix: the detector now removes the DC per 64-sample block and takes the peak loudness (a real mic signal is AC; the old window average could never see it)**; **W27 on-screen clap meter** under the boss bar while boss 1 lives (level bar, white threshold line, yellow flash on a clap); threshold SW5-SW8 (0 = `MIC_TH` 448, else 128 x value); SW11 / key C = same pulse as a fallback; not tested on the board |
| 7-segment | floor - HP - mm.ss |
| LEDs | LED0-3 buttons / lamps / Simon round, LED4-7 monsters left (boss room: boss HP), LED8-11 HP, LED12 door locked, LED13 item, LED14 sprint (SW14), LED15 WIN; RGB16 = form colour, RGB17 red = hit |

## 12. Built but switched OFF
| Feature | How to switch on | Cost |
|---|---|---|
| Human idle / attack / hurt / death animations; Orc + Angel attack pictures (ON, W14); red hurt flash (ON, no ROM) | flags in `sprites/sprites.json` -> `animations`, rebuild, re-synthesise | ~22 / 6 / 6 / 6 RAMB36; the 3-form attack ROM about 16 RAMB36 |
| Wall variants (room border pictures) | not merged: branch `wip/wall-variants` | ~+6 RAMB36 |

## 13. Tooling and verification
| Tool | What |
|---|---|
| `scripts/check_all.sh [--fast]` | rebuild all generated files, nothing stale, 8 Python suites, iverilog suite |
| `scripts/run_sim.sh <name>` | iverilog testbenches: player, world, fsm, objects, puzzles, mic, audio, boss, hud, **[plates]** simonplate, sprites, tileset, monster, bosssprites, puzzleart, facelock, playerframe, animroms, topanim, top |
| `sim/verilator` | full-game player (last WIN run is older than the newest RTL) |
| Vivado Tcl | `scripts/create_project.tcl` (re-create the project), `vivado_update_project.tcl` (add missing files), `vivado_synth.tcl` |
| Docs | index `docs/README.md`, board steps `docs/BOARD_TEST_STEPS.md`, backlog `docs/NEXT_STEPS.md`, plan `docs/DESIGN_PLAN.md` |
| Backups | `mem/*_v1.mem`, `maps_v1/` (originals, never edited; rollback = copy back) |

## 14. Planned (not implemented)
See `docs/DESIGN_PLAN.md`: boss rework (boss 1 fast + clap stun, boss 2 summons minions and is hurt only when all minions are dead, boss 3 armour + charge), form 3 AOE, charged shot stops, key + Ball in a Maze (accelerometer), breakable blocks / traps, pause switch, new start screen, prologue + story, door spike traps, Orc / Angel animations.
