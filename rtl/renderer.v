// วาดภาพต่อพิกเซล (pipeline 3 clock ทุกชั้นเท่ากัน)
//   ชั้น (ล่าง -> บน): tile < มอน < กระสุน < เอฟเฟกต์ฟัน < ผู้เล่น      F0F = โปร่งใส
//   screen: 0 เกม · 1 TITLE (พื้นกรมท่า + sprite ที่ px,py ที่ top ส่งมา) · 2 GAME OVER (แดงเข้ม) · 3 WIN (ทอง)
//   hide_player: ซ่อน sprite (กะพริบตอน EVOLVE / อมตะหลังโดนตี)
//
// pipeline (สีของพิกเซล hcount/vcount ออกที่ color หลัง 3 clock -> top หน่วง hsync/vsync/active 3 clock ให้ตรงกัน)
//   stage 1: tile map + ผู้เล่น -> register address ROM + flag
//   stage 2: อ่าน ROM (BRAM sync) + หน่วง flag; ชั้น object มาจาก objline.v (line buffer) ตรงเวลานี้
//   stage 3: เลือกชั้น -> register color
// ที่ CE_DIV = 4 hcount ค้าง 4 clock, top จับสีตอน ce -> latency 3 ไม่ทำให้ภาพเลื่อน
module renderer (
    input  wire         clk,
    input  wire         ce,
    input  wire [9:0]   hcount, vcount,
    input  wire [3:0]   grid,
    input  wire [1:0]   floor,
    input  wire [1:0]   form,
    input  wire         doors_open, open_L,
    input  wire [1:0]   screen,
    input  wire         hide_player,
    input  wire [9:0]   px, py,
    input  wire [5:0]   pframe,        // form*12 + facing*3 + pose
    // ---------- objects (จาก objects.v) ----------
    input  wire [5:0]   mon_act, mon_type, mon_flash,
    input  wire [59:0]  mon_x, mon_y,
    input  wire         mon_anim,
    input  wire [1:0]   pb_act,
    input  wire [19:0]  pb_x, pb_y,
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
    input  wire [2:0]   txt_scr,          // ข้อความ: 0 ไม่มี 1 TITLE 2 FLOOR CLEAR 3 ESCAPE! 4 WIN 5 GAME OVER
    input  wire         txt_blink,        // 1 = ซ่อนบรรทัดที่กะพริบ
    input  wire [3:0]   t_floor, t_m1, t_m0, t_s1, t_s0,   // ตัวเลขสดในข้อความ
    output reg  [11:0]  color = 12'h000
);
    `include "text_layout.vh"
    localparam [11:0] C_NAVY = 12'h114, C_OVER = 12'h300, C_WIN = 12'hFB0, C_T = 12'hF0F;

    // ======================= stage 1 =======================
    // ----- tile -----
    wire [3:0] tid;
    // จอสั่น: ทุกชั้นภาพใช้พิกัดที่เลื่อนแล้ว (hs, vs); นอกจอ = ดำ
    wire [9:0] hs = hcount + sh_dx;
    wire [9:0] vs = vcount + sh_dy;
    wire [11:0] taddr = grid * 12'd300 + vs[8:5] * 12'd20 + hs[9:5];
    tilemap_rom map (.addr(taddr), .data(tid));
    reg [3:0] tvis;
    always @* begin                  // สถานะประตูเลือกรูปเปิด/ปิด
        case (tid)
            4'h2: tvis = doors_open ? 4'h8 : 4'h2;
            4'h3: tvis = open_L     ? 4'h9 : 4'h3;
            4'h4: tvis = (form == 2'd3) ? 4'hA : 4'h4;
            4'h7: tvis = ((pbox_en[0] && taddr == pbox0) || (pbox_en[1] && taddr == pbox1)) ? 4'hB : 4'h7;
            default: tvis = tid;
        endcase
    end

    // ----- player -----
    wire [9:0] sx = hs - px;
    wire [9:0] sy = vs - py;
    wire in_spr = (hs >= px) && (sx < 10'd32) && (vs >= py) && (sy < 10'd32);

    reg [15:0] r1_taddr = 0;
    reg [15:0] r1_paddr = 0;
    reg        r1_p = 0, r1_lit = 0, r1_red = 0, r1_out = 0;
    reg [1:0]  r1_scr = 0;
    // ----- ข้อความ: ไม่เกิน 2 บรรทัดต่อหน้าจอ, ฟอนต์ 8x8 ขยาย 2x / 4x (คิดเฉพาะตอนมีข้อความบนจอ) -----
    reg [5:0]  txtmem [0:127];
    reg [7:0]  fontmem [0:511];
    initial $readmemh("text.mem", txtmem);
    initial $readmemh("font.mem", fontmem);
    reg [8:0]  r1_faddr = 0;
    reg [2:0]  r1_gx = 0;
    reg        r1_txt = 0;
    reg [9:0]  ly0, lx0, lw0, lh0, ly1, lx1, lw1, lh1, rx, ry, rx0, ry0, rx1, ry1;
    reg        ls0, ls1, lk0, lk1, in0, in1, s4, kk;
    reg [6:0]  lb0, lb1, bb, ta_;
    reg [5:0]  code;
    reg [4:0]  colc;
    always @(posedge clk) begin
        r1_txt <= 1'b0;
        if (txt_scr != 0) begin
            case (txt_scr)
                3'd1: begin ly0 = T10_Y; lx0 = T10_X; lw0 = T10_W; lh0 = T10_H; ls0 = T10_S; lb0 = T10_B; lk0 = T10_K;
                            ly1 = T11_Y; lx1 = T11_X; lw1 = T11_W; lh1 = T11_H; ls1 = T11_S; lb1 = T11_B; lk1 = T11_K; end
                3'd2: begin ly0 = T20_Y; lx0 = T20_X; lw0 = T20_W; lh0 = T20_H; ls0 = T20_S; lb0 = T20_B; lk0 = T20_K;
                            ly1 = T21_Y; lx1 = T21_X; lw1 = T21_W; lh1 = T21_H; ls1 = T21_S; lb1 = T21_B; lk1 = T21_K; end
                3'd3: begin ly0 = T30_Y; lx0 = T30_X; lw0 = T30_W; lh0 = T30_H; ls0 = T30_S; lb0 = T30_B; lk0 = T30_K;
                            ly1 = T31_Y; lx1 = T31_X; lw1 = T31_W; lh1 = T31_H; ls1 = T31_S; lb1 = T31_B; lk1 = T31_K; end
                3'd4: begin ly0 = T40_Y; lx0 = T40_X; lw0 = T40_W; lh0 = T40_H; ls0 = T40_S; lb0 = T40_B; lk0 = T40_K;
                            ly1 = T41_Y; lx1 = T41_X; lw1 = T41_W; lh1 = T41_H; ls1 = T41_S; lb1 = T41_B; lk1 = T41_K; end
                default: begin ly0 = T50_Y; lx0 = T50_X; lw0 = T50_W; lh0 = T50_H; ls0 = T50_S; lb0 = T50_B; lk0 = T50_K;
                            ly1 = T51_Y; lx1 = T51_X; lw1 = T51_W; lh1 = T51_H; ls1 = T51_S; lb1 = T51_B; lk1 = T51_K; end
            endcase
            rx0 = hcount - lx0; ry0 = vcount - ly0; in0 = (rx0 < lw0) && (ry0 < lh0);
            rx1 = hcount - lx1; ry1 = vcount - ly1; in1 = (rx1 < lw1) && (ry1 < lh1);
            rx = in0 ? rx0 : rx1;  ry = in0 ? ry0 : ry1;
            s4 = in0 ? ls0 : ls1;  bb = in0 ? lb0 : lb1;  kk = in0 ? lk0 : lk1;
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
            r1_txt   <= (in0 || in1) && !(kk && txt_blink);
        end
    end
    always @(posedge clk) begin
        r1_out   <= (hs >= 10'd640) || (vs >= 10'd480);
        r1_taddr <= {floor * 6'd16 + {2'b00, tvis}, vs[4:0], hs[4:0]};
        r1_paddr <= {pframe, sy[4:0], sx[4:0]};
        r1_p     <= in_spr && !hide_player;
        r1_scr   <= screen;
        r1_lit   <= simon_lit_on && (tid == {2'b11, simon_lit});
        r1_red   <= simon_wrong && (tid >= 4'hC);
    end

    // ======================= stage 2: ROM =======================
    wire [11:0] tile_px, spr_px, obj_px;
    tileset_rom tset (.clk(clk), .addr(r1_taddr), .data(tile_px));
    player_rom  pspr (.clk(clk), .addr(r1_paddr), .data(spr_px));
    objline     objl (.clk(clk), .ce(ce), .hcount(hcount), .vcount(vcount),
                      .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                      .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y),
                      .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir),
                      .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame),
                      .boss_act(boss_act), .boss_x(boss_x), .boss_y(boss_y), .boss_frame(boss_frame),
                      .boss_flash(boss_flash), .sh_dx(sh_dx), .sh_dy(sh_dy),
                      .px(px), .py(py), .obj_px(obj_px));

    reg r2_p = 0, r2_lit = 0, r2_red = 0, r2_out = 0, r2_txt = 0;
    reg [1:0] r2_scr = 0;
    reg [2:0] r2_gx = 0;
    reg [7:0] r2_font = 0;
    always @(posedge clk) begin
        r2_p <= r1_p; r2_scr <= r1_scr; r2_lit <= r1_lit; r2_red <= r1_red; r2_out <= r1_out;
        r2_txt <= r1_txt; r2_gx <= r1_gx;
        r2_font <= fontmem[r1_faddr];
    end
    wire txt_on = r2_txt && r2_font[3'd7 - r2_gx];

    // ======================= stage 3: เลือกชั้น =======================
    always @(posedge clk) begin
        if (txt_on)                                  color <= 12'hFFF;    // ข้อความอยู่บนสุด
        else if (r2_scr == 2'd2)                     color <= C_OVER;
        else if (r2_scr == 2'd3)                     color <= C_WIN;
        else if (r2_p && spr_px != C_T)              color <= spr_px;
        else if (r2_scr == 2'd1)                     color <= C_NAVY;
        else if (r2_out)                             color <= 12'h000;    // จอสั่น: ขอบที่เลื่อนออก
        else if (obj_px != C_T)                      color <= obj_px;   // มอน < กระสุน < ฟัน (เรียงใน objline)
        else if (r2_red)                             color <= {4'hF, 1'b0, tile_px[7:5], 1'b0, tile_px[3:1]};   // Simon ผิด: แดง
        else if (r2_lit)                             color <= {1'b1, tile_px[11:9], 1'b1, tile_px[7:5], 1'b1, tile_px[3:1]}; // สว่าง
        else                                         color <= tile_px;
    end
endmodule
