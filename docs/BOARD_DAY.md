# วันทดสอบบนบอร์ด (BOARD DAY) — Group 10

สำหรับเพื่อนที่มี Vivado + บอร์ด Nexys A7-100T แต่ยังไม่ได้อ่าน repo นี้ ทำตามลำดับ ติ๊กช่อง ☐ และจดผลที่ช่อง "บันทึก"
ถึงตอนนี้ **ยังไม่เคย build ใน Vivado และยังไม่เคยลงบอร์ดเลย** — ทุกอย่างผ่านเฉพาะ simulation (Icarus + Verilator) ดังนั้นคาดว่าจะเจอ warning / timing / pin ที่ต้องแก้ จดไว้แล้วส่งกลับมา

## 0. เตรียมของ
- ☐ บอร์ด Nexys A7-100T + สาย USB (ไฟ + JTAG), สาย VGA + จอที่รับ 640×480 @ 60 Hz
- ☐ ลำโพงหรือหูฟังเสียบช่อง **AUDIO OUT** (jack 3.5 mm สีเขียว บนบอร์ด)
- ☐ คอมที่ลง Vivado (รุ่นเดียวกับที่ใช้ใน lab) + clone repo `Mc4minta/Group10_Dungeon` branch `main` (หลัง merge P6)
- ☐ กล้องมือถือ (ถ่ายหน้าจอ / บอร์ด), ที่สำหรับจด

## 1. Build เกม
**แบบ batch (แนะนำ)** — เปิด terminal ที่โฟลเดอร์ repo:
```
vivado -mode batch -source scripts/create_project.tcl -tclargs build
```
**แบบ GUI**: `Tools → Run Tcl Script…` เลือก `scripts/create_project.tcl` (ไม่ใส่ `build`) แล้วเปิด `vivado/Group10_Dungeon.xpr` → Run Synthesis → Run Implementation → Generate Bitstream

- ไฟล์ bitstream อยู่ที่ `vivado/Group10_Dungeon.runs/impl_1/top.bit`
- เวลาโดยประมาณ: synthesis 3–8 นาที, implementation 5–15 นาที (ขึ้นกับเครื่อง) ถ้านานกว่า 40 นาทีให้หยุดแล้วบอกเรา
- ☐ build ผ่านโดยไม่ error · บันทึก: ______________________

### สิ่งที่ต้องดูหลัง build (บันทึกไฟล์ส่งกลับ)
เปิด Reports → Timing → Report Timing Summary แล้ว **Save เป็น `timing_summary.rpt`** จากนั้นเช็ค:
- ☐ **WNS ≥ 0** และ TNS = 0 (ถ้า WNS ติดลบ จด path ที่แย่สุด 3 อันดับแรก — เรารู้ว่า path `tilemap ROM → tileset BRAM` ใน `renderer.v` และตัวเลือก object ใน `objline.v` เสี่ยง)
- ☐ Messages → Critical Warnings / Warnings: ก๊อปทั้งหมดลงไฟล์ `critical_warnings.txt` โดยเฉพาะ
  - **unconstrained ports** (ทุกพอร์ตของ `top` ต้องมี pin; พอร์ตที่ไม่มี pin = ลืมใส่ใน `.xdc`)
  - **latch** ("Inferred latch" ต้องไม่มี)
  - **multi-driven net** (ต้องไม่มี)
  - **`$readmemh` file not found** / "can't open file" (ไฟล์ `mem/*.mem` ต้องถูกเพิ่มเป็น source: tilemap, tileset, player, monster, bullet, effect, puzzle, boss, font, text, music, monsters)
  - include ไม่เจอ (`params.vh`, `puzzle_layout.vh`, `text_layout.vh` — `create_project.tcl` ตั้ง include dir ให้แล้ว ถ้าไม่เจอให้ตั้ง Settings → Verilog Options → Include Dirs = `rtl`)
- ☐ Utilization / Synthesis log: ROM ใหญ่ต้องถูก infer เป็น **BRAM** (ดู "RAMB36/RAMB18" ใน utilization) — tileset (49,152×12), player (49,152×12), monster / bullet / effect / puzzle / boss sprite, **ไม่ใช่** LUT ล้วน (ถ้า LUT พุ่งหลายหมื่น = ROM กลายเป็น logic) · tilemap (4096×4) กับ `music.mem` (768×32) เป็น distributed ROM ได้
  - บันทึก: LUT ______ / FF ______ / BRAM ______ / DSP ______

## 2. ลงบอร์ด + ทดสอบเกม
Hardware Manager → Open Target → Auto Connect → Program Device (`top.bit`)

| ☐ | ขั้น | ควรเห็น | บันทึก |
| --- | --- | --- | --- |
| ☐ | 1. เปิดบอร์ด ต่อ VGA | ภาพขึ้นจอ นิ่ง ไม่กระพริบ — **ภาพเลื่อน 1–2 px หรือขอบเบี้ยว?** | |
| ☐ | 2. หน้า TITLE | พื้นกรมท่า, `DUNGEON`, `PRESS BTNC` กะพริบ, 7-seg `--------`, RGB16 เขียว | |
| ☐ | 3. กด BTNC | เข้าเกม ห้อง START, 7-seg `1-3-00.00`, LED8–10 ติด (HP 3), เวลานับ | |
| ☐ | 4. เดิน BTNU/D/L/R + ทแยง | เดิน 8 ทิศ ชนกำแพง ไถล ไม่กระตุก | |
| ☐ | 5. SW14 (sprint) | เดินเร็วขึ้น, LED14 ติด | |
| ☐ | 5b. SW15 (pause) | เกมหยุด + ข้อความ PAUSED + เสียงเงียบ, ลงแล้วเล่นต่อ | |
| ☐ | 6. SW13 | ไม่เกิดอะไรนอกห้อง Sokoban | |
| ☐ | 7. ยก SW3 ทีละครั้ง ×3 | EVOLVE (ตัวกะพริบ, RGB16 ขาว 1 วิ) → ร่าง 2, 3, 4 (เขียว→ฟ้า→ม่วง→ทอง) | |
| ☐ | 8. ยก SW4 | HP ลด 1 (LED10 ดับ) | |
| ☐ | 9. กด BTNC ในห้อง | ร่าง 1 ฟัน, ร่าง 2 ยิง, ร่าง 3 กระจาย 3 ทาง, ร่าง 4 ชาร์จ (ค้าง 0.75 วิ ตัวกะพริบ ปล่อย = ลูกใหญ่) | |
| ☐ | 10. เดินเข้าห้อง Combat | ประตูปิด, มอนไล่ / ป้อมยิง, LED4–7 = จำนวนมอน, ฆ่าหมดประตูเปิด | |
| ☐ | 11. ปริศนาชั้น 1–3 | Light Bulb (LED0–3 = หลอด), Sokoban (SW13 รีเซ็ต), Simon (ยืนบนแผ่นตามลำดับ) → ไอเทม → LED13 ติด → ประตู L เปิด | |
| ☐ | 12. บอส 1 / 2 / 3 | LED0–7 = HP บอส; บอส 2 ตบมือ = มึน; ฆ่าบอสแล้วขึ้น `FLOOR n CLEAR` | |
| ☐ | 13. บอส 3 ตาย → ได้กุญแจ → ประตู E ที่ START ชั้น 3 → เขาวงกต | ประตูเปิด; เขาวงกต: ลูกบอลกลิ้งตามการเอียงบอร์ด (ถ้าทิศผิดแก้ `MAZE_SIGN_X/Y`), 7-seg นับถอยหลัง 60 วิ, ถึงเส้นชัย = WIN, SW10 = ใช้ปุ่ม | |
| ☐ | 14. วิ่งไปประตู E ก่อนหมดเวลา | จอทอง `YOU WIN` + เวลา (ถ้าไม่ทัน = `GAME OVER`) | |
| ☐ | 15. CPU_RESETN | กลับ TITLE ได้ทุกเมื่อ | |

ปุ่ม debug (ใช้ได้เพราะตอนนี้ `DEBUG = 1`): SW0 เปิดประตู L, SW1 ข้ามชั้น, SW2 ลบมอนทั้งห้อง, SW3 evolve, SW4 โดนตี

## 3. เสียง
ต้องเห็นเกมทำงานก่อน เสียงเริ่มตอนกด BTNC (หน้า TITLE เงียบ)
- ☐ **มีเสียงออกไหม?** บันทึก: ______
  - ถ้า **เงียบสนิท**: ขา `AUD_SD` อาจ active ตรงข้าม — แก้ `AUD_SD_ON` จาก `1` เป็น `0` ใน `rtl/params.vh` แล้ว build ใหม่ (ตอนนี้เป็น 1 = เปิดแอมป์; โค้ด demo ของ Digilent ก็ขับ 1 ตลอด)
  - ถ้ามีเสียงฉ่าอย่างเดียว: ลองเสียบสายอีกครั้ง / ลด volume ของลำโพงแล้วจด
- ☐ ดัง / เบาไป ไหม (ลำโพงของคอมเสียบแล้วฟังสบายไหม)? บันทึก: ______ (ปรับได้ที่ `SFX_AMP` / `BGM_AMP` ใน `params.vh`)
- ☐ เพลงพื้นหลังเล่นและเปลี่ยนตามชั้น (ชั้น 1–3 คนละท่อน) และ ESCAPE เร่งเร้า, WIN / GAME OVER มี jingle
- ☐ SFX ตามลำดับความสำคัญ: โดนตี > บอสมึน > มอนตาย > ไอเทม > ประตูเปิด > ผิด > ถูก > ศัตรูโดน > ยิง > ฟัน (เสียงสำคัญกว่าตัดเสียงเบากว่า ไม่ควรเป็นเสียงรกจนฟังไม่ออก)
- ☐ ห้อง Simon: แต่ละแผ่นมีเสียงโน้ตของตัวเอง (4 โน้ต สูงขึ้นตามแผ่น)

## 4. ทดสอบไมค์ (ตัวทดสอบแยก ไม่ต้องมีเกม)
```
vivado -mode batch -source scripts/create_mic_project.tcl -tclargs build
```
ได้ `vivado_mic/mic_test.runs/impl_1/mic_test_top.bit` → Program Device

| ปุ่ม / จอ | ความหมาย |
| --- | --- |
| LED0–15 | แถบความดัง (log คร่าว ๆ) |
| 7-seg ซ้าย 4 หลัก | amplitude ปัจจุบัน (0–2048) |
| 7-seg ขวา 4 หลัก | peak ตั้งแต่กด BTNC ล่าสุด (ค้างกด BTND = จำนวนครั้งที่ตบมือ) |
| BTNC | ล้าง peak (BTNC + BTND = ล้างตัวนับตบมือ) |
| SW[10:0] | threshold TH (0–2047); ลงหมด = ค่าเริ่ม 600 |
| RGB16 เขียว | เพิ่งตบมือ (200 ms) · RGB17 แดง = ช่วง holdoff 200 ms |

ทำตามนี้ แล้วจดค่า:
1. ☐ เงียบ ๆ แล้วกด BTNC: peak นิ่งอยู่ที่ ______ (ควรต่ำกว่า TH มาก)
2. ☐ พูดดังปกติใกล้ไมค์ (ไมค์อยู่ใกล้ปุ่ม BTND บนบอร์ด ด้านซ้ายของ SW) กด BTNC ก่อน แล้วอ่าน peak: **พูด peak = ______**
3. ☐ ตบมือ 1 ครั้งห่างไมค์ ~20 ซม. กด BTNC ก่อน แล้วอ่าน peak: **ตบมือ peak = ______**; RGB16 เขียวขึ้นไหม; ค้าง BTND ดูจำนวน = 1 ไหม
4. ☐ ปรับ SW[10:0] จนตบมือติด (เขียว) แต่พูดไม่ติด: **TH ที่เลือก = ______** (ค่าไบนารีของสวิตช์ หรือทศนิยม)
5. ☐ ใส่ TH ที่ได้ใน `rtl/params.vh` บรรทัด `MIC_TH` แล้ว build เกมใหม่ (ถ้าเสียงในห้องดังต่างจากตอนวัดมาก ให้วัดซ้ำ)
- ถ้า amplitude ค้างสูงตลอดแม้เงียบ (> 500): ไมค์อ่านผิดขอบ — บอกเรา (เราเดาขอบขาขึ้นสำหรับ `M_LRSEL = 0` ยังไม่ได้ยืนยัน)

## 5. ส่งอะไรกลับมา
- `timing_summary.rpt` + `critical_warnings.txt` (ข้อ 1)
- ตาราง "ลงบอร์ด" ข้อ 2 ที่ติ๊ก/จดแล้ว + ภาพถ่ายหน้าจอ (หน้า TITLE, ห้องต่อสู้, ESCAPE, WIN) + ถ้าภาพเลื่อนหรือเบี้ยว ถ่ายให้เห็นขอบ
- ผลเสียง (ข้อ 3) และค่าไมค์ (ข้อ 4: พูด peak, ตบมือ peak, TH ที่เลือก)
- ข้อความ error ที่ Vivado ฟ้องทุกอันที่แก้ไม่ได้เอง (ถ่ายจอก็ได้)
