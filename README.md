# Group10_Dungeon (ชื่อเกมชั่วคราว)

เกม dungeon crawler + ห้องปริศนา บน Digilent Nexys A7-100T, VGA 640×480 @ 60 Hz, Verilog

สถานะ: **P0–P5 เสร็จใน simulation — เล่นจบเกมได้ใน sim** — ภาพขึ้นจอ, เดิน 8 ทิศ, ชนกำแพง + ไถล + corner slide, เปลี่ยนห้อง flip-screen ครบ 3 ชั้น × 5 ห้อง, หลุม/ประตูบอส/ประตูทางออกเช็คตามร่าง, Game FSM (TITLE / PLAY / EVOLVE / FLOOR_CLEAR / WIN / GAME_OVER), 4 ร่าง + HP + เวลา mm.ss + sprint, การต่อสู้ (ฟัน/ยิง, มอน A ไล่ + มอน B ป้อมยิง 4 ทิศ, โดนตี knockback + อมตะ, ห้อง Combat ล็อกจนมอนตายหมด), ปริศนา 3 ห้อง (Light Bulb, Sokoban + ดันกล่อง, Simon) + ไอเทมจริง (EVOLVE + เปิดประตูบอส L), บอส 3 ตัว + FLOOR_CLEAR จริง, ฉากหนี ESCAPE 30 วิ, ข้อความบนจอ, ไมค์ PDM (ตบมือ = บอส 2 มึน) (ยังไม่ได้ลงบอร์ดจริง) — ดูความคืบหน้าที่ `docs/PROGRESS.md`

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
| BTNC กด | เริ่มเกมจากหน้า TITLE · **โจมตี** ตอนเล่น (ดูตารางอาวุธต่อร่าง) · กลับ TITLE จากหน้า WIN / GAME OVER |
| BTNC กดค้าง | strafe (ไม่เปลี่ยนทิศที่หัน) + ร่าง 2–3 ยิงซ้ำทุก cooldown, ร่าง 4 ชาร์จลูกใหญ่ |
| **SW15** | **sprint**: ความเร็ว +1 px/เฟรม (ค่า `SPRINT_BONUS` ใน `rtl/params.vh`) ใช้ได้ทุกร่าง ระหว่างเล่น |
| **SW13** ยกขึ้น | รีเซ็ตกล่องห้อง Sokoban (ชั้น 2) กลับที่เดิม — ใช้ได้เฉพาะในห้องนั้น ตอน gate ยังปิด (control จริง ไม่ใช่ debug) |
| CPU_RESETN | reset (กลับหน้า TITLE) |

สวิตช์ **debug** ทำงานเฉพาะเมื่อ `top.v` ตั้ง `parameter DEBUG = 1` (ค่าตอนนี้ทั้งบอร์ดและ Verilator) — **build ส่งงานตั้ง `DEBUG = 0`**
(`vivado ... create_project.tcl` แล้วแก้ generic `DEBUG` ของ top เป็น 0 หรือแก้ค่า default ใน `rtl/top.v`):

| อุปกรณ์ | ทำอะไร (DEBUG = 1) |
| --- | --- |
| SW0 | เปิดประตูบอส L ทุกชั้น (ทับ `has_item`) |
| SW1 ยกขึ้น | ข้ามชั้น: `floor_done` → FLOOR_CLEAR 2 วิ → ชั้นถัดไป (ของจริงคือฆ่าบอส) · ตอน PLAY เดินเข้าประตู E = WIN ทันทีด้วย (ทางลัดเดิม) |
| SW2 ยกขึ้น | ลบมอนทั้งห้อง → ห้องเคลียร์ (ใช้ย่อสคริปต์ทดสอบ) |
| SW3 ยกขึ้น | `got_item` → EVOLVE (ของจริง: เก็บไอเทมในห้องปริศนา) |
| SW4 ยกขึ้น | `take_hit` → HP −1 (ไม่มี knockback) |

ไอเทมและปริศนา (P4):

| ชั้น | ห้องปริศนา | ทำอย่างไร | ไอเทม |
| --- | --- | --- | --- |
| 1 | Light Bulb | ฟันประชิดหรือยิงคันโยก a–d (แถวบน) แต่ละครั้งสลับหลอด 4 ดวงตาม mask a = 0111, b = 1011, c = 1101, d = 1110 (bit 3 = หลอด 1) จนติดครบ 4 ดวง · รูปแบบเริ่มต้นสุ่มทุกเกม ต้องตีอย่างน้อย 2 ครั้ง | โผล่ที่ `I` เมื่อแก้ได้ |
| 2 | Sokoban | เดินตรง (แกนเดียว) ชนกล่องเพื่อดัน 1 ช่อง ช่องถัดไปต้องเป็นพื้น/แผ่น · กล่องทับแผ่นครบ 2 แผ่น = gate เปิด · ติดเมื่อไหร่ยก SW13 · คำตอบน้อยสุด 24 ครั้ง (`scripts/solve_sokoban.py`) | อยู่หลัง gate ตั้งแต่แรก |
| 3 | Simon | ยืนรอดูแผ่นสว่างตามลำดับ แล้วเดินเหยียบตาม (นับเมื่อจุดกลางตัวเข้าแผ่น ต้องลงจากแผ่นก่อนก้าวต่อไป) 3 รอบ ยาว 3 / 4 / 5 · ผิด = HP −1 แผ่นแดง แล้วโชว์รอบเดิมใหม่ | โผล่ที่ `I` เมื่อครบ 3 รอบ |

เดินทับไอเทม → EVOLVE (ร่างถัดไป) + `has_item[ชั้น]` = ประตูบอส `L` ชั้นนั้นเปิด (LED13) · ปริศนาที่แก้แล้ว/ไอเทมที่เก็บแล้วค้างไว้แม้ออกจากห้อง · เริ่มเกมใหม่จาก TITLE = รีเซ็ตทั้งหมด

จอและ LED:

| อุปกรณ์ | แสดง |
| --- | --- |
| 7-seg | `ชั้น - HP - mm.ss` (TITLE = `--------`; WIN / GAME OVER ค้างค่าสุดท้าย) |
| LED0–3 | ปุ่มทิศ · ในห้อง Light Bulb = หลอด 1–4 (LED3 = หลอด 1 … LED0 = หลอด 4) · ในห้อง Simon = รอบที่ผ่านแล้ว (LED0–2) |
| LED4–7 | มอนที่เหลือในห้อง (bar: LED4 = ≥1 … LED7 = ≥4, ห้องมีได้ถึง 6 ตัว) |
| LED8–11 | HP (หนึ่งดวงต่อ HP เริ่มจาก LED8) |
| LED12 | ประตูห้องล็อกอยู่ (ห้อง Combat ที่ยังมีมอน) |
| LED13 | มีไอเทมของชั้นนี้แล้ว (ประตูบอส L เปิด) |
| LED14 / LED15 | sprint เปิดอยู่ / WIN |
| RGB LED16 | สีตามร่าง เขียว/ฟ้า/ม่วง/ทอง · ขาวตอน EVOLVE |
| RGB LED17 | แดง = เพิ่งโดนตี (ช่วง knockback + อมตะ 68 เฟรม) |
| จอ VGA | TITLE = ชื่อเกม + `PRESS BTNC` (กะพริบ) · FLOOR CLEAR = `FLOOR n CLEAR` · ESCAPE = `ESCAPE!` 2 วิแรก + จอสั่น · WIN = ทอง `YOU WIN` + เวลา `mm:ss` · GAME OVER = แดงเข้ม `GAME OVER` + `PRESS BTNC` |
| ห้องบอส | LED0–7 = HP บอส (8 ดวงตามสัดส่วน) · ESCAPE: LED ทั้ง 16 ดวงกะพริบ 4 Hz, 7-seg 4 หลักขวา = นับถอยหลัง `ss.ff` (วินาที.เฟรม) |
| 7-seg ในห้อง Simon | ยังแสดง HP ตามเดิม (เหยียบผิดเสีย HP) รอบที่ผ่านดูที่ LED0–2 |

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

## อาวุธต่อร่าง (P6)

| ร่าง | กด Space | กดค้าง | กระสุน | ดาเมจ |
| --- | --- | --- | --- | --- |
| 1 | ฟันประชิด (กล่อง 24×16 หน้าตัว) | strafe | — | 1 |
| 2 | ยิง 1 นัด 4 px/เฟรม (ผ่านรั้ว `F`) | strafe + ยิงซ้ำทุก 15 เฟรม | 8×8 ฟ้า | 1 |
| 3 | ยิงกระจาย 3 ทาง: ตรง + ทแยง 45° สองข้าง (ทแยง 3 px/แกน/เฟรม) | strafe + ยิงซ้ำทุก 20 เฟรม | 8×8 เขียว ×3 | 2 ต่อนัด |
| 4 | นัดเร็ว 6 px/เฟรม | ชาร์จ (strafe): ครบ 45 เฟรม ตัวละครกะพริบสว่าง ปล่อยแล้วยิง **ลูกใหญ่** | 8×8 เหลือง / ลูกใหญ่ 16×16 ส้ม | 2 / ลูกใหญ่ 4 |

- **ฟันได้ทุกร่าง**: ร่าง 2–4 กด Space ตอนมีมอนหรือบอสอยู่ในกล่องหน้าตัว = ฟัน (ดาเมจของร่าง) แทนยิง/ชาร์จ
- ลูกใหญ่: ทะลุมอน (โดนแต่ละตัว/บอสครั้งเดียว), หยุดที่กำแพงและประตูปิด, ทำลายกระสุนศัตรูที่โดน, บนจอได้ทีละลูก · ปล่อยก่อน 45 เฟรม = ไม่มีลูกใหญ่ (ได้แค่นัดเร็วตอนกด) · ร่าง 4 ไม่ยิงซ้ำอัตโนมัติ
- **กระสุนชนกัน**: กระสุนผู้เล่นโดนกระสุนศัตรู = หายทั้งคู่ (ยกเว้นลูกใหญ่ ไปต่อ)
- กระสุนผู้เล่นมี 6 slot (กระจาย 2 ชุดพอดี) · ทแยงตรวจ tile ปลายทาง + ช่องที่ขยับแกน x (ไม่ลอดมุมกำแพง)
- ค่าทั้งหมดใน `rtl/params.vh` (`SPREAD_*`, `TAP_*`, `CHARGE_FRAMES`, `BIG_*`) · SW15 sprint +1 px/เฟรม ใช้ได้ทุกร่างเหมือนเดิม (LED14)
- **Sokoban ล็อกเมื่อแก้สำเร็จ**: gate เปิดแล้วกล่องดันไม่ได้อีก (เป็นกำแพง), SW13 ไม่ทำอะไร; ทางจาก gate กลับประตูออกยังเปิด (ผ่านช่อง (7, 9) ระหว่างแผ่น)

## บอส ฉากหนี ไมค์ (P5)

| บอส | ชั้น | HP | เคลื่อนที่ | โจมตี |
| --- | --- | --- | --- | --- |
| 1 | 1 | 10 | ไล่ช้า 1 px ทุก 2 เฟรม | ชนตัวอย่างเดียว |
| 2 | 2 | 16 | เด้งทแยง 2 px/เฟรม ในวงรั้ว `F` | ยิง 4 ทิศทุก 120 เฟรม · **ตบมือ = มึน 2 วิ** แล้ว cooldown 5 วิ |
| 3 | 3 | 24 | ไล่เร็ว 2 px/เฟรม | ยิง 4 ทิศทุก 60 เฟรม |

- sprite 64×64, ชนตัว = HP −1, โดนกระสุน/ฟันแล้วกะพริบ, กระสุนผู้เล่นผ่านรั้ว `F` (ร่าง 2–4 ยิงบอส 2 ข้ามรั้วได้) · ค่าทั้งหมดอยู่ใน `rtl/params.vh`
- เข้าห้องบอสตอนบอสยังอยู่ = ประตูปิด ออกไม่ได้จนบอสตาย (หรือผู้เล่นตาย) · บอสที่ตายแล้วตายถาวรจนเริ่มเกมใหม่
- บอส 1, 2 ตาย → FLOOR CLEAR 2 วิ → ชั้นถัดไป · บอส 3 ตาย → **ESCAPE**: 30 วิ วิ่งกลับ ห้องบอส → C1 → START → ประตู `E` (ต้องร่าง 4 จากไอเทมชั้น 3) = WIN, หมดเวลา = GAME OVER
- ไมค์บอร์ด: `M_CLK` J5 (2.5 MHz), `M_DATA` H5, `M_LRSEL` F5 (= 0, อ่านขอบขาขึ้น) · นับ bit 1 ทุก 4096 sample, |ones − 2048| > `MIC_TH` (600) = ตบมือ แล้วไม่สน 200 ms (`rtl/pdm_mic.v`) — ยังไม่ได้ลองกับไมค์จริง
- ชื่อเกม (ตอนนี้ `DUNGEON`) แก้ที่ `GAME_NAME` ใน `scripts/make_font.py` ที่เดียว แล้วรันสคริปต์ใหม่

## โครงสร้าง

```
rtl/          Verilog
  params.vh     ค่าเกม tentative ทั้งหมด (`include ใน game_fsm / player / objects)
  top.v         ต่อทุก module + input/จอ/LED
  world.v       ห้อง: floor, room, grid, ตารางประตู + จุดเกิด, load player
  game_fsm.v    TITLE/PLAY/EVOLVE/FLOOR_CLEAR/ESCAPE/WIN/GAME_OVER, ร่าง, HP, timer, sprint
  objects.v     slot มอน 6 / กระสุนผู้เล่น 2 / กระสุนศัตรู 16 / บอส 1, spawn, โจมตี, AABB, โดนตี, ห้องล็อก
  boss.v        บอส 3 ตัว + boss_rom (ค่าต่อตัว), เดิน ยิง มึน HP bar
  pdm_mic.v     ไมค์ PDM -> clap_pulse
  text_layout.vh ตำแหน่งข้อความบนจอ (สร้างโดย make_font.py)
  objline.v     ชั้นภาพ object แบบ line buffer สองชุด (วาดบรรทัดถัดไประหว่างบรรทัดนี้) รวมของในห้องปริศนา
  puzzles.v     Light Bulb, Sokoban (ดันกล่อง), Simon, ไอเทม -> has_item / got_item
  puzzle_layout.vh  ตำแหน่งคันโยก หลอด กล่อง แผ่น gate ไอเทม (สร้างจาก maps/ โดย build_maps.py)
  vga_sync.v    VGA timing, frame_tick
  renderer.v    pipeline 3 clock: tile < object < ผู้เล่น + หน้า TITLE / GAME OVER / WIN
  player.v      Movement FSM + collision + ประตู + knockback
  roms.v        tilemap / tileset / player / monster / bullet / effect / puzzle / spawn ROM
  debounce.v    sync 2FF + debounce + edge
  seg7.v        7-segment 8 หลัก + จุดทศนิยม
maps/         แมพ ASCII 20×15 ทั้ง 13 ห้อง (แก้ที่นี่)
mem/          ไฟล์ .mem ที่สร้างจากสคริปต์ (อย่าแก้มือ)
scripts/
  build_maps.py        maps/*.txt → mem/tilemap.mem + mem/objects.txt + mem/monsters.mem + rtl/puzzle_layout.vh
  make_placeholders.py สร้าง sprite placeholder → mem/tileset.mem, player.mem, monster.mem, bullet.mem, effect.mem, puzzle.mem
  solve_sokoban.py     BFS หาคำตอบห้อง Sokoban (ดันน้อยสุด), --vh เขียน sim/sokoban_solution.vh ให้ testbench
  make_floor2_script.py สร้างสคริปต์ Verilator ชั้น 2 จากคำตอบ solver
  create_project.tcl   สร้าง Vivado project
  run_sim.sh           simulation ด้วย Icarus Verilog
sim/          testbench + ภาพจาก simulation
constraints/  .xdc
docs/         ภาพ preview ของ placeholder + ภาพจาก simulation (p2_*, p3_*, p4_*)
  PROGRESS.md   checklist ความคืบหน้า P0–P7 / sprite / asset (อัปเดตทุกครั้งที่งานเสร็จ)
```

## แก้แมพ / sprite

- แก้แมพ: แก้ `maps/*.txt` แล้วรัน `python3 scripts/build_maps.py` (สัญลักษณ์ตาม Core Mechanics Bible, แผ่น Simon ใช้ `q w e r`)
- เปลี่ยน sprite จริง: ใช้ sprite_tool ทำ `.mem` แล้ววางทับ `mem/tileset.mem` / `mem/player.mem` ขนาดและลำดับเฟรมต้องเหมือนเดิม
  - tileset: 3 ชั้น × 16 tile, address = (ชั้น×16 + tile)×1024 + y×32 + x
  - player: เฟรม = ร่าง×12 + ทิศ×3 + ท่า (ทิศ 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา, ท่า 0 idle 1 ก้าว A 2 ก้าว B)
  - monster: 4 เฟรม 32×32 = มอน A เฟรม 0, 1 แล้วมอน B เฟรม 0, 1 · bullet: 2 เฟรม 8×8 (ผู้เล่น, ศัตรู) · effect: ฟันประชิด 4 ทิศ 32×32
  - puzzle: 10 เฟรม 32×32 = หลอดดับ, หลอดติด, คันโยกขึ้น, คันโยกลง, กล่อง, gate ปิด, gate เปิด, ไอเทม 1, 2, 3 (tile 11 ของ tileset = กล่องบนแผ่น)
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
| C | ตบมือจำลอง (ไมค์ดัง 100 ms → `clap_pulse`; ชื่อหน้าต่างขึ้น `CLAP`, บอส 2 มึนขึ้น `STUN`) |
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

ข้อแตกต่างจากบอร์ดจริง: simulator ตั้ง `CE_DIV=1` (pixel clock ทุก clock เพื่อให้เร็วขึ้น 4 เท่า) และ debounce สั้นลง ส่วน logic เกมเหมือนบอร์ดทุกอย่าง ความเร็วขึ้นกับเครื่อง (WSL2 ~16–21 fps) ถ้าช้ากว่า 60 fps เกมจะดูช้าลงตาม แต่ไม่ผิด

ตัวเลือก build (ใน `sim/verilator`):

| คำสั่ง | ทำอะไร |
| --- | --- |
| `make` / `make run` | build ปกติ: ปริศนาสุ่มทุกเกม, eval ครั้งเดียวต่อ clock + PGO (g++) → `obj_dir/Vtop` |
| `make seeded` | build seed คงที่ (`SEED=0x1234`) → `obj_dir_seeded/Vtop` สำหรับสคริปต์ใน `sim/verilator/scripts/` (หลอด 1010, Simon w q q e q ทุกครั้ง) |
| `make SEED=0x5678` | seed อื่น (ใช้ `obj_dir_seeded/` เหมือนกัน) |
| `make PGO=0` | ไม่ทำ PGO: build เร็วกว่า ~2 เท่า แต่ sim ช้ากว่า ~10% |
| `make FAST_CLOCK=0` | กลับไป eval 2 ครั้งต่อ clock (ถ้า Verilator รุ่นอื่น build ไม่ผ่าน เพราะใช้ชื่อตัวแปรภายในของ Verilator 5.x) |

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
./scripts/run_sim.sh puzzles  # ปริศนา 3 ห้อง + ดันกล่อง (เล่นตามคำตอบ solver เป็นการกดปุ่ม) + ไอเทม + ค้างสถานะ + restart
./scripts/run_sim.sh debug    # parameter DEBUG: สวิตช์ debug ใช้ได้เฉพาะ DEBUG = 1
./scripts/run_sim.sh top      # จำลองทั้งระบบ ได้ภาพ sim/frame_*.ppm
./scripts/run_sim.sh all      # รันทั้งหมดข้างบน
```
ต้องมี Icarus Verilog (`sudo apt install iverilog` หรือ `brew install icarus-verilog`) ภาพตัวอย่างอยู่ใน `sim/*.png`, `docs/p2_*.png`, `docs/p3_*.png`, `docs/p4_*.png`

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

สคริปต์อยู่ใน `sim/verilator/scripts/` (ไฟล์ข้อความ: บรรทัดละรายการ `ปุ่ม:เฟรมเริ่ม:เฟรมจบ`, `#` = คอมเมนต์; ปุ่ม `U D L R C`, สวิตช์ `0-9 a-f`, `K` = ตบมือ)
**ทุกสคริปต์ต้องใช้ build แบบ seeded** (บอกไว้ที่หัวไฟล์):
```
cd sim/verilator && make seeded && cd ../../mem
../sim/verilator/obj_dir_seeded/Vtop --script-file ../sim/verilator/scripts/full_game.txt      # ดูในหน้าต่าง
SDL_VIDEODRIVER=dummy LOG=50 ../sim/verilator/obj_dir_seeded/Vtop --frames 1900 --script-file ../sim/verilator/scripts/floor1.txt
./scripts/run_full_game.sh            # (จาก root) เล่นเต็มเกมแบบไม่เปิดหน้าต่าง ผ่านเมื่อจบที่ WIN (~10 นาที)
SHOTS=1 ./scripts/run_full_game.sh    # + บันทึกภาพ docs/p5_*.png
```

| สคริปต์ | เฟรม | ทำอะไร |
| --- | --- | --- |
| `full_game.txt` | ~9800 | TITLE → ชั้น 1 (Light Bulb, บอส 1) → ชั้น 2 (Sokoban, บอส 2 + ตบมือ 2 ครั้ง) → ชั้น 3 (Simon, บอส 3) → ESCAPE → E → WIN · ไม่ใช้ SW1 / SW3 |
| `floor1.txt` | ~2100 | START → C1 → C2 → Light Bulb (ตีคันโยก b, d) → ไอเทม 1 → EVOLVE → กลับ C2 → C1 → ประตู L → ห้องบอส |
| `floor2.txt` | ~2400 | ข้ามชั้นด้วย SW1 → C1 → C2 → Sokoban เล่นตามคำตอบ solver 24 ครั้ง → gate เปิด → ไอเทม 2 (สร้างด้วย `scripts/make_floor2_script.py`) |
| `floor3.txt` | ~2900 | ข้าม 2 ชั้น + SW3 เป็นร่าง 3 (บินข้ามหลุม) → C1 → C2 → Simon 3 รอบ → ไอเทม 3 |

ห้อง Combat ในสคริปต์เหล่านี้เคลียร์ด้วย SW2 (DEBUG) ให้สั้น (บอสสู้จริง) · build seeded ทำให้รูปแบบหลอด / ลำดับ Simon มาจาก `SEED` อย่างเดียว ไม่ขึ้นกับเวลาที่เข้าห้อง จึงไม่พังเมื่อแก้ RTL ที่ไม่เกี่ยวกับการเดิน
`LOG=N` พิมพ์สถานะทุก N เฟรม (ห้อง, ตำแหน่ง, HP, ร่าง, หลอด, Simon, บอส `boss/bhp/bx/by/stun`, ESCAPE `esc`)

## ขั้นต่อไป (ตามแผน Implement)

- P6 เสียง (SFX + BGM, โน้ต Simon) + sprite จริง + เล่นทดสอบ · ลงบอร์ดจริง (Vivado build + timing)
- งานคู่ขนาน: sprite จริง, ทดสอบไมค์ PDM
