. /mnt/e/vivado/Group10_Dungeon/Group10_Dungeon/report_shots/env.sh
cd $ROOT/sim/verilator
SDL_CF=$(sdl2-config --cflags); SDL_LD=$(sdl2-config --libs)
# Verilator 5.054 treats "inside" as a SV keyword; force Verilog-2005 so rtl/ stays untouched.
make seeded PGO=0 VFLAGS="--cc --exe -O3 -j 0 --top-module top -I../../rtl -Wno-fatal -Wno-lint -Wno-style --default-language 1364-2005 -GDEBOUNCE=2000 -GCE_DIV=1 -GSEED=4660 -GPROLOGUE=0 --Mdir obj_dir_seeded --x-assign fast --x-initial fast -CFLAGS \"-DNDEBUG -DCE_DIV=1 -DFAST_CLOCK=1 $SDL_CF\" -LDFLAGS \"$SDL_LD\"" 2>&1 > /tmp/build.log; grep -n "%Error" -A3 /tmp/build.log | head -20
ls -la obj_dir_seeded/Vtop
