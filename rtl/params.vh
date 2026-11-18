// ค่าเกมทั้งหมดที่ยัง *tentative* อยู่ที่นี่ที่เดียว (บรรทัดละค่า)
// ไฟล์นี้ถูก `include ภายใน module (game_fsm, player, objects, renderer) — ห้ามมี module/port
// เปลี่ยนค่าแล้ว: iverilog/Verilator build ใหม่, Vivado re-run synthesis
// include path: iverilog -I rtl, Verilator -I rtl, Vivado include_dirs = rtl (ตั้งใน create_project.tcl)

// ---------- ร่าง 1..4 ----------
localparam [2:0] SPD1 = 3'd2;              // ความเร็ว px/เฟรม ร่าง 1
localparam [2:0] SPD2 = 3'd2;              // ร่าง 2
localparam [2:0] SPD3 = 3'd3;              // ร่าง 3
localparam [2:0] SPD4 = 3'd3;              // ร่าง 4
localparam [2:0] HP1  = 3'd3;              // Max HP ร่าง 1
localparam [2:0] HP2  = 3'd3;              // ร่าง 2
localparam [2:0] HP3  = 3'd4;              // ร่าง 3
localparam [2:0] HP4  = 3'd4;              // ร่าง 4
localparam [1:0] DMG1 = 2'd1;              // ดาเมจ ร่าง 1
localparam [1:0] DMG2 = 2'd1;              // ร่าง 2
localparam [1:0] DMG3 = 2'd2;              // ร่าง 3
localparam [1:0] DMG4 = 2'd2;              // ร่าง 4
localparam [2:0] RGB1 = 3'b010;            // {R,G,B} เขียว
localparam [2:0] RGB2 = 3'b011;            // ฟ้า
localparam [2:0] RGB3 = 3'b101;            // ม่วง
localparam [2:0] RGB4 = 3'b110;            // ทอง
localparam [2:0] SPRINT_BONUS = 3'd1;      // SW15: +px/เฟรม
localparam [6:0] EVOLVE_FRAMES = 7'd60;    // EVOLVE 1 วิ
localparam [7:0] CLEAR_FRAMES  = 8'd120;   // FLOOR_CLEAR 2 วิ

// ---------- การโจมตีของผู้เล่น ----------
localparam MELEE_FRAMES   = 8;             // ร่าง 1: hit box อยู่กี่เฟรม (24x16 หน้าตัว)
localparam MELEE_COOLDOWN = 20;            // ร่าง 1: เฟรมจากกดถึงกดได้อีก
localparam PB_SPEED       = 4;             // กระสุนผู้เล่น px/เฟรม (8x8)
localparam PB_COOLDOWN    = 15;            // ร่าง 2-4: เฟรมระหว่างนัด (กดค้างยิงซ้ำ)

// ---------- มอน ----------
localparam MON_A_HP       = 2;             // มอน A (ไล่)
localparam MON_A_SPEED    = 1;             // px/เฟรม
localparam MON_B_HP       = 3;             // มอน B (ป้อม)
localparam TURRET_PERIOD  = 120;           // ยิง 4 ทิศทุก 2 วิ
localparam TURRET_PHASE   = 30;            // ป้อมตัวถัดไปในห้องเหลื่อม 0.5 วิ
localparam TURRET_FIRST   = 60;            // ยิงครั้งแรกหลังเข้าห้อง 1 วิ (+ phase)
localparam EB_SPEED       = 3;             // กระสุนศัตรู px/เฟรม (8x8)
localparam MON_FLASH      = 8;             // มอนโดนตีกะพริบกี่เฟรม

// ---------- ผู้เล่นโดนตี ----------
localparam KB_FRAMES      = 8;             // knockback กี่เฟรม
localparam KB_SPEED       = 2;             // px/เฟรม (รวม 16 px)
localparam INV_FRAMES     = 60;            // อมตะหลัง knockback (กะพริบ)

// ---------- ปริศนา (P4) ----------
localparam [3:0] LB_MASK0 = 4'b0111;       // คันโยก a: XOR หลอด (bit 3 = หลอด 1)
localparam [3:0] LB_MASK1 = 4'b1011;       // คันโยก b
localparam [3:0] LB_MASK2 = 4'b1101;       // คันโยก c
localparam [3:0] LB_MASK3 = 4'b1110;       // คันโยก d
localparam BOX_SLIDE_FRAMES = 8;           // กล่องเลื่อน 1 ช่อง (32 px) กี่เฟรม (ต้องหาร 32 ลงตัว)
localparam SIMON_PRE      = 45;            // เข้าห้อง/ก่อนโชว์รอบใหม่ รอกี่เฟรม
localparam SIMON_ON       = 30;            // แผ่นสว่างตอนโชว์
localparam SIMON_GAP      = 15;            // ช่องว่างระหว่างแผ่นตอนโชว์
localparam SIMON_FEEDBACK = 15;            // แผ่นสว่างตอนผู้เล่นเหยียบถูก
localparam SIMON_WRONG    = 45;            // จอแผ่นแดงตอนเหยียบผิด
localparam SIMON_LEN0     = 3;             // ความยาวรอบ 1
localparam SIMON_LEN1     = 4;             // รอบ 2
localparam SIMON_LEN2     = 5;             // รอบ 3
localparam PUZZLE_DELAY   = 256;           // puzzles.v เริ่มงานต่อเฟรมหลัง frame_tick กี่ clock (ให้ objects.v เสร็จก่อน)

// ---------- บอส (P5) ----------
localparam BOSS1_HP        = 10;           // บอส 1 (ชั้น 1)
localparam BOSS2_HP        = 16;           // บอส 2 (ชั้น 2)
localparam BOSS3_HP        = 24;           // บอส 3 (ชั้น 3)
localparam BOSS1_SPEED     = 1;            // px ต่อก้าว
localparam BOSS1_EVERY     = 2;            // บอส 1 ก้าวทุกกี่เฟรม (1 px ทุก 2 เฟรม)
localparam BOSS2_SPEED     = 2;            // เด้งทแยง px/เฟรม
localparam BOSS3_SPEED     = 2;            // ไล่ px/เฟรม
localparam BOSS2_FIRE      = 120;          // ยิง 4 ทิศทุกกี่เฟรม
localparam BOSS3_FIRE      = 60;
localparam BOSS_FLASH      = 8;            // โดนตีกะพริบ
localparam STUN_FRAMES     = 120;          // ตบมือ -> บอส 2 มึน
localparam STUN_COOLDOWN   = 300;          // หลังมึนจบ รอกี่เฟรมถึงตบมือได้อีก

// ---------- ฉากหนี (P5) ----------
localparam ESCAPE_SECONDS  = 30;           // นับถอยหลัง (1800 เฟรม)
localparam ESCAPE_BANNER   = 120;          // ข้อความ ESCAPE! กี่เฟรม
localparam SHAKE_PX        = 2;            // จอสั่น +-px (ค่า 1..3)
localparam SHAKE_EVERY     = 4;            // เปลี่ยน offset ทุกกี่เฟรม
localparam LED_BLINK       = 15;           // LED กะพริบ 4 Hz (คาบ 15 เฟรม)

// ---------- ไมค์ PDM (P5) ----------
localparam MIC_CLK_DIV     = 40;           // 100 MHz / 40 = 2.5 MHz (M_CLK)
localparam MIC_WINDOW      = 4096;         // นับ bit 1 ทุกกี่ sample (1.64 ms)
localparam MIC_TH          = 600;          // |ones - 2048| > TH = ตบมือ (เงียบ ~ +-100, ตบมือดังกว่ามาก)
localparam MIC_HOLDOFF     = 20000000;     // หลังตบมือ ไม่สนกี่ clock (200 ms ที่ 100 MHz)
localparam BOSS_DELAY      = 300;          // boss.v เริ่มงานต่อเฟรมหลัง frame_tick กี่ clock (หลัง objects.v)

// ---------- อาวุธต่อร่าง (P6) ----------
localparam SPREAD_SPEED    = 4;            // ร่าง 3 กระสุนกระจาย: ทางตรง px/เฟรม
localparam SPREAD_DIAG     = 3;            // ร่าง 3: ทแยง 45 องศา px/เฟรม ต่อแกน
localparam SPREAD_COOLDOWN = 20;           // ร่าง 3: เฟรมระหว่างชุด (3 นัด)
localparam TAP_SPEED       = 6;            // ร่าง 4 กดครั้งเดียว: กระสุนเร็ว px/เฟรม
localparam TAP_COOLDOWN    = 15;           // ร่าง 4: เฟรมระหว่างนัด
localparam CHARGE_FRAMES   = 45;           // ร่าง 4: กดค้างกี่เฟรมถึงชาร์จเต็ม (0.75 วิ)
localparam BIG_SPEED       = 4;            // ร่าง 4 ลูกใหญ่ 16x16 px/เฟรม
localparam BIG_DMG         = 4;            // ร่าง 4 ลูกใหญ่: ดาเมจ (ทะลุมอน, โดนแต่ละตัวครั้งเดียว)
