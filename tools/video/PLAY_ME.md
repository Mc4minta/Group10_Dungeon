# PLAY_ME - record a run for the video

You play the game in the PC window. Your key presses are written to a text file. Later that file is replayed
headless (no window) and rendered to a clean 60 fps MP4 with sound. Nobody has to play in real time, and the
window does not have to be fast: the file stores **simulation frame numbers**, never clock time.

This is footage of the **PC simulation** of the FPGA design (Verilator), not of the board.

## 1. Build the seeded game (once, and again after every change in `rtl/` or `main.cpp`)

You need Linux or WSL with `verilator` 5.x, `g++`, `make`, `libsdl2-dev`, and for rendering `ffmpeg`.

```bash
cd sim/verilator
make SEED=0x1234          # -> obj_dir_seeded/Vtop   (a few minutes; PGO build)
```

**Always use `SEED=0x1234` for recordings.** The Light Bulb and Simon puzzles take their pattern from a free-running
counter; with the normal build (`SEED=0`) every start is a different puzzle and a replay would not match your play.
The same binary must be used to record, to verify and to render. Do not rebuild between recording and rendering
(if you must, record again).

Tested with Verilator 5.048 (the signal named `inside` in `rtl/renderer.v` was renamed `in_box` because newer Verilator rejects it).

## 2. Record

Run from the `mem/` folder (the game loads its `.mem` files from the current directory):

```bash
cd mem
../sim/verilator/obj_dir_seeded/Vtop --skip 2 --record-inputs ../recordings/run_floor1.txt
```

(`mkdir recordings` in the repo root first. Use a new file name for every take: an existing file is overwritten.)

Start with a fresh game: the first frame of the recording must be the TITLE screen. Play, then press **Esc** to stop.
The file is saved on Esc, on closing the window, on Ctrl-C and every 3 seconds while you play.
If the program crashes you lose at most the last 3 seconds, plus a button that was held at that moment.

### Keys

| Key | What it does |
|---|---|
| Arrow keys | walk (two together = diagonal) |
| **Space** | attack; starts the game on the title screen; closes story boxes (hold = keep firing) |
| **F5** | sprint on/off (switch SW14, a toggle: press once to turn on, again to turn off) |
| **F6** | pause on/off (switch SW15, also a toggle) |
| **C** | clap (the simulated microphone hears 100 ms of noise): stuns boss 1 |
| **F1** | maze mode on/off (SW10) |
| F2, F3, F4 | SW11 / SW12 / SW13 (clap fallback, facing lock, reset the boxes) |
| 0 - 9 | toggle SW0 - SW9 (SW9 = auto aim on/off, SW8 = show hit boxes; SW0-SW4 only do something in a DEBUG build) |
| Backspace | reset the whole game while held |
| **M** | mute the live sound (does not change the recording) |
| `[` and `]` | simulate fewer / more frames per window refresh (same as `--skip`) |
| **Esc** | quit and save |

Everything above is recorded, except M and `[` `]` (they do not change the game).
See `docs/CONTROLS.md` for the full list of what each switch does on the board.

### If the window is slow

The simulation runs at only a few frames per second on most PCs (the window title shows `fps`). The game runs in
slow motion, that is normal and does not change the video.

* Use a higher `--skip`: `--skip 4` draws only every 4th frame and reads the keyboard only every 4th frame, so
  the window is smoother, but key presses are rounded to 4-frame steps (a very short tap can be missed).
  `--skip 2` is a good balance; use `--skip 1` for exact timing in a boss fight.
* Use the software renderer: `RENDERER=sw ../sim/verilator/obj_dir_seeded/Vtop --skip 2 --record-inputs ...`
  (helps on some laptops and in WSL).
* Turn the live sound off with `NOAUDIO=1`, or press M. The sound in the final video comes from the replay, not from your session.
* You can change skip while playing with `[` and `]`. This is noted in the file as a `# skip changed` comment.

## 3. Check the recording (replay twice, same result?)

```bash
scripts/verify_replay.sh recordings/run_floor1.txt
```

It replays the file twice headless on the seeded build and compares the frame hashes (FNV-1a of every 640x480 VGA
frame). It must print `PASS`. Quick check of only the first 600 frames: `FRAMES=600 scripts/verify_replay.sh recordings/run_floor1.txt`.
A replay runs at the same slow speed as playing, so a 1 minute run (3600 frames) needs about 20 minutes.

If it prints `FAIL`, the run cannot be rendered reliably: check that the binary was built with `SEED=0x1234` and not rebuilt after the recording.

## 4. Render the video

```bash
tools/video/render_run.sh recordings/run_floor1.txt out/floor1.mp4
tools/video/render_run.sh recordings/run_floor1.txt recordings/run_floor2.txt recordings/run_boss.txt out/all.mp4
```

Result: 1920x1080, 60 fps, H.264 (CRF 20, yuv420p), AAC audio, the label "PC simulation of the FPGA design"
bottom left. The 640x480 picture is enlarged with nearest neighbour to 1440x1080 with black bars left and right.
At the end the script prints the `ffprobe` data and the audio/video length difference (it should be a few milliseconds).
`FIT=smooth3 tools/video/render_run.sh ...` gives evenly sized pixels (enlarge x3, then shrink) if the 2.25x
scaling looks uneven to you. `AUDIO=0` renders without sound.

### Re-render just one part

```bash
python3 tools/video/trim_run.py recordings/run_boss.txt 5200 6400 recordings/boss_part.txt
tools/video/render_run.sh recordings/boss_part.txt out/boss_part.mp4
```

The replay still has to simulate from frame 1 (the game state at frame 5200 depends on everything before it), but only
frames 5200-6400 are written to the video. Find the frame numbers in the window title (`[frame N]`) while you play,
or note them in `RUN_SHEET.md`.

## 5. Hand in

Send the `.txt` file (small) to the video editor. Do not send MP4 or WAV files via git: they are ignored by `.gitignore`.
Fill in a row in `tools/video/RUN_SHEET.md`.

## What the file looks like

```
# Group10 Dungeon input recording (replay: Vtop --headless --script-file THIS_FILE)
# seed: 4660 (0x1234)
# skip: 2
# date: 2026-11-23 20:15:00
# git: ecf5807 (+uncommitted changes in rtl/ or sim/verilator)
C:120:121          <- Space held in frames 120..121
R:200:380          <- right arrow held
e:900              <- switch SW14 (sprint) toggled at frame 900
K:1500             <- clap
# end: frame 4210
```

It is the same format `--script-file` already reads (and `scripts/*.txt` use), plus `B:a:b` for Backspace held.
