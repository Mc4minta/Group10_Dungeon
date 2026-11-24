# Board test - what is in this build and exactly what to do

**Status 23/11/2026:** code is on `main` = `dev` (`3e908a3`); `sprite-zip` below is historical. Board-confirmed so far: the USB keyboard only; everything else = board: not tested. A local Vivado run (22/11, reports git-ignored, source commit unknown) gave WNS -4.045 ns (timing NOT met, 1853 failing endpoints) and Block RAM 103.5 / 135; step 6 below expects WNS >= 0, so timing must be fixed or accepted first. Set `DEBUG = 0` in `rtl/top.v` for the hand-in build (default is 1).

Branch (older text): `sprite-zip` (it contains everything merged: art, difficulty, sound, animations OFF). Tag of THIS build: `board-test-2`. Tag of the previous known-good build: `board-test-1`.
Before building, `scripts/check_all.sh --fast` should print `CHECK_ALL: PASS` (it proves the generated files are current).

## 1a. What is new since 20/11 (W19-W46) - the short list

Keyboard (confirmed), clap meter + settings page, story boxes that freeze the game + hint strip + tutorial, title pages, bosses (patterns, charge bar, storm, boss 2 box, second phases), timed spikes, waves, smarter skeletons / aimed turrets, auto aim default + marker, hitbox overlay (SW8 / H), retry current floor, maze axes flipped, redrawn rooms, Human attack animation. The numbered checks are items 6b-6f in section 3. After every Vivado build look at the **critical warnings** (multi-driven nets) and the Block RAM line (last build 103.5 / 135).

## 1. What is new in this build (compared with the bitstream you programmed before; older text)

| Area | What you will notice |
|---|---|
| Art | Human and Orc 2x bigger, gold form 4, new tiles / decoration, skeleton + vampire enemies and bosses, torch bulbs, new lever, keys and shield items |
| Difficulty (easier) | start HP 4 (forms 1-2), invulnerable 90 frames after a hit (was 60), the chasing monster moves at **half speed** |
| Controls | tap BTNC to attack and the facing stays locked for 0.4 s (step back while swinging); **SW12 up** = facing locked all the time (flip down to turn; was SW14) · **SW15 up = PAUSE**, **SW14 = sprint** |
| Feel | the screen shakes briefly when you are hit |
| Sound | the music on floors 1-3 is the chiptune version of **Connect** (loops); escape / win / game over music unchanged; two new sounds: room change blip, boss-appears rumble |
| Not visible | the Human idle / attack / hurt / death animations exist but are switched OFF (no extra block RAM) |

## 2. Steps in Vivado (about 10 minutes plus the build)

1. Update the folder: it is already on branch `sprite-zip` (I merged everything into it). In a terminal in the project folder: `git status` should say `On branch sprite-zip`.
2. In Vivado: **File -> Close Project** (stop any running synthesis first).
3. In the Tcl Console run:
   `source <path-to-your-clone>/scripts/create_project.tcl`
   This rebuilds the project from the folders, so the new files (`face_lock.v`, `player_frame.v`, new `.mem` files and headers) are all included. It opens the new project.
4. Check **Sources**: about 19 `.v` files (including `face_lock`, `player_frame`, `hud`, `audio`, `objects`, `boss`, `puzzles`) and the `.mem` files.
5. Click **Generate Bitstream** (it runs synthesis and implementation first).
6. When it says done, open **Reports -> Report Utilization** and write down **Block RAM Tile** and, in **Report Timing Summary**, **WNS** (should be >= 0). Send me both numbers.
7. **Open Hardware Manager -> Open Target -> Auto Connect -> Program Device** and pick `vivado/Group10_Dungeon.runs/impl_1/top.bit`.
   If it says "HW Target shutdown": unplug and replug the USB cable, then Auto Connect again.

Quickest fix if synthesis says `module 'xxx' not found` (for example `face_lock`) and you do not want to re-create the project: in the Tcl Console of the OPEN project run
`source <path-to-your-clone>/scripts/vivado_update_project.tcl` (it adds every missing `rtl/*.v` and `mem/*.mem` and prints OK / MISSING for the key modules), then Generate Bitstream.

**Programming errors** ("No devices detected on target", "may be locked by another hw_server", "HW Target shutdown"): this is the cable / board, not the design. Check: the board power switch is ON, the micro-USB cable is in the PROG/UART port,
no other program uses the board (a second Vivado window, Digilent Adept). Then in the Tcl Console: `disconnect_hw_server`, `close_hw_manager`, `open_hw_manager`, `connect_hw_server -allow_non_jtag`, `open_hw_target`.
If it still fails: close Vivado, run `taskkill /F /IM hw_server.exe /IM cs_server.exe` in a Command Prompt, unplug and replug the USB cable, start Vivado, Auto Connect again.

If the Tcl `source` fails because the old project is still open, close it first. If it still fails, paste me the error text.

## 3. What to check on the board

1. Title screen is silent. Press BTNC: floor 1 starts, the Connect melody plays and loops.
2. Walk around: the hero is bigger. Tap BTNC next to a skeleton while pressing the opposite direction: you hit it and step back without turning.
3. The skeleton walks slower than before. Get hit: short screen shake, HP LEDs 8-11 drop one, you cannot be hit again for about 1.5 s.
4. SW3 up (three times) evolves through forms 2, 3, 4 (gold). SW2 clears the room's monsters, SW1 skips a floor, SW0 opens the boss door, SW14 sprints. SW12 up = locked facing. SW15 up = pause (game frozen, PAUSED text, silence; flip down to continue).
5. Walk through a door: short blip. Reach a boss: low rumble.
6. Lightbulb room: torches and the new switch. Sokoban: crate and spikes gate. Simon (floor 3): red / blue / gold / key plates.
6b. (new 20/11, W22) USB keyboard: plug a keyboard into the USB port next to the Ethernet jack (before or after power-on, the board needs about 1 s to detect it). Arrows or WASD walk, Space attacks (also starts the game), Shift sprints, P pauses and resumes, L toggles auto-lock, R resets the Sokoban boxes. Buttons and keyboard work at the same time. Please note the keyboard model; if keys do nothing, try another keyboard (the board needs a plain USB HID boot keyboard) and tell me.
6c. (new 20/11, W4 / W27) Clap boss: enter the floor 1 boss room. A bar under the boss health bar shows the microphone level (green), a white line is the clap threshold. Clap next to the board: the bar should jump past the white line (turns red), the box flashes yellow and the boss is stunned for 3 s. Under the bar two numbers are printed: T = the threshold, L = the live level (silence should stay under about 130; a clap should read several hundred to 2000; the white line is T). Tell me your silence level, your clap level and the SW5-SW8 value that works. If the bar never moves, the microphone path is dead (tell me); if it moves but never passes the line, raise SW5-SW8 down (smaller number = lower threshold; 0 = default); if the bar moves in silence, raise the threshold. SW11 and the C key still stun the boss.
6f. (new 20/11, W43 / W45 / W35 / light puzzle) Combat rooms: after the last monster dies the doors stay shut and a second (floor 3: second and third) wave appears 1 s later. Skeletons slide around pillars and surround you; turrets fire 4 bullets plus one aimed at you. Bosses speed up and flash once at half health (boss 3 at a third). SW8 up (or H) shows the hit boxes: tell me where the boxes and the pictures disagree. Die on purpose: BTNC retries the same floor, BTNL goes to the title. Form 1 now shows an attack animation when it swings (check the Block RAM line of the build). Floor 1 puzzle: levers and bulbs are at the bottom of the room.
6e. (new 20/11, W36 / W37 / W18 level 2) Title: BTNR once = SETTINGS: clap near the board, the green bar must reach the red line; BTNU / BTND move the red line (very low .. very high); the setting stays until RESET. Maze: tilt the board right, the ball must roll right (both axes were inverted before; if only one axis is still wrong tell me which). SW9 up: shots now fly exactly at the marked enemy (not only in 8 directions).
6d. (new 20/11, W28-W34 story / help) Title: BTNR (or right arrow) pages through CONTROLS 1-5 and CREDITS 1-3, BTNL goes back, BTNC starts. After the prologue the intro boxes freeze the game: a blinking arrow in the box means press BTNC / Space / Enter; hold it 1.5 s to fast-forward. Then the hint strip (top centre) teaches move, attack, sprint, pause and auto aim and shows the goal of every room. Play a second game after GAME OVER: only one short intro box. During any box nothing moves and the attack button does not fire when the box closes. SW9 up: a yellow / red bracket marks the enemy you aim at. Please tell me anything that felt confusing.
7. (new 20/11) Prologue: after BTNC on the title, 4 black text pages (BTNC = next page, or 6 s each) then floor 1. Floor 1 start room: candlesticks (solid) and a chest-like block `Z`: shoot or swing at it, it breaks; leave and come back, it stays broken; a new game restores it. Floor 2-3 combat rooms: spike plates `X` hurt once (form 3 flies over). Boss 1: clap (or SW11) stuns it. Boss 2: summons, blinks while shielded, only hurt when all minions are dead. Boss 3: only the charged shot hurts; when it blinks and stands still, interrupt it with a charged shot or you die. Auto-lock (new): SW9 up = shots / swings aim at the nearest enemy (8 directions), SW9 down = as before; boss 2 can be hit all the time. Dialogue + story (new): the title now says THE CHOSEN ONE; after the prologue the safe-room talk freezes the game (BTNC = next line); hint boxes appear at the bottom (yellow = Voice, cyan = System). To change any sentence: edit `docs/STORY.md`, run `python scripts/build_story.py`, rebuild the project. Maze (new): kill boss 3, walk over the gold key lying on the floor, (or SW0 = door open in a DEBUG build), walk through door E at floor 3 START: banner, 60.00 countdown, the coin-ball rolls when you tilt the board. If it rolls the wrong way, flip `MAZE_SIGN_X` / `MAZE_SIGN_Y` in `rtl/params.vh`; too sluggish / too wild: `MAZE_TILT_SHIFT` (1 = twice as strong, 3 = half). SW10 up = buttons. Check the Vivado utilization: the new `ovtile` ROM adds about 2 RAMB36, the text ROM is 512 entries.

## 4. If something is wrong (all reversible)

| Problem | Fix |
|---|---|
| Music too annoying or too loud / quiet | `sprites/music.json`: set `"floor1": "default"` etc.; run `python scripts/make_music.py`; or change `BGM_AMP` (default 18) in `rtl/params.vh`; rebuild |
| Game too easy / too hard | `rtl/params.vh`: `HP1`, `HP2` (4), `INV_FRAMES` (90), `MON_A_MOVE_EVERY` (2 = half speed, 1 = old speed), `FACE_LOCK_FRAMES` (24), `HURT_SHAKE_FRAMES` (12, 0 = off); rebuild |
| Go back to the previous known-good version | `git checkout board-test-1` (do this with Vivado closed), re-create the project, rebuild; return with `git checkout sprite-zip` |
| Art problem in one place | see `docs/SPRITE_STATUS.md` and `sprites/README.md` (each sprite group has an `enabled` switch and a `*_v1.mem` backup) |

## 5. About the song (please read)

`Connect` is a commercial song. The game only contains a short square-wave version of its melody that I extracted from your preview file (`sprites/music/connect.txt`, `mem/music.mem`).
Your original files stay in `my_audio/`, which is not committed. If the repository is public (GitHub), do not push `sprites/music/connect.txt` / `mem/music.mem` with this melody, or keep the repository private;
for a class demo on your own board this is normally fine. To remove it: set the `play` entries in `sprites/music.json` to `"default"` and run `python scripts/make_music.py`.
