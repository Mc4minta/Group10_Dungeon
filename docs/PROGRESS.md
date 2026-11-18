# Group 10 — Progress Checklist

อัปเดต: 2026-11-18 14:10

## วิธีใช้
ติ๊กเมื่อโค้ดเสร็จและผ่าน test ส่วนการเช็คบนบอร์ดจริงมีข้อแยกท้ายทุก phase

เครื่องหมาย: (sim) = ผ่าน simulation แล้ว ยังไม่ทดสอบบนบอร์ด · (ph) = มี placeholder ใช้แทนได้

## Milestone
- [ ] **ศุกร์ 20/11 Progress:** บนบอร์ดจริง เดิน 8 ทิศครบ 5 ห้องชั้น 1 + เปลี่ยน 4 ร่าง + HP/ชั้นบน 7-seg + นำเสนอสไลด์ state diagram
- [ ] **พุธ 25/11:** เล่นจบเกมได้ (กราฟิก placeholder ได้) — เล่นจบได้ใน sim (full_game.txt)
- [ ] **ศุกร์ 27/11 ส่งงาน:** วิดีโอ ≤ 7 นาที, report PDF, source code

## โค้ด P0–P7
เสร็จ 31 จาก 41 ข้อ

### P0 ฐาน (17–18/11)
- [x] 0.1 vga_sync 640×480 + ce 25 MHz + frame_tick (sim)
- [x] 0.2 สคริปต์ ASCII map → tilemap.mem 13 ห้อง (`build_maps.py`)
- [x] 0.3 Renderer ชั้น tile (sim)
- [x] 0.4 Renderer ชั้น sprite, F0F โปร่งใส (sim)
- [x] 0.5 debounce + edge ทุกปุ่ม (sim)
- [x] 0.6 .xdc ครบทุก pin + เทียบกับ Master.xdc — 80 pin ตรง Master, เปิดไมค์ M_CLK/M_DATA/M_LRSEL (J5/H5/F5) + port ใน top.v แล้ว (P5)
- [ ] **เช็คบนบอร์ด:** build bitstream ผ่าน, timing ผ่าน, ภาพไม่เลื่อน 1–2 px, LED ตามปุ่ม

### P1 Movement + ห้อง (18–19/11)
- [x] 1.1 เดิน 8 ทิศ ทุก frame_tick (sim)
- [x] 1.2 Collision แยกแกน x→y, hitbox 24×24 (sim)
- [x] 1.3 Corner slide ≤ 8 px (sim)
- [x] 1.4 facing + walk animation (sim)
- [x] 1.5 ตารางประตู + flip-screen ครบ 3 ชั้น (sim)
- [x] 1.6 ดันกล่อง Sokoban (ทำหลัง 20/11 ได้) (sim) — `puzzles.v`, `tb_puzzles` (ชนกำแพง/กล่อง/gate, ทแยงไม่ดัน)
- [ ] **เช็คบนบอร์ด:** เดินวนครบ 5 ห้องชั้น 1 ไป-กลับ, ทแยงชนกำแพงแล้วไถล

### P2 Game FSM + Evolution + จอสถานะ (19–20/11)
- [x] 2.1 `game_fsm.v`: TITLE / PLAY / EVOLVE / GAME_OVER (sim) — ครบ 7 state, `tb_game_fsm` 43 checks
- [x] 2.2 Evolution + ตารางค่าต่อร่าง (ความเร็ว, Max HP, ดาเมจ, สี RGB) + กะพริบ 1 วิ (sim)
- [x] 2.3 HP บน LED8–11, 7-seg ชั้น/HP/เวลา mm.ss (sim) — ตรวจจากภาพ Verilator `docs/p2_*.png`
- [x] 2.4 หน้า Title / Game Over แบบง่าย (sim) — ยังไม่มีข้อความ รอ font P5
- [x] 2.5 Sprint SW15: ความเร็ว +1 ตอนเปิด (sim) — `tb_player` speed 4, `tb_game_fsm`
- [ ] **เช็คบนบอร์ด:** กด BTNC เริ่มเกม, HP 0 กลับ Title, เปลี่ยน 4 ร่างแล้ว RGB16 เปลี่ยนสี

### P3 การต่อสู้ (21–23/11)
- [x] 3.1 Object slot (มอน 6, กระสุน 2 + 16, บอส 1) + วาด (sim) — `objects.v` + `objline.v`, `tb_objects`, ภาพ `docs/p3_*.png`
- [x] 3.2 AABB ทุกคู่ช่วง vblank (≤ 36,000 clock) (sim) — วัดได้สูงสุด 88 clock/เฟรม, ขอบแตะ = ไม่ชน
- [x] 3.3 ตีประชิด + ยิง + cooldown + strafe (sim)
- [x] 3.4 มอน A (ไล่) + มอน B (ยิง 4 ทิศ เหลื่อมเฟส) (sim)
- [x] 3.5 โดนตี: knockback + อมตะ 60 เฟรม (sim)
- [x] 3.6 ห้อง Combat ล็อก + cleared[room] + ประตู L/E จริง (เอา SW0/SW2 debug ออก) (sim) — SW2 เอาออกแล้ว; SW0 ยังแทน has_item[floor] จนกว่า P4 จะให้ไอเทมจริง

### P4 ปริศนา (22–24/11)
- [x] 4.1 Light Bulb: LFSR + คันโยก XOR mask + LED0–3 (sim) — ต้องตี ≥ 2 ครั้ง, ฟันหรือยิงคันโยก
- [x] 4.2 Sokoban: กล่อง 2, plate 2, gate, SW13 reset (sim) — คำตอบ solver 24 ครั้งเล่นเป็นการกดปุ่มผ่านทั้ง iverilog และ Verilator
- [x] 4.3 Simon: SHOW / INPUT / WRONG / ROUND_OK + โน้ต 4 โน้ต (sim) — เสียงโน้ตต่อใน P6 (มีสัญญาณ `simon_note` / `simon_note_on` แล้ว)

### P5 บอส + ไมค์ + ฉากหนี (23–25/11)
- [x] 5.1 Boss module + ROM พารามิเตอร์ 3 ตัว (sim) — `boss.v`, `tb_boss`
- [x] 5.2 FLOOR_CLEAR → ชั้นถัดไป (เอา SW1 debug ออก) (sim) — บอส 1, 2 ตาย = FLOOR_CLEAR; SW1 เหลือเป็นทางลัด DEBUG เท่านั้น
- [x] 5.3 ไมค์: clap_pulse → STUN บอส 2 (sim) — logic ไมค์ + ตบมือจำลองใน sim เท่านั้น ยังไม่ได้ลองไมค์จริง และขอบที่ใช้อ่าน (ขาขึ้น) ยังไม่ได้ยืนยันบนบอร์ด
- [x] 5.4 ESCAPE: นับถอยหลัง 30 วิ, จอสั่น, LED กะพริบ, WIN (sim)
- [x] 5.5 Font ROM + ข้อความหน้าจอ (sim) — `scripts/make_font.py`, TITLE / FLOOR CLEAR / ESCAPE! / YOU WIN + เวลา / GAME OVER

### P6 เสียง + รวม (25–26/11)
- [ ] 6.1 SFX 10 แบบ + priority mux
- [ ] 6.2 BGM 4 ทำนอง (ตัดก่อนถ้าไม่ทัน)
- [ ] 6.3 สลับ sprite จริงแทน placeholder ทั้งหมด
- [ ] 6.4 เล่นทดสอบจบเกม 3 รอบ, ปรับ HP/ความเร็ว

### P7 ส่งงาน (26–27/11)
- [ ] 7.1 วิดีโอ ≤ 7 นาที
- [ ] 7.2 Report PDF
- [ ] 7.3 Source code: repo สะอาด build ได้, ชื่อ Group10_[ชื่อเกม]

## Sprite
วาดจริงแล้ว 1 จาก 16 ชิ้น (รวม ~1.6 Mbit) ติ๊กเมื่อแปลงเป็น .mem ด้วย sprite_tool แล้วสลับเข้าเกมได้ไม่มีสีเพี้ยน

- [ ] 1 Tileset ชั้น 1 — 32×32 × 16 tile · ต้องใช้ 18/11 (ph)
- [ ] 2 ผู้เล่น ร่าง 1 — 32×32 × 12 เฟรม (4 ทิศ × idle + ก้าว 2) · 19/11 (ph)
- [ ] 3 ผู้เล่น ร่าง 2–4 — 32×32 × 36 เฟรม · 20/11, demo ใช้เฟรม idle ก่อนได้ (ph)
- [ ] 4 มอน A — 32×32 × 2 · 21/11 (ph)
- [ ] 5 มอน B — 32×32 × 2, ปากกระบอก 4 ทิศ · 21/11 (ph)
- [ ] 6 กระสุนผู้เล่น + ศัตรู — 8×8 × 1 + 1, สีต่างกันชัด · 21/11 (ph)
- [ ] 7 Tileset ชั้น 2 — 32×32 × 16, รั้ว F มองทะลุได้ · 21/11 (ph)
- [ ] 8 หลอดไฟ + คันโยก — 32×32 × 2 + 2 · 22/11 (ph)
- [ ] 9 กล่อง + gate — 32×32 × 1 + 2 · 22/11 (ph)
- [ ] 10 ไอเทม 1–3 — 32×32 × 3 · 22/11 (ph)
- [ ] 11 Tileset ชั้น 3 — 32×32 × 16 รวมแผ่น Simon 4 สี · 22/11 (ph)
- [ ] 12 บอส 1 — 64×64 × 2 · 23/11 (ph)
- [ ] 13 บอส 2 — 64×64 × 2, ดูบินได้ + ท่ามึน · 23/11 (ph)
- [ ] 14 บอส 3 — 64×64 × 2 · 23/11 (ph)
- [x] 15 Font 8×8 1 bit × 37 ตัว (A–Z, 0–9, ช่องว่าง) · 23/11 — วาดด้วย `scripts/make_font.py` (41 ตัว รวม - : ! .) แสดงถูกต้องใน sim
- [ ] 16 โลโก้ชื่อเกม ≤ 128×32 · 25/11, รอชื่อเกม

placeholder ตอนนี้มาจาก `scripts/make_placeholders.py` (tileset 3 ชั้น × 16 + ผู้เล่น 48 เฟรม + มอน A/B 2 เฟรม + กระสุน 2 แบบ + เอฟเฟกต์ฟัน 4 ทิศ + ของในห้องปริศนา 10 เฟรม)

## Data / ROM asset
เสร็จ 10 จาก 13 ชิ้น

- [x] 1 Tile map 13 ห้อง (`mem/tilemap.mem`)
- [x] 2 ห้อง Puzzle ชั้น 3 ใหม่ แผ่น Simon (`maps/12_f3_puzzle_simon.txt`)
- [x] 3 ตารางประตู + จุดเกิดหน้าประตู (ใน `top.v`)
- [x] 4 ตาราง object ต่อห้อง (`mem/objects.txt`; มอนอ่านเข้า Verilog แล้วผ่าน `mem/monsters.mem`)
- [x] 5 พารามิเตอร์บอส 3 ตัว (HP 10/16/24, ความเร็ว, แบบเคลื่อนที่, fire_timer) · P5 (`rtl/params.vh` + `boss_rom` ใน `boss.v`)
- [x] 6 ค่าต่อร่าง (ความเร็ว 2/2/3/3, Max HP 3/3/4/4, ดาเมจ 1/1/2/2, สี) · P2, ค่ายังรอยืนยัน (ตาราง `localparam` ใน `rtl/game_fsm.v`)
- [x] 7 mask Light Bulb 0111/1011/1101/1110 · P4 (`rtl/params.vh`, ตรวจแล้วแก้ได้ทุกแบบ)
- [x] 8 ตำแหน่งกล่อง Sokoban + เฉลย 24 ครั้ง · P4 (`maps/09_*`, `scripts/solve_sokoban.py` ยืนยันน้อยสุด 24)
- [ ] 9 โน้ต Simon 4 โน้ต (ค่า divider) · P4
- [ ] 10 ตาราง SFX 10 แบบ · P6
- [ ] 11 BGM 4 ทำนอง (ชั้น 1–3 + ฉากหนี) · P6
- [x] 12 Text ROM: ชื่อเกม, PRESS BTNC, YOU WIN, GAME OVER, FLOOR n · P5 (`mem/text.mem` + `rtl/text_layout.vh` จาก `make_font.py`; ชื่อเกมแก้ที่ GAME_NAME)
- [x] 13 .xdc ครบ รวมไมค์ (ดู 0.6)

## ทีมและเรื่องค้าง
- [x] สร้าง GitHub repo และ push โค้ด (`Mc4minta/Group10_Dungeon`)
- [ ] แบ่งงาน 5 คน (บทบาท A–E) + ตกลง interface สัญญาณ · 18/11
- [ ] ยืนยัน Max HP 3/3/4/4, ดาเมจ 1/1/2/2, stun 2 วิ / cooldown 5 วิ
- [ ] ทดสอบไมค์ PDM แยกบนบอร์ด + จูน threshold · เริ่ม 18/11
- [ ] เช็คลูกศรในสไลด์ 21 หน้าด้วยตา + Mermaid ใน doc แสดงเป็นภาพ · ก่อน 20/11
- [ ] แก้ dropdown #1–8 และ #34 ในเอกสารเลือก Sub-feature เป็น "เอา"
- [ ] ชื่อเกม + เนื้อเรื่อง (ปกสไลด์ยังเป็น [ชื่อเกม])
- [ ] ตำแหน่ง HUD + sprite_tool รองรับ font 1 bit ไหม
- [ ] ถาม TA เรื่อง bonus หลังล็อก scope
