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
    output reg  [11:0]  color = 12'h000
);
    localparam [11:0] C_NAVY = 12'h114, C_OVER = 12'h300, C_WIN = 12'hFB0, C_T = 12'hF0F;

    // ======================= stage 1 =======================
    // ----- tile -----
    wire [3:0] tid;
    wire [11:0] taddr = grid * 12'd300 + vcount[8:5] * 12'd20 + hcount[9:5];
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
    wire [9:0] sx = hcount - px;
    wire [9:0] sy = vcount - py;
    wire in_spr = (hcount >= px) && (sx < 10'd32) && (vcount >= py) && (sy < 10'd32);

    reg [15:0] r1_taddr = 0;
    reg [15:0] r1_paddr = 0;
    reg        r1_p = 0, r1_lit = 0, r1_red = 0;
    reg [1:0]  r1_scr = 0;
    always @(posedge clk) begin
        r1_taddr <= {floor * 6'd16 + {2'b00, tvis}, vcount[4:0], hcount[4:0]};
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
                      .px(px), .py(py), .obj_px(obj_px));

    reg r2_p = 0, r2_lit = 0, r2_red = 0;
    reg [1:0] r2_scr = 0;
    always @(posedge clk) begin
        r2_p <= r1_p; r2_scr <= r1_scr; r2_lit <= r1_lit; r2_red <= r1_red;
    end

    // ======================= stage 3: เลือกชั้น =======================
    always @(posedge clk) begin
        if (r2_scr == 2'd2)                          color <= C_OVER;
        else if (r2_scr == 2'd3)                     color <= C_WIN;
        else if (r2_p && spr_px != C_T)              color <= spr_px;
        else if (r2_scr == 2'd1)                     color <= C_NAVY;
        else if (obj_px != C_T)                      color <= obj_px;   // มอน < กระสุน < ฟัน (เรียงใน objline)
        else if (r2_red)                             color <= {4'hF, 1'b0, tile_px[7:5], 1'b0, tile_px[3:1]};   // Simon ผิด: แดง
        else if (r2_lit)                             color <= {1'b1, tile_px[11:9], 1'b1, tile_px[7:5], 1'b1, tile_px[3:1]}; // สว่าง
        else                                         color <= tile_px;
    end
endmodule
