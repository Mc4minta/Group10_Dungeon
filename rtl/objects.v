// P3: object system — มอน 6, กระสุนผู้เล่น 2, กระสุนศัตรู 16, บอส 1 (สำรองไว้ P5 ยังไม่ใช้)
//
// ทุกอย่างอัปเดตครั้งเดียวต่อ frame_tick (ต้น vblank) แบบทีละขั้น 1 clock (FSM) — ไม่มี logic ขนานใหญ่
//   ATK  : cooldown, ฟันประชิด (ร่าง 1) / ยิง (ร่าง 2-4), นับถอยหลังโดนตี
//   PB   : กระสุนผู้เล่นเดิน + ชน tile                         (2 clock / นัด)
//   EB   : กระสุนศัตรูเดิน + ชน tile                           (2 clock / นัด)
//   MON  : มอน A เดินแยกแกน x แล้ว y ชน tile / มอน B นับเวลายิง (≤ 4 clock / ตัว, ยิง ≤ 16 clock)
//   COL  : AABB ทีละคู่ 1 clock: กระสุนผู้เล่น×มอน 12, ฟัน×มอน 6, ผู้เล่น×มอน 6, ผู้เล่น×กระสุนศัตรู 16
//   END  : ห้อง Combat มอนตายหมด -> cleared
// รวมไม่เกิน ~190 clock ต่อเฟรม (vblank มี 36,000 clock ที่ CE_DIV = 1, 144,000 ที่ CE_DIV = 4)
//
// เข้าห้องใหม่ (room_load จาก world.v): ล้างกระสุน, โหลดมอนของห้องจาก monsters.mem ถ้าห้องยังไม่ cleared
// ห้อง Combat (C1, C2) ที่มีมอนเหลือ -> doors_open = 0 (ประตู D ปิดทั้งสองทาง)
// restart (เริ่มเกมใหม่จาก TITLE) -> ล้าง cleared ทุกห้อง
//
// hitbox: มอน = พิกเซล 4..27 ของ sprite 32x32 (24x24), ผู้เล่น (ที่โดนตี) = HURT_BOX กลาง sprite (16x16, params.vh), กระสุน 8x8 ทั้งก้อน
// ฟันประชิด 24x16 หน้าตัว: ลง (px+4, py+28) ขึ้น (px+4, py-12) ซ้าย (px-12, py+4) ขวา (px+28, py+4) [ซ้าย/ขวา = 16x24]
// AABB: ชนเมื่อซ้อนกันอย่างน้อย 1 px (ขอบแตะกันพอดี = ไม่ชน)
module objects (
    input  wire         clk,
    input  wire         rst,
    input  wire         frame_tick,
    input  wire         run,            // 1 = state PLAY (นอกนั้นทุกอย่างหยุด)
    input  wire         restart,        // pulse: เกมใหม่ -> ล้าง cleared ทุกห้อง
    input  wire         room_load,      // pulse: world.load (เข้าห้องใหม่ / restart / ชั้นใหม่)
    input  wire [1:0]   floor,
    input  wire [2:0]   room,
    input  wire [3:0]   grid,
    input  wire         open_L,         // ประตู L เปิด (กระสุนผ่านได้)
    input  wire [9:0]   px, py,         // มุมซ้ายบน sprite ผู้เล่น
    input  wire [1:0]   facing,
    input  wire [1:0]   form,
    input  wire [1:0]   damage,         // ดาเมจของร่างปัจจุบัน (game_fsm)
    input  wire         atk_press,      // BTNC rise
    input  wire         atk_hold,       // BTNC level
    input  wire         dbg_clear,      // pulse (DEBUG): ลบมอนทั้งห้อง -> ห้องเคลียร์
    input  wire [11:0]  blk0, blk1, blk2,   // tile กันเพิ่ม (กล่อง / gate จาก puzzles.v)
    input  wire [2:0]   blk_en,
    // ---------- บอส (slot บอส; ตัว state อยู่ใน boss.v) ----------
    input  wire         boss_act,
    input  wire [9:0]   boss_x, boss_y,   // มุมซ้ายบน sprite 64x64, hitbox 48x48 ที่ +8
    input  wire         boss_fire,        // pulse: ยิง 4 ทิศจากจุดกลางบอส
    input  wire [7:0]   brk,                // W5: บล็อกพังได้ของห้องนี้ที่พังแล้ว (overlay.v)
    output reg          brk_set = 1'b0,     // pulse: กระสุน / ฟันโดนบล็อกพังได้ -> overlay.v ตั้งบิต brk_idx
    output reg  [2:0]   brk_idx = 3'd0,
    input  wire         auto_lock,        // W18 (SW9): auto-lock - attacks aim at the nearest enemy (8 directions) instead of the facing
    output reg          lock_use = 1'b0,  // a target is locked this frame
    output reg  [1:0]   lock_face = 2'd0,// 4-way direction of the target (the hero turns that way while attacking)
    input  wire         summon,           // pulse (W11): บอส 2 เรียกลูกน้อง -> spawn มอน A ที่ SUMMON*_T* ใน slot ว่าง
    output reg          boss_dmg = 1'b0,  // pulse: บอสโดนกระสุน / ฟัน
    output reg  [2:0]   boss_dmg_amt = 3'd0,
    output reg          boss_dmg_big = 1'b0,  // มาพร้อม boss_dmg: กระสุนชาร์จ (บอส 3 รับเฉพาะอันนี้)
    output wire         doors_open,     // ประตู D เปิด (0 = ห้อง Combat ล็อก)
    output wire [2:0]   alive,          // มอนที่เหลือในห้อง
    output reg          hit = 1'b0,     // pulse: ผู้เล่นโดนตี -> game_fsm.take_hit
    output reg          kb_start = 1'b0,// pulse: เริ่ม knockback
    output reg  [1:0]   kb_dir = 2'd0,  // ทิศ knockback (0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา)
    output wire         invuln,         // อยู่ในช่วง knockback + อมตะ
    output wire         player_blink,   // ซ่อน sprite ผู้เล่นเฟรมนี้ (กะพริบตอนอมตะ)
    output wire         busy,           // กำลังประมวลผล (ใช้วัดจำนวน clock ใน testbench)
    // ---------- ให้ renderer ----------
    output wire [5:0]   mon_act,
    output wire [5:0]   mon_type,       // 0 = A, 1 = B
    output wire [5:0]   mon_flash,      // วาดเป็นสีขาว (กะพริบตอนโดนตี)
    output wire [59:0]  mon_x, mon_y,   // {m5, ..., m0} ตัวละ 10 bit
    output wire         mon_anim,       // เฟรม animation 0/1
    output wire [5:0]   pb_act,           // กระสุนผู้เล่น 6 slot
    output wire [59:0]  pb_x, pb_y,
    output wire [11:0]  pb_kind,          // 0 ร่าง 2, 1 กระจาย (ร่าง 3), 2 เร็ว (ร่าง 4), 3 ลูกใหญ่ 16x16
    output reg          ev_shoot = 1'b0,  // pulse (เสียง): ยิงกระสุนผู้เล่น
    output reg  [1:0]   ev_shoot_k = 2'd0,// 0 ร่าง 2, 1 กระจาย, 2 นัดเร็ว, 3 ลูกใหญ่
    output reg          ev_melee = 1'b0,  // pulse: ฟัน
    output reg          ev_mdmg = 1'b0,   // pulse: มอนโดนตี
    output reg          ev_mdie = 1'b0,   // pulse: มอนตาย
    output wire         charged,          // ร่าง 4 ชาร์จเต็มแล้ว (ให้ผู้เล่นกะพริบ)
    output wire [15:0]  eb_act,
    output wire [159:0] eb_x, eb_y,
    output wire         melee_on,
    output wire [1:0]   melee_dir
);
    `include "params.vh"

    localparam NM = 6, NP = 6, NE = 16;
    localparam [10:0] OFS = 11'd64;          // บวกทุกพิกัดตอนเทียบ AABB กันค่าติดลบ (เช่น px - 12)
    localparam R_C1 = 3'd1, R_C2 = 3'd2;

    // ---------- slot ----------
    reg [5:0]  m_act = 0, m_typ = 0;
    reg [NM*10-1:0] m_xv = 0;
    reg [NM*10-1:0] m_yv = 0;
    reg [NM*3-1:0] m_hpv = 0;
    reg [NM*4-1:0] m_flv = 0;
    reg [NM*9-1:0] m_tmrv = 0;
    reg [5:0]  p_act = 0;
    reg [NP*10-1:0] p_xv = 0;
    reg [NP*10-1:0] p_yv = 0;
    reg [NP*3-1:0] p_dirv = 0;               // 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา 4 ลงซ้าย 5 ลงขวา 6 ขึ้นซ้าย 7 ขึ้นขวา
    reg [NP*2-1:0] p_kindv = 0;
    reg [NP-1:0]   p_child = 0;              // W13: ลูกที่แตกจากกระสุนร่าง 3 (ไม่แตกซ้ำ, มีอายุ)
    reg [NP*5-1:0] p_lifev = 0;
    reg [6:0]  chg = 0;                      // ร่าง 4: เฟรมที่กดค้าง
    reg        chg_ok = 1'b0;                // กดครั้งนี้ยิงนัดเร็ว (ไม่ใช่ฟัน) -> ชาร์จได้
    reg [15:0] e_act = 0;
    reg [NE*10-1:0] e_xv = 0;
    reg [NE*10-1:0] e_yv = 0;
    reg [NE*2-1:0] e_dirv = 0;

    reg [14:0] cleared = 0;                  // [floor*5 + room]
    reg [3:0]  cur_idx = 0;                  // ห้องที่ spawn ล่าสุด
    reg        cur_combat = 1'b0;

    reg [4:0]  melee_cnt = 0;
    reg [1:0]  mel_dir = 0;
    reg [5:0]  mel_mask = 0;                 // มอนที่โดนฟันครั้งนี้แล้ว
    reg        mel_boss = 1'b0;              // บอสโดนฟันครั้งนี้แล้ว
    reg        bfire_req = 1'b0;             // บอสขอยิง (ทำตอนประมวลผลเฟรมถัดไป)
    reg [4:0]  cool = 0;
    reg [6:0]  hurt_cnt = 0;                 // KB_FRAMES + INV_FRAMES .. 0
    reg        atk_req = 1'b0;
    reg [7:0]  fcnt = 0;
    reg        spawn_req = 1'b0;
    reg        summon_req = 1'b0;

    integer k;

    // ---------- tile ROM (2 อ่านต่อ clock) ----------
    reg  [11:0] ta = 0, tb = 0;
    wire [3:0]  tda, tdb;
    wire [7:0]  ova, ovb, ovt, ovm;
    tilemap_rom rom_a (.addr(ta), .brk(brk), .data(tda), .ov(ova));
    tilemap_rom rom_b (.addr(tb), .brk(brk), .data(tdb), .ov(ovb));
    `include "tilebase.vh"
    function [11:0] taddr(input [3:0] g, input [9:0] x, input [9:0] y);
        taddr = rbase(g) + rowx20(y[8:5]) + x[9:5];
    endfunction
    // W5: tile under the player's centre (spike trap) and under the centre of the melee box (breakable block)
    wire [11:0] addr_t = taddr(grid, px + 10'd16, py + 10'd16);
    tilemap_rom rom_t (.addr(addr_t), .brk(brk), .data(), .ov(ovt));
    wire trap_under = (ovt[3:0] == 4'd2);
    // กระสุน: หยุดที่ # ประตูปิด (D ตอนล็อก, L ตอนยังไม่เปิด, E); ผ่าน H F
    function bpass(input [3:0] t);
        case (t)
            4'h0, 4'h4: bpass = 1'b0;
            4'h2:       bpass = doors_open;
            4'h3:       bpass = open_L;
            default:    bpass = 1'b1;
        endcase
    endfunction
    // มอน: เดินได้แค่พื้น / แผ่น (ไม่ผ่าน # ประตูทุกแบบ H F)
    function mpass(input [3:0] t);
        mpass = (t == 4'h1) || (t == 4'h7) || (t >= 4'hB);
    endfunction

    function blocked(input [11:0] a);
        blocked = (blk_en[0] && a == blk0) || (blk_en[1] && a == blk1) || (blk_en[2] && a == blk2);
    endfunction

    // ---------- spawn ROM ----------
    reg  [2:0]  si = 0;
    wire [15:0] sd;
    spawn_rom srom (.addr({grid, si}), .data(sd));

    // ---------- AABB ----------
    function ovl(input [10:0] ax, input [10:0] ay, input [6:0] aw, input [6:0] ah,
                 input [10:0] bx, input [10:0] by, input [6:0] bw, input [6:0] bh);
        ovl = (ax < bx + bw) && (bx < ax + aw) && (ay < by + bh) && (by < ay + ah);
    endfunction

    reg [10:0] plx, ply, mbx, mby;           // คิดเฉพาะช่วงตรวจชน (ไม่เป็น logic ทุก clock)
    reg [6:0]  mbw, mbh;
    wire [9:0]  mcx = mbx[9:0] - 10'd64 + {5'd0, mbw[5:1]}, mcy = mby[9:0] - 10'd64 + {5'd0, mbh[5:1]};
    wire [11:0] addr_m = taddr(grid, mcx, mcy);
    tilemap_rom rom_m (.addr(addr_m), .brk(brk), .data(), .ov(ovm));

    // ---------- FSM ----------
    localparam [4:0] S_IDLE = 5'd0, S_SPAWN = 5'd1, S_ATK = 5'd2, S_PB = 5'd3, S_EB = 5'd4,
                     S_MON = 5'd5, S_FIRE = 5'd6, S_CPB = 5'd7, S_CMEL = 5'd8, S_CPM = 5'd9,
                     S_CPE = 5'd10, S_END = 5'd11, S_BFIRE = 5'd12, S_BPB = 5'd13, S_BMEL = 5'd14, S_BPM = 5'd15,
                     S_CLASH = 5'd16, S_NEAR = 5'd17, S_SUMMON = 5'd18, S_LOCK = 5'd19, S_LOCK2 = 5'd20;
    reg [4:0] st = S_IDLE;
    // มอน A เดินเฉพาะเฟรมที่ mv_div == 0 (MON_A_MOVE_EVERY = 1 -> ทุกเฟรม)
    reg [3:0] mv_div = 4'd0;
    always @(posedge clk) if (rst) mv_div <= 4'd0;
                          else if (frame_tick) mv_div <= (mv_div >= MON_A_MOVE_EVERY - 1) ? 4'd0 : mv_div + 4'd1;
    wire mon_go = (mv_div == 4'd0);
    reg [1:0] ph = 0;
    reg [3:0] i = 0, j = 0;                  // i = มอน / กระสุนผู้เล่น, j = กระสุนศัตรู
    reg [2:0] slot = 0, nb = 0, fk = 0;
    reg [9:0] nx = 0, ny = 0;                // ตำแหน่งถัดไป (เก็บข้าม 2 clock)

    assign busy = (st != S_IDLE);

    // ตัวช่วย: ทิศ -> ก้าว
    function [9:0] step_x(input [9:0] x, input [1:0] d, input [2:0] s);
        step_x = (d == 2'd2) ? x - s : (d == 2'd3) ? x + s : x;
    endfunction
    function [9:0] step_y(input [9:0] y, input [1:0] d, input [2:0] s);
        step_y = (d == 2'd1) ? y - s : (d == 2'd0) ? y + s : y;
    endfunction
    // ออกนอกจอ (กระสุน 8x8)
    function oob(input [9:0] x, input [1:0] d, input [2:0] s, input [9:0] y);
        oob = (d == 2'd2 && x < s) || (d == 2'd3 && x + s > 10'd632) ||
              (d == 2'd1 && y < s) || (d == 2'd0 && y + s > 10'd472);
    endfunction

    // ---------- กระสุนผู้เล่น ----------
    function dl(input [2:0] d); dl = (d == 3'd2) || (d == 3'd4) || (d == 3'd6); endfunction
    function dr(input [2:0] d); dr = (d == 3'd3) || (d == 3'd5) || (d == 3'd7); endfunction
    function du(input [2:0] d); du = (d == 3'd1) || (d == 3'd6) || (d == 3'd7); endfunction
    function dd(input [2:0] d); dd = (d == 3'd0) || (d == 3'd4) || (d == 3'd5); endfunction
    function [2:0] bspd(input [1:0] kd, input [2:0] d);
        bspd = d[2] ? SPREAD_DIAG : (kd == 2'd0) ? PB_SPEED : (kd == 2'd1) ? SPREAD_SPEED :
               (kd == 2'd2) ? TAP_SPEED : BIG_SPEED;
    endfunction
    function [2:0] bdmg(input [1:0] kd);
        bdmg = (kd == 2'd0) ? DMG2 : (kd == 2'd1) ? DMG3 : (kd == 2'd2) ? DMG4 : BIG_DMG;
    endfunction
    reg [2:0]  pk_s, pd_s;  reg [1:0] pk_k;
    reg [9:0]  px_s, py_s, nxx, nyy;
    reg [4:0]  psz;
    reg        pout;
    reg [10:0] fbx, fby; reg [6:0] fbw, fbh;
    // W18 auto-lock: nearest enemy (6 monsters + boss), 8-direction aim
    reg [11:0] best_d = 12'hFFF, dstm; reg signed [11:0] bdx = 0, bdy = 0, tdx, tdy, lax, lay; reg found = 1'b0, cand_act;
    reg [11:0] ccx, ccy; reg [2:0] aim_dir = 3'd0;
    wire [1:0] fe   = lock_use ? lock_face : facing;               // facing used by the melee box
    wire [2:0] aim8 = lock_use ? aim_dir : {1'b0, facing};         // direction of shots
    function [2:0] ring_p(input [2:0] d);                          // next direction clockwise (right, down-right, down, down-left, left, up-left, up, up-right)
        case (d) 3'd3: ring_p = 3'd5; 3'd5: ring_p = 3'd0; 3'd0: ring_p = 3'd4; 3'd4: ring_p = 3'd2;
                 3'd2: ring_p = 3'd6; 3'd6: ring_p = 3'd1; 3'd1: ring_p = 3'd7; default: ring_p = 3'd3; endcase
    endfunction
    function [2:0] ring_m(input [2:0] d);                          // previous direction
        case (d) 3'd3: ring_m = 3'd7; 3'd5: ring_m = 3'd3; 3'd0: ring_m = 3'd5; 3'd4: ring_m = 3'd0;
                 3'd2: ring_m = 3'd4; 3'd6: ring_m = 3'd2; 3'd1: ring_m = 3'd6; default: ring_m = 3'd1; endcase
    endfunction
    reg        near, sp_done;
    reg        near_r = 1'b0;
    reg [5:0]  freev;
    reg [15:0] clash;
    reg [15:0] clash_r = 16'd0;
    reg [2:0]  sdir [0:2];
    integer    q, nsp;

    // ทิศ knockback: หนีจากจุดศูนย์กลางของสิ่งที่ชน (แกนที่ห่างกว่า)
    function [1:0] away(input [9:0] sx, input [9:0] sy);
        reg signed [11:0] dx, dy, ax, ay;
        begin
            dx = $signed({2'b00, px}) + 12'sd16 - $signed({2'b00, sx});
            dy = $signed({2'b00, py}) + 12'sd16 - $signed({2'b00, sy});
            ax = (dx < 0) ? -dx : dx;
            ay = (dy < 0) ? -dy : dy;
            if (ax >= ay) away = (dx >= 0) ? 2'd3 : 2'd2;
            else          away = (dy >= 0) ? 2'd0 : 2'd1;
        end
    endfunction

    wire [3:0] idx_now = {2'b00, floor} * 4'd5 + {1'b0, room};

    always @(posedge clk) begin
        if (st >= S_CPB) begin
            plx = {1'b0, px} + OFS + HURT_OFS;              // hitbox ผู้เล่น (ที่โดนตี): HURT_BOX x HURT_BOX กลาง sprite (params.vh)
            ply = {1'b0, py} + OFS + HURT_OFS;
            mbx = (mel_dir == 2'd2) ? {1'b0, px} + OFS - 11'd12 :     // hit box ฟันประชิด
                  (mel_dir == 2'd3) ? {1'b0, px} + OFS + 11'd28 : {1'b0, px} + OFS + 11'd4;
            mby = (mel_dir == 2'd0) ? {1'b0, py} + OFS + 11'd28 :
                  (mel_dir == 2'd1) ? {1'b0, py} + OFS - 11'd12 : {1'b0, py} + OFS + 11'd4;
            mbw = mel_dir[1] ? 7'd16 : 7'd24;
            mbh = mel_dir[1] ? 7'd24 : 7'd16;
        end
        hit <= 1'b0;
        kb_start <= 1'b0;
        ev_shoot <= 1'b0; ev_melee <= 1'b0; ev_mdmg <= 1'b0; ev_mdie <= 1'b0;
        if (atk_press && run) atk_req <= 1'b1;
        if (!run) atk_req <= 1'b0;
        if (room_load) spawn_req <= 1'b1;
        boss_dmg <= 1'b0; boss_dmg_big <= 1'b0; brk_set <= 1'b0;
        if (boss_fire) bfire_req <= 1'b1;
        if (summon) summon_req <= 1'b1;
        if (dbg_clear && st == S_IDLE && !spawn_req) m_act <= 0;   // ห้องเคลียร์ที่ S_END ของเฟรมถัดไป

        if (rst || restart) begin
            cleared <= 0;
            hurt_cnt <= 0; cool <= 0; melee_cnt <= 0; chg <= 0; chg_ok <= 1'b0;
            m_act <= 0; p_act <= 0; e_act <= 0;
            st <= S_IDLE;
            if (rst) spawn_req <= 1'b1;
        end else case (st)
        // ------------------------------------------------------------------
        S_IDLE:
            if (spawn_req) begin
                spawn_req <= 1'b0; summon_req <= 1'b0;
                m_act <= 0; p_act <= 0; e_act <= 0; melee_cnt <= 0; bfire_req <= 1'b0;
                cur_idx <= idx_now;
                cur_combat <= (room == R_C1) || (room == R_C2);
                si <= 0; slot <= 0; nb <= 0;
                st <= S_SPAWN;
            end else if (summon_req) begin
                summon_req <= 1'b0;
                st <= S_SUMMON;
            end else if (frame_tick && run) begin
                fcnt <= fcnt + 1'b1;
                if (auto_lock) begin i <= 0; best_d <= 12'hFFF; found <= 1'b0; st <= S_LOCK; end
                else begin lock_use <= 1'b0; st <= S_NEAR; end
            end
        // ------------------------------------------------------------------
        S_SUMMON: begin                      // W11: ลูกน้องบอส 2 = มอน A BOSS2_MINIONS ตัว ลง slot ว่าง (ตำแหน่ง SUMMON0..2)
            nsp = 0;
            for (q = 0; q < NM; q = q + 1)
                if (!m_act[q] && nsp < BOSS2_MINIONS) begin
                    m_act[q] <= 1'b1; m_typ[q] <= 1'b0;
                    m_xv[q*10 +: 10] <= {(nsp == 0) ? SUMMON0_TX : (nsp == 1) ? SUMMON1_TX : SUMMON2_TX, 5'd0};
                    m_yv[q*10 +: 10] <= {1'b0, (nsp == 0) ? SUMMON0_TY : (nsp == 1) ? SUMMON1_TY : SUMMON2_TY, 5'd0};
                    m_hpv[q*3 +: 3] <= MON_A_HP; m_flv[q*4 +: 4] <= 0; m_tmrv[q*9 +: 9] <= 0;
                    nsp = nsp + 1;
                end
            st <= S_IDLE;
        end
        // ------------------------------------------------------------------
        S_LOCK: begin                        // W18: one candidate per clock (monsters 0..5, boss = 6)
            if (i < NM) begin cand_act = m_act[i]; ccx = {2'b00, m_xv[i*10 +: 10]} + 12'd16; ccy = {2'b00, m_yv[i*10 +: 10]} + 12'd16; end
            else        begin cand_act = boss_act; ccx = {2'b00, boss_x} + 12'd32; ccy = {2'b00, boss_y} + 12'd32; end
            tdx = ccx - ({2'b00, px} + 12'd16); tdy = ccy - ({2'b00, py} + 12'd16);
            dstm = (tdx[11] ? -tdx : tdx) + (tdy[11] ? -tdy : tdy);
            if (cand_act && dstm < LOCK_RANGE && dstm < best_d) begin best_d <= dstm; bdx <= tdx; bdy <= tdy; found <= 1'b1; end
            if (i == NM) st <= S_LOCK2; else i <= i + 1'b1;
        end
        S_LOCK2: begin                       // W18: target vector -> 8 directions (|dx| >= 2|dy| horizontal, |dy| >= 2|dx| vertical, else diagonal)
            lax = bdx[11] ? -bdx : bdx; lay = bdy[11] ? -bdy : bdy;
            lock_use <= found;
            if (lax >= 2 * lay)       aim_dir <= bdx[11] ? 3'd2 : 3'd3;
            else if (lay >= 2 * lax)  aim_dir <= bdy[11] ? 3'd1 : 3'd0;
            else aim_dir <= bdx[11] ? (bdy[11] ? 3'd6 : 3'd4) : (bdy[11] ? 3'd7 : 3'd5);
            lock_face <= (lax >= lay) ? (bdx[11] ? 2'd2 : 2'd3) : (bdy[11] ? 2'd1 : 2'd0);
            st <= S_NEAR;
        end
        // ------------------------------------------------------------------
        S_NEAR: begin                        // มีศัตรูในกล่องฟันหน้าตัวไหม (ผลเก็บใน near_r ให้ S_ATK ใช้; แยก state เพื่อไม่ให้ 7 overlap ต่อกับ logic ยิงใน clock เดียว)
            fbx = (fe == 2'd2) ? {1'b0, px} + OFS - 11'd12 :
                  (fe == 2'd3) ? {1'b0, px} + OFS + 11'd28 : {1'b0, px} + OFS + 11'd4;
            fby = (fe == 2'd0) ? {1'b0, py} + OFS + 11'd28 :
                  (fe == 2'd1) ? {1'b0, py} + OFS - 11'd12 : {1'b0, py} + OFS + 11'd4;
            fbw = fe[1] ? 7'd16 : 7'd24;
            fbh = fe[1] ? 7'd24 : 7'd16;
            near = boss_act && ovl(fbx, fby, fbw, fbh, {1'b0, boss_x} + OFS + 11'd8, {1'b0, boss_y} + OFS + 11'd8, 7'd48, 7'd48);
            for (q = 0; q < NM; q = q + 1)
                if (m_act[q] && ovl(fbx, fby, fbw, fbh, {1'b0, m_xv[q*10 +: 10]} + OFS + 11'd4,
                                    {1'b0, m_yv[q*10 +: 10]} + OFS + 11'd4, 7'd24, 7'd24)) near = 1'b1;
            near_r <= near;
            st <= S_ATK;
        end
        // ------------------------------------------------------------------
        S_SPAWN: begin                       // 8 entry ต่อห้อง, 1 clock / entry
            if (sd[15] && !cleared[cur_idx] && slot < NM) begin
                m_act[slot] <= 1'b1;
                m_typ[slot] <= sd[12];
                m_xv[(slot)*10 +: 10]   <= {sd[4:0], 5'd0};
                m_yv[(slot)*10 +: 10]   <= {sd[11:8], 5'd0};
                m_flv[(slot)*4 +: 4]  <= 0;
                if (sd[12]) begin
                    m_hpv[(slot)*3 +: 3]  <= MON_B_HP;
                    m_tmrv[(slot)*9 +: 9] <= TURRET_FIRST + nb * TURRET_PHASE - 1;
                    nb <= nb + 1'b1;
                end else begin
                    m_hpv[(slot)*3 +: 3]  <= MON_A_HP;
                    m_tmrv[(slot)*9 +: 9] <= 0;
                end
                slot <= slot + 1'b1;
            end
            si <= si + 1'b1;
            if (si == 3'd7) st <= S_IDLE;
        end
        // ------------------------------------------------------------------
        S_ATK: begin
            if (hurt_cnt != 0) hurt_cnt <= hurt_cnt - 1'b1;
            if (melee_cnt != 0) melee_cnt <= melee_cnt - 1'b1;
            atk_req <= 1'b0;
            // near_r (คำนวณใน S_NEAR): มีศัตรูในกล่องฟันหน้าตัวไหม (ร่าง 2-4: กดแล้วฟันแทนยิง)
            // ร่าง 4: นับเฟรมที่กดค้าง; ปล่อยหลังชาร์จเต็ม = ลูกใหญ่ (มีได้ทีละลูก)
            if (form == 2'd3 && chg_ok && atk_hold) begin
                if (chg < CHARGE_FRAMES) chg <= chg + 1'b1;
            end else begin
                if (form == 2'd3 && chg_ok && chg >= CHARGE_FRAMES) begin
                    sp_done = 1'b0;
                    for (q = 0; q < NP; q = q + 1)
                        if (p_act[q] && p_kindv[q*2 +: 2] == 2'd3) sp_done = 1'b1;   // มีลูกใหญ่อยู่แล้ว
                    for (q = 0; q < NP; q = q + 1)
                        if (!sp_done && !p_act[q]) begin
                            p_act[q] <= 1'b1; p_kindv[q*2 +: 2] <= 2'd3; p_dirv[q*3 +: 3] <= aim8; p_child[q] <= 1'b0;
                            p_xv[q*10 +: 10] <= px + 10'd8; p_yv[q*10 +: 10] <= py + 10'd8;
                            sp_done = 1'b1; ev_shoot <= 1'b1; ev_shoot_k <= 2'd3;
                        end
                end
                chg <= 0; chg_ok <= 1'b0;
            end
            if (cool != 0) cool <= cool - 1'b1;
            else if (atk_req && (form == 2'd0 || near_r)) begin      // ฟันประชิด (ร่าง 1 เสมอ, ร่าง 2-4 เมื่อศัตรูอยู่ในกล่อง)
                melee_cnt <= MELEE_FRAMES; ev_melee <= 1'b1;
                mel_dir   <= fe;
                mel_mask  <= 0;
                mel_boss  <= 1'b0;
                cool      <= MELEE_COOLDOWN - 1;
            end else if (form != 2'd0 && (atk_req || (atk_hold && form != 2'd3))) begin
                // ยิง: ร่าง 2 นัดเดียว, ร่าง 3 กระจาย 3 ทาง, ร่าง 4 นัดเร็ว (+ เริ่มชาร์จ) — ค้างยิงซ้ำเฉพาะร่าง 2-3
                freev = ~p_act;
                pk_k = (form == 2'd1) ? 2'd0 : (form == 2'd2) ? 2'd1 : 2'd2;
                sdir[0] = aim8;
                sdir[1] = lock_use ? ring_m(aim8) : (facing == 2'd0) ? 3'd4 : (facing == 2'd1) ? 3'd6 : (facing == 2'd2) ? 3'd6 : 3'd7;
                sdir[2] = lock_use ? ring_p(aim8) : (facing == 2'd0) ? 3'd5 : (facing == 2'd1) ? 3'd7 : (facing == 2'd2) ? 3'd4 : 3'd5;
                nsp = 0;
                for (q = 0; q < NP; q = q + 1)
                    if (freev[q] && nsp < ((form == 2'd2) ? AOE_PARENTS : 1)) begin
                        p_child[q] <= 1'b0;
                        p_act[q] <= 1'b1; p_kindv[q*2 +: 2] <= pk_k; p_dirv[q*3 +: 3] <= sdir[nsp];
                        p_xv[q*10 +: 10] <= px + 10'd12; p_yv[q*10 +: 10] <= py + 10'd12;
                        nsp = nsp + 1;
                    end
                if (nsp != 0) begin ev_shoot <= 1'b1; ev_shoot_k <= pk_k; end
                if (nsp != 0) cool <= (form == 2'd1) ? PB_COOLDOWN - 1 : (form == 2'd2) ? SPREAD_COOLDOWN - 1 : TAP_COOLDOWN - 1;
                if (form == 2'd3 && atk_req) begin chg_ok <= 1'b1; chg <= 0; end
            end
            i <= 0; ph <= 0;
            st <= S_PB;
        end
        // ------------------------------------------------------------------
        S_PB: if (ph == 0) begin             // กระสุนผู้เล่น: 8 ทิศ, ตรวจ tile ปลายทาง + ช่องที่ขยับแกน x อย่างเดียว
            pk_k = p_kindv[i[2:0]*2 +: 2]; pd_s = p_dirv[i[2:0]*3 +: 3];
            pk_s = bspd(pk_k, pd_s); psz = (pk_k == 2'd3) ? 5'd16 : 5'd8;
            px_s = p_xv[i[2:0]*10 +: 10]; py_s = p_yv[i[2:0]*10 +: 10];
            pout = (dl(pd_s) && px_s < pk_s) || (dr(pd_s) && px_s + pk_s > 10'd640 - psz) ||
                   (du(pd_s) && py_s < pk_s) || (dd(pd_s) && py_s + pk_s > 10'd480 - psz);
            nxx = dl(pd_s) ? px_s - pk_s : dr(pd_s) ? px_s + pk_s : px_s;
            nyy = du(pd_s) ? py_s - pk_s : dd(pd_s) ? py_s + pk_s : py_s;
            if (!p_act[i[2:0]] || pout) begin
                if (pout) p_act[i[2:0]] <= 1'b0;
                if (i == NP - 1) begin j <= 0; st <= S_EB; end
                i <= i + 1'b1;
            end else begin
                nx <= nxx; ny <= nyy;
                ta <= taddr(grid, nxx + psz[4:1], nyy + psz[4:1]);   // ปลายทาง
                tb <= taddr(grid, nxx + psz[4:1], py_s + psz[4:1]);  // ขยับแกน x อย่างเดียว
                ph <= 1;
            end
        end else begin                       // ph 1: ตัดสินจาก tile (กำแพง / ประตูปิด / กล่อง = หยุด, H F ผ่าน)
            if (bpass(tda) && !blocked(ta) && bpass(tdb) && !blocked(tb)) begin
                p_xv[i[2:0]*10 +: 10] <= nx; p_yv[i[2:0]*10 +: 10] <= ny;
                if (p_child[i[2:0]]) begin                           // ลูกที่แตก: หมดอายุ SPLIT_LIFE เฟรม
                    if (p_lifev[i[2:0]*5 +: 5] == 0) p_act[i[2:0]] <= 1'b0;
                    else p_lifev[i[2:0]*5 +: 5] <= p_lifev[i[2:0]*5 +: 5] - 1'b1;
                end
            end else begin
                p_act[i[2:0]] <= 1'b0;
                // W5: กระสุนหยุดที่บล็อกพังได้ (ปลายทาง ta หรือช่อง x tb) -> พัง (1 ที)
                if (ova[3:0] == 4'd1 && !brk[ova[6:4]]) begin brk_set <= 1'b1; brk_idx <= ova[6:4]; end
                else if (ovb[3:0] == 4'd1 && !brk[ovb[6:4]]) begin brk_set <= 1'b1; brk_idx <= ovb[6:4]; end
            end
            ph <= 0;
            if (i == NP - 1) begin j <= 0; st <= S_EB; end
            i <= i + 1'b1;
        end
        // ------------------------------------------------------------------
        S_EB: if (ph == 0) begin             // กระสุนศัตรู
            if (!e_act[j]) begin
                if (j == NE - 1) begin i <= 0; st <= S_MON; end
                j <= j + 1'b1;
            end else if (oob(e_xv[(j)*10 +: 10], e_dirv[(j)*2 +: 2], EB_SPEED, e_yv[(j)*10 +: 10])) begin
                e_act[j] <= 1'b0;
                if (j == NE - 1) begin i <= 0; st <= S_MON; end
                j <= j + 1'b1;
            end else begin
                nx <= step_x(e_xv[(j)*10 +: 10], e_dirv[(j)*2 +: 2], EB_SPEED);
                ny <= step_y(e_yv[(j)*10 +: 10], e_dirv[(j)*2 +: 2], EB_SPEED);
                ta <= taddr(grid, step_x(e_xv[(j)*10 +: 10], e_dirv[(j)*2 +: 2], EB_SPEED) + 10'd4,
                                  step_y(e_yv[(j)*10 +: 10], e_dirv[(j)*2 +: 2], EB_SPEED) + 10'd4);
                ph <= 1;
            end
        end else begin
            if (bpass(tda) && !blocked(ta)) begin e_xv[(j)*10 +: 10] <= nx; e_yv[(j)*10 +: 10] <= ny; end
            else e_act[j] <= 1'b0;
            ph <= 0;
            if (j == NE - 1) begin i <= 0; st <= S_MON; end
            j <= j + 1'b1;
        end
        // ------------------------------------------------------------------
        S_MON: begin
            case (ph)
            2'd0: begin
                if (m_flv[(i)*4 +: 4] != 0) m_flv[(i)*4 +: 4] <= m_flv[(i)*4 +: 4] - 1'b1;
                if (!m_act[i]) begin
                    if (i == NM - 1) begin i <= 0; j <= 0; st <= S_CPB; end
                    else i <= i + 1'b1;
                end else if (m_typ[i]) begin                  // มอน B: นับเวลายิง
                    if (m_tmrv[(i)*9 +: 9] == 0) begin
                        m_tmrv[(i)*9 +: 9] <= TURRET_PERIOD - 1;
                        fk <= 0; j <= 0;
                        st <= S_FIRE;
                    end else begin
                        m_tmrv[(i)*9 +: 9] <= m_tmrv[(i)*9 +: 9] - 1'b1;
                        if (i == NM - 1) begin i <= 0; j <= 0; st <= S_CPB; end
                        else i <= i + 1'b1;
                    end
                end else if (mon_go && px != m_xv[(i)*10 +: 10]) begin           // มอน A แกน x (mon_go: เดินทุก MON_A_MOVE_EVERY เฟรม)
                    if (px > m_xv[(i)*10 +: 10]) begin
                        nx <= m_xv[(i)*10 +: 10] + MON_A_SPEED;
                        ta <= taddr(grid, m_xv[(i)*10 +: 10] + MON_A_SPEED + 10'd27, m_yv[(i)*10 +: 10] + 10'd4);
                        tb <= taddr(grid, m_xv[(i)*10 +: 10] + MON_A_SPEED + 10'd27, m_yv[(i)*10 +: 10] + 10'd27);
                    end else begin
                        nx <= m_xv[(i)*10 +: 10] - MON_A_SPEED;
                        ta <= taddr(grid, m_xv[(i)*10 +: 10] - MON_A_SPEED + 10'd4, m_yv[(i)*10 +: 10] + 10'd4);
                        tb <= taddr(grid, m_xv[(i)*10 +: 10] - MON_A_SPEED + 10'd4, m_yv[(i)*10 +: 10] + 10'd27);
                    end
                    ph <= 2'd1;
                end else ph <= 2'd2;
            end
            2'd1: begin
                if (mpass(tda) && mpass(tdb) && !blocked(ta) && !blocked(tb)) m_xv[(i)*10 +: 10] <= nx;
                ph <= 2'd2;
            end
            2'd2: begin                                         // มอน A แกน y
                if (mon_go && py != m_yv[(i)*10 +: 10]) begin
                    if (py > m_yv[(i)*10 +: 10]) begin
                        ny <= m_yv[(i)*10 +: 10] + MON_A_SPEED;
                        ta <= taddr(grid, m_xv[(i)*10 +: 10] + 10'd4,  m_yv[(i)*10 +: 10] + MON_A_SPEED + 10'd27);
                        tb <= taddr(grid, m_xv[(i)*10 +: 10] + 10'd27, m_yv[(i)*10 +: 10] + MON_A_SPEED + 10'd27);
                    end else begin
                        ny <= m_yv[(i)*10 +: 10] - MON_A_SPEED;
                        ta <= taddr(grid, m_xv[(i)*10 +: 10] + 10'd4,  m_yv[(i)*10 +: 10] - MON_A_SPEED + 10'd4);
                        tb <= taddr(grid, m_xv[(i)*10 +: 10] + 10'd27, m_yv[(i)*10 +: 10] - MON_A_SPEED + 10'd4);
                    end
                    ph <= 2'd3;
                end else begin
                    ph <= 2'd0;
                    if (i == NM - 1) begin i <= 0; j <= 0; st <= S_CPB; end
                    else i <= i + 1'b1;
                end
            end
            default: begin
                if (mpass(tda) && mpass(tdb) && !blocked(ta) && !blocked(tb)) m_yv[(i)*10 +: 10] <= ny;
                ph <= 2'd0;
                if (i == NM - 1) begin i <= 0; j <= 0; st <= S_CPB; end
                else i <= i + 1'b1;
            end
            endcase
        end
        // ------------------------------------------------------------------
        S_FIRE: begin                        // มอน B ตัวที่ i ยิง 4 ทิศ ลง slot ว่าง (1 clock / slot)
            if (!e_act[j] && fk < 4) begin
                e_act[j] <= 1'b1;
                e_xv[(j)*10 +: 10]   <= m_xv[(i)*10 +: 10] + 10'd12;
                e_yv[(j)*10 +: 10]   <= m_yv[(i)*10 +: 10] + 10'd12;
                e_dirv[(j)*2 +: 2] <= fk[1:0];
                fk <= fk + 1'b1;
            end
            j <= j + 1'b1;
            if (j == NE - 1 || (fk == 3'd3 && !e_act[j])) begin
                ph <= 0;
                if (i == NM - 1) begin i <= 0; j <= 0; st <= S_CPB; end
                else begin i <= i + 1'b1; st <= S_MON; end
            end
        end
        // ------------------------------------------------------------------
        S_CPB: begin                         // กระสุนผู้เล่น j x มอน i (6 x 6 คู่); ทุกชนิดหายเมื่อโดน (W3)
            pk_k = p_kindv[j[2:0]*2 +: 2]; psz = (pk_k == 2'd3) ? 5'd16 : 5'd8;
            if (p_act[j[2:0]] && m_act[i] &&
                ovl({1'b0, p_xv[j[2:0]*10 +: 10]} + OFS, {1'b0, p_yv[j[2:0]*10 +: 10]} + OFS, {2'b00, psz}, {2'b00, psz},
                    {1'b0, m_xv[(i)*10 +: 10]} + OFS + 11'd4, {1'b0, m_yv[(i)*10 +: 10]} + OFS + 11'd4, 7'd24, 7'd24)) begin
                if (pk_k == 2'd1 && !p_child[j[2:0]]) begin       // W13: กระสุนร่าง 3 โดนมอน -> แตก 4 ทิศ (ลง ขึ้น ซ้าย ขวา) จากกลางมอน
                    p_dirv[j[2:0]*3 +: 3] <= 3'd0; p_child[j[2:0]] <= 1'b1; p_lifev[j[2:0]*5 +: 5] <= SPLIT_LIFE;
                    p_xv[j[2:0]*10 +: 10] <= m_xv[(i)*10 +: 10] + 10'd12; p_yv[j[2:0]*10 +: 10] <= m_yv[(i)*10 +: 10] + 10'd28;
                    nsp = 1;
                    for (q = 0; q < NP; q = q + 1)
                        if (!p_act[q] && nsp < 4) begin
                            p_act[q] <= 1'b1; p_kindv[q*2 +: 2] <= 2'd1; p_child[q] <= 1'b1; p_lifev[q*5 +: 5] <= SPLIT_LIFE;
                            p_dirv[q*3 +: 3] <= nsp[2:0];
                            p_xv[q*10 +: 10] <= m_xv[(i)*10 +: 10] + ((nsp == 2) ? 10'd12 - 10'd16 : (nsp == 3) ? 10'd12 + 10'd16 : 10'd12);
                            p_yv[q*10 +: 10] <= m_yv[(i)*10 +: 10] + ((nsp == 1) ? 10'd12 - 10'd16 : 10'd12);
                            nsp = nsp + 1;
                        end
                end else p_act[j[2:0]] <= 1'b0;               // W3: ลูกใหญ่หยุดเมื่อโดน (ไม่ทะลุแล้ว)
                m_flv[(i)*4 +: 4] <= MON_FLASH; ev_mdmg <= 1'b1;
                if (m_hpv[(i)*3 +: 3] <= bdmg(pk_k)) begin m_hpv[(i)*3 +: 3] <= 0; m_act[i] <= 1'b0; ev_mdie <= 1'b1; end
                else m_hpv[(i)*3 +: 3] <= m_hpv[(i)*3 +: 3] - bdmg(pk_k);
            end
            if (i == NM - 1) begin
                i <= 0;
                if (j == NP - 1) begin j <= 0; st <= S_CMEL; end
                else j <= j + 1'b1;
            end else i <= i + 1'b1;
        end
        S_CMEL: begin                        // ฟันประชิด x มอน (ครั้งละ 1 ทีต่อการฟัน)
            if (melee_cnt != 0 && m_act[i] && !mel_mask[i] &&
                ovl(mbx, mby, mbw, mbh,
                    {1'b0, m_xv[(i)*10 +: 10]} + OFS + 11'd4, {1'b0, m_yv[(i)*10 +: 10]} + OFS + 11'd4, 7'd24, 7'd24)) begin
                mel_mask[i] <= 1'b1;
                m_flv[(i)*4 +: 4] <= MON_FLASH; ev_mdmg <= 1'b1;
                if (m_hpv[(i)*3 +: 3] <= damage) begin m_hpv[(i)*3 +: 3] <= 0; m_act[i] <= 1'b0; ev_mdie <= 1'b1; end
                else m_hpv[(i)*3 +: 3] <= m_hpv[(i)*3 +: 3] - damage;
            end
            // W5: ฟันโดนบล็อกพังได้ตรงกลางกล่องฟัน -> พัง
            if (i == 0 && melee_cnt != 0 && ovm[3:0] == 4'd1 && !brk[ovm[6:4]] && mcx < 10'd640 && mcy < 10'd480) begin
                brk_set <= 1'b1; brk_idx <= ovm[6:4];
            end
            if (i == NM - 1) begin i <= 0; st <= S_CPM; end
            else i <= i + 1'b1;
        end
        S_CPM: begin                         // ผู้เล่น x มอน (ชนตัว) + W5 กับดักหนาม
            // กับดัก: ยืนบนหนาม (ร่าง 3 บินผ่าน) -> HP -1 + knockback ถอยหลังตามทิศที่หัน (ใช้ช่วงอมตะเดียวกัน)
            if (i == 0 && hurt_cnt == 0 && trap_under && form != 2'd2) begin
                hit <= 1'b1; kb_start <= 1'b1;
                kb_dir <= (facing == 2'd0) ? 2'd1 : (facing == 2'd1) ? 2'd0 : (facing == 2'd2) ? 2'd3 : 2'd2;
                hurt_cnt <= KB_FRAMES + INV_FRAMES;
            end
            if (hurt_cnt == 0 && m_act[i] &&
                ovl(plx, ply, HURT_BOX, HURT_BOX,
                    {1'b0, m_xv[(i)*10 +: 10]} + OFS + 11'd4, {1'b0, m_yv[(i)*10 +: 10]} + OFS + 11'd4, 7'd24, 7'd24)) begin
                hit <= 1'b1; kb_start <= 1'b1;
                kb_dir <= away(m_xv[(i)*10 +: 10] + 10'd16, m_yv[(i)*10 +: 10] + 10'd16);
                hurt_cnt <= KB_FRAMES + INV_FRAMES;
            end
            if (i == NM - 1) begin j <= 0; st <= S_CPE; end
            else i <= i + 1'b1;
        end
        S_CPE: begin                         // ผู้เล่น x กระสุนศัตรู (อมตะ = กระสุนทะลุ)
            if (hurt_cnt == 0 && e_act[j] &&
                ovl(plx, ply, HURT_BOX, HURT_BOX, {1'b0, e_xv[(j)*10 +: 10]} + OFS, {1'b0, e_yv[(j)*10 +: 10]} + OFS, 7'd8, 7'd8)) begin
                e_act[j] <= 1'b0;
                hit <= 1'b1; kb_start <= 1'b1;
                kb_dir <= away(e_xv[(j)*10 +: 10] + 10'd4, e_yv[(j)*10 +: 10] + 10'd4);
                hurt_cnt <= KB_FRAMES + INV_FRAMES;
            end
            if (j == NE - 1) begin j <= 0; st <= S_CLASH; end
            else j <= j + 1'b1;
        end
        S_CLASH: begin                       // กระสุนผู้เล่น j x กระสุนศัตรูทั้ง 16: ชนกันหายทั้งคู่, ลูกใหญ่ไปต่อ
            pk_k = p_kindv[j[2:0]*2 +: 2]; psz = (pk_k == 2'd3) ? 5'd16 : 5'd8;
            if (ph == 0) begin               // phase 0: เทียบ 16 คู่ขนานกัน -> เก็บผลใน register clash_r
                clash = 0;
                for (q = 0; q < NE; q = q + 1)
                    if (p_act[j[2:0]] && e_act[q] &&
                        ovl({1'b0, p_xv[j[2:0]*10 +: 10]} + OFS, {1'b0, p_yv[j[2:0]*10 +: 10]} + OFS, {2'b00, psz}, {2'b00, psz},
                            {1'b0, e_xv[q*10 +: 10]} + OFS, {1'b0, e_yv[q*10 +: 10]} + OFS, 7'd8, 7'd8)) clash[q] = 1'b1;
                clash_r <= clash;
                ph <= 1;
            end else begin                   // phase 1: ใช้ผล (ไม่มี compare ใน clock นี้)
                if (clash_r != 0) begin
                    e_act <= e_act & ~clash_r;
                    if (pk_k != 2'd3) p_act[j[2:0]] <= 1'b0;
                end
                ph <= 0;
                if (j == NP - 1) begin j <= 0; fk <= 0; st <= S_BFIRE; end
                else j <= j + 1'b1;
            end
        end
        // ------------------------------------------------------------------ บอส
        S_BFIRE: begin                       // บอสยิง 4 ทิศ ลง slot กระสุนศัตรูที่ว่าง (1 clock / slot)
            if (!bfire_req || !boss_act) begin bfire_req <= 1'b0; j <= 0; st <= S_BPB; end
            else begin
                if (!e_act[j] && fk < 4) begin
                    e_act[j] <= 1'b1;
                    e_xv[(j)*10 +: 10] <= boss_x + 10'd28;
                    e_yv[(j)*10 +: 10] <= boss_y + 10'd28;
                    e_dirv[(j)*2 +: 2] <= fk[1:0];
                    fk <= fk + 1'b1;
                end
                j <= j + 1'b1;
                if (j == NE - 1 || (fk == 3'd3 && !e_act[j])) begin bfire_req <= 1'b0; j <= 0; st <= S_BPB; end
            end
        end
        S_BPB: begin                         // กระสุนผู้เล่น j x บอส (ลูกใหญ่โดนบอสครั้งเดียวต่อลูก)
            pk_k = p_kindv[j[2:0]*2 +: 2]; psz = (pk_k == 2'd3) ? 5'd16 : 5'd8;
            if (boss_act && p_act[j[2:0]] &&
                ovl({1'b0, p_xv[j[2:0]*10 +: 10]} + OFS, {1'b0, p_yv[j[2:0]*10 +: 10]} + OFS, {2'b00, psz}, {2'b00, psz},
                    {1'b0, boss_x} + OFS + 11'd8, {1'b0, boss_y} + OFS + 11'd8, 7'd48, 7'd48)) begin
                p_act[j[2:0]] <= 1'b0;               // W3: ลูกใหญ่หยุดเมื่อโดนบอส
                boss_dmg <= 1'b1; boss_dmg_amt <= bdmg(pk_k); boss_dmg_big <= (pk_k == 2'd3);
            end
            if (j == NP - 1) st <= S_BMEL;
            j <= j + 1'b1;
        end
        S_BMEL: begin                        // ฟันประชิด x บอส (1 ทีต่อการฟัน)
            if (boss_act && melee_cnt != 0 && !mel_boss &&
                ovl(mbx, mby, mbw, mbh, {1'b0, boss_x} + OFS + 11'd8, {1'b0, boss_y} + OFS + 11'd8, 7'd48, 7'd48)) begin
                mel_boss <= 1'b1;
                boss_dmg <= 1'b1; boss_dmg_amt <= {1'b0, damage};
            end
            st <= S_BPM;
        end
        S_BPM: begin                         // ผู้เล่น x บอส (ชนตัว)
            if (boss_act && hurt_cnt == 0 &&
                ovl(plx, ply, HURT_BOX, HURT_BOX, {1'b0, boss_x} + OFS + 11'd8, {1'b0, boss_y} + OFS + 11'd8, 7'd48, 7'd48)) begin
                hit <= 1'b1; kb_start <= 1'b1;
                kb_dir <= away(boss_x + 10'd32, boss_y + 10'd32);
                hurt_cnt <= KB_FRAMES + INV_FRAMES;
            end
            st <= S_END;
        end
        // ------------------------------------------------------------------
        S_END: begin
            if (cur_combat && m_act == 0) cleared[cur_idx] <= 1'b1;
            st <= S_IDLE;
        end
        default: st <= S_IDLE;
        endcase
    end

    // ---------- outputs ----------
    assign alive = m_act[0] + m_act[1] + m_act[2] + m_act[3] + m_act[4] + m_act[5];
    assign doors_open = !(cur_combat && m_act != 0) && !boss_act;   // ห้อง Combat ที่มีมอน / ห้องบอสที่บอสยังอยู่ = ประตูปิด
    assign invuln = (hurt_cnt != 0);
    assign player_blink = (hurt_cnt != 0) && hurt_cnt[2];
    assign mon_act = m_act;
    assign mon_x = m_xv;
    assign mon_y = m_yv;
    assign pb_x = p_xv;
    assign pb_y = p_yv;
    assign eb_x = e_xv;
    assign eb_y = e_yv;
    assign mon_type = m_typ;
    assign mon_anim = fcnt[4];
    assign pb_act = p_act;
    assign pb_kind = p_kindv;
    assign charged = (form == 2'd3) && chg_ok && (chg >= CHARGE_FRAMES);
    assign eb_act = e_act;
    assign melee_on = (melee_cnt != 0);
    assign melee_dir = mel_dir;
    genvar g;
    generate
        for (g = 0; g < NM; g = g + 1) begin : gm
            assign mon_flash[g] = (m_flv[(g)*4 +: 4] != 0) && m_flv[(g)*4 + 1];
        end
    endgenerate
endmodule
