#!/usr/bin/env bash
# Check that a recording replays deterministically: run it twice headless on the SEEDED build and compare the frame hashes.
#   scripts/verify_replay.sh RUN.txt            prints PASS or FAIL (exit code 0 / 1)
#   FRAMES=600 scripts/verify_replay.sh RUN.txt replay only the first 600 frames (quick check)
#   VTOP=/path/to/Vtop scripts/verify_replay.sh RUN.txt   use another binary
#
# WHY THE SEEDED BUILD: the Light Bulb and Simon puzzles take their pattern from a free-running LFSR, so the
# normal build (obj_dir/Vtop, SEED=0) plays a different puzzle every start and a replay would not match.
# Record AND replay with the seeded build:  cd sim/verilator && make SEED=0x1234   ->   obj_dir_seeded/Vtop
# A recording is only valid for the same binary (same rtl/, same SEED); rebuild the model and old recordings may no longer match.
#
# Both replays run at the same time (about 3 simulated frames per second each, so a 1 minute run = 3600 frames = about 20 minutes).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUN=${1:-}
[ -n "$RUN" ] && [ -f "$RUN" ] || { echo "usage: scripts/verify_replay.sh RUN.txt"; exit 2; }
RUN=$(cd "$(dirname "$RUN")" && pwd)/$(basename "$RUN")
VTOP=${VTOP:-$ROOT/sim/verilator/obj_dir_seeded/Vtop}
[ -x "$VTOP" ] || { echo "missing $VTOP - build it:  cd sim/verilator && make SEED=0x1234"; exit 2; }
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python

USER_FRAMES=${FRAMES:-}
eval "$($PY "$ROOT/tools/video/runinfo.py" "$RUN")"          # sets FRAMES VID_A VID_B SEED SKIP
[ -n "$USER_FRAMES" ] && FRAMES=$USER_FRAMES
case "$SEED" in
  ""|"4660"*|*0x1234*) ;;
  *) echo "WARNING: recording header says '# seed: $SEED' but the replay build must be SEED=0x1234 (4660)" ;;
esac
if [ -n "$(find "$ROOT/rtl" "$ROOT/sim/verilator/main.cpp" -newer "$VTOP" 2>/dev/null | head -1)" ]; then
  echo "WARNING: rtl/ or main.cpp is newer than $VTOP - rebuild with make SEED=0x1234 or the check may not mean what you think"
fi

T=$(mktemp -d "${TMPDIR:-/tmp}/g10verify.XXXXXX"); trap 'rm -rf "$T"' EXIT
echo "[verify] $RUN: $FRAMES frames, binary $VTOP (seed ${SEED:-not in file})"
for i in 1 2; do       # $readmemh finds the .mem files in the current directory -> run from mem/
  ( cd "$ROOT/mem" && "$VTOP" --headless --frames "$FRAMES" --script-file "$RUN" --frame-hash > "$T/run$i.log" 2>&1 ) &
done
wait

H1=$(grep '^FINAL-HASH' "$T/run1.log"); H2=$(grep '^FINAL-HASH' "$T/run2.log")
if [ -z "$H1" ] || [ -z "$H2" ]; then
  echo "FAIL: a replay did not finish (no FINAL-HASH line). Last output:"; tail -3 "$T/run1.log" "$T/run2.log"; exit 1
fi
echo "run 1: $H1"
echo "run 2: $H2"
if [ "$H1" = "$H2" ] && diff -q <(grep '^frame-hash' "$T/run1.log") <(grep '^frame-hash' "$T/run2.log") >/dev/null; then
  echo "PASS: both replays are identical"
  exit 0
fi
echo "FAIL: replays differ. First differing hash line:"
diff <(grep -E '^(frame-hash|FINAL-HASH)' "$T/run1.log") <(grep -E '^(frame-hash|FINAL-HASH)' "$T/run2.log") | head -4
exit 1
