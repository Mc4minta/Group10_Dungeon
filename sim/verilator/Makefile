# เล่นเกมบนจอคอมด้วย Verilator + SDL2
#   make          build
#   make run      build + เปิดหน้าต่าง
# ต้องมี: verilator (5.x), libsdl2-dev / sdl2, g++/clang, make
ROOT    := ../..
RTL     := $(wildcard $(ROOT)/rtl/*.v)
SDL_CF  := $(shell sdl2-config --cflags)
SDL_LD  := $(shell sdl2-config --libs)

# debounce สั้นลงใน simulation (ของจริง 10 ms = 1,000,000 clock)
VFLAGS  := --cc --exe --build -O3 -j 0 --top-module top -Wno-fatal -Wno-lint -Wno-style \
           -GDEBOUNCE=2000 -GCE_DIV=1 --x-assign fast --x-initial fast \
           -CFLAGS "-O3 -march=native -DCE_DIV=1 $(SDL_CF)" -LDFLAGS "$(SDL_LD)"

all: obj_dir/Vtop

obj_dir/Vtop: $(RTL) main.cpp
	verilator $(VFLAGS) $(RTL) main.cpp

# $readmemh หาไฟล์ .mem จากโฟลเดอร์ปัจจุบัน -> รันจาก mem/
run: obj_dir/Vtop
	cd $(ROOT)/mem && $(CURDIR)/obj_dir/Vtop $(ARGS)

clean:
	rm -rf obj_dir

.PHONY: all run clean
