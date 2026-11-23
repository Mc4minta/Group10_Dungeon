#!/usr/bin/env python3
"""Writes README.txt from figs.py (fig, job script, frame). Run after finalize."""
import os
from figs import FIGS
HERE = os.path.dirname(os.path.abspath(__file__))
FRAMES = {}   # filled from frames.txt (name=job:frame)
for ln in open(os.path.join(HERE, "frames.txt")):
    ln = ln.strip()
    if ln:
        n, jf = ln.split("="); j, f = jf.split(":"); FRAMES[n] = (j, int(f))
out = []
w = out.append
w("""CPE222 report screenshots, Figures 20-37  (Group10 Dungeon, Verilator simulation of the real RTL)
=====================================================================================================
Nothing under rtl/, mem/ or sim/verilator was changed. The PPM/PNG files are 640x480.

Files
  ppm/<name>.ppm   P6, 640x480, 8-bit (cut out of the simulator capture, see below)
  png/<name>.png   made FROM THAT PPM by convert.py:  Image.open(ppm).convert("RGB").save(png)   (lossless copy)
  scripts/<job>.txt  Vtop key scripts (line = key:startFrame:endFrame; U D L R C = buttons, 0-9 a-f = SW0-SW15, K = clap)
  convert.py       BMP (Vtop --shot-at) -> PPM -> PNG for every BMP in /tmp/g10shots; the same code for all figures
  check.py         final check (both files exist, P6 640x480, PNG 640x480 RGB identical to the PPM, not one colour)
  gen_*.py tl.py   generate the scripts in scripts/ (timeline builder)   maze_*.py tb_maze.v  maze key planner + RTL check
  finalize.py      copies the chosen frame of a run to /tmp/g10shots/<name>.bmp

Capture size: Vtop --shot-at writes 640x552 = the 640x480 VGA frame + a 72 px simulator panel (7-seg / LEDs / switches) below it.
convert.py cuts the top 640x480 (plain crop, no resize). The panel is not part of the game picture.

Build (the seeded build is required: Light Bulb pattern 1010 and Simon sequence w q q e q come from SEED=0x1234)
  Environment used: WSL2 kali-linux, conda env "dungeon" (Verilator 5.054, SDL2, g++), Pillow in the system python3  (report_shots/env.sh)
  cd sim/verilator && make seeded     -> needs these changes on the command line only (Makefile and RTL untouched), see report_shots/_build.sh:
     * Verilator 5.054 treats the Verilog identifier "inside" (rtl/renderer.v) as a SystemVerilog keyword -> add  --default-language 1364-2005
     * -GPROLOGUE=0 (the Makefile passes an empty PROLOGUE_V; the replay scripts assume TITLE -> PLAY with no prologue pages), PGO=0
  Result: sim/verilator/obj_dir_seeded/Vtop

Run one figure (from the repo root, WSL):
  mkdir -p /tmp/g10shots && cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames <F+1> \
      --script-file ../report_shots/scripts/<JOB>.txt --shot-at <F>:/tmp/g10shots/<name>.bmp
  python3 ../report_shots/convert.py          # BMP -> PPM -> PNG
The simulator runs at only 2-3 frames/s on this PC, so each figure needs 10-45 minutes. While exploring, every job was run once
with many --shot-at flags (every 20/40 frames); the chosen frame is the BMP of that run. The simulation is deterministic: a run with only
the one flag gives the identical BMP (checked for fig34 and fig37 with cmp, see end of file).

DEBUG switches: rtl/top.v has DEBUG = 1 (current default). The scripts use SW1 (floor done), SW2 (clear the monsters of a combat room, waves need
several pulses), SW3 (evolve one form), SW0 (held: boss door open), SW4 (take 1 hit) ONLY to skip things that would need many minutes of play
and are not what the figure shows. What each figure needs is listed below.
Intro dialogs: the first game starts with 12 blocking dialog boxes; the scripts press BTNC (C) every 6 frames to skip them.
Wherever a figure is a real fight / puzzle / boss it is played by the script, not forced.

Figure table  (frame = Vtop frame number of the BMP; command = see "Run one figure")
""")
w("%-26s %-5s %-6s %s" % ("figure", "job", "frame", "what is shown  |  DEBUG switches used in that script"))
for name, job, fr0, what, dbg in FIGS:
    j, f = FRAMES.get(name, (job, fr0))
    w("%-26s %-5s %-6s %s  |  %s" % (name, j, f, what, dbg))
w("")
w("Exact commands")
for name, job, fr0, what, dbg in FIGS:
    j, f = FRAMES.get(name, (job, fr0))
    w("  %s: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames %d --script-file ../report_shots/scripts/%s.txt --shot-at %d:/tmp/g10shots/%s.bmp" % (name, f + 1, j, f, name))
w("""
Notes per job script
  A   title, intro dialogs skipped, walk right to floor 1 combat room 1 (real play)
  E   A + fight in combat room 1 (hold left, press C every 12 frames = Form 1 melee); no debug switch
  B   floor 1: SW2 clears combat rooms 1 and 2 (2-3 waves each), then the Light Bulb room is played for real: levers b and d are hit from above
      with the Form 1 swing -> bulbs 1010 -> 1111 -> item
  H2  floor 1 boss: SW0 + SW2, boss 1 fought for real, K = clap (the mic is replaced by the K key, stun lasts 3 s)
  C   floor 2 (SW1): C1 + C2 cleared with SW2, Sokoban solved by the solver replay (scripts/solve_sokoban.py moves, 16 frames per tile)
  F   floor 2 with Form 3 (SW1, SW3 x2): the hero shoots in combat room 1 (turrets, skeletons)
  F2  same, then walks to boss 2 (SW0 door) and fights it with the Form 3 shot
  G3  floor 3 with Form 4 (SW1 x2, SW3 x3): boss 3 fought with charged shots (hold C 46 frames)
  D   floor 3 Simon: SW1 x2, SW3 x3 (form 4 flies over the pits), SW2; the Simon plates are walked for real (w q q / w q q e / w q q e q)
  K   SW1 right after the intro = FLOOR 1 CLEAR screen;  SW4 x4 = GAME OVER (HP 0)
  N   full late game: floor 3 boss 3 killed for real (charged shots), the key is picked up, the hero walks back through C1 and START to door E,
      the maze is played by key presses (maze_slide.py: 12 moves of "hold a direction until the wall stops the ball", checked with the real
      maze.v in iverilog: tb_maze.v / maze_check.sh), ball reaches the goal -> WIN.  Only SW0 (boss door), SW1, SW3, SW2 skip floor 1-2 and combat rooms.

Not done as asked / things to know
  * A full TITLE -> WIN play with scripts/run_full_game.sh was NOT used: sim/verilator/scripts/full_game.txt and floor1-3.txt were written
    before the dialog boxes (W16/W31) and the map redesign (W35/W43) and no longer work (hero is frozen by the intro boxes, routes are blocked).
    The jobs above replace them; the dialog boxes freeze the game, so every script waits for them.
  * Fig 31: the clap (K key) stuns boss 1 (LOG shows stun=1 at that frame).
  * Fig 23: "later form shooting a turret monster": form 3 (angel) shots split into 4 green bullets on a hit; in that room the turrets also fire.
""")
open(os.path.join(HERE, "README.txt"), "w", encoding="utf-8").write("\n".join(out))
print("README.txt written")
