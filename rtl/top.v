// Group 10 — top module (Nexys A7-100T)
// สถานะตอนนี้: P2 = TITLE/PLAY/EVOLVE/FLOOR_CLEAR/WIN/GAME_OVER + HP + timer + sprint (ดู game_fsm.v, world.v)
//
// ปุ่ม / สวิตช์:
//   BTNU/D/L/R เดิน · BTNC กดครั้งเดียว = เริ่มเกม (TITLE) / กลับ TITLE (WIN, GAME_OVER) · BTNC ค้าง = strafe
//   SW15 = sprint (ความเร็ว +1 px/เฟรม, ใช้ได้ทุกร่าง)
// ปุ่ม debug ชั่วคราว (ลบเมื่อมีระบบจริง):
//   SW0 = เปิดประตูบอส L (แทน has_item)        SW2 = ปิดประตู D (ทดสอบห้อง Combat ล็อก)
//   SW1 ยก = floor_done  (P5: มาจากบอสตาย)      SW3 ยก = got_item -> EVOLVE (P4: มาจากปริศนา)
//   SW4 ยก = take_hit HP-1 (P3: มาจากศัตรู)
// 7-seg: [ชั้น] - [HP] - mm.ss (TITLE = ----)   LED0-3 = ปุ่มทิศ, LED8-11 = HP, LED14 = sprint, LED15 = WIN
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
    wire bu, bd, bl, br, bc, bc_rise, sw1_rise, sw3_rise, sw4_rise, sw15;
    debounce #(DEBOUNCE) d_u (.clk(clk), .in(BTNU),  .level(bu), .rise());
    debounce #(DEBOUNCE) d_d (.clk(clk), .in(BTND),  .level(bd), .rise());
    debounce #(DEBOUNCE) d_l (.clk(clk), .in(BTNL),  .level(bl), .rise());
    debounce #(DEBOUNCE) d_r (.clk(clk), .in(BTNR),  .level(br), .rise());
    debounce #(DEBOUNCE) d_c (.clk(clk), .in(BTNC),  .level(bc), .rise(bc_rise));
    debounce #(DEBOUNCE) d_s1(.clk(clk), .in(SW[1]),  .level(), .rise(sw1_rise));
    debounce #(DEBOUNCE) d_s3(.clk(clk), .in(SW[3]),  .level(), .rise(sw3_rise));
    debounce #(DEBOUNCE) d_s4(.clk(clk), .in(SW[4]),  .level(), .rise(sw4_rise));
    debounce #(DEBOUNCE) d_s15(.clk(clk), .in(SW[15]), .level(sw15), .rise());

    // ---------- VGA timing ----------
    wire [9:0] hcount, vcount;
    wire hsync, vsync, active, frame_tick;
    vga_sync vga (.clk(clk), .rst(rst), .ce(ce), .hcount(hcount), .vcount(vcount),
                  .hsync(hsync), .vsync(vsync), .active(active), .frame_tick(frame_tick));

    // ---------- world (ห้อง/ประตู) + game FSM ----------
    wire [1:0] floor;
    wire [2:0] room;
    wire [3:0] grid;
    wire       load, exit_evt, restart, next_floor;
    wire [9:0] load_x, load_y;

    wire doors_open = ~SW[2];
    wire open_L     = SW[0];

    wire [9:0] px, py;
    wire [1:0] facing, pose, door_dir;
    wire       door_evt;

    wire [2:0] state, hp, hp_max, speed, rgb;
    wire [1:0] form, damage;
    wire       freeze, hide_player;
    wire [3:0] m_t, m_o, s_t, s_o;

    world wld (.clk(clk), .rst(rst), .restart(restart), .next_floor(next_floor),
               .door_evt(door_evt), .door_dir(door_dir),
               .floor(floor), .room(room), .grid(grid),
               .load(load), .load_x(load_x), .load_y(load_y), .exit_evt(exit_evt));

    game_fsm fsm (.clk(clk), .rst(rst), .frame_tick(frame_tick), .btnc_rise(bc_rise),
                  .got_item(sw3_rise), .take_hit(sw4_rise), .floor_done(sw1_rise),
                  .exit_evt(exit_evt), .sprint(sw15),
                  .state(state), .restart(restart), .next_floor(next_floor),
                  .form(form), .hp(hp), .hp_max(hp_max), .speed(speed), .damage(damage),
                  .rgb(rgb), .freeze(freeze), .hide_player(hide_player),
                  .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o));

    localparam [2:0] S_TITLE = 3'd0, S_WIN = 3'd5, S_GAME_OVER = 3'd6;
    wire is_title = (state == S_TITLE);
    wire is_win   = (state == S_WIN);

    player pl (.clk(clk), .rst(rst), .frame_tick(frame_tick),
               .up(bu), .down(bd), .left(bl), .right(br), .hold_facing(bc),
               .form(form), .speed(speed), .freeze(freeze),
               .grid(grid), .doors_open(doors_open), .open_L(open_L),
               .load(load), .load_x(load_x), .load_y(load_y),
               .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir));

    // ---------- render ----------
    // TITLE: sprite ร่าง 1 idle หันลง กลางจอ
    wire [9:0]  rpx = is_title ? 10'd304 : px;
    wire [9:0]  rpy = is_title ? 10'd224 : py;
    wire [5:0]  pframe = is_title ? 6'd0 : form * 6'd12 + facing * 6'd3 + pose;
    wire [1:0]  screen = is_title ? 2'd1 : (state == S_GAME_OVER) ? 2'd2 : is_win ? 2'd3 : 2'd0;
    wire [11:0] color;
    renderer rnd (.clk(clk), .hcount(hcount), .vcount(vcount), .grid(grid), .floor(floor),
                  .form(form), .doors_open(doors_open), .open_L(open_L),
                  .screen(screen), .hide_player(hide_player),
                  .px(rpx), .py(rpy), .pframe(pframe), .color(color));

    always @(posedge clk) if (ce) begin
        {VGA_R, VGA_G, VGA_B} <= active ? color : 12'h000;
        VGA_HS <= hsync;
        VGA_VS <= vsync;
    end

    // ---------- 7-seg / LED / RGB ----------
    // [ชั้น] - [HP] - m m . s s   (d7 ซ้ายสุด; DP ที่ d2 = หลังหลักนาทีหน่วย) TITLE = ทุกหลัก '-'
    wire [6:0] seg;
    wire [31:0] digits = is_title ? 32'hEEEEEEEE :
                         {1'b0, {1'b0, floor} + 3'd1, 4'hE, 1'b0, hp, 4'hE, m_t, m_o, s_t, s_o};
    seg7 s7 (.clk(clk), .digits(digits), .dots(is_title ? 8'h00 : 8'b0000_0100),
             .seg(seg), .an(AN), .dp(DP));
    assign {CG, CF, CE, CD, CC, CB, CA} = seg;

    // LED0-3 = ปุ่มทิศ, LED8-11 = HP bar (LED8 = HP 1 ...), LED14 = sprint, LED15 = WIN
    assign LED = {is_win, sw15, 2'd0, hp >= 3'd4, hp >= 3'd3, hp >= 3'd2, hp >= 3'd1, 4'd0, br, bl, bd, bu};

    reg [7:0] pwm = 0;
    always @(posedge clk) pwm <= pwm + 1'b1;
    wire dim = (pwm < 8'd16);                     // RGB LED สว่างมาก: duty ~6%
    // สีตามร่าง (เขียว / ฟ้า / ม่วง / ทอง) ขาวตอน EVOLVE — ตารางอยู่ใน game_fsm.v
    assign LED16_R = dim & rgb[2];
    assign LED16_G = dim & rgb[1];
    assign LED16_B = dim & rgb[0];
    assign {LED17_R, LED17_G, LED17_B} = 3'b000;  // P3: แดงตอนโดนตี

    assign AUD_PWM = 1'b0;                        // P6: เสียง
    assign AUD_SD  = 1'b0;
endmodule
