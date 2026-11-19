# Board test - what is in this build and exactly what to do

Branch: `sprite-zip` (it contains everything merged: art, difficulty, sound, animations OFF). Tag of THIS build: `board-test-2`. Tag of the previous known-good build: `board-test-1`.
Before building, `scripts/check_all.sh --fast` should print `CHECK_ALL: PASS` (it proves the generated files are current).

## 1. What is new in this build (compared with the bitstream you programmed before)

| Area | What you will notice |
|---|---|
| Art | Human and Orc 2x bigger, gold form 4, new tiles / decoration, skeleton + vampire enemies and bosses, torch bulbs, new lever, keys and shield items |
| Difficulty (easier) | start HP 4 (forms 1-2), invulnerable 90 frames after a hit (was 60), the chasing monster moves at **half speed** |
| Controls | tap BTNC to attack and the facing stays locked for 0.4 s (step back while swinging); **SW14 up** = facing locked all the time (flip down to turn) |
| Feel | the screen shakes briefly when you are hit |
| Sound | the music on floors 1-3 is the chiptune version of **Connect** (loops); escape / win / game over music unchanged; two new sounds: room change blip, boss-appears rumble |
| Not visible | the Human idle / attack / hurt / death animations exist but are switched OFF (no extra block RAM) |

## 2. Steps in Vivado (about 10 minutes plus the build)

1. Update the folder: it is already on branch `sprite-zip` (I merged everything into it). In a terminal in the project folder: `git status` should say `On branch sprite-zip`.
2. In Vivado: **File -> Close Project** (stop any running synthesis first).
3. In the Tcl Console run:
   `source E:/vivado/Group10_Dungeon/Group10_Dungeon/scripts/create_project.tcl`
   This rebuilds the project from the folders, so the new files (`face_lock.v`, `player_frame.v`, new `.mem` files and headers) are all included. It opens the new project.
4. Check **Sources**: about 19 `.v` files (including `face_lock`, `player_frame`, `audio`, `objects`, `boss`, `puzzles`) and the `.mem` files.
5. Click **Generate Bitstream** (it runs synthesis and implementation first).
6. When it says done, open **Reports -> Report Utilization** and write down **Block RAM Tile** and, in **Report Timing Summary**, **WNS** (should be >= 0). Send me both numbers.
7. **Open Hardware Manager -> Open Target -> Auto Connect -> Program Device** and pick `vivado/Group10_Dungeon.runs/impl_1/top.bit`.
   If it says "HW Target shutdown": unplug and replug the USB cable, then Auto Connect again.

If the Tcl `source` fails because the old project is still open, close it first. If it still fails, paste me the error text.

## 3. What to check on the board

1. Title screen is silent. Press BTNC: floor 1 starts, the Connect melody plays and loops.
2. Walk around: the hero is bigger. Tap BTNC next to a skeleton while pressing the opposite direction: you hit it and step back without turning.
3. The skeleton walks slower than before. Get hit: short screen shake, HP LEDs 8-11 drop one, you cannot be hit again for about 1.5 s.
4. SW3 up (three times) evolves through forms 2, 3, 4 (gold). SW2 clears the room's monsters, SW1 skips a floor, SW0 opens the boss door, SW15 sprints. SW14 up = locked facing.
5. Walk through a door: short blip. Reach a boss: low rumble.
6. Lightbulb room: torches and the new switch. Sokoban: crate and spikes gate. Simon (floor 3): red / blue / gold / key plates.

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
