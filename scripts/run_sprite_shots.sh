#!/usr/bin/env bash
# Verilator + SDL (dummy video) screenshots: every form x 4 facings, moving and idle -> preview/game/*.png
# needs the prebuilt/seeded Verilator binary (cd sim/verilator && make seeded)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/sim/verilator"; [ -x obj_dir_seeded/Vtop ] || make seeded
cd "$ROOT/mem"; mkdir -p ../preview/game
export SDL_VIDEODRIVER=dummy
../sim/verilator/obj_dir_seeded/Vtop --frames 1200 --script-file ../sim/verilator/scripts/sprite_check.txt $(cat ../preview/game/shots.txt) | tail -2
python3 - <<'P'
import glob
from PIL import Image
for p in glob.glob('../preview/game/*.bmp'):
    Image.open(p).convert('RGB').save(p[:-4] + '.png')
P
echo "screenshots in preview/game/"
