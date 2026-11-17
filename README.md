# Group10_Dungeon (ชื่อเกมชั่วคราว)

เกม dungeon crawler + ห้องปริศนา บน Digilent Nexys A7-100T, VGA 640×480 @ 60 Hz, Verilog

สถานะ: **P0–P3 เสร็จใน simulation** — ภาพขึ้นจอ, เดิน 8 ทิศ, ชนกำแพง + ไถล + corner slide, เปลี่ยนห้อง flip-screen ครบ 3 ชั้น × 5 ห้อง, หลุม/ประตูบอส/ประตูทางออกเช็คตามร่าง, Game FSM (TITLE / PLAY / EVOLVE / FLOOR_CLEAR / WIN / GAME_OVER), 4 ร่าง + HP + เวลา mm.ss + sprint, การต่อสู้ (ฟัน/ยิง, มอน A ไล่ + มอน B ป้อมยิง 4 ทิศ, โดนตี knockback + อมตะ, ห้อง Combat ล็อกจนมอนตายหมด) (ยังไม่ได้ลงบอร์ดจริง) — ดูความคืบหน้าที่ `docs/PROGRESS.md`

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
| BTNC กด | เริ่มเกมจากหน้า TITLE · **โจมตี** ตอนเล่น (ร่าง 1 ฟันประชิดหน้าตัว, ร่าง 2–4 ยิงกระสุนตามทิศที่หัน) · กลับ TITLE จากหน้า WIN / GAME OVER |
| BTNC กดค้าง | strafe (ไม่เปลี่ยนทิศที่หัน) + ร่าง 2–4 ยิงซ้ำทุก cooldown |
| **SW15** | **sprint**: ความเร็ว +1 px/เฟรม (ค่า `SPRINT_BONUS` ใน `rtl/params.vh`) ใช้ได้ทุกร่าง ระหว่างเล่น |
| CPU_RESETN | reset (กลับหน้า TITLE) |

ปุ่ม **debug ชั่วคราว** (จะเอาออกเมื่อมีระบบจริง):

| อุปกรณ์ | ทำอะไร | แทนของจริงใน |
| --- | --- | --- |
| SW0 | เปิดประตูบอส L | `has_item[floor]` จากปริศนา (P4) |
| SW1 ยกขึ้น | `floor_done` → FLOOR_CLEAR 2 วิ → ชั้นถัดไป | บอสตาย (P5) |
| SW3 ยกขึ้น | `got_item` → EVOLVE (ร่างถัดไป, HP เต็ม) | ไอเทมจากปริศนา (P4) |
| SW4 ยกขึ้น | `take_hit` → HP −1 (ไม่มี knockback) | ใช้ทดสอบ; โดนศัตรูจริงทำงานแล้ว (P3) |

SW2 (ปิดประตู D) เอาออกแล้ว: ประตูห้อง Combat ปิดเองเมื่อมีมอนเหลือ

จอและ LED:

| อุปกรณ์ | แสดง |
| --- | --- |
| 7-seg | `ชั้น - HP - mm.ss` (TITLE = `--------`; WIN / GAME OVER ค้างค่าสุดท้าย) |
| LED0–3 | ปุ่มทิศ |
| LED4–7 | มอนที่เหลือในห้อง (bar: LED4 = ≥1 … LED7 = ≥4, ห้องมีได้ถึง 6 ตัว) |
| LED8–11 | HP (หนึ่งดวงต่อ HP เริ่มจาก LED8) |
| LED12 | ประตูห้องล็อกอยู่ (ห้อง Combat ที่ยังมีมอน) |
| LED14 / LED15 | sprint เปิดอยู่ / WIN |
| RGB LED16 | สีตามร่าง เขียว/ฟ้า/ม่วง/ทอง · ขาวตอน EVOLVE |
| RGB LED17 | แดง = เพิ่งโดนตี (ช่วง knockback + อมตะ 68 เฟรม) |
| จอ VGA | TITLE = พื้นกรมท่า + ตัวละคร · GAME OVER = แดงเข้ม · WIN = ทอง (ยังไม่มีข้อความ รอ font ใน P5) |

ค่าเกมที่ยัง *tentative* ทั้งหมดอยู่ใน `rtl/params.vh` ที่เดียว (บรรทัดละค่า) ค่าต่อร่าง:

| ร่าง | ความเร็ว px/เฟรม | Max HP | ดาเมจ | RGB16 |
| --- | --- | --- | --- | --- |
| 1 | 2 | 3 | 1 | เขียว |
| 2 | 2 | 3 | 1 | ฟ้า |
| 3 | 3 | 4 | 2 | ม่วง |
| 4 | 3 | 4 | 2 | ทอง |

การต่อสู้ (P3, *tentative*):

| อย่าง | ค่า |
| --- | --- |
| ร่าง 1 ฟันประชิด | hit box 24×16 หน้าตัว อยู่ 8 เฟรม, cooldown 20 เฟรม, โดนมอนตัวละ 1 ทีต่อการฟัน |
| ร่าง 2–4 ยิง | กระสุน 8×8 วิ่ง 4 px/เฟรม, บนจอได้ 2 นัด, cooldown 15 เฟรม · หยุดที่ `#` และประตูปิด, ผ่าน `H` `F` |
| มอน A (`S` ในแมพ) | HP 2, เดินหาผู้เล่น 1 px/เฟรม แยกแกน x/y ชน tile (ไม่ผ่าน `#` ประตู `H` `F`), ชนตัว = HP −1 |
| มอน B (`T` ในแมพ) | HP 3, อยู่กับที่ ยิง 4 ทิศทุก 120 เฟรม (ครั้งแรก 60 เฟรมหลังเข้าห้อง) ตัวถัดไปในห้องเหลื่อม 30 เฟรม, กระสุน 3 px/เฟรม |
| มอนโดนตี | กะพริบขาว 8 เฟรม, HP 0 = หายไป |
| ผู้เล่นโดนตี | HP −1, ถอย 16 px ใน 8 เฟรม (ประตูเป็นกำแพงระหว่างถอย), แล้วอมตะ 60 เฟรม (กะพริบ) — กระสุนศัตรูทะลุตอนอมตะ |
| ห้อง Combat (C1, C2) | เข้าแล้วมีมอน = ประตู D ปิด · มอนตายหมด = cleared ประตูเปิด ไม่เกิดใหม่ · เริ่มเกมใหม่ = ล้าง cleared |

## โครงสร้าง

```
rtl/          Verilog
  params.vh     ค่าเกม tentative ทั้งหมด (`include ใน game_fsm / player / objects)
  top.v         ต่อทุก module + input/จอ/LED
  world.v       ห้อง: floor, room, grid, ตารางประตู + จุดเกิด, load player
  game_fsm.v    TITLE/PLAY/EVOLVE/FLOOR_CLEAR/ESCAPE/WIN/GAME_OVER, ร่าง, HP, timer, sprint
  objects.v     slot มอน 6 / กระสุนผู้เล่น 2 / กระสุนศัตรู 16 / บอส 1, spawn, โจมตี, AABB, โดนตี, ห้องล็อก
  objline.v     ชั้นภาพ object แบบ line buffer สองชุด (วาดบรรทัดถัดไประหว่างบรรทัดนี้)
  vga_sync.v    VGA timing, frame_tick
  renderer.v    pipeline 3 clock: tile < object < ผู้เล่น + หน้า TITLE / GAME OVER / WIN
  player.v      Movement FSM + collision + ประตู + knockback
  roms.v        tilemap / tileset / player / monster / bullet / effect / spawn ROM
  debounce.v    sync 2FF + debounce + edge
  seg7.v        7-segment 8 หลัก + จุดทศนิยม
maps/         แมพ ASCII 20×15 ทั้ง 13 ห้อง (แก้ที่นี่)
mem/          ไฟล์ .mem ที่สร้างจากสคริปต์ (อย่าแก้มือ)
scripts/
  build_maps.py        maps/*.txt → mem/tilemap.mem + mem/objects.txt + mem/monsters.mem (มอนต่อห้อง)
  make_placeholders.py สร้าง sprite placeholder → mem/tileset.mem, player.mem, monster.mem, bullet.mem, effect.mem
  create_project.tcl   สร้าง Vivado project
  run_sim.sh           simulation ด้วย Icarus Verilog
sim/          testbench + ภาพจาก simulation
constraints/  .xdc
docs/         ภาพ preview ของ placeholder + ภาพจาก simulation (p2_*, p3_*)
  PROGRESS.md   checklist ความคืบหน้า P0–P7 / sprite / asset (อัปเดตทุกครั้งที่งานเสร็จ)
```

## แก้แมพ / sprite

- แก้แมพ: แก้ `maps/*.txt` แล้วรัน `python3 scripts/build_maps.py` (สัญลักษณ์ตาม Core Mechanics Bible, แผ่น Simon ใช้ `q w e r`)
- เปลี่ยน sprite จริง: ใช้ sprite_tool ทำ `.mem` แล้ววางทับ `mem/tileset.mem` / `mem/player.mem` ขนาดและลำดับเฟรมต้องเหมือนเดิม
  - tileset: 3 ชั้น × 16 tile, address = (ชั้น×16 + tile)×1024 + y×32 + x
  - player: เฟรม = ร่าง×12 + ทิศ×3 + ท่า (ทิศ 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา, ท่า 0 idle 1 ก้าว A 2 ก้าว B)
  - monster: 4 เฟรม 32×32 = มอน A เฟรม 0, 1 แล้วมอน B เฟรม 0, 1 · bullet: 2 เฟรม 8×8 (ผู้เล่น, ศัตรู) · effect: ฟันประชิด 4 ทิศ 32×32
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
| Space | BTNC (เริ่มเกม / โจมตี / ค้าง = strafe + ยิงซ้ำ) |
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

ข้อแตกต่างจากบอร์ดจริง: simulator ตั้ง `CE_DIV=1` (pixel clock ทุก clock เพื่อให้เร็วขึ้น 4 เท่า) และ debounce สั้นลง ส่วน logic เกมเหมือนบอร์ดทุกอย่าง ความเร็วขึ้นกับเครื่อง (WSL2 ~20 fps หลังเพิ่ม object ใน P3) ถ้าช้ากว่า 60 fps เกมจะดูช้าลงตาม แต่ไม่ผิด

ทดสอบอัตโนมัติแบบไม่เปิดหน้าต่าง:
```
SDL_VIDEODRIVER=dummy make run ARGS='--frames 300 --script "R:5:200,C:60:62" --shot shot.bmp'
```

## Simulation (testbench)

```
./scripts/run_sim.sh player   # 12 test เดิม + speed 4 + freeze: เดิน ชน ไถล corner slide หลุม ประตู animation
./scripts/run_sim.sh world    # ประตูทุกบาน ทุกชั้น, grid, จุดเกิด, restart, next_floor, exit_evt
./scripts/run_sim.sh fsm      # game_fsm: TITLE→PLAY, EVOLVE 60 เฟรม, HP, GAME OVER, FLOOR_CLEAR 120 เฟรม, timer, sprint
./scripts/run_sim.sh objects  # objects: AABB, ฟัน, ยิง, กระสุนชน tile, มอน A/B, โดนตี knockback อมตะ, ห้องล็อก
./scripts/run_sim.sh top      # จำลองทั้งระบบ ได้ภาพ sim/frame_*.ppm
./scripts/run_sim.sh all      # รันทั้งหมดข้างบน
```
ต้องมี Icarus Verilog (`sudo apt install iverilog` หรือ `brew install icarus-verilog`) ภาพตัวอย่างอยู่ใน `sim/*.png`, `docs/p2_*.png`, `docs/p3_*.png`

ทดสอบ Verilator แบบไม่เปิดหน้าต่าง + จับภาพหลายเฟรม (สวิตช์ใน `--script`: `0-9` = SW0–9, `a-f` = SW10–15):
```
cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir/Vtop --frames 540   --script "C:20:23,f:50,R:45:230,3:240,3:250" --shot-at 15:t.bmp --shot-at 270:e.bmp
```

สคริปต์ต่อสู้ห้อง Combat 1 ชั้น 1 (ที่ใช้ทำ `docs/p3_*.png`): เข้าห้อง, หันขึ้นฟันมอนตัวแรก, SW3 เป็นร่าง 2, หันขวายิงค้างจนห้องเคลียร์ แล้วเดินออกประตูซ้าย
`LOG=10` พิมพ์ค่า LED ทุก 10 เฟรม (LED4–7 มอนเหลือ, LED8–11 HP, LED12 ล็อก):
```
cd mem && SDL_VIDEODRIVER=dummy LOG=10 ../sim/verilator/obj_dir/Vtop --frames 900 \
  --script "C:20:23,R:40:200,U:201:202,C:300:301,C:321:322,C:342:343,C:363:364,C:384:385,C:405:406,C:426:427,3:450,3:455,R:514:517,C:525:800,L:820:900" \
  --shot-at 300:locked.bmp --shot-at 560:shooting.bmp --shot-at 815:cleared.bmp
```

## ขั้นต่อไป (ตามแผน Implement)

- P1.6 ดันกล่อง Sokoban
- ESCAPE (P5), ข้อความบนจอ (font, P5)
- P4 ปริศนา 3 ห้อง (ให้ `has_item` แทน SW0, `got_item` แทน SW3)
- งานคู่ขนาน: sprite จริง, ทดสอบไมค์ PDM
