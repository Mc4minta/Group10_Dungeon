# Group10_Dungeon — THE CHOSEN ONE (ชื่อเกมบนจอ; โฟลเดอร์ = Group10_Dungeon)

เกม dungeon crawler + ห้องปริศนา บน Digilent Nexys A7-100T, VGA 640×480 @ 60 Hz, Verilog (Vivado 2024.2)
เอกสารนี้อัปเดตจากโค้ดจริง 23/11/2026 (branch `dev` = `main` ที่ commit `3e908a3`) — รายงานการอัปเดตเอกสาร: `docs/DOC_UPDATE_REPORT.md`

คำศัพท์สถานะ: **sim** = ตรวจด้วย testbench / script แล้ว · **board** = ลองบนบอร์ด Nexys A7 จริงแล้ว · **board: not tested** = ยังไม่ได้ลอง

## สถานะปัจจุบัน (Current status) — อ่านก่อน

เกมเล่นได้ครบตั้งแต่ TITLE ถึง WIN **ใน simulation (sim)** — ส่วนที่ยืนยันบนบอร์ดจริง (board) มีเท่าที่บันทึกไว้ใน `docs/BOARD_TEST_STEPS.md`: **คีย์บอร์ด USB ใช้ได้** (บันทึกของเจ้าของโปรเจกต์ 20-21/11) ส่วนอื่นทั้งหมด **board: not tested**

สิ่งที่มีในเกม (รายละเอียด `docs/FEATURES.md`, วิธีเล่น `docs/CONTROLS.md`):

* **State ของเกม** (`rtl/game_fsm.v`): TITLE → PROLOGUE (4 หน้าจอดำ, BTNC = หน้าถัดไป หรือ 6 วิ/หน้า) → PLAY → EVOLVE (60 เฟรม) → FLOOR_CLEAR (120 เฟรม) → … → ESCAPE (= Ball in a Maze 60 วิ, เอียงบอร์ด ADXL362 หรือปุ่ม) → WIN · ตายหรือหมดเวลา = GAME_OVER (BTNC = retry ชั้นที่ตาย, BTNL = TITLE) · **PAUSE ไม่ใช่ state**: SW15 หรือคีย์ P/Esc ตัด frame tick ตอน PLAY/ESCAPE
* **แผนที่:** 3 ชั้น × 5 บทบาทห้อง (START, Combat 1, Combat 2, Puzzle, Boss) = **15 ห้องที่เดินผ่านจริง** ใช้แมพ ASCII **13 ไฟล์** (`maps/00..12`; START ชั้น 1+2 ใช้แมพเดียวกัน และ BOSS ชั้น 1+3 ใช้แมพเดียวกัน)
* **4 ร่าง** (ฟัน / ยิง / กระจาย 3 ทาง+แตก / ยิงเร็ว+ชาร์จลูกใหญ่), auto aim (เปิดเป็นค่าเริ่มต้น), กับดักหนามตั้งเวลา, กล่องพังได้, หลุม, hint strip + tutorial, กล่องเรื่องราวที่หยุดเกม, หน้า title (SETTINGS / CONTROLS / CREDITS)
* **บอส 3 ตัว พร้อมเฟส 2 ("rage" ที่ HP ต่ำ):** บอส 1 (HP 10, ตบมือ/SW11/คีย์ C = มึน 3 วิ), บอส 2 (HP 16, อยู่กลางกรอบรั้ว เรียกลูกน้อง ตีได้เมื่อลูกน้องตายหมด), บอส 3 (HP 9, เกราะ: เจ็บเฉพาะลูกชาร์จ ร่าง 4 ยกเว้นตอนพัก, ชาร์จ 4 วิ แล้วพายุกระสุน 2 วิ) — บอส 3 ตาย = ได้กุญแจ → ประตู E ที่ START ชั้น 3 → ESCAPE
* **อินพุต:** ปุ่ม/สวิตช์บนบอร์ด **และ** คีย์บอร์ด USB (PS/2 ผ่าน USB-HID) พร้อมกันได้ · ไมค์ PDM (ตบมือ) · accelerometer ADXL362 (เขาวงกต)
* **เสียง:** SFX 13 แบบ + โน้ต Simon + BGM (ชั้น 1-3 ใช้ track 6 เดียวกัน, ESCAPE, jingle WIN / GAME OVER) — ออก `AUD_PWM`; **board: not tested** (ระดับ `AUD_SD` ยังไม่ยืนยันกับ manual)
* **Build จริง:** local Vivado run 22/11/2026 (`vivado/` ถูก git-ignore, ไม่อยู่ใน git) รายงาน: Block RAM Tile **103.5 / 135**, Slice LUT 18,182 / 63,400, **WNS −4.045 ns (timing ไม่ผ่านที่ 100 MHz, 1853 endpoint ล้มเหลว)** ดู "Known gaps" — ไม่ทราบว่า run นั้นมาจาก commit ไหน

**Branch:** `main` และ `dev` = commit เดียวกัน (`3e908a3`) · งานใหม่ลง `dev` ก่อน, `main` เมื่อเจ้าของสั่ง "merge" · tag `board-test-2` = build บอร์ดรุ่นเก่า

## Known gaps (สิ่งที่ยังไม่ทำ / ยังไม่ยืนยัน)

1. **ยังไม่ได้ทดสอบบนบอร์ด** ยกเว้นคีย์บอร์ด USB: จอ/ภาพไม่เลื่อน, เสียง, ไมค์ (ตบมือ), เขาวงกตเอียงบอร์ด (ทิศแกน), ปุ่ม/สวิตช์ทั้งหมดหลัง W19 — รายการเช็คที่ `docs/BOARD_TEST_STEPS.md` (ข้อ 6b–6f, 7)
2. **Timing ไม่ผ่านใน run ล่าสุดที่มีไฟล์ในเครื่อง:** `vivado/Group10_Dungeon.runs/impl_1/top_timing_summary_routed.rpt` (22/11) WNS −4.045 ns, TNS −2904.290 ns; path แย่สุด `pz/b0x_reg[1]` → `rnd/a_bb_reg[11]` (ที่อยู่ข้อความใน `renderer.v`) · ไฟล์นี้ไม่อยู่ใน git จึงต้อง run ใหม่หลังแก้ ยังไม่มีการแก้ timing
3. `tb_puzzles`: เอกสารเก่าบันทึกว่าเช็ค lever-XOR ล้ม แต่รันซ้ำ 23/11 (Icarus 13.0, WSL) ได้ 42 checks, errors = 0 และบรรทัด "16 lever subsets give 16 different XOR results" = PASS — ปัจจุบัน **ไม่ล้ม** (sim)
4. `DEBUG` ใน `rtl/top.v` ค่าเริ่มต้น = **1** (สวิตช์ SW0–SW4 โกงได้) — **build ส่งงานต้องตั้ง `DEBUG = 0`** ตอนนี้ `create_project.tcl` ไม่ได้ตั้ง generic ให้
5. Verilator `sim/verilator/Makefile` ส่ง `-GPROLOGUE=$(PROLOGUE_V)` แต่ไม่เคยนิยาม `PROLOGUE_V` (ค่าว่าง) และ `sim/verilator/scripts/full_game.txt` เขียนไว้สำหรับ `PROLOGUE=0` — ดู "Needs a human decision" ใน `docs/DOC_UPDATE_REPORT.md`; รัน full game ล่าสุดเต็มเกม (WIN) ยังไม่ได้รันซ้ำบนโค้ดล่าสุดในรอบเอกสารนี้
6. เนื้อเรื่อง/เครดิตบนจอเป็น placeholder บางส่วน; art ที่ยังไม่ final ดู `docs/SPRITE_STATUS.md`; wall variants / sample playback ไม่ได้ทำ (planned)
7. ภาพ `docs/*.png` ส่วนใหญ่ถ่ายก่อนงาน W19–W46 (เช่น `p5_*.png`, `p4_*.png`) อาจไม่ตรงกับหน้าตาเกมปัจจุบัน — ไม่ได้สร้างใหม่
8. เพลง "Connect" เป็นเพลงมีลิขสิทธิ์ (melody อยู่ใน `mem/music.mem`, `sprites/music/connect.txt`) — เช็คความเป็น public ของ repo ก่อนแชร์

## Quick start for the art / map / sound pipelines (English)

The sprites, tiles, enemies, bosses, puzzle objects, maps and music are generated from files you edit (`my_asset/`, `my_audio/` (not committed), `sprites/*.json`, `maps/*.txt`).
**Start with `docs/README.md`** (index, folder map, workflow, branches). Handy commands:

| What | Command |
|---|---|
| Rebuild all art + previews | `scripts/update_sprites.sh` (Windows: `scripts\update_sprites.bat`) |
| Check everything before a commit | `scripts/check_all.sh` (`--fast` = no iverilog suite) |
| Build and test on the board | `docs/BOARD_TEST_STEPS.md`, `docs/BOARD_DAY.md` |
| Which sprites are final / still needed | `docs/SPRITE_STATUS.md` |
| Sounds and music | `docs/SOUND_PLAN.md` |
| What to do next | `docs/NEXT_STEPS.md` |

## เริ่มใช้ (build ลงบอร์ด)

1. ติดตั้ง Vivado 2024.2 แล้วเปิด terminal ที่โฟลเดอร์นี้
2. สร้าง project:
   ```
   vivado -mode batch -source scripts/create_project.tcl
   ```
   หรือใน Vivado GUI: **Tools → Run Tcl Script…** เลือก `scripts/create_project.tcl`
3. เปิด `vivado/Group10_Dungeon.xpr` → Generate Bitstream → Program Device
   (หรือ build ทีเดียว: `vivado -mode batch -source scripts/create_project.tcl -tclargs build`)
4. ต่อจอ VGA, ลำโพง/หูฟังที่ช่อง AUDIO OUT แล้วเล่น
5. **ก่อน build ส่งงาน:** ตั้ง `parameter DEBUG = 0` ใน `rtl/top.v` (ค่าเริ่มต้นตอนนี้ = 1)

วันลงบอร์ด: [`docs/BOARD_DAY.md`](docs/BOARD_DAY.md) (ตัวทดสอบไมค์แยก: `scripts/create_mic_project.tcl`) · ก่อน build ครั้งแรกเทียบ pin ใน `constraints/nexys_a7.xdc` กับ Master XDC ของ Digilent อีกรอบ

## ปุ่ม / สวิตช์ / คีย์บอร์ด (ตามโค้ด `rtl/top.v`, `rtl/ps2_kbd.v`)

คู่มือผู้เล่นเต็ม: **`docs/CONTROLS.md`**

| อุปกรณ์ | คีย์บอร์ด | ทำอะไร |
| --- | --- | --- |
| BTNU/D/L/R | ลูกศร / WASD | เดิน (2 ปุ่ม = ทแยง; ทิศตรงข้ามหักล้าง) |
| BTNC | Space / J / Enter | เริ่มเกม (TITLE) · โจมตี (PLAY) · ปิดกล่องเรื่อง · WIN = กลับ TITLE · GAME OVER = retry ชั้นที่ตาย |
| BTNL (ตอน GAME OVER) | ลูกศรซ้าย | กลับ TITLE |
| BTNR / BTNL (ตอน TITLE) | → / ← (D / A) | หน้าถัดไป / ก่อนหน้า: 0 TITLE, 1 SETTINGS, 2–6 CONTROLS, 7–9 CREDITS |
| BTNU / BTND (SETTINGS) | ↑ / ↓ (W / S) | ระดับเสียงตบมือ 5 ขั้น (ค่าเริ่ม MID = 448) |
| **SW15** | **P หรือ Esc** (toggle) | **PAUSE** — ใช้ได้ตอน PLAY / ESCAPE (จอ PAUSED, เสียงเงียบ) |
| **SW14** | **Shift** | **sprint** +1 px/เฟรม (`SPRINT_BONUS`), LED14 |
| SW12 | — | ล็อกทิศค้าง (strafe/ถอยโดยไม่หัน) · แตะ BTNC ล็อกทิศ 24 เฟรมอยู่แล้ว |
| SW13 (ยกขึ้น) | R | รีเซ็ตกล่อง Sokoban (ชั้น 2) |
| SW9 | L (toggle) | auto aim: **เปิดเป็นค่าเริ่มต้น**, SW9 ขึ้น / L = ปิด |
| SW10 | — | เขาวงกต: ใช้ปุ่มแทนเซนเซอร์เอียง (อัตโนมัติถ้า ADXL ไม่ตอบ) |
| SW11 (ยกขึ้น) | C | ตบมือสำรอง (stun บอส 1) |
| SW5–SW7 | — | ปรับระดับตบมือ (0 = ใช้ค่าจากหน้า SETTINGS, อื่น ๆ = 128 × ค่า 3 บิต) |
| SW8 | H (toggle) | แสดง hit box (เขียว = ฮีโร่, แดง = มอน, ส้ม = บอส, เหลือง = กระสุน) |
| CPU_RESETN | — | reset ทั้งหมด (กลับ TITLE, รีเซ็ตระดับตบมือ, intro เต็มอีกครั้ง) |
| ไมค์ PDM | — | ตบมือ = stun บอส 1 (ข้อ "ไมค์" ด้านล่าง) |
| ADXL362 | — | เอียงบอร์ด = กลิ้งลูกบอลใน ESCAPE |

สวิตช์ **debug** ทำงานเฉพาะเมื่อ `top.v` `DEBUG = 1` (**ค่าเริ่มต้น = 1** ทั้ง Vivado และ Verilator) — build ส่งงานต้องตั้ง 0:

| สวิตช์ | ทำอะไร (DEBUG = 1) |
| --- | --- |
| SW0 | เปิดประตูบอส L ทุกชั้น และประตู E (ไม่ต้องมีกุญแจ) |
| SW1 ยกขึ้น | `floor_done` → FLOOR_CLEAR · ตอน PLAY เดินเข้าประตู E ไม่มีกุญแจ = WIN ทันที |
| SW2 ยกขึ้น | ลบมอนทั้งห้อง |
| SW3 ยกขึ้น | `got_item` → EVOLVE |
| SW4 ยกขึ้น | `take_hit` → HP −1 (ไม่มี knockback) |

### ปริศนาและไอเทม

| ชั้น | ห้องปริศนา | ทำอย่างไร | ไอเทม |
| --- | --- | --- | --- |
| 1 | Light Bulb | ฟัน/ยิงคันโยก a–d (แถวล่างของห้อง) สลับหลอด 4 ดวงตาม mask a = 0111, b = 1011, c = 1101, d = 1110 (bit 3 = หลอด 1) จนติดครบ · รูปแบบเริ่มสุ่มต่อเกม (SEED = 0) | โผล่เมื่อแก้ได้ |
| 2 | Sokoban | เดินตรงชนกล่องเพื่อดัน 1 ช่อง · กล่องทับแผ่นครบ 2 = gate เปิด · ติดแล้วกด SW13 / R · คำตอบน้อยสุด 24 ครั้ง (`scripts/solve_sokoban.py`) | อยู่หลัง gate |
| 3 | Simon | ดูแผ่นสว่างตามลำดับแล้วเหยียบตาม 3 รอบ ยาว 3 / 4 / 5 · ผิด = HP −1 แล้วโชว์ใหม่ | โผล่เมื่อครบ 3 รอบ |

เดินทับไอเทม → EVOLVE (ร่างถัดไป, HP เต็ม) + ประตูบอส `L` ของชั้นนั้นเปิด (LED13) · ปริศนาที่แก้แล้วค้างไว้แม้ออกจากห้อง · เริ่มเกมใหม่จาก TITLE = รีเซ็ตทั้งหมด

### จอและ LED

| อุปกรณ์ | แสดง |
| --- | --- |
| 7-seg | `ชั้น - HP - mm.ss` (TITLE / PROLOGUE = `--------`); ESCAPE: 4 หลักขวา = นับถอยหลัง `ss.ff`; ตอน PAUSE จุดทศนิยมกะพริบ |
| LED0–3 | ปุ่มทิศ · ห้อง Light Bulb = หลอด · ห้อง Simon = รอบที่ผ่าน |
| LED4–7 | มอนที่เหลือ (bar: ≥1 … ≥4) · ห้องบอส: LED0–7 = HP บอส (8 ดวงตามสัดส่วน) |
| LED8–11 | HP (หนึ่งดวงต่อ HP; max 4 ทุกร่าง) |
| LED12 / 13 | ประตูห้องล็อก / มีไอเทมชั้นนี้ |
| LED14 / 15 | sprint (SW14) / WIN |
| ESCAPE | LED ทั้ง 16 ดวงกะพริบ 4 Hz |
| RGB LED16 | สีร่าง เขียว / ฟ้า / ม่วง / ทอง · ขาวตอน EVOLVE |
| RGB LED17 | แดง = โดนตี (knockback + อมตะ) · **น้ำเงิน** กะพริบ = สาย PS2_CLK ขยับ, **เขียว** กะพริบ = ถอดรหัส byte คีย์บอร์ดได้ (ไว้เช็คคีย์บอร์ด) |
| จอ VGA | หัวใจผู้เล่น (ซ้ายบน, 4 ดวง), แถบ HP บอส (ขวาบน, ห้องบอส) + แถบชาร์จบอส 3 + มิเตอร์ไมค์ (บอส 1 / หน้า SETTINGS) |

### ค่าต่อร่าง (`rtl/params.vh`)

| ร่าง | ความเร็ว px/เฟรม | Max HP | ดาเมจ | RGB16 | อาวุธ |
| --- | --- | --- | --- | --- | --- |
| 1 Human | 2 | 4 | 1 | เขียว | ฟันประชิด |
| 2 Orc | 2 | 4 | 1 | ฟ้า | ยิง 1 นัด |
| 3 Angel | 3 | 4 | 2 | ม่วง | ยิงกระจาย 3 ทาง (นัดที่โดนมอนแตกเป็น 4) |
| 4 Gold | 3 | 4 | 2 | ทอง | นัดเร็ว / ค้าง 45 เฟรม = ลูกใหญ่ (ดาเมจ 4) |

sprint +1 px/เฟรมทุกร่าง · อมตะหลังโดนตี `INV_FRAMES` = 90 เฟรม (knockback 8 เฟรม × 2 px ก่อน) · hurt box 16×16 (`HURT_BOX`)

### การต่อสู้

| อย่าง | ค่า (`params.vh`) |
| --- | --- |
| ฟัน | hit box 24×16 หน้าตัว 8 เฟรม, cooldown 20 · ทุกร่างฟันได้เมื่อศัตรูอยู่ในกล่องหน้าตัว |
| ยิงร่าง 2 | 8×8, 4 px/เฟรม, cooldown 15 (กดค้างยิงซ้ำ) |
| กระจายร่าง 3 | 3 นัด (ตรง + ทแยง 3 px/แกน), cooldown 20, ลูกที่แตก 24 เฟรม |
| ร่าง 4 | แตะ = 6 px/เฟรม cooldown 15 · ค้าง 45 เฟรม ปล่อย = ลูกใหญ่ 16×16, 4 px/เฟรม, ดาเมจ 4, หยุดเมื่อโดน; มีลูกบอลโตหน้าตัวระหว่างชาร์จ |
| มอน A (`S`) | HP 2, เดินทุก 2 เฟรม (ครึ่งความเร็ว) ไถลตามกำแพง |
| มอน B (`T`, ป้อม) | HP 3, ยิง 4 ทิศ + 1 นัดเล็งผู้เล่น ทุก 120 เฟรม (ครั้งแรก 60, ตัวถัดไปเหลื่อม 30), กระสุน 3 px/เฟรม |
| Combat room | เข้าแล้วประตูปิดจนมอนตายหมด; ห้อง 4, 5, 8 มี 2 wave, ห้อง 10, 11 มี 3 wave (wave ถัดไปโผล่ 1 วิหลังตัวสุดท้ายตาย), ห้อง 7 wave เดียว |
| กับดัก | ชั้น 2: หนามตั้งเวลา 90 ปกติ / 30 เตือน / 60 ขึ้น (ดาเมจ 2) ปลอดภัย 60 เฟรมหลังเข้าห้อง · ชั้น 3: หนามค้าง `X` (1 HP) · ร่าง 3 บินข้ามหลุม/หนาม |
| ตัวเลขทั้งหมด | `rtl/params.vh` |

### บอส (`rtl/boss.v`, `rtl/params.vh`)

| บอส | HP | เคลื่อนที่ | โจมตี | เฟส 2 (rage) |
| --- | --- | --- | --- | --- |
| 1 (ชั้น 1) | 10 | ไล่ 1 px ทุก 2 เฟรม | แพทเทิร์นกระสุนทุก 90 เฟรม (กะพริบเตือน 20 เฟรม); ตบมือ / SW11 / C = มึน 180 เฟรม แล้ว cooldown 240 | HP ≤ 5: ยิงทุก 55 เฟรม, เดินทุกเฟรม |
| 2 (ชั้น 2) | 16 | อยู่กับที่ในกรอบรั้ว | กระสุน cross / X ทุก 90 เฟรม · เรียกลูกน้อง 3 ตัวต่อรอบ · **อมตะจนลูกน้องตายหมด** แล้วตีได้ 240 เฟรม แล้วพัก 75 | HP ≤ 8: ยิงทุก 60, ตีได้ 180, พัก 45 |
| 3 (ชั้น 3) | **9** | ไล่ 1 px ทุก 2 เฟรม | เกราะ: เจ็บเฉพาะลูกชาร์จร่าง 4 (1 HP ต่อนัด); ไล่ 180 เฟรม → ชาร์จ 240 เฟรม (ลูกชาร์จขัดได้) → พายุกระสุนหนัก 120 เฟรม (2 HP ต่อนัด) → พัก 120 เฟรม (ตีแบบใดก็เจ็บ) | HP ≤ 3: ไล่ 120, พัก 90, พายุถี่ขึ้น (คาบ 18) |

บอส 3 ต้องโดน **9 ครั้ง** (HP 9 ลดทีละ 1) แถบ HP บนจอ = hp / 9 ตามสัดส่วน ไม่ใช่ 3 ช่อง · ชนตัว = HP −1 · sprite 64×64, hitbox 48×48 · เข้าห้องบอสแล้วประตูปิดจนบอสตาย · บอสที่ตายแล้วตายถาวรจนเริ่มเกมใหม่ · บอส 1, 2 ตาย → FLOOR CLEAR; บอส 3 ตาย → กุญแจที่พื้นห้อง (เดินทับเก็บ) → ประตู E → ESCAPE

### ESCAPE (Ball in a Maze) และไมค์

* ESCAPE = เขาวงกต 20×15 (`maps/maze/maze.txt` → `mem/maze.mem`), 60 วิ (`ESCAPE_SECONDS`), ถึงเส้นชัย = WIN, หมดเวลา = GAME OVER · เซนเซอร์ ADXL362 ผ่าน SPI (deadzone 3, `MAZE_SIGN_X/Y` = 0 หลังพลิกแกน W37) — **ทิศแกนบนบอร์ดยังไม่ยืนยัน (board: not tested)**
* ไมค์ PDM: `M_CLK` 2.5 MHz, นับทุก 4096 sample, ตรวจ peak ของ |block − DC| (W4) > `MIC_TH` = **448** (ปรับได้จากหน้า SETTINGS 192 / 320 / 448 / 704 / 1024 หรือ SW5–SW7) แล้ว holdoff 200 ms · clap = **stun บอส 1** (ไม่ใช่บอส 2) · **board: not tested**
* ชื่อเกมบนจอ แก้ที่ `docs/STORY.md` แล้วรัน `python scripts/build_story.py` (ฟอนต์/ข้อความสร้างโดย `scripts/make_font.py`)

## เสียง

- `AUD_PWM` ส่ง PWM 8 bit (carrier 100 MHz / 256) · `AUD_SD` ขับ 1 = เปิดแอมป์ (`AUD_SD_ON`; **ยังไม่ยืนยันกับ manual / board: not tested**)
- `rtl/audio.v`: SFX ทีละเสียงมี priority (เลขน้อยสำคัญกว่า; ที่ต่ำกว่าระหว่างเล่นอยู่ถูกทิ้ง) + BGM เบากว่า (SFX ±48, BGM ±18)

| # | เหตุการณ์ | ความถี่ | ยาว (เฟรม) |
| --- | --- | --- | --- |
| 1 | ผู้เล่นโดนตี | 330 → 110 Hz | 18 |
| 2 | บอส 1 มึน (ตบมือ) | 1200 → 600 Hz | 24 |
| 3 | มอน / บอสตาย | 500 → 120 Hz | 14 |
| 4 | เก็บไอเทม / evolve | 800 → 2000 Hz | 28 |
| 5 | ห้องเคลียร์ / gate เปิด | 600 → 1000 Hz | 20 |
| 6 | ปริศนาผิด | 200 → 170 Hz | 24 |
| 7 | ปริศนาถูก | 1500 Hz | 5 |
| 8 | ศัตรูโดนตี | 900 → 700 Hz | 4 |
| 9 | ยิง (ร่าง 2 / กระจาย / นัดเร็ว / ลูกใหญ่) | 1800→1200 / 1400→1000 / 2400→1600 / 600→250 Hz | 5 / 6 / 4 / 16 |
| 10 | ฟันประชิด | 450 → 250 Hz | 7 |
| 11 | บอสปรากฏ | 250 → 204 Hz | 30 |
| 12 | ผ่านประตู | 1000 Hz | 4 |
| 13 | บอส 3 ชาร์จ (บี๊บทุกขั้น) | 600 → ~1000 Hz | 12 |
| — | โน้ต Simon | C5 E5 G5 C6 (523 / 659 / 784 / 1047 Hz) ทับ SFX ตลอดที่แผ่นสว่าง | ตามแผ่น |

- **BGM** (`mem/music.mem` จาก `scripts/make_music.py`, ตั้งค่า `sprites/music.json`): ชั้น 1–3 ใช้ track 6 เดียวกัน (ทำนอง Connect) · ESCAPE track 3 (วน) · WIN track 4, GAME OVER track 5 (เล่นครั้งเดียว) · TITLE / PROLOGUE เงียบ
- เสียงใน Verilator: เล่นสดผ่าน SDL ที่ 12,207 Hz (ช้ากว่าจริง 4 เท่า) · `AUDIO_RATE=<Hz>`, `NOAUDIO=1`, คีย์ **M** = ปิด/เปิด · บันทึก `--wav out.wav` / `--wav-seg A:B:out.wav` · ตัวอย่างใน `docs/audio/`

## โครงสร้างโฟลเดอร์

```
rtl/            Verilog (+ *.vh)  [*_cfg.vh, puzzle_layout.vh, text_layout.vh, text_select.vh, tilebase.vh สร้างโดยสคริปต์ — ไม่แก้มือ]
  top.v           ต่อทุก module: input, pause, 7-seg, LED, เสียง, tutorial/hint, dialogue event
  params.vh       ค่าเกมทั้งหมด (`include ใน module)
  game_fsm.v      state TITLE/PROLOGUE/PLAY/EVOLVE/FLOOR_CLEAR/ESCAPE/WIN/GAME_OVER, ร่าง, HP, timer
  world.v         floor / room / grid / ประตู / จุดเกิด · player.v movement+collision+knockback · player_frame.v เลือก animation · face_lock.v
  objects.v       มอน 6 / กระสุนผู้เล่น 6 / กระสุนศัตรู 16 / บอส, AABB, wave, ห้องล็อก, auto aim
  boss.v          บอส 3 ตัว (boss_rom + FSM, rage) · keyitem.v กุญแจ · maze.v + adxl362.v เขาวงกต
  puzzles.v       Light Bulb / Sokoban / Simon + ไอเทม · overlay.v สถานะกล่องพังได้
  renderer.v      pipeline 4 clock · objline.v line buffer วัตถุ · hud.v หัวใจ/แถบบอส/มิเตอร์ · roms.v ROM ทั้งหมด · vga_sync.v
  dialog.v        กล่องเรื่อง + hint strip · dlg_cfg.vh, text_*.vh (สร้างจาก docs/STORY.md)
  audio.v         PWM, SFX 13, BGM · pdm_mic.v ไมค์ · ps2_kbd.v คีย์บอร์ด · debounce.v · seg7.v · bin2bcd.v
  mic_test_top.v  ตัวทดสอบไมค์แยก (docs/BOARD_DAY.md)
constraints/    nexys_a7.xdc, mic_test.xdc
maps/           แมพ ASCII 20×15 จำนวน 13 ไฟล์ + maps/maze/maze.txt (แก้ที่นี่) · maps_v1/ = ต้นฉบับ
mem/            ไฟล์ .mem / objects.txt ที่สร้างจากสคริปต์ (ไม่แก้มือ) · *_v1.mem = ต้นฉบับ
sprites/        ค่าตั้ง JSON ของ art/เพลง (sprites.json, tileset.json, monsters.json, bosses.json, puzzle.json, hud.json, overlay.json, music.json, music/) + README.md
my_asset/       art ต้นฉบับ · my_audio/ เสียงต้นฉบับ (ไม่ commit)
scripts/        build_*_mem.py, build_maps.py, build_story.py, make_*.py, audio_to_music.py, solve_sokoban.py, update_sprites.*,
                check_all.sh/.bat, run_sim.sh, run_full_game.sh, run_sprite_shots.sh, make_shots.sh, create_project.tcl, create_mic_project.tcl,
                vivado_synth.tcl, vivado_update_project.tcl
tests/          Python tests (test_*.py 10 ไฟล์) + fallback_drill.sh
sim/            testbench tb_*.v (iverilog), sim/verilator (Makefile, main.cpp, scripts/*.txt), sim/anim_on/, sim/vig.vh, sokoban_solution.vh
report_shots/   (untracked) สคริปต์ WSL ถ่ายภาพ Verilator: env.sh, _build.sh, run.sh, convert.py, scripts/t1.txt
preview/        ภาพ preview ที่สร้าง (git-ignore ยกเว้น layout_guide.png)
docs/           เอกสาร (ดู docs/README.md) + ภาพ *.png + docs/audio/*.wav + docs/archive/
vivado/         Vivado project (git-ignore, สร้างด้วย create_project.tcl)
```

## แก้แมพ / sprite

- แก้แมพ: แก้ `maps/*.txt` แล้วรัน `python3 scripts/build_maps.py` (สร้าง `mem/tilemap.mem`, `monsters.mem`, `objects.txt`, `overlay.mem`, `rtl/puzzle_layout.vh`) — รายละเอียด `docs/MAP_DESIGN.md`
- art ทั้งหมด: แก้ `my_asset/` + `sprites/*.json` แล้วรัน `scripts/update_sprites.sh` · อ่าน `sprites/README.md`
- ข้อความบนจอ: แก้ `docs/STORY.md` แล้ว `python scripts/build_story.py`
- แก้ไฟล์ .mem แล้วใน Vivado ต้อง re-run synthesis · ก่อน commit รัน `scripts/check_all.sh`

## เล่นบนจอคอม (ไม่ต้องมีบอร์ด) — Verilator + SDL2

Verilator แปลง Verilog ชุดเดียวกับบอร์ดเป็นโปรแกรม แสดง VGA ในหน้าต่าง SDL2 + แผง 7-seg / LED / สวิตช์ (Verilator 5.x; ทดสอบกับ 5.054 ใน conda env `dungeon` บน WSL ดู `report_shots/env.sh`)

```
cd sim/verilator
make run        # build + เปิดหน้าต่าง
```

> **ข้อควรระวัง:** `Makefile` ปัจจุบันส่ง `-GPROLOGUE=$(PROLOGUE_V)` โดย `PROLOGUE_V` ไม่ถูกนิยาม (ค่าว่าง) — ยังไม่ได้ยืนยันว่า `make run` / `make seeded` เปล่า ๆ build ผ่านหรือไม่ · วิธีที่น่าจะใช้ได้ (**ไม่ได้รัน**): `make seeded PROLOGUE_V=0` (สำหรับสคริปต์ `scripts/*.txt` ซึ่งเขียนไว้สำหรับไม่มีหน้า PROLOGUE) หรือ `PROLOGUE_V=1` สำหรับเล่นปกติ · binary seeded ในเครื่องนี้ build ด้วย `report_shots/_build.sh` (`-GPROLOGUE=0`)

| คีย์ใน simulator | เทียบบอร์ด |
| --- | --- |
| ลูกศร | BTNU / BTND / BTNL / BTNR |
| Space | BTNC |
| 0–9 | สลับ SW0–SW9 |
| F1–F6 | สลับ SW10–SW15 (F5 = SW14 sprint, F6 = SW15 pause) |
| Backspace | CPU_RESETN |
| C | ตบมือจำลอง 100 ms |
| M | ปิด/เปิดเสียง |
| [ / ] | ลด / เพิ่ม frame skip |
| Esc | ออก |

(Verilator ไม่มีโมเดลคีย์บอร์ด PS/2 — คีย์ P / L / H / R / WASD ใช้ได้เฉพาะบนบอร์ดและใน `tb_ps2`)

Windows: ใช้ WSL2 + Ubuntu / Kali (`sudo apt install -y build-essential verilator libsdl2-dev`; Verilator ต้องเป็น 5.x — apt ของ Ubuntu 22.04 ได้ 4.x เก่าไป) · macOS: `brew install verilator sdl2`

simulator ตั้ง `CE_DIV=1`, `DEBOUNCE=2000` (บอร์ดจริง `CE_DIV=4`, `DEBOUNCE=1_000_000` = 10 ms) ส่วน logic เหมือนบอร์ด · `DEBUG` เป็นค่าเริ่มต้น (=1)

ตัวเลือก build (`sim/verilator`): `make` / `make run` (PGO g++, ปริศนาสุ่ม → `obj_dir/Vtop`) · `make seeded` (SEED=0x1234 → `obj_dir_seeded/Vtop`) · `make SEED=0x5678` · `make PGO=0` · `make FAST_CLOCK=0`

ทดสอบไม่เปิดหน้าต่าง:
```
cd mem && SDL_VIDEODRIVER=dummy ../sim/verilator/obj_dir/Vtop --frames 300 --script "R:5:200,C:60:62" --shot shot.bmp
```
ตัวเลือก `Vtop`: `--frames N`, `--shot f.bmp`, `--shot-at N:f.bmp`, `--script "..."` / `--script-file f`, `--wav f`, `--wav-seg A:B:f`, `--headless`, env `LOG=N` (พิมพ์สถานะทุก N เฟรม), `HEADLESS=1`, `AUDIO_RATE`, `NOAUDIO` · รูปแบบสคริปต์: `ปุ่ม:เฟรมเริ่ม:เฟรมจบ` (ปุ่ม `U D L R C`, สวิตช์ `0-9 a-f` = SW0–SW15, `K` = ตบมือ, `#` = คอมเมนต์)

สคริปต์ใน `sim/verilator/scripts/` (**ต้องใช้ build แบบ seeded** และเขียนไว้สำหรับไม่มีหน้า PROLOGUE):

| สคริปต์ | ทำอะไร |
| --- | --- |
| `full_game.txt` (196 บรรทัด) | TITLE → ชั้น 1–3 (ห้อง Combat เคลียร์ด้วย SW2 debug, บอสสู้จริง) → กุญแจ → ESCAPE → WIN (แสดงว่าผ่านเมื่อจบที่ WIN; ไม่ได้รันซ้ำบนโค้ดล่าสุดในรอบเอกสารนี้) |
| `floor1.txt` / `floor2.txt` / `floor3.txt` | ปริศนาชั้น 1 / 2 (Sokoban 24 ครั้ง, สร้างโดย `scripts/make_floor2_script.py`) / 3 (Simon) |
| `weapons_demo.txt` | ร่าง 1→4 สาธิตอาวุธ (ใช้ SW3 / SW2 debug) |
| `sprite_check.txt` | ภาพ sprite ทุกร่าง/ทิศ (ใช้โดย `scripts/run_sprite_shots.sh`) |

```
./scripts/run_full_game.sh            # เล่นเต็มเกมไม่เปิดหน้าต่าง ผ่านเมื่อจบที่ WIN (~10 นาที; build seeded ให้เองถ้ายังไม่มี)
SHOTS=1 ./scripts/run_full_game.sh    # + บันทึก docs/p5_*.png
WAVS=1 ./scripts/run_full_game.sh     # + บันทึก docs/audio/*.wav
./scripts/run_sprite_shots.sh         # ภาพทุกร่าง → preview/game/
./scripts/make_shots.sh               # render renderer ล้วน (iverilog) → preview/shots/
```
`report_shots/` (untracked): ชุดสคริปต์ถ่ายภาพ Verilator ใน WSL (`_build.sh` build seeded ด้วย `-GPROLOGUE=0`, `run.sh <script> <frames> [--shot-at ...]`, `convert.py` แปลง BMP → PNG)

## Simulation (testbench, Icarus Verilog)

ต้องมี Icarus Verilog (`sudo apt install iverilog`; ทดสอบกับ 13.0 ใน WSL) · รันจากโฟลเดอร์ root:

```
./scripts/run_sim.sh <target>     # target ด้านล่าง; ผ่านเมื่อไม่มี FAIL และ "errors = 0"
./scripts/run_sim.sh all          # player world fsm objects puzzles mic mictop audio boss hud simonplate dialog ovrender text ps2 orb debug top
./scripts/check_all.sh [--fast]   # rebuild ไฟล์ที่สร้าง + เช็คว่าไม่ stale + Python tests + (ไม่ --fast) run_sim.sh all (~12 นาที; --fast ~1 นาที)
```

| target | testbench | ตรวจอะไร |
| --- | --- | --- |
| `player` / `playerframe` / `facelock` | tb_player, tb_player_frame, tb_facelock | เดิน ชน ไถล ประตู · เลือก animation · ล็อกทิศ |
| `world` | tb_world | ประตู/grid/จุดเกิด/restart/retry/next_floor (52 checks) |
| `fsm` | tb_game_fsm | state, EVOLVE, HP, GAME OVER, FLOOR_CLEAR, timer, sprint (67 checks) |
| `objects` / `orb` | tb_objects, tb_orb | AABB, อาวุธ, มอน, wave, กับดัก, overlay · ลูกบอลชาร์จ |
| `puzzles` | tb_puzzles | Light Bulb / Sokoban (เล่นตามคำตอบ solver) / Simon / ไอเทม |
| `boss` | tb_boss | บอส 3 ตัว, มึน, FLOOR_CLEAR, กุญแจ, ESCAPE |
| `hud`, `dialog`, `text`, `ovrender`, `simonplate` | tb_hud, tb_dialog, tb_text, tb_ovrender, tb_simonplate | HUD (เทียบ mem ทุกพิกเซล), กล่องเรื่อง, ข้อความ, overlay, แผ่น Simon |
| `audio` / `mic` / `mictop` / `ps2` / `adxl` / `maze` | tb_audio, tb_pdm_mic, tb_mic_test_top, tb_ps2, tb_adxl362, tb_maze | เสียง (64 checks) · ไมค์ · ตัวทดสอบไมค์ · คีย์บอร์ด (30) · ADXL · เขาวงกต |
| `sprites` `tileset` `monster` `bosssprites` `puzzleart` `animroms` | tb_sprites … | ROM art ตรงกับ `.mem` |
| `debug` | tb_debug | พารามิเตอร์ `DEBUG` (SW0–SW4 ใช้ได้เฉพาะ DEBUG = 1) |
| `top` / `topanim` | tb_top | จำลองทั้งระบบ (`topanim` = animation flags ON) |

`tb_shot.v` ใช้กับ `scripts/make_shots.sh` ไม่ใช่ target ของ `run_sim.sh`

## ขั้นต่อไป

ดู `docs/NEXT_STEPS.md` และตาราง FUTURE BACKLOG ใน `docs/DESIGN_PLAN.md`: ทดสอบบอร์ด (ภาพ เสียง ไมค์ เขาวงกต) → แก้ timing (WNS −4.045 ns) → ตั้ง `DEBUG = 0` → วิดีโอ + report ส่งงาน
