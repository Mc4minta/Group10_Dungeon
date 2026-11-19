#!/usr/bin/env bash
# Whole-system iverilog test with wall variants ON (does not touch mem/ or rtl/tileset_cfg.vh):
# builds a 64-tile tileset in a throw-away folder, compiles the full design with WALL_VAR_EN = 1 and the animations ON,
# runs tb_top and writes the captured frames to sim/_wall_tmp/sim/*.ppm (look at them to check the room borders).
#   scripts/test_wall_variants.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
T="$ROOT/sim/_wall_tmp"; rm -rf "$T"; mkdir -p "$T/mem" "$T/sim"
cp mem/*.mem mem/*.txt "$T/mem/" 2>/dev/null || true
cp sim/tb_top.v sim/*.vh "$T/sim/" 2>/dev/null || true
$PY - <<PYEOF
import json, os
c = json.load(open("sprites/tileset.json", encoding="utf-8"))
c["wall_variants"]["enabled"] = True
c["output_mem"] = "sim/_wall_tmp/mem/tileset.mem"
c["verilog_cfg"] = "sim/_wall_tmp/tileset_cfg.vh"
json.dump(c, open("sim/_wall_tmp/tileset_on.json", "w", encoding="utf-8"), indent=1)
PYEOF
$PY scripts/build_tileset_mem.py --config sim/_wall_tmp/tileset_on.json | grep -E "Wall variants|WARNING|ERROR|Wrote" | cut -c1-160
cp sim/anim_on/sprite_cfg.vh "$T/sprite_cfg.vh"
cd "$T/mem"
iverilog -g2012 -I"$T" -I"$ROOT/rtl" -I"$ROOT/sim" -o "$T/tb_top_wall.vvp" "$ROOT/sim/tb_top.v" "$ROOT"/rtl/*.v
vvp "$T/tb_top_wall.vvp" | tee "$T/run.log" | tail -5
if grep -q "FAIL" "$T/run.log"; then echo "== wall variants + animations ON: tb_top FAILED"; exit 1; fi
echo "== wall variants + animations ON: tb_top OK, frames in $T/sim"
