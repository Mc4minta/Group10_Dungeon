#!/usr/bin/env bash
# รัน simulation ด้วย Icarus Verilog (ไม่ต้องเปิด Vivado)
#   ./scripts/run_sim.sh player   ทดสอบเดิน/ชน/ประตู (~5 วิ)
#   ./scripts/run_sim.sh world    ทดสอบระบบห้อง/ประตู/จุดเกิด ทุกชั้น (~1 วิ)
#   ./scripts/run_sim.sh fsm      ทดสอบ game_fsm (TITLE/PLAY/EVOLVE/...) (~1 วิ)
#   ./scripts/run_sim.sh objects  ทดสอบ objects.v: AABB ฟัน ยิง มอน โดนตี ห้องล็อก (~1 นาที)
#   ./scripts/run_sim.sh puzzles  ทดสอบปริศนา 3 ห้อง + ดันกล่อง (เล่นตามคำตอบ solver) + ไอเทม (~2 นาที)
#   ./scripts/run_sim.sh mictop   ทดสอบตัวทดสอบไมค์แยก (peak hold, BTNC ล้าง, ตัวนับ, TH จากสวิตช์)
#   ./scripts/run_sim.sh audio    ทดสอบเสียง: PWM, SFX 10 แบบ, priority, โน้ต Simon, BGM (~1 นาที)
#   ./scripts/run_sim.sh mic      ทดสอบไมค์ PDM: เงียบ / ตบมือ / holdoff 200 ms (~1 นาที)
#   ./scripts/run_sim.sh boss     ทดสอบบอส 3 ตัว, มึน, ห้องล็อก, FLOOR_CLEAR, ESCAPE -> WIN / GAME_OVER
#   ./scripts/run_sim.sh debug    ทดสอบ parameter DEBUG (สวิตช์ debug ใช้ได้เฉพาะ DEBUG = 1)
#   ./scripts/run_sim.sh top      จำลองทั้งระบบ บันทึกภาพ 3 เฟรมเป็น sim/*.ppm (~1 นาที)
#   ./scripts/run_sim.sh all      player + world + fsm + objects + puzzles + mic + mictop + audio + boss + debug + top (ล้มเหลวถ้ามี FAIL / errors != 0)
set -e
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$0")/../mem"          # $readmemh หาไฟล์ .mem จากโฟลเดอร์นี้

run() {   # run <tb> <files...>
  local tb=$1; shift
  iverilog -g2012 -I../rtl -I../sim -o ../sim/$tb.vvp "$@"
  vvp ../sim/$tb.vvp | tee /tmp/run_sim_$tb.log
  if grep -q "FAIL" /tmp/run_sim_$tb.log; then echo "== $tb: FAILED"; return 1; fi
  if grep -Eq "errors = [1-9]" /tmp/run_sim_$tb.log; then echo "== $tb: FAILED"; return 1; fi
}

case "${1:-player}" in
  player) run tb_player ../sim/tb_player.v ../rtl/player.v ../rtl/roms.v ;;
  world)  run tb_world  ../sim/tb_world.v ../rtl/world.v ;;
  sprites) run tb_sprites ../sim/tb_sprites.v ../rtl/roms.v ;;
  tileset) run tb_tileset ../sim/tb_tileset.v ../rtl/roms.v ;;
  monster) run tb_monster ../sim/tb_monster.v ../rtl/roms.v ;;
  fsm)    run tb_game_fsm ../sim/tb_game_fsm.v ../rtl/game_fsm.v ;;
  puzzles) run tb_puzzles ../sim/tb_puzzles.v ../rtl/puzzles.v ../rtl/objects.v ../rtl/player.v ../rtl/game_fsm.v ../rtl/roms.v ;;
  audio)  run tb_audio ../sim/tb_audio.v ../rtl/audio.v ;;
  mictop) run tb_mic_test_top ../sim/tb_mic_test_top.v ../rtl/mic_test_top.v ../rtl/pdm_mic.v ../rtl/seg7.v ../rtl/debounce.v ../rtl/bin2bcd.v ;;
  mic)    run tb_pdm_mic ../sim/tb_pdm_mic.v ../rtl/pdm_mic.v ;;
  boss)   run tb_boss ../sim/tb_boss.v ../rtl/boss.v ../rtl/objects.v ../rtl/player.v ../rtl/game_fsm.v ../rtl/world.v ../rtl/roms.v ;;
  debug)  run tb_debug ../sim/tb_debug.v ../rtl/*.v ;;
  objects) run tb_objects ../sim/tb_objects.v ../rtl/objects.v ../rtl/player.v ../rtl/game_fsm.v ../rtl/roms.v ;;
  top)    iverilog -g2012 -I../rtl -o ../sim/tb_top.vvp ../sim/tb_top.v ../rtl/*.v
          vvp ../sim/tb_top.vvp | tee /tmp/run_sim_tb_top.log
          if grep -q "FAIL" /tmp/run_sim_tb_top.log; then echo "== tb_top: FAILED"; exit 1; fi ;;
  all)    "$SELF" player && "$SELF" world && "$SELF" fsm && "$SELF" objects && "$SELF" puzzles && "$SELF" mic && "$SELF" mictop && "$SELF" audio && "$SELF" boss && "$SELF" debug && "$SELF" top && echo "== ALL OK" ;;
  *) echo "usage: $0 [player|world|fsm|top|all]"; exit 1 ;;
esac
