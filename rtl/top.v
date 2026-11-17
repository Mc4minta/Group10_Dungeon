// Group 10 — top module (Nexys A7-100T)
// สถานะตอนนี้: P0-P1 = ภาพ + เดิน 8 ทิศ + collision + เปลี่ยนห้อง flip-screen
//
// ปุ่ม debug ชั่วคราว (ลบออกเมื่อมีระบบจริง):
//   BTNC  กด  = เปลี่ยนร่าง (แทน EVOLVE จนกว่าจะมีปริศนา)   กดค้าง = strafe
//   SW0       = เปิดประตูบอส L (แทน has_item)
//   SW1   ยก  = ไปชั้นถัดไป (แทน FLOOR_CLEAR)
//   SW2       = ปิดประตู D (ทดสอบห้อง Combat ล็อก)
// 7-seg: [ชั้น] - [ร่าง] - [ห้อง]    LED0-3 = ปุ่มทิศ, LED15 = ชนะ (แตะประตู E)
module top #(
    parameter DEBOUNCE = 1_000_000,         // 10 ms ที่ 100 MHz
    parameter CE_DIV   = 4                  // บอร์ดจริง = 4 (25 MHz) / simulator บนจอคอม = 1 (เร็วขึ้น 4 เท่า)
) (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC, BTNU, BTND, BTNL, BTNR,
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire        LED16_R, LED16_G, LED16_B,
    output wire        LED17_R, LED17_G, LED17_B,
    output wire        CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0]  AN,
    output reg  [3:0]  VGA_R = 0, VGA_G = 0, VGA_B = 0,
    output reg         VGA_HS = 1, VGA_VS = 1,
    output wire        AUD_PWM, AUD_SD
);
    wire clk = CLK100MHZ;

    // ---------- reset + pixel enable ----------
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~CPU_RESETN};
    wire rst = rst_sync[1];

    reg [1:0] ce_cnt = 0;
    always @(posedge clk) ce_cnt <= (ce_cnt == CE_DIV - 1) ? 2'd0 : ce_cnt + 1'b1;
    wire ce = (ce_cnt == CE_DIV - 1);        // 25 MHz เมื่อ CE_DIV = 4

    // ---------- input ----------
    wire bu, bd, bl, br, bc, bc_rise, sw1, sw1_rise;
    debounce #(DEBOUNCE) d_u (.clk(clk), .in(BTNU),  .level(bu), .rise());
    debounce #(DEBOUNCE) d_d (.clk(clk), .in(BTND),  .level(bd), .rise());
    debounce #(DEBOUNCE) d_l (.clk(clk), .in(BTNL),  .level(bl), .rise());
    debounce #(DEBOUNCE) d_r (.clk(clk), .in(BTNR),  .level(br), .rise());
    debounce #(DEBOUNCE) d_c (.clk(clk), .in(BTNC),  .level(bc), .rise(bc_rise));
    debounce #(DEBOUNCE) d_s1(.clk(clk), .in(SW[1]), .level(sw1), .rise(sw1_rise));

    // ---------- VGA timing ----------
    wire [9:0] hcount, vcount;
    wire hsync, vsync, active, frame_tick;
    vga_sync vga (.clk(clk), .rst(rst), .ce(ce), .hcount(hcount), .vcount(vcount),
                  .hsync(hsync), .vsync(vsync), .active(active), .frame_tick(frame_tick));

    // ---------- game state (P2 จะย้ายไป game_fsm.v) ----------
    localparam R_START = 3'd0, R_C1 = 3'd1, R_C2 = 3'd2, R_PUZ = 3'd3, R_BOSS = 3'd4;
    reg [1:0] floor = 0;
    reg [2:0] room  = R_START;
    reg [1:0] form  = 0;
    reg       win   = 0;

    // ห้อง (floor, room) -> grid 0..12 (ลำดับไฟล์ใน maps/)
    wire [3:0] grid = (room == R_START) ? ((floor == 2'd2) ? 4'd1 : 4'd0) :
                      (room == R_C1)    ? 4'd4 + floor * 4'd3 :
                      (room == R_C2)    ? 4'd5 + floor * 4'd3 :
                      (room == R_PUZ)   ? 4'd6 + floor * 4'd3 :
                                          ((floor == 2'd1) ? 4'd3 : 4'd2);   // BOSS

    wire doors_open = ~SW[2];
    wire open_L     = SW[0];

    // จุดเกิดหน้าประตู (มุมซ้ายบนของ sprite)
    localparam [9:0] SP_LX = 10'd40,  SP_RX = 10'd568, SP_MX = 10'd304,
                     SP_MY = 10'd240, SP_TY = 10'd40,  SP_BY = 10'd408,
                     ST_X  = 10'd288, ST_Y  = 10'd224;   // จุด P ในห้อง START

    wire [9:0] px, py;
    wire [1:0] facing, pose, door_dir;
    wire       door_evt;
    reg        load = 1;
    reg  [9:0] load_x = ST_X, load_y = ST_Y;

    always @(posedge clk) begin
        load <= 1'b0;
        if (rst) begin
            floor <= 0; room <= R_START; form <= 0; win <= 0;
            load <= 1'b1; load_x <= ST_X; load_y <= ST_Y;
        end else begin
            if (bc_rise) form <= form + 1'b1;                 // debug: เปลี่ยนร่าง
            if (sw1_rise) begin                               // debug: ชั้นถัดไป
                floor <= (floor == 2'd2) ? 2'd0 : floor + 1'b1;
                room  <= R_START;
                load <= 1'b1; load_x <= ST_X; load_y <= ST_Y;
            end else if (door_evt) begin
                load <= 1'b1;
                case (room)
                    R_START: if (door_dir == 2'd3) begin room <= R_C1;  load_x <= SP_LX; load_y <= SP_MY; end
                             else                  begin win <= 1'b1; load <= 1'b0; end   // ประตู E
                    R_C1: case (door_dir)
                            2'd2:    begin room <= R_START; load_x <= SP_RX; load_y <= SP_MY; end
                            2'd1:    begin room <= R_C2;    load_x <= SP_MX; load_y <= SP_BY; end
                            default: begin room <= R_BOSS;  load_x <= SP_LX; load_y <= SP_MY; end
                          endcase
                    R_C2:    if (door_dir == 2'd0) begin room <= R_C1;  load_x <= SP_MX; load_y <= SP_TY; end
                             else                  begin room <= R_PUZ; load_x <= SP_LX; load_y <= SP_MY; end
                    R_PUZ:   begin room <= R_C2; load_x <= SP_RX; load_y <= SP_MY; end
                    default: begin room <= R_C1; load_x <= SP_RX; load_y <= SP_MY; end   // BOSS -> C1
                endcase
            end
        end
    end

    player pl (.clk(clk), .rst(rst), .frame_tick(frame_tick),
               .up(bu), .down(bd), .left(bl), .right(br), .hold_facing(bc),
               .form(form), .grid(grid), .doors_open(doors_open), .open_L(open_L),
               .load(load), .load_x(load_x), .load_y(load_y),
               .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir));

    // ---------- render ----------
    wire [5:0]  pframe = form * 6'd12 + facing * 6'd3 + pose;
    wire [11:0] color;
    renderer rnd (.clk(clk), .hcount(hcount), .vcount(vcount), .grid(grid), .floor(floor),
                  .form(form), .doors_open(doors_open), .open_L(open_L),
                  .px(px), .py(py), .pframe(pframe), .color(color));

    always @(posedge clk) if (ce) begin
        {VGA_R, VGA_G, VGA_B} <= active ? color : 12'h000;
        VGA_HS <= hsync;
        VGA_VS <= vsync;
    end

    // ---------- 7-seg / LED / RGB ----------
    wire [6:0] seg;
    seg7 s7 (.clk(clk),
             .digits({1'b0, {1'b0, floor} + 3'd1, 4'hE, 1'b0, {1'b0, form} + 3'd1, 4'hE, 4'hF, 4'hF, 4'hF, 1'b0, room}),
             .seg(seg), .an(AN));
    assign {CG, CF, CE, CD, CC, CB, CA} = seg;
    assign DP = 1'b1;

    assign LED = {win, 11'd0, br, bl, bd, bu};

    reg [7:0] pwm = 0;
    always @(posedge clk) pwm <= pwm + 1'b1;
    wire dim = (pwm < 8'd16);                     // RGB LED สว่างมาก: duty ~6%
    // สีตามร่าง: เขียว / ฟ้า / ม่วง / ทอง
    assign LED16_R = dim & (form == 2'd2 || form == 2'd3);
    assign LED16_G = dim & (form == 2'd0 || form == 2'd1 || form == 2'd3);
    assign LED16_B = dim & (form == 2'd1 || form == 2'd2);
    assign {LED17_R, LED17_G, LED17_B} = 3'b000;  // P3: แดงตอนโดนตี

    assign AUD_PWM = 1'b0;                        // P6: เสียง
    assign AUD_SD  = 1'b0;
endmodule
