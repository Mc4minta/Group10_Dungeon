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
    input  wire [5:0]   pframe,        // form*12 + facing*3 + pose
    input  wire [2:0]   p_anim,        // 0 = pframe, 1 idle, 2 attack, 3 hurt, 4 death (from player_frame.v)
    input  wire [5:0]   p_aframe,      // picture number inside the animation ROM
    // ---------- objects (จาก objects.v) ----------
    input  wire [5:0]   mon_act, mon_type, mon_flash,
    input  wire [59:0]  mon_x, mon_y,
    input  wire         mon_anim,
    input  wire [5:0]   pb_act,
    input  wire [59:0]  pb_x, pb_y,
    input  wire [11:0]  pb_kind,
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
    input  wire [9:0]   sh_dx, sh_dy,     // จอสั่น (two's complement): เลื่อนพิกัดภาพ ไม่ยุ่ง sync
    input  wire [3:0]   txt_scr,          // ข้อความ: 0 ไม่มี 1 TITLE 2 FLOOR CLEAR 3 ESCAPE! 4 WIN 5 GAME OVER 6 PAUSED 7-10 PROLOGUE 11-13 NEW FORM
    input  wire         txt_blink,        // 1 = ซ่อนบรรทัดที่กะพริบ
    input  wire [3:0]   t_floor, t_m1, t_m0, t_s1, t_s0,   // ตัวเลขสดในข้อความ
    input  wire [2:0]   hud_hp, hud_hp_max,                // player hearts (hud.v)
    input  wire [4:0]   hud_b_hp,                          // boss bar (shown while boss_act)
    output reg  [11:0]  color = 12'h000
);
    `include "text_layout.vh"
    `include "sprite_cfg.vh"
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
    reg [2:0]  r1_scr = 0;
    reg [1:0]  r1_ovs = 0, r2_ovs = 0;         // overlay picture: 0 none, 1 breakable block, 2 spike trap, 3 solid decoration
    reg [11:0] r1_oaddr = 0;
    reg [2:0]  r1_vb = 0, r2_vb = 0;            // W6: แถบแนวนอน 8 แถบ (vcount[8:6]) ทำพื้นหน้า TITLE เป็นไล่สี
    // ----- ข้อความ: ไม่เกิน 2 บรรทัดต่อหน้าจอ, ฟอนต์ 8x8 ขยาย 2x / 4x (คิดเฉพาะตอนมีข้อความบนจอ) -----
    reg [5:0]  txtmem [0:511];
    reg [7:0]  fontmem [0:511];
    initial $readmemh("text.mem", txtmem);
    initial $readmemh("font.mem", fontmem);
    reg [8:0]  r1_faddr = 0;
    reg [2:0]  r1_gx = 0;
    reg        r1_txt = 0;
    reg [9:0]  ly0, lx0, lw0, lh0, ly1, lx1, lw1, lh1, rx, ry, rx0, ry0, rx1, ry1;
    reg        ls0, ls1, lk0, lk1, in0, in1, s4, kk;
    reg [8:0]  lb0, lb1, bb, ta_;
    reg [5:0]  code;
    reg [4:0]  colc;
    // stage A: ตำแหน่งในบรรทัดข้อความ (ลบ + เทียบขอบ + เลือกบรรทัด) -> register; stage B: อ่านตัวอักษรจาก text ROM + เลขสด
    reg [9:0]  a_rx = 0, a_ry = 0; reg a_in = 0, a_s4 = 0, a_kk = 0, a_on = 0; reg [8:0] a_bb = 0;
    always @(posedge clk) begin
        a_on <= (txt_scr != 0);
        if (txt_scr != 0) begin
            case (txt_scr)
                `include "text_select.vh"
            endcase
            rx0 = hcount - lx0; ry0 = vcount - ly0; in0 = (rx0 < lw0) && (ry0 < lh0);
            rx1 = hcount - lx1; ry1 = vcount - ly1; in1 = (rx1 < lw1) && (ry1 < lh1);
            a_rx <= in0 ? rx0 : rx1;  a_ry <= in0 ? ry0 : ry1;  a_in <= in0 || in1;
            a_s4 <= in0 ? ls0 : ls1;  a_bb <= in0 ? lb0 : lb1;  a_kk <= in0 ? lk0 : lk1;
        end
    end
    always @(posedge clk) begin
        r1_txt <= 1'b0;
        if (a_on) begin
            rx = a_rx; ry = a_ry; s4 = a_s4; bb = a_bb; kk = a_kk;
            colc = s4 ? rx[9:5] : rx[8:4];
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
        r1_scr   <= screen;
        r1_ovs   <= maze_on ? 2'd0 : (ovraw[3:0] == 4'd1 && !brk[ovraw[6:4]]) ? 2'd1 : (ovraw[3:0] == 4'd2) ? 2'd2 : (ovraw[3:0] == 4'd3) ? 2'd3 : 2'd0;
        r1_oaddr <= {((ovraw[3:0] == 4'd2) ? 2'd1 : (ovraw[3:0] == 4'd3) ? 2'd2 : 2'd0), vs_r[4:0], hs_r[4:0]};
        r1_vb    <= vcount[8:6];
        r1_lit   <= simon_lit_on && (tid == {2'b11, simon_lit});
        r1_red   <= simon_wrong && (tid >= 4'hC);
    end

    // ======================= stage 2: ROM =======================
    wire [11:0] tile_px, spr_px, obj_px;
    tileset_rom tset (.clk(clk), .addr(r1_taddr), .data(tile_px));
    wire [11:0] ov_px;
    ovtile_rom  otr  (.clk(clk), .addr(r1_oaddr), .data(ov_px));
    player_rom  pspr (.clk(clk), .addr(r1_paddr), .data(spr_px));
    // animation ROMs: only built when their flag in sprite_cfg.vh is 1
    wire [11:0] idle_px, atk_px, hurt_px, die_px;
    generate
        if (IDLE_ANIM_EN)   begin : g_idle   player_idle_rom   ri (.clk(clk), .addr(r1_aaddr),        .data(idle_px)); end
        else begin : g_idle_off   assign idle_px = 12'd0; end
        if (ATTACK_ANIM_EN) begin : g_attack player_attack_rom ra (.clk(clk), .addr(r1_aaddr[13:0]),  .data(atk_px)); end
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
                      .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                      .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .pb_kind(pb_kind),
                      .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir),
                      .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame),
                      .boss_act(boss_act), .boss_x(boss_x), .boss_y(boss_y), .boss_frame(boss_frame),
                      .boss_flash(boss_flash), .sh_dx(sh_dx), .sh_dy(sh_dy),
                      .px(px), .py(py), .obj_px(obj_px));

    reg [11:0] obj_px_d = 12'hF0F;          // ชั้น object มาถึงเร็วกว่า tile 1 clock (tile มี stage 0 เพิ่ม) -> หน่วง 1 clock
    always @(posedge clk) obj_px_d <= obj_px;
    reg r2_p = 0, r2_lit = 0, r2_red = 0, r2_out = 0, r2_txt = 0, r2_tint = 0;
    reg [2:0] r2_scr = 0;
    reg [2:0] r2_gx = 0;
    reg [7:0] r2_font = 0;
    always @(posedge clk) begin
        r2_p <= r1_p; r2_tint <= r1_tint; r2_scr <= r1_scr; r2_vb <= r1_vb; r2_ovs <= r1_ovs; r2_lit <= r1_lit; r2_red <= r1_red; r2_out <= r1_out;
        r2_txt <= r1_txt; r2_gx <= r1_gx;
        r2_font <= fontmem[r1_faddr];
    end
    wire txt_on = r2_txt && r2_font[3'd7 - r2_gx];
    // on-screen health: hearts (player) + bar (boss), same latency as the tile path; game screen only
    wire [11:0] hud_px; wire hud_on;
    hud hud0 (.clk(clk), .hcount(hcount), .vcount(vcount), .hp(hud_hp), .hp_max(hud_hp_max), .boss_on(boss_act), .floor(floor),
              .b_hp(hud_b_hp), .hud_px(hud_px), .hud_on(hud_on));

    // ======================= stage 3: เลือกชั้น =======================
    always @(posedge clk) begin
        if (txt_on)                                  color <= 12'hFFF;    // ข้อความอยู่บนสุด
        else if (r2_scr == 3'd0 && hud_on)           color <= hud_px;     // hearts / boss bar above the world
        else if (DEATH_ANIM_EN && r2_scr == 3'd2 && r2_p && r2_asel == 3'd4 && spr_fin != C_T) color <= spr_fin;   // death animation over the GAME OVER colour
        else if (r2_scr == 3'd4)                     color <= 12'h000;    // prologue: black screen
        else if (r2_scr == 3'd2)                     color <= C_OVER;
        else if (r2_scr == 3'd3)                     color <= C_WIN;
        else if (r2_p && spr_fin != C_T)             color <= r2_tint ? (spr_fin | 12'hCCC) : spr_fin;   // ชาร์จเต็ม: สว่าง
        else if (r2_scr == 3'd1)                     color <= {4'h1, 2'b00, r2_vb[2:1], 4'h4 + {1'b0, r2_vb}};   // TITLE: navy -> blue gradient (W6)
        else if (r2_out)                             color <= 12'h000;    // จอสั่น: ขอบที่เลื่อนออก
        else if (obj_px_d != C_T)                    color <= obj_px_d;   // มอน < กระสุน < ฟัน (เรียงใน objline)
        else if (r2_red)                             color <= {4'hF, 1'b0, tile_px[7:5], 1'b0, tile_px[3:1]};   // Simon ผิด: แดง
        else if (r2_lit)                             color <= {1'b1, tile_px[11:9], 1'b1, tile_px[7:5], 1'b1, tile_px[3:1]}; // สว่าง
        else if (r2_ovs != 2'd0 && ov_px != C_T)     color <= ov_px;       // W5: breakable block / trap / decoration over the floor
        else                                         color <= tile_px;
    end
endmodule
