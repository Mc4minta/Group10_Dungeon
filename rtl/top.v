// Group 10 — top module (Nexys A7-100T)
// สถานะตอนนี้: P4 = P3 (game_fsm, world, objects) + ปริศนา 3 ห้อง + ดันกล่อง + ไอเทมจริง (puzzles.v)
//
// ปุ่ม / สวิตช์:
//   BTNU/D/L/R เดิน · BTNC = เริ่มเกม (TITLE) / โจมตี (PLAY: ร่าง 1 ฟัน, ร่าง 2-4 ยิง, ค้าง = ยิงซ้ำ + strafe)
//                    / กลับ TITLE (WIN, GAME_OVER)
//   SW15 = sprint (ความเร็ว +1 px/เฟรม, ใช้ได้ทุกร่าง)   SW13 ยก = รีเซ็ตกล่องห้อง Sokoban (ตอน gate ยังปิด)
// สวิตช์ debug (ทำงานเฉพาะ DEBUG = 1; build ส่งงานตั้ง DEBUG = 0):
//   SW0 = เปิดประตูบอส L ทุกชั้น (ทับ has_item)   SW1 ยก = floor_done (P5: มาจากบอสตาย)
//   SW2 ยก = ลบมอนทั้งห้อง (ห้องเคลียร์)          SW3 ยก = got_item -> EVOLVE      SW4 ยก = take_hit HP-1
// 7-seg: [ชั้น] - [HP] - mm.ss (TITLE = ----)
// LED0-3 = ปุ่มทิศ (ห้อง Light Bulb = หลอด 1-4 ที่ LED3..0, ห้อง Simon = รอบที่ผ่าน), LED4-7 = มอนที่เหลือ (bar),
// LED8-11 = HP, LED12 = ประตูห้องล็อก, LED13 = มีไอเทมชั้นนี้ (ประตู L เปิด), LED14 = sprint, LED15 = WIN,
// RGB16 = สีร่าง, RGB17 แดง = โดนตี (ช่วงอมตะ)
module top #(
    parameter DEBOUNCE = 1_000_000,         // 10 ms ที่ 100 MHz
    parameter CE_DIV   = 4,                 // บอร์ดจริง = 4 (25 MHz) / simulator บนจอคอม = 1 (เร็วขึ้น 4 เท่า)
    parameter DEBUG    = 1,                 // 1 = สวิตช์ debug SW0/SW1/SW2/SW3/SW4 ใช้ได้, 0 = build ส่งงาน
    parameter [15:0] SEED = 16'd0           // 0 = ปริศนาสุ่มต่างกันทุกเกม, อื่น ๆ = คงที่ (ทดสอบ)
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
    wire bu, bd, bl, br, bc, bc_rise, sw1_r, sw2_r, sw3_r, sw4_r, sw13_rise, sw15;
    debounce #(DEBOUNCE) d_u (.clk(clk), .in(BTNU),  .level(bu), .rise());
    debounce #(DEBOUNCE) d_d (.clk(clk), .in(BTND),  .level(bd), .rise());
    debounce #(DEBOUNCE) d_l (.clk(clk), .in(BTNL),  .level(bl), .rise());
    debounce #(DEBOUNCE) d_r (.clk(clk), .in(BTNR),  .level(br), .rise());
    debounce #(DEBOUNCE) d_c (.clk(clk), .in(BTNC),  .level(bc), .rise(bc_rise));
    debounce #(DEBOUNCE) d_s1(.clk(clk), .in(SW[1]),  .level(), .rise(sw1_r));
    debounce #(DEBOUNCE) d_s2(.clk(clk), .in(SW[2]),  .level(), .rise(sw2_r));
    debounce #(DEBOUNCE) d_s3(.clk(clk), .in(SW[3]),  .level(), .rise(sw3_r));
    debounce #(DEBOUNCE) d_s4(.clk(clk), .in(SW[4]),  .level(), .rise(sw4_r));
    debounce #(DEBOUNCE) d_s13(.clk(clk), .in(SW[13]), .level(), .rise(sw13_rise));
    // debug: ใช้ได้เฉพาะ DEBUG = 1
    wire dbg = (DEBUG != 0);
    wire sw1_rise = dbg & sw1_r, sw2_rise = dbg & sw2_r, sw3_rise = dbg & sw3_r, sw4_rise = dbg & sw4_r;
    wire sw0_key  = dbg & SW[0];
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

    wire doors_open;                 // จาก objects.v: ห้อง Combat ที่ยังมีมอน = ปิด
    wire [2:0] has_item;
    wire open_L     = has_item[floor] | sw0_key;   // ประตูบอส L: ได้ไอเทมของชั้นนี้แล้ว (หรือ debug SW0)

    wire [9:0] px, py;
    wire [1:0] facing, pose, door_dir;
    wire       door_evt;

    wire [2:0] state, hp, hp_max, speed, rgb;
    wire [1:0] form, damage;
    wire       freeze, fsm_hide;
    wire       obj_hit, kb_start, invuln, obj_blink, melee_on, mon_anim;
    wire [1:0] kb_dir, melee_dir, pb_act;
    wire [2:0] alive;
    wire [5:0] mon_act, mon_type, mon_flash;
    wire [59:0] mon_x, mon_y;
    wire [19:0] pb_x, pb_y;
    wire [15:0] eb_act;
    wire [159:0] eb_x, eb_y;
    wire        pz_got, pz_hit, pz_busy, simon_lit_on, simon_wrong, simon_note_on, room_led_on;
    wire        lb_ok, gate_open, sm_ok;
    wire [1:0]  simon_lit, simon_note, pbox_en;
    wire [3:0]  room_led, bulbs;
    wire [11:0] blk0, blk1, blk2, pbox0, pbox1;
    wire [2:0]  blk_en;
    wire [8:0]  pz_act;
    wire [89:0] pz_x, pz_y;
    wire [35:0] pz_frame;
    wire [9:0]  pz_seq;
    wire [2:0]  pz_sm;
    wire [1:0]  pz_round;
    wire [3:0] m_t, m_o, s_t, s_o;

    world wld (.clk(clk), .rst(rst), .restart(restart), .next_floor(next_floor),
               .door_evt(door_evt), .door_dir(door_dir),
               .floor(floor), .room(room), .grid(grid),
               .load(load), .load_x(load_x), .load_y(load_y), .exit_evt(exit_evt));

    game_fsm fsm (.clk(clk), .rst(rst), .frame_tick(frame_tick), .btnc_rise(bc_rise),
                  .got_item(sw3_rise | pz_got), .take_hit(sw4_rise | obj_hit | pz_hit), .floor_done(sw1_rise),
                  .exit_evt(exit_evt), .sprint(sw15),
                  .state(state), .restart(restart), .next_floor(next_floor),
                  .form(form), .hp(hp), .hp_max(hp_max), .speed(speed), .damage(damage),
                  .rgb(rgb), .freeze(freeze), .hide_player(fsm_hide),
                  .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o));

    localparam [2:0] S_TITLE = 3'd0, S_PLAY = 3'd1, S_WIN = 3'd5, S_GAME_OVER = 3'd6;
    wire is_title = (state == S_TITLE);
    wire is_win   = (state == S_WIN);

    player pl (.clk(clk), .rst(rst), .frame_tick(frame_tick),
               .up(bu), .down(bd), .left(bl), .right(br), .hold_facing(bc),
               .form(form), .speed(speed), .freeze(freeze),
               .grid(grid), .doors_open(doors_open), .open_L(open_L),
               .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
               .load(load), .load_x(load_x), .load_y(load_y),
               .kb_start(kb_start), .kb_dir(kb_dir),
               .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir));

    // ---------- objects: มอน กระสุน ฟัน โดนตี ห้องล็อก ----------
    objects obj (.clk(clk), .rst(rst), .frame_tick(frame_tick), .run(state == S_PLAY),
                 .restart(restart), .room_load(load), .floor(floor), .room(room), .grid(grid),
                 .open_L(open_L), .px(px), .py(py), .facing(facing), .form(form), .damage(damage),
                 .atk_press(bc_rise), .atk_hold(bc), .dbg_clear(sw2_rise),
                 .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
                 .doors_open(doors_open), .alive(alive), .hit(obj_hit), .kb_start(kb_start), .kb_dir(kb_dir),
                 .invuln(invuln), .player_blink(obj_blink), .busy(),
                 .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                 .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y),
                 .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir));

    // ---------- ปริศนา + ไอเทม ----------
    puzzles #(.SEED(SEED)) pz (.clk(clk), .rst(rst), .frame_tick(frame_tick), .run(state == S_PLAY),
                 .restart(restart), .room_load(load), .floor(floor), .grid(grid), .px(px), .py(py),
                 .up(bu), .down(bd), .left(bl), .right(br), .melee_on(melee_on), .melee_dir(melee_dir),
                 .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .soko_reset(sw13_rise),
                 .got_item(pz_got), .hit(pz_hit), .has_item(has_item),
                 .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
                 .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame),
                 .pbox0(pbox0), .pbox1(pbox1), .pbox_en(pbox_en),
                 .simon_lit_on(simon_lit_on), .simon_lit(simon_lit), .simon_wrong(simon_wrong),
                 .simon_note_on(simon_note_on), .simon_note(simon_note),
                 .room_led(room_led), .room_led_on(room_led_on),
                 .bulbs(bulbs), .lb_ok(lb_ok), .gate_open(gate_open), .sm_ok(sm_ok), .busy(pz_busy),
                 .dbg_seq(pz_seq), .dbg_sm(pz_sm), .dbg_round(pz_round));

    // ---------- debug ให้ Verilator อ่าน (ไม่ใช่ขาบอร์ด) ----------
    wire [2:0]  dbg_state /*verilator public*/ = state;
    wire [1:0]  dbg_floor /*verilator public*/ = floor;
    wire [2:0]  dbg_room  /*verilator public*/ = room;
    wire [9:0]  dbg_px    /*verilator public*/ = px;
    wire [9:0]  dbg_py    /*verilator public*/ = py;
    wire [2:0]  dbg_hp    /*verilator public*/ = hp;
    wire [1:0]  dbg_form  /*verilator public*/ = form;
    wire [9:0]  dbg_seq   /*verilator public*/ = pz_seq;
    wire [2:0]  dbg_sm    /*verilator public*/ = pz_sm;
    wire [1:0]  dbg_round /*verilator public*/ = pz_round;
    wire [3:0]  dbg_bulbs /*verilator public*/ = bulbs;
    wire [2:0]  dbg_alive /*verilator public*/ = alive;

    // ---------- render ----------
    // TITLE: sprite ร่าง 1 idle หันลง กลางจอ
    wire [9:0]  rpx = is_title ? 10'd304 : px;
    wire [9:0]  rpy = is_title ? 10'd224 : py;
    wire [5:0]  pframe = is_title ? 6'd0 : form * 6'd12 + facing * 6'd3 + pose;
    wire [1:0]  screen = is_title ? 2'd1 : (state == S_GAME_OVER) ? 2'd2 : is_win ? 2'd3 : 2'd0;
    wire [11:0] color;
    renderer rnd (.clk(clk), .ce(ce), .hcount(hcount), .vcount(vcount), .grid(grid), .floor(floor),
                  .form(form), .doors_open(doors_open), .open_L(open_L),
                  .screen(screen), .hide_player(fsm_hide | (obj_blink && !is_title)),
                  .px(rpx), .py(rpy), .pframe(pframe),
                  .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                  .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y),
                  .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir),
                  .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame),
                  .pbox0(pbox0), .pbox1(pbox1), .pbox_en(pbox_en),
                  .simon_lit_on(simon_lit_on), .simon_lit(simon_lit), .simon_wrong(simon_wrong),
                  .color(color));

    // renderer มี latency 3 clock -> หน่วง sync/active เท่ากัน ภาพตรงทั้ง CE_DIV = 1 และ 4
    reg [2:0] hs_d = 3'b111, vs_d = 3'b111, act_d = 3'b000;
    always @(posedge clk) begin
        hs_d  <= {hs_d[1:0], hsync};
        vs_d  <= {vs_d[1:0], vsync};
        act_d <= {act_d[1:0], active};
    end
    always @(posedge clk) if (ce) begin
        {VGA_R, VGA_G, VGA_B} <= act_d[2] ? color : 12'h000;
        VGA_HS <= hs_d[2];
        VGA_VS <= vs_d[2];
    end

    // ---------- 7-seg / LED / RGB ----------
    // [ชั้น] - [HP] - m m . s s   (d7 ซ้ายสุด; DP ที่ d2 = หลังหลักนาทีหน่วย) TITLE = ทุกหลัก '-'
    wire [6:0] seg;
    wire [31:0] digits = is_title ? 32'hEEEEEEEE :
                         {1'b0, {1'b0, floor} + 3'd1, 4'hE, 1'b0, hp, 4'hE, m_t, m_o, s_t, s_o};
    seg7 s7 (.clk(clk), .digits(digits), .dots(is_title ? 8'h00 : 8'b0000_0100),
             .seg(seg), .an(AN), .dp(DP));
    assign {CG, CF, CE, CD, CC, CB, CA} = seg;

    // LED0-3 = ปุ่มทิศ, LED4-7 = มอนเหลือ (bar), LED8-11 = HP bar (LED8 = HP 1 ...),
    // LED12 = ประตูห้องล็อก, LED13 = มีไอเทมชั้นนี้, LED14 = sprint, LED15 = WIN; ห้องปริศนา: LED0-3 = หลอด / รอบ Simon
    wire [3:0] mon_bar = {alive >= 3'd4, alive >= 3'd3, alive >= 3'd2, alive >= 3'd1};
    wire [3:0] led_lo = room_led_on ? room_led : {br, bl, bd, bu};
    assign LED = {is_win, sw15, has_item[floor], ~doors_open, hp >= 3'd4, hp >= 3'd3, hp >= 3'd2, hp >= 3'd1,
                  mon_bar, led_lo};

    reg [7:0] pwm = 0;
    always @(posedge clk) pwm <= pwm + 1'b1;
    wire dim = (pwm < 8'd16);                     // RGB LED สว่างมาก: duty ~6%
    // สีตามร่าง (เขียว / ฟ้า / ม่วง / ทอง) ขาวตอน EVOLVE — ตารางอยู่ใน game_fsm.v
    assign LED16_R = dim & rgb[2];
    assign LED16_G = dim & rgb[1];
    assign LED16_B = dim & rgb[0];
    assign LED17_R = dim & invuln;                // แดงตอนโดนตี (knockback + อมตะ)
    assign {LED17_G, LED17_B} = 2'b00;

    assign AUD_PWM = 1'b0;                        // P6: เสียง
    assign AUD_SD  = 1'b0;
endmodule
