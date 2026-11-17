# เล่นเกมบนจอคอมด้วย Verilator + SDL2
#   make          build (PGO: build -> ซ้อมรัน 300 เฟรม -> build ใหม่ด้วย profile, ~2 เท่าของเวลา build ปกติ)
#   make PGO=0    build ครั้งเดียว ไม่ทำ PGO (เร็วกว่าตอน build แต่ sim ช้ากว่า ~10%)
#   make run      build + เปิดหน้าต่าง
# ต้องมี: verilator (5.x), libsdl2-dev / sdl2, g++/clang, make
ROOT    := ../..
RTL     := $(wildcard $(ROOT)/rtl/*.v)
VH      := $(wildcard $(ROOT)/rtl/*.vh)
SDL_CF  := $(shell sdl2-config --cflags)
SDL_LD  := $(shell sdl2-config --libs)

# C++ optimisation. Two things were defeating -O3 in the verilated build:
#  1. verilated.mk sets OPT_FAST/OPT_GLOBAL = -Os with a plain assignment (env vars are ignored)
#  2. conda exports CXXFLAGS/CPPFLAGS containing "-Os ... -fstack-protector-strong -O2 ... -D_FORTIFY_SOURCE=2"
# Fix: run verilator without --build, then call make ourselves with command-line overrides for
# OPT_* (beat every file assignment) and strip the conda flag variables from the environment.
OPT_NATIVE := -O3 -march=native -fno-stack-protector
# eval ครั้งเดียวต่อ clock (ดู main.cpp) — ตั้ง FAST_CLOCK=0 ถ้า Verilator รุ่นอื่น build ไม่ผ่าน
FAST_CLOCK ?= 1
# profile-guided optimisation ของ g++ (+~10%): 1 = เปิด
PGO        ?= 1
PROF_DIR   := $(CURDIR)/obj_dir/pgo
PGO_GEN    := -fprofile-generate -fprofile-dir=$(PROF_DIR)
PGO_USE    := -fprofile-use -fprofile-dir=$(PROF_DIR) -fprofile-correction -Wno-missing-profile
NOCONDA    := env -u CXXFLAGS -u CPPFLAGS -u CFLAGS -u DEBUG_CXXFLAGS -u DEBUG_CPPFLAGS
ovr = OPT_FAST="$(OPT_NATIVE) $(1)" OPT_SLOW="$(OPT_NATIVE) $(1)" OPT_GLOBAL="$(OPT_NATIVE) $(1)" LDFLAGS="$(1)"

# debounce สั้นลงใน simulation (ของจริง 10 ms = 1,000,000 clock)
VFLAGS  := --cc --exe -O3 -j 0 --top-module top -I$(ROOT)/rtl -Wno-fatal -Wno-lint -Wno-style \
           -GDEBOUNCE=2000 -GCE_DIV=1 --x-assign fast --x-initial fast \
           -CFLAGS "-DNDEBUG -DCE_DIV=1 -DFAST_CLOCK=$(FAST_CLOCK) $(SDL_CF)" -LDFLAGS "$(SDL_LD)"

all: obj_dir/Vtop

obj_dir/Vtop: $(RTL) $(VH) main.cpp
	verilator $(VFLAGS) $(RTL) main.cpp
ifeq ($(PGO),1)
	rm -rf $(PROF_DIR)
	$(NOCONDA) $(MAKE) -C obj_dir -f Vtop.mk -j$(shell nproc) $(call ovr,$(PGO_GEN))
	cd $(ROOT)/mem && HEADLESS=1 $(CURDIR)/obj_dir/Vtop --frames 300 --script "C:20:23,R:40:191,C:200:260,U:261:300" > /dev/null
	rm -f obj_dir/*.o obj_dir/Vtop obj_dir/*.a
	$(NOCONDA) $(MAKE) -C obj_dir -f Vtop.mk -j$(shell nproc) $(call ovr,$(PGO_USE))
else
	$(NOCONDA) $(MAKE) -C obj_dir -f Vtop.mk -j$(shell nproc) $(call ovr,)
endif

# $readmemh หาไฟล์ .mem จากโฟลเดอร์ปัจจุบัน -> รันจาก mem/
run: obj_dir/Vtop
	cd $(ROOT)/mem && $(CURDIR)/obj_dir/Vtop $(ARGS)

clean:
	rm -rf obj_dir

.PHONY: all run clean
