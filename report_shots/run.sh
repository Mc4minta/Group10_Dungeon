#!/usr/bin/env bash
# usage: run.sh <script-file> <frames> [shot-at args...]     (run inside WSL; LOG=<n> env for state log)
. /mnt/e/vivado/Group10_Dungeon/Group10_Dungeon/report_shots/env.sh
S=$1; N=$2; shift 2
mkdir -p /tmp/g10shots
cd $ROOT/mem
LOG=${LOG:-0} ../sim/verilator/obj_dir_seeded/Vtop --frames $N --script-file $S "$@"
