CPE222 report screenshots, Figures 20-37  (Group10 Dungeon, Verilator simulation of the real RTL)
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
  mkdir -p /tmp/g10shots && cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames <F+1>       --script-file ../report_shots/scripts/<JOB>.txt --shot-at <F>:/tmp/g10shots/<name>.bmp
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

figure                     job   frame  what is shown  |  DEBUG switches used in that script
fig20_title                A     20     title screen (hero vs vampire between two torches)  |  none
fig21_play                 E     500    floor 1 combat room 1, 4 monsters alive, hero with 4 hearts, hint strip (DEFEAT ALL ENEMIES / ENEMIES LEFT) at the top  |  none (real play: intro dialogs skipped with BTNC, walk to C1)
fig22_melee                E     602    Form 1 melee swing (yellow arc) on a monster  |  none
fig23_shooting             F     1440   Form 3 (angel) shot splitting (green AOE bullets) in floor 2 combat room 1 with turrets firing  |  SW1 (skip floor 1), SW3 x2 (evolve to form 3), SW0 (boss door); combat itself is real
fig24_cleared              H2    1000   floor 1 combat room cleared: doors open, hint DOORS OPEN / GO ON, spikes down  |  SW2 (clear waves), SW0 (boss door)
fig25_lightbulb_start      B     2210   Light Bulb puzzle at the start: bulbs 1010 (seeded), 4 levers, hint LIGHT ALL BULBS / PULL THE LEVERS  |  SW2 only in the two combat rooms before it
fig26_lightbulb_solved     B     2750   Light Bulb solved: all 4 bulbs lit, item on the floor (levers b and d pulled by the hero)  |  SW2 only in the two combat rooms before it
fig27_sokoban_start        C     2780   Sokoban at the start (floor 2)  |  SW1, SW2
fig28_sokoban_gate_open    C     4300   Sokoban solved, gate open  |  SW1, SW2
fig29_simon_show           D     3174   Simon Says pattern being shown (floor 3)  |  SW1 x2, SW3 x3, SW2, SW0
fig30_simon_solved         D     5040   Simon Says solved  |  SW1 x2, SW3 x3, SW2, SW0
fig31_boss1                H2    1440   Boss 1 stunned by the clap (K key), boss HP bar  |  SW0 (boss door), SW2 (clear C1)
fig32_boss2                F2    2500   Boss 2 inside its fence with minions  |  SW1, SW3 x2, SW2, SW0
fig33_boss3                G3    2600   Boss 3 charging (charge bar under its HP bar), hero's charged shot  |  SW1 x2, SW3 x3, SW2, SW0
fig34_floor_clear          K     195    FLOOR 1 CLEAR! screen  |  SW1 (floor done)
fig35_escape_maze          N     5100   tilt maze with the ball  |  SW1 x2, SW3 x3, SW2, SW0 (boss door only); boss 3 and the key are real
fig36_win                  N     5600   WIN screen  |  same as fig35
fig37_gameover             K     630    GAME OVER screen  |  SW4 x4 (take hit)

Exact commands
  fig20_title: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 21 --script-file ../report_shots/scripts/A.txt --shot-at 20:/tmp/g10shots/fig20_title.bmp
  fig21_play: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 501 --script-file ../report_shots/scripts/E.txt --shot-at 500:/tmp/g10shots/fig21_play.bmp
  fig22_melee: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 603 --script-file ../report_shots/scripts/E.txt --shot-at 602:/tmp/g10shots/fig22_melee.bmp
  fig23_shooting: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 1441 --script-file ../report_shots/scripts/F.txt --shot-at 1440:/tmp/g10shots/fig23_shooting.bmp
  fig24_cleared: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 1001 --script-file ../report_shots/scripts/H2.txt --shot-at 1000:/tmp/g10shots/fig24_cleared.bmp
  fig25_lightbulb_start: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 2211 --script-file ../report_shots/scripts/B.txt --shot-at 2210:/tmp/g10shots/fig25_lightbulb_start.bmp
  fig26_lightbulb_solved: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 2751 --script-file ../report_shots/scripts/B.txt --shot-at 2750:/tmp/g10shots/fig26_lightbulb_solved.bmp
  fig27_sokoban_start: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 2781 --script-file ../report_shots/scripts/C.txt --shot-at 2780:/tmp/g10shots/fig27_sokoban_start.bmp
  fig28_sokoban_gate_open: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 4301 --script-file ../report_shots/scripts/C.txt --shot-at 4300:/tmp/g10shots/fig28_sokoban_gate_open.bmp
  fig29_simon_show: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 3175 --script-file ../report_shots/scripts/D.txt --shot-at 3174:/tmp/g10shots/fig29_simon_show.bmp
  fig30_simon_solved: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 5041 --script-file ../report_shots/scripts/D.txt --shot-at 5040:/tmp/g10shots/fig30_simon_solved.bmp
  fig31_boss1: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 1441 --script-file ../report_shots/scripts/H2.txt --shot-at 1440:/tmp/g10shots/fig31_boss1.bmp
  fig32_boss2: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 2501 --script-file ../report_shots/scripts/F2.txt --shot-at 2500:/tmp/g10shots/fig32_boss2.bmp
  fig33_boss3: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 2601 --script-file ../report_shots/scripts/G3.txt --shot-at 2600:/tmp/g10shots/fig33_boss3.bmp
  fig34_floor_clear: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 196 --script-file ../report_shots/scripts/K.txt --shot-at 195:/tmp/g10shots/fig34_floor_clear.bmp
  fig35_escape_maze: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 5101 --script-file ../report_shots/scripts/N.txt --shot-at 5100:/tmp/g10shots/fig35_escape_maze.bmp
  fig36_win: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 5601 --script-file ../report_shots/scripts/N.txt --shot-at 5600:/tmp/g10shots/fig36_win.bmp
  fig37_gameover: cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir_seeded/Vtop --frames 631 --script-file ../report_shots/scripts/K.txt --shot-at 630:/tmp/g10shots/fig37_gameover.bmp

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

Determinism check: fig34 (frame 195) and fig37 (frame 630) were captured again with a run that has only that one --shot-at flag
(scripts/K.txt): the BMPs are byte-identical (cmp) to the BMPs of the exploration run.
Hero hearts: in some figures the hero has lost hearts (turret fire, spike corridor); that is real play damage, not edited.
