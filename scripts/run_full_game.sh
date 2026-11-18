#!/usr/bin/env bash
# เล่นเกมเต็ม TITLE -> WIN ด้วยสคริปต์ sim/verilator/scripts/full_game.txt แบบไม่เปิดหน้าต่าง
# ผ่าน (exit 0) เมื่อสถานะสุดท้ายเป็น WIN เท่านั้น
#   ./scripts/run_full_game.sh                  (build แบบ seeded ให้เองถ้ายังไม่มี)
#   SHOTS=1 ./scripts/run_full_game.sh          (บันทึกภาพ docs/p5_*.png ด้วย; ต้องมี python3 + PIL)
# ใช้เวลา ~10 นาทีบน WSL2 (~10,000 เฟรมที่ ~16-20 fps) จึงไม่อยู่ใน run_sim.sh all
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/sim/verilator"
[ -x obj_dir_seeded/Vtop ] || make seeded
FRAMES=${FRAMES:-9900}
cd "$ROOT/mem"
SHOT_ARGS=()
[ -n "$WAVS" ] && SHOT_ARGS+=(--wav-seg 20:2300:../docs/audio/floor1.wav --wav-seg 9395:9840:../docs/audio/escape.wav)   # WAVS=1: บันทึกเสียงด้วย
if [ -n "$SHOTS" ]; then
  mkdir -p /tmp/g10shots
  SHOT_ARGS+=(--shot-at 15:/tmp/g10shots/title.bmp --shot-at 2200:/tmp/g10shots/boss1.bmp
             --shot-at 5420:/tmp/g10shots/boss2_stunned.bmp --shot-at 6010:/tmp/g10shots/floor_clear.bmp
             --shot-at ${BOSS3_F:-9250}:/tmp/g10shots/boss3.bmp --shot-at ${ESC_F:-9420}:/tmp/g10shots/escape.bmp
             --shot-at $((FRAMES - 2)):/tmp/g10shots/win.bmp)
  export SDL_VIDEODRIVER=dummy
else
  export HEADLESS=1
fi
t0=$(date +%s)
out=$(LOG=$((FRAMES)) ../sim/verilator/obj_dir_seeded/Vtop --frames "$FRAMES" \
      --script-file ../sim/verilator/scripts/full_game.txt "${SHOT_ARGS[@]}")
t1=$(date +%s)
echo "$out" | grep "^f=" | tail -1 | cut -c1-90
echo "$out" | tail -3
echo "wall-clock: $((t1 - t0)) s"
if [ -n "$SHOTS" ]; then
  python3 - <<'PY'
import glob, os
from PIL import Image
for f in glob.glob('/tmp/g10shots/*.bmp'):
    n = os.path.splitext(os.path.basename(f))[0]
    Image.open(f).save(os.path.join('..', 'docs', f'p5_{n}.png'))
print('screenshots -> docs/p5_*.png')
PY
fi
if echo "$out" | grep -q "^f=$FRAMES .* st=5 "; then echo "== WIN"; else echo "== NOT WIN"; exit 1; fi
