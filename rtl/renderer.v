// วาดภาพต่อพิกเซล (pipeline 3 clock ทุกชั้นเท่ากัน)
//   ชั้น (ล่าง -> บน): tile < มอน < กระสุน < เอฟเฟกต์ฟัน < ผู้เล่น      F0F = โปร่งใส
//   screen: 0 เกม · 1 TITLE (พื้นกรมท่า + sprite ที่ px,py ที่ top ส่งมา) · 2 GAME OVER (แดงเข้ม) · 3 WIN (ทอง)
//   hide_player: ซ่อน sprite (กะพริบตอน EVOLVE / อมตะหลังโดนตี)
//
// pipeline (สีของพิกเซล hcount/vcount ออกที่ color หลัง 3 clock -> top หน่วง hsync/vsync/active 3 clock ให้ตรงกัน)
//   stage 1: เทียบตำแหน่ง (tile map, ผู้เล่น, มอน 6, กระสุน 18, ฟัน) -> register address ROM + flag
//   stage 2: อ่าน ROM (BRAM sync) + หน่วง flag
//   stage 3: เลือกชั้น -> register color
// ที่ CE_DIV = 4 hcount ค้าง 4 clock, top จับสีตอน ce -> latency 3 ไม่ทำให้ภาพเลื่อน
module renderer (
    input  wire         clk,
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
    input  wire         melee_on,
    input  wire [1:0]   melee_dir,
    output reg  [11:0]  color = 12'h000
);
    localparam [11:0] C_NAVY = 12'h114, C_OVER = 12'h300, C_WIN = 12'hFB0, C_T = 12'hF0F;
    integer k;

    // ======================= stage 1 =======================
    // ----- tile -----
    wire [3:0] tid;
    tilemap_rom map (.addr(grid * 12'd300 + vcount[8:5] * 12'd20 + hcount[9:5]), .data(tid));
    reg [3:0] tvis;
    always @* begin                  // สถานะประตูเลือกรูปเปิด/ปิด
        case (tid)
            4'h2: tvis = doors_open ? 4'h8 : 4'h2;
            4'h3: tvis = open_L     ? 4'h9 : 4'h3;
            4'h4: tvis = (form == 2'd3) ? 4'hA : 4'h4;
            default: tvis = tid;
        endcase
    end

    // ----- player -----
    wire [9:0] sx = hcount - px;
    wire [9:0] sy = vcount - py;
    wire in_spr = (hcount >= px) && (sx < 10'd32) && (vcount >= py) && (sy < 10'd32);

    // ----- มอน: ตัว index ต่ำสุดที่ทับพิกเซลนี้ -----
    reg       m_hit;
    reg [2:0] m_sel;
    reg [9:0] m_dx, m_dy;
    always @* begin
        m_hit = 1'b0; m_sel = 3'd0;
        for (k = 5; k >= 0; k = k - 1)
            if (mon_act[k] && (hcount - mon_x[k*10 +: 10]) < 10'd32 && (vcount - mon_y[k*10 +: 10]) < 10'd32) begin
                m_hit = 1'b1; m_sel = k[2:0];
            end
        m_dx = hcount - mon_x[m_sel*10 +: 10];
        m_dy = vcount - mon_y[m_sel*10 +: 10];
    end

    // ----- กระสุน 8x8: ผู้เล่น 2 นัดก่อน แล้วศัตรู 16 นัด -----
    reg       b_hit, b_kind;
    reg [2:0] b_sx, b_sy;
    reg [9:0] t_dx, t_dy;
    always @* begin
        b_hit = 1'b0; b_kind = 1'b0; b_sx = 0; b_sy = 0;
        for (k = 15; k >= 0; k = k - 1) begin
            t_dx = hcount - eb_x[k*10 +: 10];
            t_dy = vcount - eb_y[k*10 +: 10];
            if (eb_act[k] && t_dx < 10'd8 && t_dy < 10'd8) begin
                b_hit = 1'b1; b_kind = 1'b1; b_sx = t_dx[2:0]; b_sy = t_dy[2:0];
            end
        end
        for (k = 1; k >= 0; k = k - 1) begin
            t_dx = hcount - pb_x[k*10 +: 10];
            t_dy = vcount - pb_y[k*10 +: 10];
            if (pb_act[k] && t_dx < 10'd8 && t_dy < 10'd8) begin
                b_hit = 1'b1; b_kind = 1'b0; b_sx = t_dx[2:0]; b_sy = t_dy[2:0];
            end
        end
    end

    // ----- เอฟเฟกต์ฟัน 32x32 ที่ช่องหน้าตัว -----
    wire [9:0] ex = (melee_dir == 2'd2) ? px - 10'd24 : (melee_dir == 2'd3) ? px + 10'd24 : px;
    wire [9:0] ey = (melee_dir == 2'd0) ? py + 10'd24 : (melee_dir == 2'd1) ? py - 10'd24 : py;
    wire [9:0] e_dx = hcount - ex;
    wire [9:0] e_dy = vcount - ey;
    wire e_hit = melee_on && (e_dx < 10'd32) && (e_dy < 10'd32);

    reg [15:0] r1_taddr = 0;
    reg [15:0] r1_paddr = 0;
    reg [11:0] r1_maddr = 0, r1_eaddr = 0;
    reg [6:0]  r1_baddr = 0;
    reg        r1_p = 0, r1_m = 0, r1_mf = 0, r1_b = 0, r1_e = 0;
    reg [1:0]  r1_scr = 0;
    always @(posedge clk) begin
        r1_taddr <= {floor * 6'd16 + {2'b00, tvis}, vcount[4:0], hcount[4:0]};
        r1_paddr <= {pframe, sy[4:0], sx[4:0]};
        r1_p     <= in_spr && !hide_player;
        r1_maddr <= {mon_type[m_sel], mon_anim, m_dy[4:0], m_dx[4:0]};
        r1_m     <= m_hit;
        r1_mf    <= mon_flash[m_sel];
        r1_baddr <= {b_kind, b_sy, b_sx};
        r1_b     <= b_hit;
        r1_eaddr <= {melee_dir, e_dy[4:0], e_dx[4:0]};
        r1_e     <= e_hit;
        r1_scr   <= screen;
    end

    // ======================= stage 2: ROM =======================
    wire [11:0] tile_px, spr_px, mon_px, eff_px, bul_px;
    tileset_rom tset (.clk(clk), .addr(r1_taddr), .data(tile_px));
    player_rom  pspr (.clk(clk), .addr(r1_paddr), .data(spr_px));
    monster_rom mrom (.clk(clk), .addr(r1_maddr), .data(mon_px));
    effect_rom  erom (.clk(clk), .addr(r1_eaddr), .data(eff_px));
    bullet_rom  brom (.clk(clk), .addr(r1_baddr), .data(bul_px));

    reg r2_p = 0, r2_m = 0, r2_mf = 0, r2_b = 0, r2_e = 0;
    reg [1:0] r2_scr = 0;
    always @(posedge clk) begin
        r2_p <= r1_p; r2_m <= r1_m; r2_mf <= r1_mf; r2_b <= r1_b; r2_e <= r1_e; r2_scr <= r1_scr;
    end

    // ======================= stage 3: เลือกชั้น =======================
    always @(posedge clk) begin
        if (r2_scr == 2'd2)                          color <= C_OVER;
        else if (r2_scr == 2'd3)                     color <= C_WIN;
        else if (r2_p && spr_px != C_T)              color <= spr_px;
        else if (r2_scr == 2'd1)                     color <= C_NAVY;
        else if (r2_e && eff_px != C_T)              color <= eff_px;
        else if (r2_b && bul_px != C_T)              color <= bul_px;
        else if (r2_m && mon_px != C_T)              color <= r2_mf ? 12'hFFF : mon_px;
        else                                         color <= tile_px;
    end
endmodule
