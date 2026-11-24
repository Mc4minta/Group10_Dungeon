# RUN_SHEET - recordings for the video

One row per recording. Binary for every row: `sim/verilator/obj_dir_seeded/Vtop` built with `make SEED=0x1234`.
Fill in the columns when you hand in a file. "Verified" = `scripts/verify_replay.sh` printed PASS. See `PLAY_ME.md`.

Frame numbers are simulation frames (the `[frame N]` in the window title, 60 frames = 1 s of video).

| Part | What must be shown | Recording file | Player | Date | Frames | Verified | Rendered MP4 | Notes |
|---|---|---|---|---|---|---|---|---|
| floor1 | Title, prologue, walk, form 1 melee, clear rooms, Light Bulb puzzle, evolve | | | | | | | |
| floor1 | Boss 1: clap stun (press C), win, FLOOR CLEAR | | | | | | | |
| floor2 | Rooms, Sokoban boxes, evolve | | | | | | | |
| floor2 | Boss 2 fight | | | | | | | |
| floor3 | Rooms, Simon puzzle, evolve | | | | | | | |
| floor3 | Boss 3 fight, ESCAPE, WIN screen | | | | | | | |
| extra | Game over and retry; pause (F6); maze mode (F1) | | | | | | | |

## Checklist per recording

- [ ] Started from a fresh game (TITLE screen at the first frame), seeded build
- [ ] Ended with Esc (the file ends with `# end: frame N`)
- [ ] `scripts/verify_replay.sh <file>` = PASS
- [ ] Rendered with `tools/video/render_run.sh`, A/V drift in the report is small (a few ms)
- [ ] Watched the MP4 once: no stuck keys, no accidental Backspace reset

## Retake log

| Recording | Problem | Retake file |
|---|---|---|
| | | |
