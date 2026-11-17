# Group10_Dungeon (ชื่อเกมชั่วคราว)

เกม dungeon crawler + ห้องปริศนา บน Digilent Nexys A7-100T, VGA 640×480 @ 60 Hz, Verilog

สถานะ: **P0–P1 เสร็จ** — ภาพขึ้นจอ, เดิน 8 ทิศ, ชนกำแพง + ไถล + corner slide, เปลี่ยนห้อง flip-screen ครบ 3 ชั้น × 5 ห้อง, หลุม/ประตูบอส/ประตูทางออกเช็คตามร่าง (ผ่าน simulation แล้ว ยังไม่ได้ลงบอร์ดจริง)

## เริ่มใช้

1. ติดตั้ง Vivado (ตัวเดียวกับที่ใช้ใน lab) แล้วเปิด terminal ที่โฟลเดอร์นี้
2. สร้าง project:
   ```
   vivado -mode batch -source scripts/create_project.tcl
   ```
   หรือใน Vivado GUI: **Tools → Run Tcl Script…** เลือก `scripts/create_project.tcl`
3. เปิด `vivado/Group10_Dungeon.xpr` → Generate Bitstream → Program Device
   (หรือสั่ง build ทีเดียว: `vivado -mode batch -source scripts/create_project.tcl -tclargs build`)
4. ต่อจอ VGA แล้วกดเล่น

**ก่อน build ครั้งแรก** เทียบ pin ใน `constraints/nexys_a7.xdc` กับ `Nexys-A7-100T-Master.xdc` ของ Digilent อีกรอบ

## ปุ่มตอนนี้ (มีปุ่ม debug ชั่วคราว)

| อุปกรณ์ | ทำอะไร |
| --- | --- |
| BTNU/D/L/R | เดิน (กด 2 ปุ่ม = ทแยง) |
| BTNC กด | **debug** เปลี่ยนร่าง (แทน EVOLVE จนกว่าจะมีปริศนา) |
| BTNC กดค้าง | strafe (ไม่เปลี่ยนทิศที่หัน) |
| SW0 | **debug** เปิดประตูบอส L |
| SW1 ยกขึ้น | **debug** ไปชั้นถัดไป |
| SW2 | **debug** ปิดประตู D (ทดสอบห้องล็อก) |
| CPU_RESETN | reset |
| 7-seg | `ชั้น - ร่าง - . . . ห้อง` |
| LED0–3 | ปุ่มทิศ, LED15 = แตะประตู E แล้ว (ชนะ) |
| RGB LED16 | สีตามร่าง เขียว/ฟ้า/ม่วง/ทอง |

## โครงสร้าง

```
rtl/          Verilog
  top.v         ต่อทุก module + ระบบห้อง (P2 จะแยก game_fsm.v)
  vga_sync.v    VGA timing, frame_tick
  renderer.v    วาด tile + sprite ผู้เล่น
  player.v      Movement FSM + collision + ประตู
  roms.v        tilemap / tileset / player ROM
  debounce.v    sync 2FF + debounce + edge
  seg7.v        7-segment 8 หลัก
maps/         แมพ ASCII 20×15 ทั้ง 13 ห้อง (แก้ที่นี่)
mem/          ไฟล์ .mem ที่สร้างจากสคริปต์ (อย่าแก้มือ)
scripts/
  build_maps.py        maps/*.txt → mem/tilemap.mem + mem/objects.txt
  make_placeholders.py สร้าง sprite placeholder → mem/tileset.mem, mem/player.mem
  create_project.tcl   สร้าง Vivado project
  run_sim.sh           simulation ด้วย Icarus Verilog
sim/          testbench + ภาพจาก simulation
constraints/  .xdc
docs/         ภาพ preview ของ placeholder
  PROGRESS.md   checklist ความคืบหน้า P0–P7 / sprite / asset (อัปเดตทุกครั้งที่งานเสร็จ)
```

## แก้แมพ / sprite

- แก้แมพ: แก้ `maps/*.txt` แล้วรัน `python3 scripts/build_maps.py` (สัญลักษณ์ตาม Core Mechanics Bible, แผ่น Simon ใช้ `q w e r`)
- เปลี่ยน sprite จริง: ใช้ sprite_tool ทำ `.mem` แล้ววางทับ `mem/tileset.mem` / `mem/player.mem` ขนาดและลำดับเฟรมต้องเหมือนเดิม
  - tileset: 3 ชั้น × 16 tile, address = (ชั้น×16 + tile)×1024 + y×32 + x
  - player: เฟรม = ร่าง×12 + ทิศ×3 + ท่า (ทิศ 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา, ท่า 0 idle 1 ก้าว A 2 ก้าว B)
- แก้ไฟล์ .mem แล้วใน Vivado ต้อง re-run synthesis

## เล่นบนจอคอม (ไม่ต้องมีบอร์ด)

ใช้ Verilator แปลง Verilog ชุดเดียวกับที่ลงบอร์ดเป็นโปรแกรม แล้วแสดงภาพ VGA ในหน้าต่าง SDL2 พร้อมแผง 7-seg / LED / RGB / สวิตช์ ด้านล่าง

```
cd sim/verilator
make run
```

| คีย์ | บนบอร์ด |
| --- | --- |
| ลูกศร | BTNU / BTND / BTNL / BTNR |
| Space | BTNC |
| 0–9 | สลับ SW0–SW9 |
| F1–F6 | สลับ SW10–SW15 |
| Backspace | CPU_RESETN |
| Esc | ออก |

ติดตั้งครั้งแรก:

- **Windows**: ใช้ WSL2 + Ubuntu 24.04 (Windows 11 หรือ Windows 10 ที่อัปเดต WSL แล้ว หน้าต่างเด้งขึ้นมาเองผ่าน WSLg)
  ```
  wsl --install -d Ubuntu-24.04          # ใน PowerShell (admin) ครั้งเดียว แล้วรีสตาร์ท
  sudo apt update && sudo apt install -y build-essential verilator libsdl2-dev
  ```
  เปิดโฟลเดอร์โปรเจคจาก WSL ได้ที่ `/mnt/c/Users/<ชื่อ>/...` (build เร็วกว่าถ้า copy ไปไว้ใน `~/`)
- **macOS**: `brew install verilator sdl2`
- **Ubuntu/Debian**: `sudo apt install -y build-essential verilator libsdl2-dev` (ต้องเป็น Verilator 5.x — Ubuntu 22.04 ได้ 4.x ซึ่งเก่าไป ใช้ 24.04)

ข้อแตกต่างจากบอร์ดจริง: simulator ตั้ง `CE_DIV=1` (pixel clock ทุก clock เพื่อให้เร็วขึ้น 4 เท่า ภาพเลื่อน 1 พิกเซล) และ debounce สั้นลง ส่วน logic เกมเหมือนบอร์ดทุกอย่าง ความเร็วขึ้นกับเครื่อง (บน sandbox ~23 fps, WSL2 ~20–30 fps) ถ้าช้ากว่า 60 fps เกมจะดูช้าลงตาม แต่ไม่ผิด

ทดสอบอัตโนมัติแบบไม่เปิดหน้าต่าง:
```
SDL_VIDEODRIVER=dummy make run ARGS='--frames 300 --script "R:5:200,C:60:62" --shot shot.bmp'
```

## Simulation (testbench)

```
./scripts/run_sim.sh player   # 12 test: เดิน ชน ไถล corner slide หลุม ประตู animation
./scripts/run_sim.sh top      # จำลองทั้งระบบ ได้ภาพ sim/frame_*.ppm
```
ต้องมี Icarus Verilog (`sudo apt install iverilog` หรือ `brew install icarus-verilog`) ภาพตัวอย่างอยู่ใน `sim/*.png`

## ขั้นต่อไป (ตามแผน Implement)

- P1.6 ดันกล่อง Sokoban
- P2 แยก `game_fsm.v` (TITLE / PLAY / EVOLVE / FLOOR_CLEAR / ESCAPE / WIN / GAME_OVER), HP, เวลาเล่นบน 7-seg
- P3 object slot + มอน + กระสุน + ห้อง Combat ล็อก (เอา SW2 ออก)
- งานคู่ขนาน: sprite จริง, ทดสอบไมค์ PDM
