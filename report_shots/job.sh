#!/usr/bin/env bash
# explore job (WSL): job.sh <name> <script-file> <frames> <from> <to> <step>   -> dense BMPs /tmp/g10dense/<name>_fNNNNN.bmp + log
. /mnt/e/vivado/Group10_Dungeon/Group10_Dungeon/report_shots/env.sh
N=$1; S=$ROOT/report_shots/scripts/$2; F=$3
mkdir -p /tmp/g10dense; A=""
for f in $(seq $4 $6 $5); do A="$A --shot-at $f:/tmp/g10dense/${N}_f$(printf %05d $f).bmp"; done
cd $ROOT/mem
LOG=20 ../sim/verilator/obj_dir_seeded/Vtop --frames $F --script-file $S $A > /tmp/g10dense/$N.log 2>&1
echo DONE >> /tmp/g10dense/$N.log
