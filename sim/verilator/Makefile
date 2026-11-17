# เล่นเกมบนจอคอมด้วย Verilator + SDL2
#   make          build
#   make run      build + เปิดหน้าต่าง
# ต้องมี: verilator (5.x), libsdl2-dev / sdl2, g++/clang, make
ROOT    := ../..
RTL     := $(wildcard $(ROOT)/rtl/*.v)
SDL_CF  := $(shell sdl2-config --cflags)
SDL_LD  := $(shell sdl2-config --libs)

# C++ optimisation. Two things were defeating -O3 in the verilated build:
#  1. verilated.mk sets OPT_FAST/OPT_GLOBAL = -Os with a plain assignment (env vars are ignored)
#  2. conda exports CXXFLAGS/CPPFLAGS containing "-Os ... -fstack-protector-strong -O2 ... -D_FORTIFY_SOURCE=2"
# Fix: run verilator without --build, then call make ourselves with command-line overrides for
# OPT_* (beat every file assignment) and strip the conda flag variables from the environment.
OPT_NATIVE := -O3 -march=native -fno-stack-protector
MAKE_OVR   := OPT_FAST="$(OPT_NATIVE)" OPT_SLOW="$(OPT_NATIVE)" OPT_GLOBAL="$(OPT_NATIVE)"

# debounce สั้นลงใน simulation (ของจริง 10 ms = 1,000,000 clock)
VFLAGS  := --cc --exe -O3 -j 0 --top-module top -Wno-fatal -Wno-lint -Wno-style \
           -GDEBOUNCE=2000 -GCE_DIV=1 --x-assign fast --x-initial fast \
           -CFLAGS "-DNDEBUG -DCE_DIV=1 $(SDL_CF)" -LDFLAGS "$(SDL_LD)"

all: obj_dir/Vtop

obj_dir/Vtop: $(RTL) main.cpp
	verilator $(VFLAGS) $(RTL) main.cpp
	env -u CXXFLAGS -u CPPFLAGS -u CFLAGS -u DEBUG_CXXFLAGS -u DEBUG_CPPFLAGS $(MAKE) -C obj_dir -f Vtop.mk -j$(shell nproc) $(MAKE_OVR)

# $readmemh หาไฟล์ .mem จากโฟลเดอร์ปัจจุบัน -> รันจาก mem/
run: obj_dir/Vtop
	cd $(ROOT)/mem && $(CURDIR)/obj_dir/Vtop $(ARGS)

clean:
	rm -rf obj_dir

.PHONY: all run clean
