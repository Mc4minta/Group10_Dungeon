# tools/video - gameplay video from the Verilator simulation

Renders the real RTL (`rtl/`, unchanged) in the Verilator model without a window and encodes it to MP4.
This is footage of the **PC simulation**, not of the FPGA board; every video carries the label
"PC simulation of the FPGA design".

```
tools/video/render.sh scripts/b_forms.txt            # -> tools/video/out/b_forms.mp4 (+ .log state log)
FIT=native AUDIO=0 tools/video/render.sh scripts/a_floor1.txt /tmp/a.mp4
```

Needs on PATH: verilator 5.x, g++, make, sdl2-config (SDL2 dev files), python3, ffmpeg with drawtext.
The simulation runs at about 3 frames/s on one core (1.2-1.3 fps when several runs share the machine),
so a 30 s video (about 2000 simulated frames) takes 10-25 minutes.

## Input script (segment format)
One line per segment: `<frames> <tokens>`, `#` starts a comment.

| token | meaning |
|---|---|
| `U D L R C` | BTNU/D/L/R/C held for the segment |
| `K` | clap heard by the simulated microphone (100 ms) at the segment start |
| `SW0`..`SW15` | slide switch ON for this segment only |
| `+SW0` / `-SW0` | switch turned ON and left on / turned off again |
| `@skip` / `@rec` | following segments are simulated but not recorded / recorded |

`seg2script.py` converts it to the frame script that `Vtop --script-file` already reads;
`frames2seg.py` converts old frame scripts to this format.

## What was added to the simulator
Only `sim/verilator/main.cpp`: `--raw-out FILE` (every VGA frame, 640x480 RGB24, also with `--headless`)
and `--rec A:B` (limit video and WAV to those frames). Audio uses the existing `--wav` (the PWM output
averaged per 512 clocks, mono 16 bit); nothing is synthesised.

## Notes
- Build: `render.sh` builds its own model in `tools/video/build/` with the same parameters as the Makefile plus
  `--default-language 1364-2005` (Verilator 5.x rejects `inside` in rtl/renderer.v) and `-GPROLOGUE=0`. The model is built with `-GDEBUG=1` (override with `DEBUG=0`) because scripts b, c and d need the debug switches SW0-SW4, whatever default rtl/top.v currently has.
- Output: 1920x1080 H.264, yuv420p, 60 fps. `FIT=pad` (default) = x3 nearest-neighbour, then scaled to 1440x1080 with `area` and padded;
  `FIT=native` = pure x3 nearest, 1920x1440.
- Audio is stretched by about 0.8 % (ffmpeg `atempo`) because the board's frame rate is about 59.5 Hz, not 60.
- Puzzle seed is fixed (SEED=4660, as `make seeded`), so Light Bulb and Simon patterns match the scripts.
- Scripts use debug switches only where stated in their first comment lines.
