# usage (WSL): maze_check.sh keys.hex N   -> prints RTL ball position per frame (iverilog, rtl/maze.v + rtl/roms.v, mem/maze.mem)
cd /mnt/e/vivado/Group10_Dungeon/Group10_Dungeon/report_shots
iverilog -g2005 -o /tmp/tb_maze.vvp tb_maze.v ../rtl/maze.v ../rtl/roms.v || exit 1
cd ../mem && cp ../report_shots/$1 keys.hex && vvp /tmp/tb_maze.vvp +N=$2 | grep -v '^\$'; rm -f keys.hex
