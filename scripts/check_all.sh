#!/usr/bin/env bash
# ONE command to check the whole project before you commit or build the board:
#   scripts/check_all.sh          generated files up to date + all Python tests + the full iverilog suite (about 12 minutes)
#   scripts/check_all.sh --fast   same without the iverilog suite (about 1 minute)
# Works on Linux / WSL / Git Bash (the iverilog part needs iverilog; it is skipped with a note if it is missing).
# Exit code 0 = everything OK.
cd "$(dirname "$0")/.." || exit 2
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
FAST=0; [ "$1" = "--fast" ] && FAST=1
fail=0
step() { echo; echo "== $*"; }

# snapshot of the generated files (hash of the content with line endings removed, so Windows / WSL / Linux agree)
GEN="mem/*.mem mem/objects.txt rtl/sprite_cfg.vh rtl/bgm_cfg.vh rtl/puzzle_layout.vh rtl/text_layout.vh rtl/text_select.vh rtl/dlg_cfg.vh"
snapshot() { for f in $GEN; do [ -f "$f" ] && printf '%s %s\n' "$(tr -d '\r' < "$f" | cksum)" "$f"; done; }
BEFORE=$(snapshot)

step "1/4 rebuild every generated file (art, tiles, monsters, bosses, puzzle objects, health display, maps, music)"
for b in player tileset monster boss puzzle hud overlay; do
  $PY scripts/build_${b}_mem.py > /tmp/check_all_$b.log 2>&1; rc=$?
  [ $rc -ge 2 ] && { echo "FAIL: build_${b}_mem.py exit code $rc"; tail -3 /tmp/check_all_$b.log; fail=1; }
done
$PY scripts/build_story.py > /tmp/check_all_story.log 2>&1 || { echo "FAIL: build_story.py"; fail=1; }
$PY scripts/build_maps.py > /tmp/check_all_maps.log 2>&1 || { echo "FAIL: build_maps.py"; fail=1; }
$PY scripts/make_music.py > /tmp/check_all_music.log 2>&1 || { echo "FAIL: make_music.py"; fail=1; }

step "2/4 the rebuild must not change any generated file (nothing stale)"
AFTER=$(snapshot)
if [ "$BEFORE" = "$AFTER" ]; then echo "OK: every generated file was already up to date";
else echo "FAIL: the rebuild changed these generated files (they were stale: commit the new versions):"; diff <(echo "$BEFORE") <(echo "$AFTER") | grep '^>' | sed 's/^> [0-9]* [0-9]* //' ; fail=1; fi

step "3/4 Python tests"
for t in tests/test_*.py; do
  if $PY -W error "$t" > /tmp/check_all_test.log 2>&1; then echo "OK   $t"; else echo "FAIL $t"; tail -5 /tmp/check_all_test.log; fail=1; fi
done

step "4/4 iverilog suite (run_sim.sh all)"
if [ $FAST -eq 1 ]; then echo "skipped (--fast)";
elif command -v iverilog >/dev/null 2>&1; then
  if ./scripts/run_sim.sh all > /tmp/check_all_sim.log 2>&1; then echo "OK: ALL OK"; else echo "FAIL: see /tmp/check_all_sim.log"; grep FAIL /tmp/check_all_sim.log | head -5; fail=1; fi
else echo "iverilog not found: skipped (on Windows run this script inside WSL)"; fi

echo; [ $fail -eq 0 ] && echo "CHECK_ALL: PASS" || echo "CHECK_ALL: FAIL"
exit $fail
