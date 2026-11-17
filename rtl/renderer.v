// วาดภาพต่อพิกเซล: tile -> sprite ผู้เล่น (F0F = โปร่งใส)
// screen: 0 เกม · 1 TITLE (พื้นกรมท่า + sprite ที่ px,py ที่ top ส่งมา) · 2 GAME OVER (แดงเข้มเต็มจอ) · 3 WIN (ทองเต็มจอ)
// hide_player: ซ่อน sprite (กะพริบตอน EVOLVE)
// สีออกมาภายใน 2 clock หลัง hcount/vcount เปลี่ยน (top จับค่าตอน ce ถัดไป)
// TODO P3: object slot (มอน กระสุน บอส), P5: ข้อความ, จอสั่น
module renderer (
    input  wire        clk,
    input  wire [9:0]  hcount, vcount,
    input  wire [3:0]  grid,
    input  wire [1:0]  floor,
    input  wire [1:0]  form,
    input  wire        doors_open, open_L,
    input  wire [1:0]  screen,
    input  wire        hide_player,
    input  wire [9:0]  px, py,
    input  wire [5:0]  pframe,        // form*12 + facing*3 + pose
    output wire [11:0] color
);
    // ----- tile -----
    wire [3:0] tid;
    tilemap_rom map (.addr(grid * 12'd300 + vcount[8:5] * 12'd20 + hcount[9:5]), .data(tid));

    // สถานะประตูเลือกรูปเปิด/ปิด
    reg [3:0] tvis;
    always @* begin
        case (tid)
            4'h2: tvis = doors_open ? 4'h8 : 4'h2;
            4'h3: tvis = open_L     ? 4'h9 : 4'h3;
            4'h4: tvis = (form == 2'd3) ? 4'hA : 4'h4;
            default: tvis = tid;
        endcase
    end

    wire [11:0] tile_px;
    tileset_rom tset (.clk(clk),
                      .addr({floor * 6'd16 + {2'b00, tvis}, vcount[4:0], hcount[4:0]}),
                      .data(tile_px));

    // ----- player sprite -----
    wire [9:0] sx = hcount - px;
    wire [9:0] sy = vcount - py;
    wire in_spr = (hcount >= px) && (sx < 10'd32) && (vcount >= py) && (sy < 10'd32);
    wire [11:0] spr_px;
    player_rom pspr (.clk(clk), .addr({pframe, sy[4:0], sx[4:0]}), .data(spr_px));

    reg in_spr_d = 0;
    always @(posedge clk) in_spr_d <= in_spr;

    localparam [11:0] C_NAVY = 12'h114, C_OVER = 12'h300, C_WIN = 12'hFB0;
    wire spr_on = in_spr_d && !hide_player && (spr_px != 12'hF0F);
    assign color = (screen == 2'd2) ? C_OVER :
                   (screen == 2'd3) ? C_WIN  :
                   spr_on           ? spr_px :
                   (screen == 2'd1) ? C_NAVY : tile_px;
endmodule
