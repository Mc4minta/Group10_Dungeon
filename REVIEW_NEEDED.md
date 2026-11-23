# Review needed

Items I could not settle from the code and the existing documents, and documents that look outdated.
Nothing was deleted. Date of the review: 23/11/2026.

## 1. Facts that disagree and need an owner decision

| Topic | What the sources say | What I did |
| --- | --- | --- |
| Board test status | `docs/BOARD_TEST_STEPS.md`, `docs/CHANGE_REVIEW.md`, `docs/NEXT_STEPS.md`, `docs/README.md` say nothing is board-tested except the USB keyboard. The project team states that the full game ran on the board and works. | README says: the team reports it works; the repository records only the keyboard. The older documents were not rewritten. Please confirm and update `BOARD_TEST_STEPS.md` with the real results. |
| Boss 3 "3 charged hits" | The report text (as given to me) says "3 charged hits (HP 9)". `rtl/params.vh:72` says `BOSS3_HP = 9`, one HP per accepted hit, so 9 hits (charged shot, or any hit while it rests). `docs/STORY.md` and `docs/FEATURES.md` say 9. | Docs follow the code (9 hits). Check the wording in the report. |
| Timing | The final design did not meet timing (WNS -4.045 ns, TNS -2904.290 ns, 1853 of 9926 endpoints, WHS +0.046 ns). The numbers come from `vivado/Group10_Dungeon.runs/impl_1/top_timing_summary_routed.rpt`, which is git-ignored. `docs/CHANGE_REVIEW.md` records that the commit of that run is unknown. | Documented as not met. Re-run Vivado on the final commit to be sure the numbers belong to it. |

## 2. Code and test problems found while checking the documents (not fixed, by instruction)

| Problem | Where | Effect |
| --- | --- | --- |
| `reg inside;` — `inside` is a SystemVerilog keyword | `rtl/renderer.v:162` | Icarus Verilog 13.0 (`-g2012`) cannot compile it. Six `run_sim.sh` targets fail to compile: `simonplate`, `ovrender`, `text`, `orb`, `debug`, `top`. Verilator 5.054 stops on it too. |
| `tb_player` reports 2 failed checks | `form1 blocked by hole`, `spd4: form1 still blocked by hole` (`sim/tb_player.v`) | The testbench expects form 1 to be blocked by a hole, but the hero reached the other side (`px=304 py=40` and `py=12`). `rtl/player.v` lets only form 3 and 4 cross holes, so the cause (testbench, map or code) is not known. Not listed as a known gap anywhere in the docs. |
| `-GPROLOGUE=$(PROLOGUE_V)` with `PROLOGUE_V` undefined | `sim/verilator/Makefile` | The Verilator build fails with an empty parameter value in Verilator 5.054. |
| Old replay scripts | `sim/verilator/scripts/*.txt`, `scripts/run_full_game.sh` | Written before the story boxes and the room redesign; the hero is frozen by dialogs and routes are blocked. |
| Local paths with the old folder name | `report_shots/*.sh` (`/mnt/e/vivado/Group10_Dungeon/...`) | These are paths of one WSL machine, not the repository name. Not changed. |
| Python test and line endings | `tests/test_overlay_pipeline.py` | The test compares bytes. It failed in one run (`python -m unittest discover`) because the Windows checkout has CRLF line endings; `scripts/check_all.sh` regenerates the files first and passes. |

## 3. Possibly outdated documents (listed, not removed)

| File | Reason |
| --- | --- |
| `docs/DESIGN_PLAN.md` | History of work items W1 to W46; line 7 refers to `Group10_Dungeon_DEVELOPER_GUIDE.md`, which is not in the repository. Branch `sprite-zip` references are historical. |
| `docs/PROGRESS.md` | Original Thai checklist P0 to P7; its own header says it is historical. Contains old values (for example HP 3/3/4/4). |
| `docs/BOARD_DAY.md` | Thai checklist from before the P6 merge; mentions branch `main` "after merge P6". |
| `docs/DOC_UPDATE_REPORT.md` | Report of the 23/11 refresh; refers to commit `3e908a3`. |
| `docs/FEATURES.md`, `docs/NEXT_STEPS.md`, `docs/README.md` | Status lines say "`main` = `dev` (`3e908a3`)". The branches moved afterwards (`main` is at the merge of pull request 1, `dev` is ahead). The feature content was not re-verified line by line against the code. |
| `docs/CHANGE_REVIEW.md` | Long sections about branch `sprite-zip` and `board-test-2` are historical. |
| `docs/SOUND_PIPELINE_PLAN.md` | Plan only; none of the tools exist. |
| `docs/archive/SPRITE_PLAN.md` | Archived plan. |
| `docs/p*.png`, `docs/*_preview.png` | Screenshots from before W19 to W46; they may not match the current look. The pictures in `docs/images/` are current. |
| `docs/README_detailed_reference.md` | Copy of the previous root README; partly duplicates the new README. Kept for its detailed tables. |
| `report_shots.zip` | Zip of an earlier state of `report_shots/`; duplicates the folder. |

## 4. What I checked against the code and found correct

Hero forms (speed 2/2/3/3, HP 4, damage 1/1/2/2), boss HP (10/16/9), monster HP (2/3), 3 floors with 5 room roles, 13 map files, game states and retry/reset behaviour in `rtl/game_fsm.v`, the keyboard keys in `rtl/ps2_kbd.v`, SW5 to SW15 in `rtl/top.v`, VGA 640×480 (`rtl/vga_sync.v`), 100 MHz clock with a clock enable (`CE_DIV = 4`), trap timing, ESCAPE 60 s, ROM sizes, and the Vivado utilisation numbers.
Not re-verified line by line: the long tables in `docs/FEATURES.md`, `docs/MAP_DESIGN.md`, `docs/SOUND_PLAN.md` and `docs/DESIGN_PLAN.md`.
