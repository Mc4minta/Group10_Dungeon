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
// hitbox: ผู้เล่น / มอน = พิกเซล 4..27 ของ sprite 32x32 (24x24), กระสุน 8x8 ทั้งก้อน
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
    output reg          boss_dmg = 1'b0,  // pulse: บอสโดนกระสุน / ฟัน
    output reg  [1:0]   boss_dmg_amt = 2'd0,
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
    output wire [1:0]   pb_act,
    output wire [19:0]  pb_x, pb_y,
    output wire [15:0]  eb_act,
    output wire [159:0] eb_x, eb_y,
    output wire         melee_on,
    output wire [1:0]   melee_dir
);
    `include "params.vh"

    localparam NM = 6, NP = 2, NE = 16;
    localparam [10:0] OFS = 11'd64;          // บวกทุกพิกัดตอนเทียบ AABB กันค่าติดลบ (เช่น px - 12)
    localparam R_C1 = 3'd1, R_C2 = 3'd2;

    // ---------- slot ----------
    reg [5:0]  m_act = 0, m_typ = 0;
    reg [NM*10-1:0] m_xv = 0;
    reg [NM*10-1:0] m_yv = 0;
    reg [NM*3-1:0] m_hpv = 0;
    reg [NM*4-1:0] m_flv = 0;
    reg [NM*9-1:0] m_tmrv = 0;
    reg [1:0]  p_act = 0;
    reg [NP*10-1:0] p_xv = 0;
    reg [NP*10-1:0] p_yv = 0;
    reg [NP*2-1:0] p_dirv = 0;
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

    integer k;

    // ---------- tile ROM (2 อ่านต่อ clock) ----------
    reg  [11:0] ta = 0, tb = 0;
    wire [3:0]  tda, tdb;
    tilemap_rom rom_a (.addr(ta), .data(tda));
    tilemap_rom rom_b (.addr(tb), .data(tdb));
    function [11:0] taddr(input [3:0] g, input [9:0] x, input [9:0] y);
        taddr = g * 12'd300 + y[8:5] * 12'd20 + x[9:5];
    endfunction
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

    // ---------- FSM ----------
    localparam [3:0] S_IDLE = 4'd0, S_SPAWN = 4'd1, S_ATK = 4'd2, S_PB = 4'd3, S_EB = 4'd4,
                     S_MON = 4'd5, S_FIRE = 4'd6, S_CPB = 4'd7, S_CMEL = 4'd8, S_CPM = 4'd9,
                     S_CPE = 4'd10, S_END = 4'd11, S_BFIRE = 4'd12, S_BPB = 4'd13, S_BMEL = 4'd14, S_BPM = 4'd15;
    reg [3:0] st = S_IDLE;
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
            plx = {1'b0, px} + OFS + 11'd4;                 // hitbox ผู้เล่น
            ply = {1'b0, py} + OFS + 11'd4;
            mbx = (mel_dir == 2'd2) ? {1'b0, px} + OFS - 11'd12 :     // hit box ฟันประชิด
                  (mel_dir == 2'd3) ? {1'b0, px} + OFS + 11'd28 : {1'b0, px} + OFS + 11'd4;
            mby = (mel_dir == 2'd0) ? {1'b0, py} + OFS + 11'd28 :
                  (mel_dir == 2'd1) ? {1'b0, py} + OFS - 11'd12 : {1'b0, py} + OFS + 11'd4;
            mbw = mel_dir[1] ? 7'd16 : 7'd24;
            mbh = mel_dir[1] ? 7'd24 : 7'd16;
        end
        hit <= 1'b0;
        kb_start <= 1'b0;
        if (atk_press && run) atk_req <= 1'b1;
        if (!run) atk_req <= 1'b0;
        if (room_load) spawn_req <= 1'b1;
        boss_dmg <= 1'b0;
        if (boss_fire) bfire_req <= 1'b1;
        if (dbg_clear && st == S_IDLE && !spawn_req) m_act <= 0;   // ห้องเคลียร์ที่ S_END ของเฟรมถัดไป

        if (rst || restart) begin
            cleared <= 0;
            hurt_cnt <= 0; cool <= 0; melee_cnt <= 0;
            m_act <= 0; p_act <= 0; e_act <= 0;
            st <= S_IDLE;
            if (rst) spawn_req <= 1'b1;
        end else case (st)
        // ------------------------------------------------------------------
        S_IDLE:
            if (spawn_req) begin
                spawn_req <= 1'b0;
                m_act <= 0; p_act <= 0; e_act <= 0; melee_cnt <= 0; bfire_req <= 1'b0;
                cur_idx <= idx_now;
                cur_combat <= (room == R_C1) || (room == R_C2);
                si <= 0; slot <= 0; nb <= 0;
                st <= S_SPAWN;
            end else if (frame_tick && run) begin
                fcnt <= fcnt + 1'b1;
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
            if (cool != 0) cool <= cool - 1'b1;
            else if (form == 2'd0) begin
                if (atk_req) begin           // ฟันประชิด
                    melee_cnt <= MELEE_FRAMES;
                    mel_dir   <= facing;
                    mel_mask  <= 0;
                    mel_boss  <= 1'b0;
                    cool      <= MELEE_COOLDOWN - 1;
                end
            end else if (atk_req || atk_hold) begin   // ยิง (กดค้างยิงซ้ำทุก cooldown)
                if (!p_act[0] || !p_act[1]) begin
                    k = p_act[0] ? 1 : 0;
                    p_act[k] <= 1'b1;
                    p_xv[(k)*10 +: 10]   <= px + 10'd12;
                    p_yv[(k)*10 +: 10]   <= py + 10'd12;
                    p_dirv[(k)*2 +: 2] <= facing;
                    cool     <= PB_COOLDOWN - 1;
                end
            end
            i <= 0; ph <= 0;
            st <= S_PB;
        end
        // ------------------------------------------------------------------
        S_PB: if (ph == 0) begin             // กระสุนผู้เล่น: คำนวณตำแหน่งใหม่ + address tile
            if (!p_act[i[0]]) begin
                if (i == NP - 1) begin j <= 0; st <= S_EB; end
                i <= i + 1'b1;
            end else if (oob(p_xv[(i[0])*10 +: 10], p_dirv[(i[0])*2 +: 2], PB_SPEED, p_yv[(i[0])*10 +: 10])) begin
                p_act[i[0]] <= 1'b0;
                if (i == NP - 1) begin j <= 0; st <= S_EB; end
                i <= i + 1'b1;
            end else begin
                nx <= step_x(p_xv[(i[0])*10 +: 10], p_dirv[(i[0])*2 +: 2], PB_SPEED);
                ny <= step_y(p_yv[(i[0])*10 +: 10], p_dirv[(i[0])*2 +: 2], PB_SPEED);
                ta <= taddr(grid, step_x(p_xv[(i[0])*10 +: 10], p_dirv[(i[0])*2 +: 2], PB_SPEED) + 10'd4,
                                  step_y(p_yv[(i[0])*10 +: 10], p_dirv[(i[0])*2 +: 2], PB_SPEED) + 10'd4);
                ph <= 1;
            end
        end else begin                       // ph 1: ตัดสินจาก tile
            if (bpass(tda) && !blocked(ta)) begin p_xv[(i[0])*10 +: 10] <= nx; p_yv[(i[0])*10 +: 10] <= ny; end
            else p_act[i[0]] <= 1'b0;
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
                end else if (px != m_xv[(i)*10 +: 10]) begin                     // มอน A แกน x
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
                if (py != m_yv[(i)*10 +: 10]) begin
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
        S_CPB: begin                         // กระสุนผู้เล่น i[3] x มอน i[2:0]  (12 คู่)
            if (p_act[j[0]] && m_act[i] &&
                ovl({1'b0, p_xv[(j[0])*10 +: 10]} + OFS, {1'b0, p_yv[(j[0])*10 +: 10]} + OFS, 7'd8, 7'd8,
                    {1'b0, m_xv[(i)*10 +: 10]} + OFS + 11'd4, {1'b0, m_yv[(i)*10 +: 10]} + OFS + 11'd4, 7'd24, 7'd24)) begin
                p_act[j[0]] <= 1'b0;
                m_flv[(i)*4 +: 4] <= MON_FLASH;
                if (m_hpv[(i)*3 +: 3] <= damage) begin m_hpv[(i)*3 +: 3] <= 0; m_act[i] <= 1'b0; end
                else m_hpv[(i)*3 +: 3] <= m_hpv[(i)*3 +: 3] - damage;
            end
            if (i == NM - 1) begin
                i <= 0;
                if (j[0]) begin j <= 0; st <= S_CMEL; end
                else j <= 1;
            end else i <= i + 1'b1;
        end
        S_CMEL: begin                        // ฟันประชิด x มอน (ครั้งละ 1 ทีต่อการฟัน)
            if (melee_cnt != 0 && m_act[i] && !mel_mask[i] &&
                ovl(mbx, mby, mbw, mbh,
                    {1'b0, m_xv[(i)*10 +: 10]} + OFS + 11'd4, {1'b0, m_yv[(i)*10 +: 10]} + OFS + 11'd4, 7'd24, 7'd24)) begin
                mel_mask[i] <= 1'b1;
                m_flv[(i)*4 +: 4] <= MON_FLASH;
                if (m_hpv[(i)*3 +: 3] <= damage) begin m_hpv[(i)*3 +: 3] <= 0; m_act[i] <= 1'b0; end
                else m_hpv[(i)*3 +: 3] <= m_hpv[(i)*3 +: 3] - damage;
            end
            if (i == NM - 1) begin i <= 0; st <= S_CPM; end
            else i <= i + 1'b1;
        end
        S_CPM: begin                         // ผู้เล่น x มอน (ชนตัว)
            if (hurt_cnt == 0 && m_act[i] &&
                ovl(plx, ply, 7'd24, 7'd24,
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
                ovl(plx, ply, 7'd24, 7'd24, {1'b0, e_xv[(j)*10 +: 10]} + OFS, {1'b0, e_yv[(j)*10 +: 10]} + OFS, 7'd8, 7'd8)) begin
                e_act[j] <= 1'b0;
                hit <= 1'b1; kb_start <= 1'b1;
                kb_dir <= away(e_xv[(j)*10 +: 10] + 10'd4, e_yv[(j)*10 +: 10] + 10'd4);
                hurt_cnt <= KB_FRAMES + INV_FRAMES;
            end
            if (j == NE - 1) begin j <= 0; fk <= 0; st <= S_BFIRE; end
            else j <= j + 1'b1;
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
        S_BPB: begin                         // กระสุนผู้เล่น j x บอส
            if (boss_act && p_act[j[0]] &&
                ovl({1'b0, p_xv[(j[0])*10 +: 10]} + OFS, {1'b0, p_yv[(j[0])*10 +: 10]} + OFS, 7'd8, 7'd8,
                    {1'b0, boss_x} + OFS + 11'd8, {1'b0, boss_y} + OFS + 11'd8, 7'd48, 7'd48)) begin
                p_act[j[0]] <= 1'b0;
                boss_dmg <= 1'b1; boss_dmg_amt <= damage;
            end
            if (j[0]) st <= S_BMEL;
            j <= j + 1'b1;
        end
        S_BMEL: begin                        // ฟันประชิด x บอส (1 ทีต่อการฟัน)
            if (boss_act && melee_cnt != 0 && !mel_boss &&
                ovl(mbx, mby, mbw, mbh, {1'b0, boss_x} + OFS + 11'd8, {1'b0, boss_y} + OFS + 11'd8, 7'd48, 7'd48)) begin
                mel_boss <= 1'b1;
                boss_dmg <= 1'b1; boss_dmg_amt <= damage;
            end
            st <= S_BPM;
        end
        S_BPM: begin                         // ผู้เล่น x บอส (ชนตัว)
            if (boss_act && hurt_cnt == 0 &&
                ovl(plx, ply, 7'd24, 7'd24, {1'b0, boss_x} + OFS + 11'd8, {1'b0, boss_y} + OFS + 11'd8, 7'd48, 7'd48)) begin
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
