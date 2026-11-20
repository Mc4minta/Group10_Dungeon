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
| 1 (floor 1) | HP 10, very fast (2 px every frame), no shot, always takes damage; **a clap (or SW11) stuns it 3 s**, then 4 s cooldown | `rtl/boss.v`, `rtl/pdm_mic.v` |
| 2 (floor 2) | HP 16, stationary, no shot; summons waves of 3 minions; **can be hit at all times, also while its minions live (W17)**; when a wave is dead it waits 2 s and summons the next | `boss.v`, `objects.v` (summon) |
| 3 (floor 3) | HP 3, **armour: only the charged shot (form 4) hurts, 1 per hit**; chases and shoots 3 s, then charges a big attack for 2 s (blinks, stands still): if it completes the player dies (GAME OVER); a charged hit interrupts and restarts the cycle; death starts ESCAPE (key + maze come with W7) | `boss.v`, `game_fsm.v` (`kill`) |
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
| Decoration | bones, skull, cracks, rubble in 7 rooms (look only; ids behave as floor) | `maps/*.txt` |
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
| SW9 | **auto-lock (W18)**: up = attacks aim at the nearest enemy within 240 px (8 directions, the hero turns that way for a moment); form 3's spread is centred on it, melee swings turn toward it; down = old behaviour (aim = facing) |
| SW10 | maze: use the 4 direction buttons instead of the accelerometer (also automatic when the sensor does not answer) |
| SW15 | **PAUSE** (game frozen, PAUSED text, music + sfx muted; PLAY / ESCAPE only) |
| SW14 | sprint (+1 px/frame) |
| SW11 | clap fallback: up = one stun pulse for boss 1 |
| SW12 | facing lock |
| SW13 | Sokoban box reset |
| SW0-SW4 | debug (only `DEBUG = 1`) |
| Microphone (PDM) | clap = stun boss 1 (only tested in simulation); SW11 = same pulse as a fallback |
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
