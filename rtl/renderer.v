// วาดภาพต่อพิกเซล (pipeline 4 clock ทุกชั้นเท่ากัน — เดิม 3 ก่อน board prep)
//   ชั้น (ล่าง -> บน): tile < ปริศนา/มอน/บอส/กระสุน/ฟัน (objline) < ผู้เล่น < ข้อความ      F0F = โปร่งใส
//   screen: 0 เกม · 1 TITLE (พื้นกรมท่า + sprite ที่ px,py ที่ top ส่งมา) · 2 GAME OVER (แดงเข้ม) · 3 WIN (ทอง) · 4 PROLOGUE (ดำ)
//   hide_player: ซ่อน sprite (กะพริบตอน EVOLVE / อมตะหลังโดนตี)
//
// pipeline (สีของพิกเซล hcount/vcount ออกที่ color หลัง 4 clock -> top หน่วง hsync/vsync/active 4 clock ให้ตรงกัน)
//   stage 0: จอสั่น (hs, vs = hcount/vcount + offset) + ที่อยู่ tile = LUT(grid) + (ty << 4) + (ty << 2) + tx -> register;
//            ข้อความ: ตำแหน่งในบรรทัด (ลบ/เทียบขอบ) -> register   (ไม่มีตัวคูณ ไม่มี ROM ใน stage นี้)
//   stage 1: อ่าน tilemap (async ROM เล็ก) -> เลือกรูปประตู/แผ่น -> register address ของ tileset/ผู้เล่น; ข้อความ: อ่าน text ROM
//   stage 2: อ่าน ROM (BRAM sync) + หน่วง flag; ชั้น object จาก objline.v (line buffer, หน่วงเพิ่ม 1 clock ให้ตรง)
//   stage 3: เลือกชั้น -> register color
// ที่ CE_DIV = 4 hcount ค้าง 4 clock, top จับสีตอน ce -> latency 4 พอดี 1 พิกเซล, ภาพไม่เลื่อน (เทียบ pixel ต่อ pixel กับ 3 stage แล้ว)
module renderer (
    input  wire         clk,
    input  wire         ce,
    input  wire [9:0]   hcount, vcount,
    input  wire [3:0]   grid,
    input  wire [1:0]   floor,
    input  wire [1:0]   form,
    input  wire         doors_open, open_L,
    input  wire [2:0]   screen,
    input  wire         open_E,           // W7: ประตู E เปิด (มีกุญแจ) -> วาดเป็นพื้น
    input  wire [7:0]   brk,              // W5: บล็อกพังได้ของห้องนี้ที่พังแล้ว (overlay.v)
    input  wire         hide_player,
    input  wire [9:0]   px, py,
    input  wire [1:0]   facing,        // W25: 0 down 1 up 2 left 3 right (where the charge ball grows)
    input  wire         tgt_on,        // W18 level 3: marker on the locked target
    input  wire [9:0]   tgt_x, tgt_y,  // centre of the target in px
    input  wire [2:0]   chg_lvl,       // W25: charge ball size step 0..4 (objects.v)
    input  wire [5:0]   pframe,        // form*12 + facing*3 + pose
    input  wire [2:0]   p_anim,        // 0 = pframe, 1 idle, 2 attack, 3 hurt, 4 death (from player_frame.v)
    input  wire [5:0]   p_aframe,      // picture number inside the animation ROM
    // ---------- objects (จาก objects.v) ----------
    input  wire [5:0]   mon_act, mon_type, mon_flash, mon_face,
    input  wire [59:0]  mon_x, mon_y,
    input  wire         mon_anim,
    input  wire [5:0]   pb_act,
    input  wire [59:0]  pb_x, pb_y,
    input  wire [11:0]  pb_kind,
    input  wire         hbox_on,          // W43: draw the hit boxes (hero green, monsters red, boss orange, bullets yellow)
    input  wire         dlg_top,          // W38: draw the dialogue box at the TOP (rooms with a door in the bottom wall) instead of the bottom
    input  wire         dlg_on,           // W16: dialogue box (txt_scr = 14): black band + 2 lines from dlg_b0.. (text ROM)
    input  wire [11:0]  dlg_b0, dlg_b1,
    input  wire [4:0]   dlg_n0, dlg_n1,
    input  wire [11:0]  dlg_col,
    input  wire [1:0]   trap_a, trap_b,   // W19: timed spike phase (0 down, 1 warning, 2 up), groups A (overlay code 8) and B (code 9)
    input  wire [1:0]   ov_phase,        // torch flame frame (0..3)
    input  wire [1:0]   fade,             // extra darkness 0..3 (room-change fade in)
    input  wire         p_hurt,           // W14: red flash of the player sprite (just hit)
    input  wire         p_tint,           // ผู้เล่นสว่าง (ร่าง 4 ชาร์จเต็ม)
    input  wire [15:0]  eb_act,
    input  wire [159:0] eb_x, eb_y,
    input  wire [8:0]   pz_act,
    input  wire [89:0]  pz_x, pz_y,
    input  wire [35:0]  pz_frame,
    input  wire [11:0]  pbox0, pbox1,     // tile แผ่นที่มีกล่องวางนิ่ง -> วาด tile 11
    input  wire [1:0]   pbox_en,
    input  wire         simon_lit_on,     // แผ่น Simon สว่าง
    input  wire [1:0]   simon_lit,
    input  wire         simon_wrong,      // แผ่น Simon แดงทั้งหมด
    input  wire         melee_on,
    input  wire [1:0]   melee_dir,
    // ---------- P5 ----------
    input  wire         boss_act,
    input  wire [9:0]   boss_x, boss_y,
    input  wire [2:0]   boss_frame,
    input  wire         boss_flash,
    input  wire [11:0]  boss_fcol,        // W21: blink colour of the boss
    input  wire [9:0]   sh_dx, sh_dy,     // จอสั่น (two's complement): เลื่อนพิกัดภาพ ไม่ยุ่ง sync
    input  wire [11:0]  hint_b0, hint_b1,      // W32: hint strip text addresses (text ROM)
    input  wire [4:0]   hint_n0, hint_n1,      // W32: characters in each hint line
    input  wire [5:0]   txt_scr,          // ข้อความ: 0 ไม่มี 1 TITLE 2 FLOOR CLEAR 3 ESCAPE! 4 WIN 5 GAME OVER 6 PAUSED 7-10 PROLOGUE 11-13 NEW FORM
    input  wire         txt_blink,        // 1 = ซ่อนบรรทัดที่กะพริบ
    input  wire [3:0]   t_floor, t_m1, t_m0, t_s1, t_s0,   // ตัวเลขสดในข้อความ
    input  wire [2:0]   hud_hp, hud_hp_max,                // player hearts (hud.v)
    input  wire         mic_on, mic_hit,                  // W4: clap meter on / clap detected
    input  wire         mic_nums,                          // W36: numbers under the meter
    input  wire [15:0]  mic_th_bcd, mic_lv_bcd,           // W4: the same numbers as decimal digits
    input  wire [6:0]   mic_w, mic_th,                    // W4: level and threshold in px
    input  wire [6:0]   chg_w,                            // W21: boss 3 charge bar fill in px (0 = hidden)
    input  wire [4:0]   hud_b_hp,                          // boss bar (shown while boss_act)
    output reg  [11:0]  color = 12'h000
);
    `include "text_layout.vh"
    `include "sprite_cfg.vh"
    localparam ORB_DIST = 18;               // W25: distance of the growing charge ball from the hero centre (px). Here, NOT in sprite_cfg.vh: that file is regenerated by build_player_mem.py
    `include "puzzle_layout.vh"          // G_SIMON (generated from maps/)
    localparam [11:0] C_NAVY = 12'h114, C_OVER = 12'h300, C_WIN = 12'hFB0, C_T = 12'hF0F;

    // ======================= stage 1 =======================
    // ----- tile -----
    wire [3:0] tid_map;
    wire       maze_on = (screen == 3'd5);   // W7: Ball in a Maze: tiles come from maze_rom instead of the room map
    // จอสั่น: ทุกชั้นภาพใช้พิกัดที่เลื่อนแล้ว (hs, vs); นอกจอ = ดำ
    wire [9:0] hs = hcount + sh_dx;
    wire [9:0] vs = vcount + sh_dy;
    // stage 0 (P6 board prep): register shifted coordinates + tilemap address (grid*300 from a LUT, row*20 = shift-add)
    `include "tilebase.vh"
    reg [9:0]  hs_r = 0, vs_r = 0;
    reg [11:0] taddr = 0;
    reg [11:0] maddr = 0;
    always @(posedge clk) begin
        hs_r  <= hs;
        vs_r  <= vs;
        taddr <= rbase(grid) + rowx20(vs[8:5]) + hs[9:5];
        maddr <= rowx20(vs[8:5]) + hs[9:5];
    end
    wire [7:0] ovraw;                // W5 overlay entry of this tile (art drawn from ovtile_rom over the base tile)
    tilemap_rom #(.RAW(1)) map (.addr(taddr), .brk(8'd0), .data(tid_map), .ov(ovraw));
    wire [1:0] mzd;
    maze_rom mzr (.addr(maddr[8:0]), .data(mzd));
    wire [3:0] tid = maze_on ? ((mzd == 2'd1) ? 4'h0 : (mzd == 2'd2) ? 4'h7 : 4'h1) : tid_map;   // wall / goal plate / floor
    // vignette level at this pixel (stage 0 coordinates): distance from the screen centre (dx + 1.5 dy) plus the room-change fade
    wire [9:0]  vdx = (hs_r >= 10'd320) ? hs_r - 10'd320 : 10'd320 - hs_r;
    wire [9:0]  vdy = (vs_r >= 10'd240) ? vs_r - 10'd240 : 10'd240 - vs_r;
    wire [6:0]  vx7 = vdx[9:3];                                           // 0..40
    wire [6:0]  vy7 = (vdy + {2'b00, vdy[9:2]}) >> 3;                     // dy * 1.25 / 8 = 0..37 (ellipse, not a diamond)
    wire [11:0] vm  = vx7 * vx7 + vy7 * vy7;                              // squared distance from the centre
    wire [1:0]  vig_edge = (vm >= 12'd2500) ? 2'd3 : (vm >= 12'd1900) ? 2'd2 : (vm >= 12'd1400) ? 2'd1 : 2'd0;
    wire [2:0]  vig_sum  = {1'b0, vig_edge} + {1'b0, fade};
    wire [1:0]  vig_lvl  = (screen == 3'd0 || screen == 3'd5) ? ((vig_sum > 3'd3) ? 2'd3 : vig_sum[1:0]) : 2'd0;
    reg [3:0] tvis;
    always @* begin                  // สถานะประตูเลือกรูปเปิด/ปิด
        case (tid)
            4'h2: tvis = doors_open ? 4'h8 : 4'h2;
            4'h3: tvis = open_L     ? 4'h9 : 4'h3;
            4'h4: tvis = open_E ? 4'hA : 4'h4;
            4'h7: tvis = ((pbox_en[0] && taddr == pbox0) || (pbox_en[1] && taddr == pbox1)) ? 4'hB : 4'h7;
            default: tvis = tid;
        endcase
    end

    // ----- player -----
    wire [9:0] sx = hs_r - px;
    wire [9:0] sy = vs_r - py;
    wire in_spr = (hs_r >= px) && (sx < 10'd32) && (vs_r >= py) && (sy < 10'd32);

    reg [15:0] r1_taddr = 0;
    reg [15:0] r1_paddr = 0;
    reg [15:0] r1_aaddr = 0;
    reg [2:0]  r1_asel = 0;
    reg        r1_p = 0, r1_lit = 0, r1_red = 0, r1_out = 0, r1_tint = 0;
    // ----- W25 charge ball: a disc in front of the hero that grows in 4 steps (radius 2 / 4 / 6 / 7-8), colour orange -> yellow -> white -----
    wire [10:0] orb_hb = {1'b0, hs_r} + 11'd64, orb_vb = {1'b0, vs_r} + 11'd64;           // +64 so nothing goes negative
    wire [10:0] orb_cx = {1'b0, px} + 11'd80 + ((facing == 2'd3) ? ORB_DIST : 0) - ((facing == 2'd2) ? ORB_DIST : 0);
    wire [10:0] orb_cy = {1'b0, py} + 11'd80 + ((facing == 2'd0) ? ORB_DIST : 0) - ((facing == 2'd1) ? ORB_DIST : 0);
    wire [10:0] orb_ax = (orb_hb > orb_cx) ? orb_hb - orb_cx : orb_cx - orb_hb;
    wire [10:0] orb_ay = (orb_vb > orb_cy) ? orb_vb - orb_cy : orb_cy - orb_vb;
    wire [3:0]  orb_r  = (chg_lvl == 3'd1) ? 4'd2 : (chg_lvl == 3'd2) ? 4'd4 : (chg_lvl == 3'd3) ? 4'd6 : (ov_phase[0] ? 4'd8 : 4'd7);   // full = pulses 7 / 8
    wire [8:0]  orb_d2 = orb_ax[3:0] * orb_ax[3:0] + orb_ay[3:0] * orb_ay[3:0];
    wire        orb_in = (chg_lvl != 3'd0) && (orb_ax < 11'd9) && (orb_ay < 11'd9) && (orb_d2 <= orb_r * orb_r);
    wire [11:0] orb_c  = (chg_lvl == 3'd1) ? 12'hF92 : (chg_lvl == 3'd2) ? 12'hFC4 : (chg_lvl == 3'd3) ? 12'hFE8 : 12'hFFF;
    wire        orb_core = (orb_d2 <= (orb_r >> 1) * (orb_r >> 1));
    // ----- W18 level 3 target marker: four corner brackets (20 x 20 px) around the locked enemy, blinking yellow / red -----
    wire [10:0] tg_cx = {1'b0, tgt_x} + 11'd64, tg_cy = {1'b0, tgt_y} + 11'd64;
    wire [10:0] tg_ax = (orb_hb > tg_cx) ? orb_hb - tg_cx : tg_cx - orb_hb;
    wire [10:0] tg_ay = (orb_vb > tg_cy) ? orb_vb - tg_cy : tg_cy - orb_vb;
    wire        tg_in = tgt_on && (tg_ax >= 11'd8) && (tg_ax <= 11'd11) && (tg_ay >= 11'd8) && (tg_ay <= 11'd11) && ((tg_ax >= 11'd10) || (tg_ay >= 11'd10));
    reg         r1_tgt = 0, r2_tgt = 0; reg [11:0] r1_tgtc = 0, r2_tgtc = 0;
    // ----- W43 hitbox overlay: the real boxes used by objects.v: hero hurt box 16 x 16 in the middle of its cell, monsters 24 x 24 (pixels 4..27), boss 48 x 48 (8..55), bullets 8 x 8 (big ball 16 x 16) -----
    function box_edge(input [9:0] x, input [9:0] y, input [9:0] bx, input [9:0] by, input [9:0] bw, input [9:0] bh);
        reg inside;
        begin
            inside = (x >= bx) && (x < bx + bw) && (y >= by) && (y < by + bh);
            box_edge = inside && ((x == bx) || (x == bx + bw - 10'd1) || (y == by) || (y == by + bh - 10'd1));
        end
    endfunction
    reg         hb_hit; reg [11:0] hb_col; integer hbk;
    always @* begin
        hb_hit = 1'b0; hb_col = 12'h000;
        if (box_edge(hs_r, vs_r, px + 10'd8, py + 10'd8, 10'd16, 10'd16)) begin hb_hit = 1'b1; hb_col = 12'h0F0; end
        for (hbk = 0; hbk < 6; hbk = hbk + 1) begin
            if (mon_act[hbk] && box_edge(hs_r, vs_r, mon_x[hbk*10 +: 10] + 10'd4, mon_y[hbk*10 +: 10] + 10'd4, 10'd24, 10'd24)) begin hb_hit = 1'b1; hb_col = 12'hF00; end
            if (pb_act[hbk]  && box_edge(hs_r, vs_r, pb_x[hbk*10 +: 10], pb_y[hbk*10 +: 10], (pb_kind[hbk*2 +: 2] == 2'd3) ? 10'd16 : 10'd8, (pb_kind[hbk*2 +: 2] == 2'd3) ? 10'd16 : 10'd8)) begin hb_hit = 1'b1; hb_col = 12'hFF0; end
        end
        for (hbk = 0; hbk < 16; hbk = hbk + 1)
            if (eb_act[hbk] && box_edge(hs_r, vs_r, eb_x[hbk*10 +: 10], eb_y[hbk*10 +: 10], 10'd8, 10'd8)) begin hb_hit = 1'b1; hb_col = 12'hFB0; end
        if (boss_act && box_edge(hs_r, vs_r, boss_x + 10'd8, boss_y + 10'd8, 10'd48, 10'd48)) begin hb_hit = 1'b1; hb_col = 12'hF80; end
    end
    reg         r1_hb = 0, r2_hb = 0; reg [11:0] r1_hbc = 0, r2_hbc = 0;
    reg         r1_orb = 0, r2_orb = 0; reg [11:0] r1_orbc = 0, r2_orbc = 0;
    reg        r1_hurt = 0, r2_hurt = 0, r1_band = 0, r2_band = 0, r1_arr = 0, r2_arr = 0;
    reg [2:0]  r1_scr = 0;
    reg        r1_ovl = 0, r2_ovl = 0;                 // the overlay picture is a light source (torch): not darkened
    reg        r1_ovs = 0, r2_ovs = 0;         // overlay picture present
    reg [13:0] r1_oaddr = 0;
    reg [1:0]  r1_vig = 0, r2_vig = 0;          // vignette level (0..3): darker towards the screen edges + the room fade
    reg        r1_dth = 0, r2_dth = 0;                // ordered dither of the title gradient (smooth instead of 8 visible bands)
    reg [2:0]  r1_vb = 0, r2_vb = 0;            // W6: แถบแนวนอน 8 แถบ (vcount[8:6]) ทำพื้นหน้า TITLE เป็นไล่สี
    // ----- ข้อความ: ไม่เกิน 2 บรรทัดต่อหน้าจอ, ฟอนต์ 8x8 ขยาย 2x / 4x (คิดเฉพาะตอนมีข้อความบนจอ) -----
    reg [5:0]  txtmem [0:4095];
    reg [7:0]  fontmem [0:511];
    initial $readmemh("text.mem", txtmem);
    initial $readmemh("font.mem", fontmem);
    reg [8:0]  r1_faddr = 0;
    reg [2:0]  r1_gx = 0;
    reg        r1_txt = 0;
    reg [9:0]  ly0, lx0, lw0, lh0, ly1, lx1, lw1, lh1, rx, ry, rx0, ry0, rx1, ry1;
    reg        ls0, ls1, lk0, lk1, in0, in1, s4, kk;
    reg [11:0] lb0, lb1, bb, ta_;
    reg [5:0]  code;
    reg [5:0]  colc;                              // W45: 6 bits, a 2x line may be up to 40 characters (the credits pages)
    // stage A: ตำแหน่งในบรรทัดข้อความ (ลบ + เทียบขอบ + เลือกบรรทัด) -> register; stage B: อ่านตัวอักษรจาก text ROM + เลขสด
    reg [9:0]  a_rx = 0, a_ry = 0; reg a_in = 0, a_s4 = 0, a_kk = 0, a_on = 0; reg [11:0] a_bb = 0;
    // timing: the text-screen select used to run from the puzzle / game state straight to a_bb in one clock (WNS -5.2 ns, worst path pz/b1y -> txt_scr/hint_b0 -> case -> a_bb).
    // It is now 3 short steps: (0) register the inputs, (1) the case -> registers, (A) the position test. These inputs only change at game-state speed, so the 2 extra clocks of latency are invisible.
    reg [5:0]  s_scr = 0;  reg s_top = 0;
    reg [11:0] s_hb0 = 0, s_hb1 = 0, s_db0 = 0, s_db1 = 0;
    reg [4:0]  s_hn0 = 0, s_hn1 = 0, s_dn0 = 0, s_dn1 = 0;
    always @(posedge clk) begin
        s_scr <= txt_scr;  s_top <= dlg_top;
        s_hb0 <= hint_b0;  s_hb1 <= hint_b1;  s_hn0 <= hint_n0;  s_hn1 <= hint_n1;
        s_db0 <= dlg_b0;   s_db1 <= dlg_b1;   s_dn0 <= dlg_n0;   s_dn1 <= dlg_n1;
    end
    reg [9:0]  m_ly0 = 0, m_lx0 = 0, m_lw0 = 0, m_lh0 = 0, m_ly1 = 0, m_lx1 = 0, m_lw1 = 0, m_lh1 = 0;
    reg        m_ls0 = 0, m_ls1 = 0, m_lk0 = 0, m_lk1 = 0, m_on = 0;
    reg [11:0] m_lb0 = 0, m_lb1 = 0;
    always @(posedge clk) begin
        m_on <= (s_scr != 0);
        ly0 = 0; lx0 = 0; lw0 = 0; lh0 = 0; ls0 = 0; lb0 = 0; lk0 = 0;
        ly1 = 0; lx1 = 0; lw1 = 0; lh1 = 0; ls1 = 0; lb1 = 0; lk1 = 0;
        case (s_scr)
            5'd24: begin ly0 = 10'd42; lx0 = 10'd8; lw0 = {1'b0, s_hn0, 4'b0}; lh0 = 10'd16; ls0 = 1'b0; lb0 = s_hb0; lk0 = 1'b0;      // W38: top left under the hearts, never over a door
                         ly1 = 10'd60; lx1 = 10'd8; lw1 = {1'b0, s_hn1, 4'b0}; lh1 = 10'd16; ls1 = 1'b0; lb1 = s_hb1; lk1 = 1'b0; end
            5'd14: begin ly0 = s_top ? 10'd40 : 10'd392; lx0 = 10'd320 - {1'b0, s_dn0, 4'b0} / 2; lw0 = {1'b0, s_dn0, 4'b0}; lh0 = 10'd16; ls0 = 1'b0; lb0 = s_db0; lk0 = 1'b0;
                         ly1 = s_top ? 10'd64 : 10'd416; lx1 = 10'd320 - {1'b0, s_dn1, 4'b0} / 2; lw1 = {1'b0, s_dn1, 4'b0}; lh1 = 10'd16; ls1 = 1'b0; lb1 = s_db1; lk1 = 1'b0; end
            `include "text_select.vh"
        endcase
        m_ly0 <= ly0; m_lx0 <= lx0; m_lw0 <= lw0; m_lh0 <= lh0; m_ls0 <= ls0; m_lb0 <= lb0; m_lk0 <= lk0;
        m_ly1 <= ly1; m_lx1 <= lx1; m_lw1 <= lw1; m_lh1 <= lh1; m_ls1 <= ls1; m_lb1 <= lb1; m_lk1 <= lk1;
    end
    always @(posedge clk) begin
        a_on <= m_on;
        if (m_on) begin
            rx0 = hcount - m_lx0; ry0 = vcount - m_ly0; in0 = (rx0 < m_lw0) && (ry0 < m_lh0);
            rx1 = hcount - m_lx1; ry1 = vcount - m_ly1; in1 = (rx1 < m_lw1) && (ry1 < m_lh1);
            a_rx <= in0 ? rx0 : rx1;  a_ry <= in0 ? ry0 : ry1;  a_in <= in0 || in1;
            a_s4 <= in0 ? m_ls0 : m_ls1;  a_bb <= in0 ? m_lb0 : m_lb1;  a_kk <= in0 ? m_lk0 : m_lk1;
        end
    end
    always @(posedge clk) begin
        r1_txt <= 1'b0;
        if (a_on) begin
            rx = a_rx; ry = a_ry; s4 = a_s4; bb = a_bb; kk = a_kk;
            colc = s4 ? {1'b0, rx[9:5]} : rx[9:4];
            ta_  = bb + colc;
            code = txtmem[ta_];
            case (code)                                  // ตัวเลขสด
                6'd59: code = {2'b00, t_floor};
                6'd60: code = {2'b00, t_m1};
                6'd61: code = {2'b00, t_m0};
                6'd62: code = {2'b00, t_s1};
                6'd63: code = {2'b00, t_s0};
                default: ;
            endcase
            r1_faddr <= {code, s4 ? ry[4:2] : ry[3:1]};
            r1_gx    <= s4 ? rx[4:2] : rx[3:1];
            r1_txt   <= a_in && !(kk && txt_blink);
        end
    end
    always @(posedge clk) begin
        r1_out   <= (hs_r >= 10'd640) || (vs_r >= 10'd480);
        // each Simon plate = a 2x2 block of tiles (even column / even row) drawn as ONE big plate: the 32x32 plate picture in tile 12..15 is
        // sampled at half size, quadrant = tile column / row parity (floor 3, Simon room only)
        if (floor == 2'd2 && grid == G_SIMON && tid[3:2] == 2'b11)
            r1_taddr <= {floor, tvis, vs_r[5], vs_r[4:1], hs_r[5], hs_r[4:1]};
        else
            r1_taddr <= {floor, tvis, vs_r[4:0], hs_r[4:0]};          // (floor*16 + tvis) = {floor, tvis}
        r1_paddr <= {pframe, sy[4:0], sx[4:0]};
        r1_aaddr <= {p_aframe, sy[4:0], sx[4:0]};
        r1_asel  <= p_anim;
        r1_p     <= in_spr && !hide_player;
        r1_tint  <= p_tint;
        r1_hurt  <= p_hurt;
        r1_orb   <= orb_in;
        r1_hb    <= hbox_on && hb_hit && (screen == 3'd0); r1_hbc <= hb_col;
        r1_tgt   <= tg_in; r1_tgtc <= ov_phase[1] ? 12'hFF4 : 12'hF44;
        r1_orbc  <= orb_core ? orb_c : {1'b0, orb_c[11:9], 1'b0, orb_c[7:5], 1'b0, orb_c[3:1]};   // bright core, darker rim
        r1_band  <= (dlg_on && (dlg_top ? ((vs_r >= 10'd32) && (vs_r < 10'd96)) : ((vs_r >= 10'd384) && (vs_r < 10'd448)))) ||
                    (txt_scr == 5'd24 && hs_r >= 10'd6 && hs_r < 10'd284 && vs_r >= 10'd40 && vs_r < 10'd78 && (hs_r[0] ^ vs_r[0]));          // hint strip: 50 % dithered, you still see the room through it
   // W16 dialogue band / W32 hint strip band
        r1_arr   <= dlg_on && ov_phase[1] && (hs_r >= 10'd604) && (hs_r < 10'd620) && (vs_r >= (dlg_top ? 10'd66 : 10'd418)) && (vs_r < (dlg_top ? 10'd82 : 10'd434)) &&
                    ((vs_r < (dlg_top ? 10'd74 : 10'd426) ? ((dlg_top ? 10'd73 : 10'd425) - vs_r) : (vs_r - (dlg_top ? 10'd74 : 10'd426))) <= ((10'd619 - hs_r) >> 1));          // W31: blinking arrow = press the attack button
        r1_scr   <= screen;
        // overlay code -> picture: 1 breakable block (if not broken) 0, 2 trap 1, 3 pillar 2, 4 torch 3 + phase, 5 left torch 7, 6 right torch 8, 7 shield 9
        r1_ovs   <= maze_on ? 1'b0 : (ovraw[3:0] == 4'd1) ? !brk[ovraw[6:4]] : (ovraw[3:0] >= 4'd2 && ovraw[3:0] <= 4'd9);
        // W19: code 8 / 9 = timed spikes: picture 10 flat, 11 half up, 12 fully up
        r1_oaddr <= {(ovraw[3:0] == 4'd8) ? (4'd10 + {2'b00, trap_a}) : (ovraw[3:0] == 4'd9) ? (4'd10 + {2'b00, trap_b}) :
                     (ovraw[3:0] == 4'd2) ? 4'd1 : (ovraw[3:0] == 4'd3) ? 4'd2 : (ovraw[3:0] == 4'd4) ? (4'd3 + {2'b00, ov_phase}) :
                     (ovraw[3:0] == 4'd5) ? 4'd7 : (ovraw[3:0] == 4'd6) ? 4'd8 : (ovraw[3:0] == 4'd7) ? 4'd9 : 4'd0, vs_r[4:0], hs_r[4:0]};
        r1_vig   <= vig_lvl;
        r1_ovl   <= (ovraw[3:0] >= 4'd4 && ovraw[3:0] <= 4'd6);
        r1_vb    <= vcount[8:6];
        r1_dth   <= (vcount[5:2] > bayer4({vcount[1:0], hcount[1:0]}));
        r1_lit   <= simon_lit_on && (tid == {2'b11, simon_lit});
        r1_red   <= simon_wrong && (tid >= 4'hC);
    end

    // ======================= stage 2: ROM =======================
    wire [11:0] tile_px, spr_px, obj_px;
    tileset_rom tset (.clk(clk), .addr(r1_taddr), .data(tile_px));
    wire [11:0] ov_px;
    function [3:0] bayer4(input [3:0] p);                  // 4x4 Bayer threshold {y[1:0], x[1:0]}
        case (p)
            4'd0: bayer4 = 4'd0;  4'd1: bayer4 = 4'd8;  4'd2: bayer4 = 4'd2;  4'd3: bayer4 = 4'd10;
            4'd4: bayer4 = 4'd12; 4'd5: bayer4 = 4'd4;  4'd6: bayer4 = 4'd14; 4'd7: bayer4 = 4'd6;
            4'd8: bayer4 = 4'd3;  4'd9: bayer4 = 4'd11; 4'd10: bayer4 = 4'd1; 4'd11: bayer4 = 4'd9;
            4'd12: bayer4 = 4'd15; 4'd13: bayer4 = 4'd7; 4'd14: bayer4 = 4'd13; default: bayer4 = 4'd5;
        endcase
    endfunction
    ovtile_rom  otr  (.clk(clk), .addr(r1_oaddr), .data(ov_px));
    // vignette: the tiles get darker towards the edges (25 / 37 / 50 %); `fade` adds up to 3 levels for a short fade-in after a room change
    function [11:0] shade(input [11:0] c, input [1:0] l);
        reg [3:0] r, g, b;
        begin
            r = c[11:8]; g = c[7:4]; b = c[3:0];
            case (l)
                2'd1: shade = {(r > 4'd0) ? r - 4'd1 : r, (g > 4'd0) ? g - 4'd1 : g, (b > 4'd0) ? b - 4'd1 : b};
                2'd2: shade = {(r > 4'd1) ? r - 4'd2 : 4'd0, (g > 4'd1) ? g - 4'd2 : 4'd0, (b > 4'd1) ? b - 4'd2 : 4'd0};
                2'd3: shade = {(r > 4'd2) ? r - 4'd3 : 4'd0, (g > 4'd2) ? g - 4'd3 : 4'd0, (b > 4'd2) ? b - 4'd3 : 4'd0};
                default: shade = c;
            endcase
        end
    endfunction
    player_rom  pspr (.clk(clk), .addr(r1_paddr), .data(spr_px));
    // animation ROMs: only built when their flag in sprite_cfg.vh is 1
    wire [11:0] idle_px, atk_px, hurt_px, die_px;
    generate
        if (IDLE_ANIM_EN)   begin : g_idle   player_idle_rom   ri (.clk(clk), .addr(r1_aaddr),        .data(idle_px)); end
        else begin : g_idle_off   assign idle_px = 12'd0; end
        if (ATTACK_ANIM_EN) begin : g_attack player_attack_rom ra (.clk(clk), .addr(r1_aaddr),        .data(atk_px)); end
        else begin : g_attack_off assign atk_px = 12'd0; end
        if (HURT_ANIM_EN)   begin : g_hurt   player_hurt_rom   rh (.clk(clk), .addr(r1_aaddr[13:0]),  .data(hurt_px)); end
        else begin : g_hurt_off   assign hurt_px = 12'd0; end
        if (DEATH_ANIM_EN)  begin : g_die    player_die_rom    rd (.clk(clk), .addr(r1_aaddr[13:0]),  .data(die_px)); end
        else begin : g_die_off    assign die_px = 12'd0; end
    endgenerate
    reg [2:0] r2_asel = 0;
    always @(posedge clk) r2_asel <= r1_asel;
    wire [11:0] spr_fin = (r2_asel == 3'd1) ? idle_px : (r2_asel == 3'd2) ? atk_px :
                          (r2_asel == 3'd3) ? hurt_px : (r2_asel == 3'd4) ? die_px : spr_px;
    objline     objl (.clk(clk), .ce(ce), .hcount(hcount), .vcount(vcount),
                      .mon_face(mon_face), .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                      .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .pb_kind(pb_kind),
                      .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir),
                      .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame),
                      .boss_act(boss_act), .boss_x(boss_x), .boss_y(boss_y), .boss_frame(boss_frame),
                      .boss_flash(boss_flash), .boss_fcol(boss_fcol), .sh_dx(sh_dx), .sh_dy(sh_dy),
                      .px(px), .py(py), .obj_px(obj_px));

    reg [11:0] obj_px_d = 12'hF0F;          // ชั้น object มาถึงเร็วกว่า tile 1 clock (tile มี stage 0 เพิ่ม) -> หน่วง 1 clock
    always @(posedge clk) obj_px_d <= obj_px;
    reg r2_p = 0, r2_lit = 0, r2_red = 0, r2_out = 0, r2_txt = 0, r2_tint = 0;
    reg [2:0] r2_scr = 0;
    reg [2:0] r2_gx = 0;
    reg [7:0] r2_font = 0;
    always @(posedge clk) begin
        r2_p <= r1_p; r2_hb <= r1_hb; r2_hbc <= r1_hbc; r2_tgt <= r1_tgt; r2_tgtc <= r1_tgtc; r2_orb <= r1_orb; r2_orbc <= r1_orbc; r2_tint <= r1_tint; r2_scr <= r1_scr; r2_vb <= r1_vb; r2_dth <= r1_dth; r2_hurt <= r1_hurt; r2_band <= r1_band; r2_arr <= r1_arr; r2_vig <= r1_vig; r2_ovl <= r1_ovl; r2_ovs <= r1_ovs; r2_lit <= r1_lit; r2_red <= r1_red; r2_out <= r1_out;
        r2_txt <= r1_txt; r2_gx <= r1_gx;
        r2_font <= fontmem[r1_faddr];
    end
    wire txt_on = r2_txt && r2_font[3'd7 - r2_gx];
    // on-screen health: hearts (player) + bar (boss), same latency as the tile path; game screen only
    wire [11:0] hud_px; wire hud_on;
    hud hud0 (.clk(clk), .hcount(hcount), .vcount(vcount), .hp(hud_hp), .hp_max(hud_hp_max), .boss_on(boss_act), .floor(floor),
              .b_hp(hud_b_hp), .chg_w(chg_w), .mic_on(mic_on), .mic_w(mic_w), .mic_th(mic_th), .mic_hit(mic_hit), .mic_nums(mic_nums), .mic_th_bcd(mic_th_bcd), .mic_lv_bcd(mic_lv_bcd), .hud_px(hud_px), .hud_on(hud_on));

    // ======================= stage 3: เลือกชั้น =======================
    always @(posedge clk) begin
        if (txt_on)                                  color <= dlg_on ? dlg_col : 12'hFFF;    // ข้อความอยู่บนสุด (dialogue: สีตามผู้พูด)
        else if (r2_band)                            color <= r2_arr ? 12'hFFF : 12'h000;    // W16: แถบดำใต้ข้อความ dialogue
        else if ((r2_scr == 3'd0 || (r2_scr == 3'd4 && mic_on)) && hud_on) color <= hud_px;    // W36: the meter is also drawn on the title SETTINGS page (black screen)     // hearts / boss bar above the world
        else if (DEATH_ANIM_EN && r2_scr == 3'd2 && r2_p && r2_asel == 3'd4 && spr_fin != C_T) color <= spr_fin;   // death animation over the GAME OVER colour
        else if (r2_scr == 3'd4)                     color <= 12'h000;    // prologue: black screen
        else if (r2_scr == 3'd2)                     color <= C_OVER;
        else if (r2_scr == 3'd3)                     color <= C_WIN;
        else if (r2_hb)                              color <= r2_hbc;     // W43: hitbox overlay
        else if (r2_tgt)                             color <= r2_tgtc;    // W18 level 3: target marker
        else if (r2_orb)                             color <= r2_orbc;    // W25: the charge ball is drawn over the hero
        else if (r2_p && spr_fin != C_T)             color <= r2_hurt ? {4'hF, 1'b0, spr_fin[7:5], 1'b0, spr_fin[3:1]} : r2_tint ? (spr_fin | 12'hCCC) : spr_fin;   // W14: hit = red   // ชาร์จเต็ม: สว่าง
        else if (r2_scr == 3'd1 && obj_px_d != C_T)  color <= obj_px_d;   // TITLE: the two torches
        else if (r2_scr == 3'd1)                     color <= {4'h1, 2'b00, r2_vb[2:1], 4'h4 + {1'b0, r2_vb} + {3'b000, r2_dth}};   // TITLE: dithered navy -> blue gradient (W6)
        else if (r2_out)                             color <= 12'h000;    // จอสั่น: ขอบที่เลื่อนออก
        else if (obj_px_d != C_T)                    color <= obj_px_d;   // มอน < กระสุน < ฟัน (เรียงใน objline)
        else if (r2_red)                             color <= {4'hF, 1'b0, tile_px[7:5], 1'b0, tile_px[3:1]};   // Simon ผิด: แดง
        else if (r2_lit)                             color <= {1'b1, tile_px[11:9], 1'b1, tile_px[7:5], 1'b1, tile_px[3:1]}; // สว่าง
        else if (r2_ovs && ov_px != C_T)             color <= r2_ovl ? ov_px : shade(ov_px, r2_vig);     // W5: breakable block / trap / decoration / wall torch over the floor
        else                                         color <= shade(tile_px, r2_vig);
    end
endmodule
