#!/usr/bin/env bash
# รัน simulation ด้วย Icarus Verilog (ไม่ต้องเปิด Vivado)
#   ./scripts/run_sim.sh player   ทดสอบเดิน/ชน/ประตู (~5 วิ)
#   ./scripts/run_sim.sh world    ทดสอบระบบห้อง/ประตู/จุดเกิด ทุกชั้น (~1 วิ)
#   ./scripts/run_sim.sh fsm      ทดสอบ game_fsm (TITLE/PLAY/EVOLVE/...) (~1 วิ)
#   ./scripts/run_sim.sh top      จำลองทั้งระบบ บันทึกภาพ 3 เฟรมเป็น sim/*.ppm (~1 นาที)
#   ./scripts/run_sim.sh all      player + world + fsm + top (ล้มเหลวถ้ามี FAIL / errors != 0)
set -e
cd "$(dirname "$0")/../mem"          # $readmemh หาไฟล์ .mem จากโฟลเดอร์นี้

run() {   # run <tb> <files...>
  local tb=$1; shift
  iverilog -g2012 -o ../sim/$tb.vvp "$@"
  vvp ../sim/$tb.vvp | tee /tmp/run_sim_$tb.log
  if grep -q "FAIL" /tmp/run_sim_$tb.log; then echo "== $tb: FAILED"; return 1; fi
  if grep -Eq "errors = [1-9]" /tmp/run_sim_$tb.log; then echo "== $tb: FAILED"; return 1; fi
}

case "${1:-player}" in
  player) run tb_player ../sim/tb_player.v ../rtl/player.v ../rtl/roms.v ;;
  world)  run tb_world  ../sim/tb_world.v ../rtl/world.v ;;
  fsm)    run tb_game_fsm ../sim/tb_game_fsm.v ../rtl/game_fsm.v ;;
  top)    iverilog -g2012 -o ../sim/tb_top.vvp ../sim/tb_top.v ../rtl/*.v
          vvp ../sim/tb_top.vvp ;;
  all)    "$0" player && "$0" world && "$0" fsm && "$0" top && echo "== ALL OK" ;;
  *) echo "usage: $0 [player|world|fsm|top|all]"; exit 1 ;;
esac
