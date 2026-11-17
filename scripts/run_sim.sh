#!/usr/bin/env bash
# รัน simulation ด้วย Icarus Verilog (ไม่ต้องเปิด Vivado)
#   ./scripts/run_sim.sh player   ทดสอบเดิน/ชน/ประตู (~5 วิ)
#   ./scripts/run_sim.sh top      จำลองทั้งระบบ บันทึกภาพ 3 เฟรมเป็น sim/*.ppm (~1 นาที)
set -e
cd "$(dirname "$0")/../mem"          # $readmemh หาไฟล์ .mem จากโฟลเดอร์นี้
case "${1:-player}" in
  player)
    iverilog -g2012 -o ../sim/tb_player.vvp ../sim/tb_player.v ../rtl/player.v ../rtl/roms.v
    vvp ../sim/tb_player.vvp ;;
  top)
    iverilog -g2012 -o ../sim/tb_top.vvp ../sim/tb_top.v ../rtl/*.v
    vvp ../sim/tb_top.vvp ;;
  *) echo "usage: $0 [player|top]"; exit 1 ;;
esac
