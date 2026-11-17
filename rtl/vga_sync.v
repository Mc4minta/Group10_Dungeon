// VGA 640x480 @ 60 Hz, pixel = 25 MHz (ce ทุก 4 clock ของ 100 MHz)
// hsync/vsync/active เป็น combinational จาก counter -> top ลง register พร้อมสีตอน ce
module vga_sync (
    input  wire       clk,
    input  wire       rst,
    input  wire       ce,          // pixel enable 25 MHz
    output reg  [9:0] hcount = 0,
    output reg  [9:0] vcount = 0,
    output wire       hsync,
    output wire       vsync,
    output wire       active,
    output wire       frame_tick   // 1 clock ตอนเริ่ม vertical blanking (x=0, y=480)
);
    localparam H_VIS = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOT = 800;
    localparam V_VIS = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOT = 525;

    always @(posedge clk) begin
        if (rst) begin
            hcount <= 0;
            vcount <= 0;
        end else if (ce) begin
            if (hcount == H_TOT - 1) begin
                hcount <= 0;
                vcount <= (vcount == V_TOT - 1) ? 10'd0 : vcount + 10'd1;
            end else begin
                hcount <= hcount + 10'd1;
            end
        end
    end

    assign hsync  = ~((hcount >= H_VIS + H_FP) && (hcount < H_VIS + H_FP + H_SYNC)); // active-low
    assign vsync  = ~((vcount >= V_VIS + V_FP) && (vcount < V_VIS + V_FP + V_SYNC)); // active-low
    assign active = (hcount < H_VIS) && (vcount < V_VIS);
    assign frame_tick = ce && (hcount == 0) && (vcount == V_VIS);
endmodule
