#!/usr/bin/env bash
# Live fallback drill on the real tree (run from WSL/Linux or Git Bash): breaks the art on purpose, shows that the
# build still succeeds with warnings and that the sprite ROM test + a headless game run still work, then restores.
#   tests/fallback_drill.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT" || exit 2
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
BK=$(mktemp -d); cp -a picture "$BK/picture"; cp mem/player.mem "$BK/player.mem"; cp sprites/sprites.json "$BK/sprites.json"
restore() { rm -rf picture; cp -a "$BK/picture" picture; cp "$BK/sprites.json" sprites/sprites.json; $PY scripts/build_player_mem.py >/dev/null; cmp -s mem/player.mem "$BK/player.mem" && echo "RESTORED: mem/player.mem identical to before" || echo "WARNING: mem/player.mem differs after restore"; rm -rf "$BK"; }
trap restore EXIT
fail=0
check() {  # name
  echo; echo "######## DRILL: $1"
  $PY scripts/build_player_mem.py | grep -E "^(WARNING|ERROR|NOTE)|^  form|Summary|Wrote" | cut -c1-200
  rc=${PIPESTATUS[0]}; echo "build exit code: $rc"; [ "$rc" -le 1 ] || fail=1
  [ "$(wc -l < mem/player.mem)" -eq 49152 ] || { echo "FAIL: mem/player.mem is not 49152 lines"; fail=1; }
  if command -v iverilog >/dev/null 2>&1; then
    ./scripts/run_sim.sh sprites > "$BK/tb.log" 2>&1; grep -E "sprites:|ALL PASS|FAIL" "$BK/tb.log"
    grep -q "FAIL" "$BK/tb.log" && { echo "FAIL: sprite ROM test failed"; fail=1; }
  fi
  if [ -x sim/verilator/obj_dir_seeded/Vtop ]; then ( cd mem && HEADLESS=1 ../sim/verilator/obj_dir_seeded/Vtop --frames 120 2>&1 | tail -1 ); fi
}
# 1. rename a sheet (form 2 walk)
mv picture/Character/ORc/form2_Walk.png picture/Character/ORc/form2_Walk.png.hidden; check "form 2 sheet renamed (missing)"
mv picture/Character/ORc/form2_Walk.png.hidden picture/Character/ORc/form2_Walk.png
# 2. one transparent cell (form 1 walk row 1 col 1 = down.A and right.A)
$PY - <<'P'
from PIL import Image
p = "picture/Character/Human/Walk.png"; im = Image.open(p).convert("RGBA"); im.paste((0, 0, 0, 0), (32, 0, 64, 32)); im.save(p)
P
check "form 1 walk cell r1 c1 made transparent"
cp -a "$BK/picture/Character/Human/Walk.png" picture/Character/Human/Walk.png
# 3. wrong-size sheet (form 3 walk 100x100)
$PY - <<'P'
from PIL import Image
im = Image.new("RGBA", (100, 100), (0, 0, 0, 0)); im.paste((255, 0, 0, 255), (30, 30, 50, 50)); im.save("picture/Character/Angel/Angel_walk.png.png")
P
check "form 3 walk sheet wrong size 100x100"
# 4. sheet too small (form 3 walk 128x64: rows 3-4 missing)
$PY - <<'P'
from PIL import Image
im = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
for c in range(4):
    for r in range(2):
        im.paste((255, 0, 0, 255), (c * 32 + 10, r * 32 + 10, c * 32 + 22, r * 32 + 22))
im.save("picture/Character/Angel/Angel_walk.png.png")
P
check "form 3 walk sheet too small (only rows 1-2)"
echo; [ $fail -eq 0 ] && echo "DRILL RESULT: PASS (build always succeeded, 49152 lines, sprite test + game ran)" || echo "DRILL RESULT: FAIL"
exit $fail
