// Group 10 — top module (Nexys A7-100T)
// สถานะตอนนี้: P5 = P4 + บอส 3 ตัว (boss.v) + FLOOR_CLEAR จริง + ESCAPE + ข้อความบนจอ + ไมค์ PDM (pdm_mic.v)
//
// ปุ่ม / สวิตช์:
//   BTNU/D/L/R เดิน · BTNC = เริ่มเกม (TITLE) / โจมตี (PLAY: ร่าง 1 ฟัน, ร่าง 2-4 ยิง, ค้าง = ยิงซ้ำ + strafe)
//                    / กลับ TITLE (WIN) / retry ชั้นปัจจุบัน (GAME_OVER; BTNL = กลับ TITLE)
//   SW15 = PAUSE (ยก = เกมหยุด + ข้อความ PAUSED, เสียงเงียบ; ใช้ได้ใน PLAY / ESCAPE)   SW14 = sprint (ความเร็ว +1 px/เฟรม, ใช้ได้ทุกร่าง)
//   SW13 ยก = รีเซ็ตกล่องห้อง Sokoban (ตอน gate ยังปิด)   SW12 = ล็อกทิศค้าง (เดิม SW14)
// สวิตช์ debug (ทำงานเฉพาะ DEBUG = 1; build ส่งงานตั้ง DEBUG = 0):
//   SW0 = เปิดประตูบอส L ทุกชั้น (ทับ has_item)   SW1 ยก = floor_done (P5: มาจากบอสตาย)
//   SW2 ยก = ลบมอนทั้งห้อง (ห้องเคลียร์)          SW3 ยก = got_item -> EVOLVE      SW4 ยก = take_hit HP-1
// 7-seg: [ชั้น] - [HP] - mm.ss (TITLE = ----)
// LED0-3 = ปุ่มทิศ (ห้อง Light Bulb = หลอด 1-4 ที่ LED3..0, ห้อง Simon = รอบที่ผ่าน), LED4-7 = มอนที่เหลือ (bar),
// LED8-11 = HP, LED12 = ประตูห้องล็อก, LED13 = มีไอเทมชั้นนี้ (ประตู L เปิด), LED14 = sprint (SW14), LED15 = WIN,
// RGB16 = สีร่าง, RGB17 แดง = โดนตี (ช่วงอมตะ)
module top #(
    parameter DEBOUNCE = 1_000_000,         // 10 ms ที่ 100 MHz
    parameter CE_DIV   = 4,                 // บอร์ดจริง = 4 (25 MHz) / simulator บนจอคอม = 1 (เร็วขึ้น 4 เท่า)
    parameter PROLOGUE = 1,                 // 1 = TITLE -> PROLOGUE (4 pages, black screen) -> PLAY; 0 = straight to PLAY (old testbenches)
    parameter DEBUG    = 1,                 // 1 = สวิตช์ debug SW0/SW1/SW2/SW3/SW4 ใช้ได้, 0 = build ส่งงาน
    parameter [15:0] SEED = 16'd0           // 0 = ปริศนาสุ่มต่างกันทุกเกม, อื่น ๆ = คงที่ (ทดสอบ)
) (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC, BTNU, BTND, BTNL, BTNR,
    input  wire        PS2_CLK, PS2_DATA,             // W22: USB keyboard through the Nexys USB-HID port (PS/2 protocol)
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire        LED16_R, LED16_G, LED16_B,
    output wire        LED17_R, LED17_G, LED17_B,
    output wire        CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0]  AN,
    output reg  [3:0]  VGA_R = 0, VGA_G = 0, VGA_B = 0,
    output reg         VGA_HS = 1, VGA_VS = 1,
    output wire        AUD_PWM, AUD_SD,
    // ไมค์ PDM (ADMP421)
    output wire        M_CLK,
    input  wire        M_DATA,
    output wire        M_LRSEL,
    // accelerometer ADXL362 (SPI) for Ball in a Maze
    input  wire        ACL_MISO,
    output wire        ACL_MOSI, ACL_SCLK, ACL_CSN
);
    `include "params.vh"
    wire clk = CLK100MHZ;

    // ---------- reset + pixel enable ----------
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~CPU_RESETN};
    wire rst = rst_sync[1];

    reg [1:0] ce_cnt = 0;
    always @(posedge clk) ce_cnt <= (ce_cnt == CE_DIV - 1) ? 2'd0 : ce_cnt + 1'b1;
    wire ce = (ce_cnt == CE_DIV - 1);        // 25 MHz เมื่อ CE_DIV = 4

    // ---------- input ----------
    wire bu, bd, bl, br, bc, bc_rise, sw1_r, sw2_r, sw3_r, sw4_r, sw13_rise, sw15;   // sw15 = pause switch (level)
    wire bu_b, bd_b, bl_b, br_b, bc_b, bc_rise_b, sw13_b, sw15_b;                    // the real buttons / switches (debounced)
    debounce #(DEBOUNCE) d_u (.clk(clk), .in(BTNU),  .level(bu_b), .rise());
    debounce #(DEBOUNCE) d_d (.clk(clk), .in(BTND),  .level(bd_b), .rise());
    debounce #(DEBOUNCE) d_l (.clk(clk), .in(BTNL),  .level(bl_b), .rise());
    debounce #(DEBOUNCE) d_r (.clk(clk), .in(BTNR),  .level(br_b), .rise());
    debounce #(DEBOUNCE) d_c (.clk(clk), .in(BTNC),  .level(bc_b), .rise(bc_rise_b));
    // ---- W22 USB keyboard (PS/2): arrows / WASD walk, Space / J / Enter attack, Shift sprint, P / Esc pause (toggle), L auto-lock (toggle),
    //      R Sokoban box reset, C clap fallback. Works together with the buttons (logical OR). ----
    wire k_up, k_dn, k_lf, k_rt, k_atk, k_spr, k_pause_p, k_lock_p, k_reset_p, k_clap_p, k_got, k_clkact, k_hbox_p;
    ps2_kbd kbd (.clk(clk), .rst(rst), .ps2_clk(PS2_CLK), .ps2_data(PS2_DATA), .up(k_up), .down(k_dn), .left(k_lf), .right(k_rt),
                 .atk(k_atk), .sprint(k_spr), .pause_p(k_pause_p), .lock_p(k_lock_p), .reset_p(k_reset_p), .clap_p(k_clap_p), .hbox_p(k_hbox_p), .got_key(k_got), .clk_act(k_clkact));
    // keyboard diagnostics on RGB LED 17: BLUE flickers when the PS2_CLK line moves (the keyboard talks), GREEN flickers when a good byte was decoded
    reg [23:0] kd_clk = 24'd0, kd_got = 24'd0;
    always @(posedge clk) begin
        kd_clk <= k_clkact ? 24'd10_000_000 : (kd_clk != 0) ? kd_clk - 1'b1 : 24'd0;     // 0.1 s stretch
        kd_got <= k_got    ? 24'd10_000_000 : (kd_got != 0) ? kd_got - 1'b1 : 24'd0;
    end
    reg k_pause_on = 1'b0, k_lock_on = 1'b0, k_atk_d = 1'b0, k_hbox_on = 1'b0;
    always @(posedge clk) begin
        k_atk_d <= k_atk;
        if (rst) begin k_pause_on <= 1'b0; k_lock_on <= 1'b0; end
        else begin
            if (k_pause_p) k_pause_on <= ~k_pause_on;
            if (k_lock_p)  k_lock_on  <= ~k_lock_on;
            if (k_hbox_p)  k_hbox_on  <= ~k_hbox_on;
        end
    end
    wire u_raw = bu_b | k_up, d_raw = bd_b | k_dn, l_raw = bl_b | k_lf, r_raw = br_b | k_rt;
    assign bu = u_raw & ~d_raw;                     // W34: opposite directions cancel (stand still)
    assign bd = d_raw & ~u_raw;
    assign bl = l_raw & ~r_raw;
    assign br = r_raw & ~l_raw;
    assign bc = bc_b | k_atk;
    assign bc_rise = bc_rise_b | (k_atk & ~k_atk_d);
    debounce #(DEBOUNCE) d_s1(.clk(clk), .in(SW[1]),  .level(), .rise(sw1_r));
    debounce #(DEBOUNCE) d_s2(.clk(clk), .in(SW[2]),  .level(), .rise(sw2_r));
    debounce #(DEBOUNCE) d_s3(.clk(clk), .in(SW[3]),  .level(), .rise(sw3_r));
    debounce #(DEBOUNCE) d_s4(.clk(clk), .in(SW[4]),  .level(), .rise(sw4_r));
    wire sw13_rise_b;
    debounce #(DEBOUNCE) d_s13(.clk(clk), .in(SW[13]), .level(), .rise(sw13_rise_b));
    assign sw13_rise = sw13_rise_b | k_reset_p;           // W22: key R = Sokoban box reset
    wire sw9, sw9_b;                          // SW9 = W18 auto-lock: attacks aim at the nearest enemy
    debounce #(DEBOUNCE) d_s9(.clk(clk), .in(SW[9]), .level(sw9_b), .rise());
    assign sw9 = ~(sw9_b ^ k_lock_on);                    // W46: auto aim is ON by default; SW9 up or key L turns it OFF (L again = on)
    wire sw10;                         // SW10 = เขาวงกต: ใช้ปุ่มแทนเซนเซอร์เอียง
    debounce #(DEBOUNCE) d_s10(.clk(clk), .in(SW[10]), .level(sw10), .rise());
    wire sw11_rise, sw11_rise_b;       // SW11 = ตบมือสำรอง (ถ้าไมค์ใช้ไม่ได้): ยก = pulse stun บอส 1
    debounce #(DEBOUNCE) d_s11(.clk(clk), .in(SW[11]), .level(), .rise(sw11_rise_b));
    assign sw11_rise = sw11_rise_b | k_clap_p;             // W22: key C = the same pulse
    // debug: ใช้ได้เฉพาะ DEBUG = 1
    wire dbg = (DEBUG != 0);
    wire sw1_rise = dbg & sw1_r, sw2_rise = dbg & sw2_r, sw3_rise = dbg & sw3_r, sw4_rise = dbg & sw4_r;
    wire sw0_key  = dbg & SW[0];
    debounce #(DEBOUNCE) d_s15(.clk(clk), .in(SW[15]), .level(sw15_b), .rise());
    assign sw15 = sw15_b ^ k_pause_on;                      // W22 / W34: keys P / Esc toggle the pause (SW15 up + P = running again)
    wire sw14, sw14_b;                 // SW14 = sprint (+1 px/เฟรม)
    debounce #(DEBOUNCE) d_s14(.clk(clk), .in(SW[14]), .level(sw14_b), .rise());
    assign sw14 = sw14_b | k_spr;                           // W22: Shift = sprint
    wire sw12;                         // SW12 = ล็อกทิศค้าง (ถอยหลังพร้อมฟันได้โดยไม่หันหนี; ลงเพื่อหันทิศใหม่) (เดิม SW14)
    debounce #(DEBOUNCE) d_s12(.clk(clk), .in(SW[12]), .level(sw12), .rise());

    // ---------- VGA timing ----------
    wire [9:0] hcount, vcount;
    wire hsync, vsync, active, frame_tick;
    vga_sync vga (.clk(clk), .rst(rst), .ce(ce), .hcount(hcount), .vcount(vcount),
                  .hsync(hsync), .vsync(vsync), .active(active), .frame_tick(frame_tick));
    // ---------- PAUSE (SW15): ตัด frame_tick ของทุกอย่างในเกม (ตำแหน่ง มอน กระสุน อมตะ มึน Simon timer) -> ต่อจากจุดเดิมเมื่อปล่อย ----------
    // vga_sync ใช้ frame_tick จริง (จอยังวาดต่อ); ใช้ได้เฉพาะ PLAY / ESCAPE (TITLE, EVOLVE, FLOOR_CLEAR, WIN, GAME_OVER ไม่สน SW15)
    wire [1:0] pro_page;                     // หน้า prologue จาก game_fsm
    wire [2:0] state;                        // จาก game_fsm (ประกาศไว้ตรงนี้เพราะ ft ใช้ก่อน)
    wire paused = sw15 && (state == 3'd1 || state == 3'd4);   // S_PLAY / S_ESCAPE
    wire soko_stuck;                         // W41: a Sokoban box is in a dead corner (puzzles.v)
    wire dlg_show, dlg_block;                // W16: dialogue box (dialog.v); a blocking message freezes the game like pause until BTNC
    wire ft     = frame_tick & ~paused & ~dlg_block;
    reg [7:0] fc = 0;                     // frame counter (declared here because the puzzles instance uses fc[3] for the bulb flame animation)
    // W31: after a story box closes the attack input stays ignored until the button has been released once (no accidental shot / charge)
    reg  atk_wait = 1'b0;
    always @(posedge clk) if (dlg_block) atk_wait <= 1'b1; else if (!bc) atk_wait <= 1'b0;
    // W33: holding the attack button for 1.5 s on a box fast-forwards through the boxes (one advance every 8 frames)
    reg [7:0] skip_cnt = 8'd0;
    always @(posedge clk) if (frame_tick) skip_cnt <= (dlg_block && bc) ? ((skip_cnt == 8'd255) ? 8'd90 : skip_cnt + 8'd1) : 8'd0;
    wire skip_adv = frame_tick && (skip_cnt >= 8'd90) && (skip_cnt[2:0] == 3'd0);
    wire bc_rise_g = bc_rise & ~paused & ~dlg_block;      // ปุ่มโจมตีไม่เข้าคิวระหว่างหยุด / ระหว่างอ่าน dialogue
    reg  pause_blink = 1'b0;                 // จุดทศนิยม 7-seg กะพริบตอนหยุด (ใช้ frame_tick จริง)
    reg [4:0] pb_cnt = 5'd0;
    always @(posedge clk) if (frame_tick) begin
        pb_cnt <= pb_cnt + 1'b1;
        pause_blink <= pb_cnt[4];
    end
    // ล็อกทิศหลังกด BTNC: กดฟันแล้วถอยหลังได้โดยตัวไม่หันหนี (แทนการต้องค้าง BTNC + ปุ่มทิศพร้อมกัน); FACE_LOCK_FRAMES = 0 ปิด
    wire face_lock;
    wire p_moving;                     // จาก player.v (เฉพาะเลือกภาพ animation)
    wire [2:0] p_anim;
    wire [5:0] p_aframe;
    wire       p_hurt;                 // W14: red flash after a hit
    face_lock #(FACE_LOCK_FRAMES) flk (.clk(clk), .rst(rst), .frame_tick(ft), .press(bc_rise_g), .lock(face_lock));

    // ---------- world (ห้อง/ประตู) + game FSM ----------
    wire       has_key, maze_goal, tmo, key_pick, key_vis;
    wire [9:0] lock_tx, lock_ty;                   // W18 level 3: target centre
    wire       lock_use; wire [1:0] lock_face;     // W18 auto-lock result from objects.v
    reg  [4:0] turn_cnt = 5'd0;                    // the hero faces the locked target for a moment after each attack
    wire [9:0] key_x, key_y;
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

    wire [2:0] hp, hp_max, speed, rgb;
    wire [1:0] form, damage;
    wire       freeze, fsm_hide;
    wire       obj_hit, kb_start, invuln, obj_blink, melee_on, mon_anim;
    reg [4:0] hurt_shake = 5'd0;       // จอสั่นสั้น ๆ หลังโดนตี (kb_start = เริ่ม knockback)
    always @(posedge clk) if (rst) hurt_shake <= 5'd0;
                          else if (kb_start) hurt_shake <= HURT_SHAKE_FRAMES;
                          else if (ft && hurt_shake != 5'd0) hurt_shake <= hurt_shake - 5'd1;
    wire [1:0] kb_dir, melee_dir;
    wire [5:0] pb_act;
    wire [11:0] pb_kind;
    wire       charged;
    wire       ev_shoot, ev_melee, ev_mdmg, ev_mdie, ev_ok;
    wire [1:0] ev_shoot_k;
    wire [2:0] alive;
    wire [5:0] mon_act, mon_type, mon_flash, mon_face;       // W40: mon_face = mirrored picture
    wire [59:0] mon_x, mon_y;
    wire [59:0] pb_x, pb_y;
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
    wire [3:0] e_s_t, e_s_o, e_f_t, e_f_o;
    wire       esc_banner;
    // บอส
    wire        b_act, b_flash, b_stunned, b_fire, b_died, b_anim, b_busy, b_dmg, b_dmg_big, b_summon, b_kill, b_shield, b_tele, b_vuln, b_intr, b_warn;
    wire [2:0]  p_chg_lvl;              // W25
    wire        b_heavy;                // W24
    wire [1:0]  b_tele_lvl;             // W21
    wire [6:0]  b_chg_w;                // W21
    // W21: blink colour of boss 3 while it charges: pale blue -> yellow -> orange -> red with the charge level (white = normal hit flash)
    wire [11:0] b_fcol = !b_tele ? 12'hFFF : (b_tele_lvl == 2'd0) ? 12'h8BF : (b_tele_lvl == 2'd1) ? 12'hFE6 : (b_tele_lvl == 2'd2) ? 12'hF93 : 12'hF44;
    wire [1:0]  b_pat;                  // W20: boss bullet pattern
    wire [9:0]  b_x, b_y;
    wire [1:0]  b_kind;
    wire [2:0]  b_dmg_amt;
    wire [2:0]  b_dead;
    wire [4:0]  b_hp;
    wire [7:0]  b_hpbar;
    wire        clap;
    wire [1:0]  trap_a, trap_b;         // W19: timed spike phases (objects.v -> renderer)
    wire [7:0]  brk;                  // W5 overlay: บล็อกพังได้ของห้องนี้ที่พังแล้ว
    wire        brk_set;
    wire [2:0]  brk_idx;
    wire [11:0] mic_amp;

    overlay ovl (.clk(clk), .rst(rst), .restart(restart), .grid(grid), .set(brk_set), .set_idx(brk_idx), .brk(brk));
    world wld (.clk(clk), .rst(rst), .restart(restart), .retry(retry), .next_floor(next_floor),
               .door_evt(door_evt), .door_dir(door_dir),
               .floor(floor), .room(room), .grid(grid),
               .load(load), .load_x(load_x), .load_y(load_y), .exit_evt(exit_evt));

    reg bl_dg = 1'b0; always @(posedge clk) bl_dg <= bl;
    wire bl_rise_g = bl & ~bl_dg;
    wire retry;                                // W43: GAME OVER -> retry the current floor
    game_fsm #(.PROLOGUE(PROLOGUE)) fsm (.clk(clk), .rst(rst), .frame_tick(ft), .btnc_rise(bc_rise), .btnl_rise(bl_rise_g), .floor_in(floor), .retry(retry),
                  .got_item(sw3_rise | pz_got), .take_hit(sw4_rise | obj_hit | pz_hit),
                  .floor_done(sw1_rise | (b_died && b_kind != 2'd2)),          // บอส 1, 2 ตาย -> FLOOR_CLEAR
                  .exit_evt(exit_evt), .escape_start(exit_evt & has_key),     // W7: เดินเข้าประตู E ด้วยกุญแจ -> เขาวงกต (state ESCAPE)
                  .key_get(key_pick), .goal(maze_goal), .has_key(has_key),   // บอส 3 ตาย -> ได้กุญแจ
                  .exit_direct(dbg), .sprint(sw14), .kill(b_kill),
                  .state(state), .page(pro_page), .timeout(tmo), .restart(restart), .next_floor(next_floor),
                  .form(form), .hp(hp), .hp_max(hp_max), .speed(speed), .damage(damage),
                  .rgb(rgb), .freeze(freeze), .hide_player(fsm_hide),
                  .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o),
                  .e_s_t(e_s_t), .e_s_o(e_s_o), .e_f_t(e_f_t), .e_f_o(e_f_o), .esc_banner(esc_banner));

    localparam [2:0] S_TITLE = 3'd0, S_PLAY = 3'd1, S_CLEAR = 3'd3, S_ESCAPE = 3'd4, S_WIN = 3'd5, S_GAME_OVER = 3'd6, S_PROLOGUE = 3'd7, S_EVOLVE = 3'd2;
    localparam [2:0] R_BOSS = 3'd4;
    wire is_esc   = (state == S_ESCAPE);
    wire run      = (state == S_PLAY);             // objects / puzzles / boss ทำงาน (เขาวงกต = ESCAPE: หยุดทุกอย่างยกเว้น maze)
    wire open_E   = has_key | sw0_key;             // W7: ประตู E เปิดเมื่อมีกุญแจ (debug SW0 เปิดด้วย)
    wire is_title = (state == S_TITLE);
    // ---- W29 title pages: BTNR / right arrow = next page, BTNL / left arrow = previous; 0 title, 1-5 controls, 6-8 credits ----
    // W36: page 1 = SETTINGS (clap level), 2-6 = CONTROLS 1-5, 7-9 = CREDITS 1-3
    reg [3:0] tpage = 4'd0;
    reg       br_d = 1'b0, bl_d = 1'b0, bu_d = 1'b0, bd_d = 1'b0;
    reg [2:0] mic_step = 3'd2;                      // clap level 0 VERY LOW .. 4 VERY HIGH, 2 = MID (default); kept over new games, reset only by rst
    always @(posedge clk) begin
        br_d <= br; bl_d <= bl; bu_d <= bu; bd_d <= bd;
        if (rst) mic_step <= 3'd2;
        else if (is_title && tpage == 4'd1) begin
            if (bu & ~bu_d && mic_step != 3'd4) mic_step <= mic_step + 3'd1;               // BTNU / up / W = higher trigger (louder clap needed)
            if (bd & ~bd_d && mic_step != 3'd0) mic_step <= mic_step - 3'd1;
        end
        if (rst || !is_title) tpage <= 4'd0;
        else if (br & ~br_d) tpage <= (tpage == 4'd9) ? 4'd0 : tpage + 4'd1;
        else if (bl & ~bl_d) tpage <= (tpage == 4'd0) ? 4'd9 : tpage - 4'd1;
    end
    wire [11:0] mic_step_th = (mic_step == 3'd0) ? 12'd192 : (mic_step == 3'd1) ? 12'd320 : (mic_step == 3'd2) ? 12'd448 : (mic_step == 3'd3) ? 12'd704 : 12'd1024;
    wire [11:0] mic_th_eff = (SW[7:5] != 3'd0) ? {2'b00, SW[7:5], 7'd0} : mic_step_th;      // SW5-SW7 override (0 = the menu value); SW8 = hitbox overlay (W43)
    wire is_title0 = is_title && (tpage == 4'd0);          // the hero / vampire scene is only on the first page
    wire is_win   = (state == S_WIN);
    wire is_pro   = (state == S_PROLOGUE);

    player pl (.clk(clk), .rst(rst), .frame_tick(ft),
               .up(bu), .down(bd), .left(bl), .right(br), .hold_facing(bc | face_lock | sw12),
               .form(form), .speed(speed), .freeze(freeze),
               .grid(grid), .doors_open(doors_open), .open_L(open_L),
               .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
               .load(load), .load_x(load_x), .load_y(load_y),
               .kb_start(kb_start), .kb_dir(kb_dir),
               .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir), .open_E(open_E), .brk(brk), .moving_o(p_moving));

    // ---------- objects: มอน กระสุน ฟัน โดนตี ห้องล็อก ----------
    objects obj (.clk(clk), .rst(rst), .frame_tick(ft), .run(run), .brk(brk), .brk_set(brk_set), .brk_idx(brk_idx), .auto_lock(sw9), .lock_use(lock_use), .lock_tx(lock_tx), .lock_ty(lock_ty), .lock_face(lock_face),
                 .restart(restart), .room_load(load), .floor(floor), .room(room), .grid(grid),
                 .open_L(open_L), .px(px), .py(py), .facing(facing), .form(form), .damage(damage),
                 .atk_press(bc_rise_g), .atk_hold(bc & ~paused & ~dlg_block & ~atk_wait), .dbg_clear(sw2_rise),
                 .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
                 .boss_act(b_act), .boss_x(b_x), .boss_y(b_y), .boss_fire(b_fire), .boss_pat(b_pat), .boss_heavy(b_heavy),
                 .boss_dmg(b_dmg), .boss_dmg_amt(b_dmg_amt), .boss_dmg_big(b_dmg_big), .summon(b_summon),
                 .doors_open(doors_open), .alive(alive), .hit(obj_hit), .kb_start(kb_start), .kb_dir(kb_dir),
                 .invuln(invuln), .player_blink(obj_blink), .busy(), .trap_a(trap_a), .trap_b(trap_b),
                 .mon_act(mon_act), .mon_face(mon_face), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                 .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .pb_kind(pb_kind), .chg_lvl(p_chg_lvl), .charged(charged),
                 .ev_shoot(ev_shoot), .ev_shoot_k(ev_shoot_k), .ev_melee(ev_melee), .ev_mdmg(ev_mdmg), .ev_mdie(ev_mdie),
                 .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir));

    // ---------- ปริศนา + ไอเทม ----------
    // ---------- บอส + ไมค์ ----------
    boss bs (.clk(clk), .rst(rst), .frame_tick(ft), .run(run), .brk(brk), .restart(restart), .room_load(load),
             .floor(floor), .room(room), .grid(grid), .px(px), .py(py),
             .dmg(b_dmg), .dmg_amt(b_dmg_amt), .dmg_big(b_dmg_big), .minions(alive), .clap((clap | sw11_rise) & ~paused & ~dlg_block),
             .act(b_act), .bx(b_x), .by(b_y), .kind(b_kind), .flash(b_flash), .stunned(b_stunned),
             .fire(b_fire), .fire_pat(b_pat), .fire_heavy(b_heavy), .tele_lvl(b_tele_lvl), .chg_w(b_chg_w), .warn(b_warn), .summon(b_summon), .kill(b_kill), .shield(b_shield), .tele(b_tele), .vuln(b_vuln), .intr(b_intr), .died(b_died), .dead(b_dead), .hp(b_hp), .hp_bar(b_hpbar), .anim(b_anim), .busy(b_busy));
    wire        mic_win;                    // W4: window pulse of the mic (meter)
    pdm_mic #(.CLK_DIV(MIC_CLK_DIV), .WINDOW(MIC_WINDOW), .TH(MIC_TH), .HOLDOFF(MIC_HOLDOFF)) mic (
             .clk(clk), .rst(rst), .m_clk(M_CLK), .m_data(M_DATA), .m_lrsel(M_LRSEL),
             .clap_pulse(clap), .amplitude(mic_amp),
             .win_pulse(mic_win), .holdoff(), .th_dyn(mic_th_eff), .use_dyn(1'b1));
    // ---- W4 clap meter on the screen (boss 1 fight): SW5-SW8 = threshold (0 = default MIC_TH, else 128 x the 4 bit value) ----
    reg  [11:0] mic_lvl = 12'd0;                 // level with a slow fall so the bar can be read
    reg  [4:0]  mic_hit_cnt = 5'd0;              // clap flash (about 0.5 s)
    always @(posedge clk) begin
        if (mic_win && mic_amp > mic_lvl) mic_lvl <= mic_amp;
        else if (frame_tick && mic_lvl != 0) mic_lvl <= mic_lvl - (mic_lvl >> 3) - 1'b1;
        if (clap | sw11_rise) mic_hit_cnt <= 5'd30;
        else if (frame_tick && mic_hit_cnt != 0) mic_hit_cnt <= mic_hit_cnt - 1'b1;
    end
    wire [15:0] mic_th_bcd, mic_lv_bcd;           // numbers shown under the meter (threshold, live level)
    bin2bcd bcd_th (.clk(clk), .bin({2'b00, mic_th_eff}), .bcd(mic_th_bcd));
    bin2bcd bcd_lv (.clk(clk), .bin({2'b00, mic_lvl}),    .bcd(mic_lv_bcd));
    wire        mic_on    = (b_act && (b_kind == 2'd0)) || (is_title && tpage == 4'd1);   // boss 1 fight or the title SETTINGS page
    wire        mic_nums  = is_title && tpage == 4'd1;
    wire [6:0]  mic_w     = (mic_lvl[11:4] > 8'd120) ? 7'd120 : mic_lvl[10:4];
    wire [6:0]  mic_th_px = (mic_th_eff[11:4] > 8'd120) ? 7'd120 : mic_th_eff[10:4];

    puzzles #(.SEED(SEED)) pz (.clk(clk), .rst(rst), .frame_tick(ft), .anim(fc[3]), .run(run), .brk(brk),
                 .restart(restart), .room_load(load), .floor(floor), .grid(grid), .px(px), .py(py),
                 .up(bu), .down(bd), .left(bl), .right(br), .melee_on(melee_on), .melee_dir(melee_dir),
                 .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .soko_reset(sw13_rise),
                 .got_item(pz_got), .hit(pz_hit), .ev_ok(ev_ok), .has_item(has_item),
                 .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
                 .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame),
                 .pbox0(pbox0), .pbox1(pbox1), .pbox_en(pbox_en), .soko_stuck(soko_stuck),
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
    wire [4:0]  dbg_bhp   /*verilator public*/ = b_hp;
    wire [5:0]  dbg_pact  /*verilator public*/ = pb_act;
    wire        dbg_chg   /*verilator public*/ = charged;
    wire [9:0]  dbg_bx    /*verilator public*/ = b_x;
    wire [9:0]  dbg_by    /*verilator public*/ = b_y;
    wire        dbg_bact  /*verilator public*/ = b_act;
    wire        dbg_stun  /*verilator public*/ = b_stunned;
    wire        dbg_clap  /*verilator public*/ = clap;
    wire [15:0] dbg_esc   /*verilator public*/ = {e_s_t, e_s_o, e_f_t, e_f_o};

    // ---------- เฟรม: กะพริบข้อความ / LED, จอสั่น ----------
    // (fc is declared near the top, see 'frame counter')
    reg [3:0] blk_cnt = 0;                // LED กะพริบ 4 Hz (คาบ LED_BLINK เฟรม)
    reg [3:0] sh_cnt = 0;
    reg [7:0] sh_lfsr = 8'hA5;
    reg [9:0] sh_dx = 0, sh_dy = 0;
    function [9:0] shv(input [2:0] v);    // 0..7 -> -SHAKE_PX..+SHAKE_PX (10 bit two's complement)
        case (v)
            3'd0, 3'd5: shv = -SHAKE_PX;
            3'd1, 3'd7: shv = -(SHAKE_PX / 2);
            3'd3:       shv = SHAKE_PX / 2;
            3'd4, 3'd6: shv = SHAKE_PX;
            default:    shv = 10'd0;
        endcase
    endfunction
    always @(posedge clk) if (ft) begin
        fc <= fc + 1'b1;
        blk_cnt <= (blk_cnt == LED_BLINK - 1) ? 4'd0 : blk_cnt + 1'b1;
        if (hurt_shake != 5'd0) begin
            if (sh_cnt == SHAKE_EVERY - 1) begin
                sh_cnt <= 0;
                sh_lfsr <= {sh_lfsr[6:0], sh_lfsr[7] ^ sh_lfsr[5] ^ sh_lfsr[4] ^ sh_lfsr[3]};
                sh_dx <= shv(sh_lfsr[2:0]);
                sh_dy <= shv(sh_lfsr[5:3]);
            end else sh_cnt <= sh_cnt + 1'b1;
        end else begin
            sh_cnt <= 0; sh_dx <= 0; sh_dy <= 0;
        end
    end
    wire led_blink_on = (blk_cnt < (LED_BLINK + 1) / 2);
    wire hint_on;                               // W32: the hint strip is shown (assigned below, next to its logic)
    // ข้อความ: 1 TITLE 2 FLOOR CLEAR 3 ESCAPE! 4 WIN 5 GAME OVER 6 PAUSED
    wire [4:0] txt_scr = paused ? 5'd6 : is_title ? ((tpage == 4'd0) ? 5'd1 : (tpage == 4'd1) ? (5'd25 + {2'b00, mic_step}) : (5'd14 + {1'b0, tpage})) : is_pro ? (5'd7 + {3'b000, pro_page}) :
                         (state == S_EVOLVE) ? (5'd11 + {3'b000, form}) : (state == S_CLEAR) ? 5'd2 : esc_banner ? 5'd3 :
                         is_win ? 5'd4 : (state == S_GAME_OVER) ? (tmo ? 5'd15 : 5'd5) : dlg_show ? 5'd14 : hint_on ? 5'd24 : 5'd0;
    wire [2:0] b_frame = {b_kind, 1'b0} + ((b_kind == 2'd0) ? b_stunned : b_anim);   // บอส 1 เฟรม 1 = ภาพมึน (W10)

    // ---------- W7: Ball in a Maze (state ESCAPE) ----------
    wire [7:0] adx_ax, adx_ay; wire adx_valid, adx_ready;
    adxl362 acl (.clk(clk), .rst(rst), .ACL_MISO(ACL_MISO), .ACL_MOSI(ACL_MOSI), .ACL_SCLK(ACL_SCLK), .ACL_CSN(ACL_CSN),
                 .ax(adx_ax), .ay(adx_ay), .valid(adx_valid), .ready(adx_ready));
    reg esc_d = 1'b0;
    always @(posedge clk) esc_d <= is_esc;
    wire maze_start = is_esc & ~esc_d;
    wire [9:0] ball_x, ball_y;
    maze #(.DEADZONE(MAZE_DEADZONE), .TILT_SHIFT(MAZE_TILT_SHIFT), .BTN_ACC(MAZE_BTN_ACC), .MAXV(MAZE_MAXV),
           .SIGN_X(MAZE_SIGN_X), .SIGN_Y(MAZE_SIGN_Y)) mz (
        .clk(clk), .rst(rst), .frame_tick(ft), .run(is_esc), .start(maze_start),
        .ax(adx_ax), .ay(adx_ay), .sample_valid(adx_valid), .use_btn(sw10 | ~adx_ready),
        .bu(bu), .bd(bd), .bl(bl), .br(br), .bx(ball_x), .by(ball_y), .goal(maze_goal));
    // the ball is drawn as puzzle object slot 0 (frame 10 = ball art, 32x32 sprite around the 20x20 ball box)
    // the key item (keyitem.v) lies in the floor-3 boss room after boss 3 died: puzzle frame 14
    keyitem kit (.clk(clk), .rst(rst), .restart(restart), .died3(b_died && b_kind == 2'd2), .bx(b_x), .by(b_y), .px(px), .py(py),
                 .floor(floor), .room(room), .play(state == S_PLAY), .vis(key_vis), .kx(key_x), .ky(key_y), .pick(key_pick));
    wire [1:0]  ball_ph    = ball_x[3:2] + ball_y[3:2];                         // rolling: the picture follows the position (4 pictures)
    wire [3:0]  ball_f     = 4'd10 + {2'b00, ball_ph};
    // title screen: two torches beside the hero (puzzle frames 0 lit / 1 ember alternate = flicker)
    wire [3:0]  tf         = fc[3] ? 4'd1 : 4'd0;
    wire [8:0]  pz_act_r   = is_title0 ? 9'd3 : (is_esc || key_vis) ? 9'd1 : pz_act;
    wire [89:0] pz_x_r     = is_title0 ? {70'd0, 10'd512, 10'd96} : is_esc ? {80'd0, ball_x - 10'd6} : key_vis ? {80'd0, key_x} : pz_x;
    wire [89:0] pz_y_r     = is_title0 ? {70'd0, 10'd208, 10'd208} : is_esc ? {80'd0, ball_y - 10'd6} : key_vis ? {80'd0, key_y} : pz_y;
    wire [35:0] pz_frame_r = is_title0 ? {28'd0, tf, tf} : is_esc ? {32'd0, ball_f} : key_vis ? {32'd0, 4'd14} : pz_frame;
    // room-change fade-in: the picture starts dark and brightens over 6 frames after every room load
    reg [2:0] fade_t = 3'd0;
    always @(posedge clk) if (load) fade_t <= 3'd6; else if (frame_tick && fade_t != 3'd0) fade_t <= fade_t - 3'd1;
    wire [1:0] fade_lvl = fade_t[2:1] + {1'b0, fade_t[0]};              // 6,5 -> 3 | 4,3 -> 2 | 2,1 -> 1 | 0 -> 0
    wire [9:0]  dbg_ballx /*verilator public*/ = ball_x;
    wire [9:0]  dbg_bally /*verilator public*/ = ball_y;

    // ---------- W16: dialogue events (docs/STORY.md -> rtl/dlg_cfg.vh, EV_* indices) ----------
    `include "dlg_cfg.vh"
    localparam [2:0] R_START = 3'd0, R_C1 = 3'd1, R_C2 = 3'd2, R_PUZ = 3'd3, R_BOSS3 = 3'd4;
    wire [63:0] dlg_ev;
    reg  [3:0]  ld_dly = 4'd0;                 // world.load happened: judge the room at the next frame tick (monsters are spawned by then)
    reg         ld_chk = 1'b0;
    reg [1:0]   st_cnt = 2'd0;
    reg  [2:0]  state_d = 3'd0;
    reg         vuln_d = 1'b0;
    wire        key_drop_ev = b_died && b_kind == 2'd2;
    reg         doors_dd = 1'b0, lb_d = 1'b0, gt_d = 1'b0, sm_d = 1'b0, tele_d = 1'b0, ban_d = 1'b0, fa_done = 1'b0, start_d1 = 1'b0, start_d2 = 1'b0;
    reg [5:0]   lock_seen = 6'd0;             // floor*2 + (room - 1): a locked combat room was entered (so a later "clear" is a real clear)
    always @(posedge clk) begin
        start_d1 <= restart; start_d2 <= start_d1; vuln_d <= b_vuln;
        state_d <= state; doors_dd <= doors_open; lb_d <= lb_ok; gt_d <= gate_open; sm_d <= sm_ok; tele_d <= b_tele; ban_d <= esc_banner;
        if (restart) begin lock_seen <= 6'd0; fa_done <= 1'b0; end
        else if (ld_now && locked_n) lock_seen[{floor, c2}] <= 1'b1;        // (one always block drives lock_seen: two blocks were multi-driven in synthesis, the clear messages never fired)
        if (load) ld_chk <= 1'b1;
        if (frame_tick) ld_chk <= 1'b0;
        if (state == S_PLAY && bc_rise_g) fa_done <= 1'b1;
    end
    wire ld_now   = ld_chk & frame_tick & (state == S_PLAY);
    wire in_c     = (room == R_C1) || (room == R_C2);
    wire locked_n = in_c && !doors_open && (alive != 3'd0);
    wire clr_now  = in_c && doors_open && !doors_dd;
    wire f0 = (floor == 2'd0), f1 = (floor == 2'd1), f2 = (floor == 2'd2);
    wire c1 = (room == R_C1), c2 = (room == R_C2);
    wire evolved = (state_d == 3'd2) && (state == S_PLAY);                    // EVOLVE -> PLAY
    reg seen_intro = 1'b0;                      // W33: the full intro is only told once per power-on / reset
    always @(posedge clk) if (rst) seen_intro <= 1'b0; else if (start_d2) seen_intro <= 1'b1;
    assign dlg_ev[EV_START]            = start_d2 & ~seen_intro;
    assign dlg_ev[EV_START_AGAIN]      = start_d2 & seen_intro;
    assign dlg_ev[EV_FIRST_ATTACK]     = (state == S_PLAY) && bc_rise_g && !fa_done;
    assign dlg_ev[EV_LOCK_F1C1]        = ld_now && locked_n && f0 && c1;
    assign dlg_ev[EV_CLEAR_F1C1]       = clr_now && f0 && c1 && lock_seen[{2'd0, 1'b0}];
    assign dlg_ev[EV_LOCK_F1C2]        = ld_now && locked_n && f0 && c2;
    assign dlg_ev[EV_CLEAR_F1C2]       = clr_now && f0 && c2 && lock_seen[{2'd0, 1'b1}];
    assign dlg_ev[EV_ENTER_F1PUZ]      = ld_now && f0 && room == R_PUZ;
    assign dlg_ev[EV_ITEM_F1]          = lb_ok & ~lb_d & f0;
    assign dlg_ev[EV_GOT_F1]           = pz_got & f0;
    assign dlg_ev[EV_EVOLVED_F1]       = evolved & f0;
    assign dlg_ev[EV_ENTER_F1BOSS]     = ld_now && f0 && room == R_BOSS3;
    assign dlg_ev[EV_BOSSDEAD_F1]      = b_died && b_kind == 2'd0;
    assign dlg_ev[EV_ENTER_F2START]    = ld_now && f1 && room == R_START;
    assign dlg_ev[EV_LOCK_F2C1]        = ld_now && locked_n && f1 && c1;
    assign dlg_ev[EV_ENTER_F2C1]       = ld_now && f1 && c1;
    assign dlg_ev[EV_LOCK_F2C2]        = ld_now && locked_n && f1 && c2;
    assign dlg_ev[EV_CLEAR_F2C2]       = clr_now && f1 && c2 && lock_seen[{2'd1, 1'b1}];
    assign dlg_ev[EV_ENTER_F2PUZ]      = ld_now && f1 && room == R_PUZ;
    assign dlg_ev[EV_ITEM_F2]          = gate_open & ~gt_d & f1;
    assign dlg_ev[EV_EVOLVED_F2]       = evolved & f1;
    assign dlg_ev[EV_ENTER_F2BOSS]     = ld_now && f1 && room == R_BOSS3;
    assign dlg_ev[EV_VULN_F2]          = b_vuln & ~vuln_d;
    assign dlg_ev[EV_BOSSDEAD_F2]      = b_died && b_kind == 2'd1;
    assign dlg_ev[EV_ENTER_F3START]    = ld_now && f2 && room == R_START;
    assign dlg_ev[EV_LOCK_F3C1]        = ld_now && locked_n && f2 && c1;
    assign dlg_ev[EV_LOCK_F3C2]        = ld_now && locked_n && f2 && c2;
    assign dlg_ev[EV_CLEAR_F3C2]       = clr_now && f2 && c2 && lock_seen[{2'd2, 1'b1}];
    assign dlg_ev[EV_ENTER_F3PUZ]      = ld_now && f2 && room == R_PUZ;
    assign dlg_ev[EV_ITEM_F3]          = sm_ok & ~sm_d & f2;
    assign dlg_ev[EV_EVOLVED_F3]       = evolved & f2;
    assign dlg_ev[EV_ENTER_F3BOSS]     = ld_now && f2 && room == R_BOSS3;
    assign dlg_ev[EV_CHARGE_F3]        = b_tele & ~tele_d;
    assign dlg_ev[EV_INTERRUPT_F3]     = b_intr;
    assign dlg_ev[EV_KEY_DROP]         = key_drop_ev;
    assign dlg_ev[EV_ENTER_F3START_KEY] = ld_now && f2 && room == R_START && has_key;
    assign dlg_ev[EV_MAZE_BANNER_END]  = ban_d & ~esc_banner & is_esc;
    assign dlg_ev[63:EV_START_AGAIN + 1] = 0;                    // (EV_START_AGAIN is the LAST event: the old bound EV_MAZE_BANNER_END + 1 drove bit 36 twice and Vivado kept the constant 0)
    wire [11:0] dlg_b0, dlg_b1; wire [4:0] dlg_n0, dlg_n1; wire [1:0] dlg_spk;
    // ---------- W32 hint strip: objective of the room + W28 tutorial prompts (never freezes the game) ----------
    reg [12:0]  soko_t = 13'd0;                      // W41: frames spent in the unsolved Sokoban room (90 s = probably stuck)
    always @(posedge clk) begin
        if (rst || restart || load || gate_open || sw13_rise) soko_t <= 13'd0;
        else if (frame_tick && state == S_PLAY && floor == 2'd1 && room == R_PUZ && soko_t != 13'd8191) soko_t <= soko_t + 13'd1;
    end
    wire        soko_help = soko_stuck || (soko_t >= 13'd5400);
    wire [6:0]  hint_idx;
    wire [11:0] hint_b0, hint_b1; wire [4:0] hint_n0, hint_n1;
    reg  [2:0]  tut_step = 3'd0;                 // 0 start text, 1 move, 2 attack, 3 sprint, 4 pause, 5 auto aim, 6 done
    reg  [6:0]  tut_mv = 7'd0, tut_t = 7'd0;     // frames walked / frames in a timed step
    reg         pz_d = 1'b0;
    always @(posedge clk) begin
        pz_d <= paused;
        if (rst || restart) begin tut_step <= 3'd0; tut_mv <= 7'd0; tut_t <= 7'd0; end
        else if (load && !(floor == 2'd0 && room == R_START)) tut_step <= 3'd6;       // leaving the first room ends the tutorial
        else if (frame_tick && state == S_PLAY && !paused && !dlg_show) begin
            case (tut_step)
                3'd0: if (tut_t == 7'd90) begin tut_step <= 3'd1; tut_t <= 7'd0; end else tut_t <= tut_t + 7'd1;                     // "free to move" for 1.5 s
                3'd1: if (p_moving) begin if (tut_mv == 7'd48) begin tut_step <= 3'd2; tut_mv <= 7'd0; end else tut_mv <= tut_mv + 7'd1; end
                3'd2: if (fa_done) tut_step <= 3'd3;
                3'd3: if (sw14 && p_moving) begin if (tut_mv == 7'd20) begin tut_step <= 3'd4; tut_mv <= 7'd0; end else tut_mv <= tut_mv + 7'd1; end
                3'd5: if (tut_t == 7'd120) begin tut_step <= 3'd6; end else tut_t <= tut_t + 7'd1;
                default: ;
            endcase
        end
        if (tut_step == 3'd4 && paused && !pz_d) begin tut_step <= 3'd5; tut_t <= 7'd0; end     // first pause started
    end
    wire tut_on = (state == S_PLAY) && (tut_step != 3'd6) && floor == 2'd0 && room == R_START;
    wire in_boss = (room == R_BOSS3) && b_act;
    wire [6:0] obj_idx = key_vis || has_key ? HINT_OBJ_KEY[6:0] :
                         in_boss ? ((floor == 2'd0) ? HINT_OBJ_BOSS1[6:0] : (floor == 2'd1) ? HINT_OBJ_BOSS2[6:0] : HINT_OBJ_BOSS3[6:0]) :
                         (room == R_BOSS3) ? HINT_OBJ_BOSSDEAD[6:0] :
                         (room == R_PUZ && !((floor == 2'd0) ? lb_ok : (floor == 2'd1) ? gate_open : sm_ok)) ? ((floor == 2'd0) ? HINT_OBJ_BULB[6:0] : (floor == 2'd1) ? (soko_help ? HINT_OBJ_STUCK[6:0] : HINT_OBJ_SOKO[6:0]) : HINT_OBJ_SIMON[6:0]) :
                         in_c ? ((alive != 3'd0 && !doors_open) ? HINT_OBJ_COMBAT[6:0] : HINT_OBJ_OPEN[6:0]) :
                         (room == R_PUZ) ? HINT_OBJ_OPEN[6:0] : 7'd127;
    wire [6:0] tut_idx = (tut_step == 3'd0) ? HINT_TUT_START[6:0] : (tut_step == 3'd1) ? HINT_TUT_MOVE[6:0] : (tut_step == 3'd2) ? HINT_TUT_ATTACK[6:0] :
                         (tut_step == 3'd3) ? HINT_TUT_SPRINT[6:0] : (tut_step == 3'd4) ? HINT_TUT_PAUSE[6:0] : HINT_TUT_AIM[6:0];
    assign hint_idx = tut_on ? tut_idx : obj_idx;
    assign hint_on = (state == S_PLAY) && !paused && (tut_on || obj_idx != 7'd127);
    dialog dlg (.clk(clk), .rst(rst), .restart(restart), .frame_tick(frame_tick), .en((state == S_PLAY || is_esc) && !paused),
                .ev(dlg_ev), .advance(bc_rise | skip_adv), .show(dlg_show), .block(dlg_block),
                .hint_idx(hint_idx), .hb0(hint_b0), .hb1(hint_b1), .hn0(hint_n0), .hn1(hint_n1),
                .b0(dlg_b0), .b1(dlg_b1), .n0(dlg_n0), .n1(dlg_n1), .spk(dlg_spk));
    wire [11:0] dlg_col = (dlg_spk == 2'd0) ? 12'hFFF : (dlg_spk == 2'd1) ? 12'hFF0 : 12'h0FF;      // Player white, Voice yellow, System cyan

    // ---------- render ----------
    // TITLE: sprite ร่าง 1 idle หันลง กลางจอ
    wire [9:0]  rpx = is_title0 ? 10'd232 : px;                       // title: the hero (left) faces the big vampire (right)
    wire [9:0]  rpy = is_title0 ? 10'd240 : py;
    always @(posedge clk) if (ev_shoot | ev_melee) turn_cnt <= LOCK_TURN_FRAMES; else if (ft && turn_cnt != 5'd0) turn_cnt <= turn_cnt - 5'd1;
    wire [1:0]  face_vis = (sw9 && turn_cnt != 5'd0 && lock_use) ? lock_face : facing;     // W18: the hero turns to the locked target (picture only)
    wire [5:0]  pframe = is_title0 ? 6'd9 : form * 6'd12 + face_vis * 6'd3 + pose;
    player_frame pfr (.clk(clk), .rst(rst), .frame_tick(ft), .form(form), .facing(face_vis), .melee_dir(melee_dir),
                      .moving(p_moving), .melee_on(melee_on), .invuln(invuln), .dead(state == S_GAME_OVER), .active(!is_title),
                      .shoot(ev_shoot), .anim_sel(p_anim), .aframe(p_aframe), .hurt_flash(p_hurt));
    wire [2:0]  screen = is_title ? ((tpage == 4'd0) ? 3'd1 : 3'd4) : (state == S_GAME_OVER) ? 3'd2 : is_win ? 3'd3 : is_pro ? 3'd4 : is_esc ? 3'd5 : 3'd0;
    wire [11:0] color;
    renderer rnd (.brk(brk), .trap_a(trap_a), .trap_b(trap_b), .open_E(open_E), .p_hurt(p_hurt), .ov_phase(fc[4:3]), .fade(fade_lvl), .dlg_on(txt_scr == 5'd14), .hbox_on(SW[8] ^ k_hbox_on), .dlg_top((room == R_C2) || (room == R_PUZ && floor == 2'd0)), .dlg_b0(dlg_b0), .dlg_b1(dlg_b1), .dlg_n0(dlg_n0), .dlg_n1(dlg_n1), .dlg_col(dlg_col), .hud_hp(hp), .hud_hp_max(is_title ? 3'd0 : hp_max), .hud_b_hp(b_hp), .chg_w(b_chg_w), .facing(face_vis), .chg_lvl(p_chg_lvl), .tgt_on(sw9 && lock_use && state == S_PLAY && !paused && !dlg_block), .tgt_x(lock_tx), .tgt_y(lock_ty), .boss_fcol(b_fcol), .mic_on(mic_on), .mic_w(mic_w), .mic_th(mic_th_px), .mic_hit(mic_hit_cnt != 5'd0), .mic_nums(mic_nums), .mic_th_bcd(mic_th_bcd), .mic_lv_bcd(mic_lv_bcd), .clk(clk), .ce(ce), .hcount(hcount), .vcount(vcount), .grid(grid), .floor(floor),
                  .form(form), .doors_open(doors_open), .open_L(open_L),
                  .screen(screen), .hide_player(fsm_hide | is_pro | is_esc | (is_title && tpage != 4'd0) | (obj_blink && !is_title)),
                  .px(rpx), .py(rpy), .pframe(pframe), .p_anim(p_anim), .p_aframe(p_aframe),
                  .mon_act(mon_act), .mon_face(mon_face), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                  .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .pb_kind(pb_kind),
                  .p_tint(charged && fc[2]),
                  .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir),
                  .pz_act(pz_act_r), .pz_x(pz_x_r), .pz_y(pz_y_r), .pz_frame(pz_frame_r),
                  .pbox0(pbox0), .pbox1(pbox1), .pbox_en(pbox_en),
                  .simon_lit_on(simon_lit_on), .simon_lit(simon_lit), .simon_wrong(simon_wrong),
                  .boss_act(b_act | is_title0), .boss_x(is_title0 ? 10'd352 : b_x), .boss_y(is_title0 ? 10'd192 : b_y), .boss_frame(is_title0 ? {2'b10, fc[5]} : b_frame), .boss_flash(b_flash | (b_shield & fc[3]) | (b_tele & ((b_tele_lvl == 2'd0) ? fc[4] : (b_tele_lvl == 2'd1) ? fc[3] : (b_tele_lvl == 2'd2) ? fc[2] : fc[1])) | (b_warn & fc[2])),
                  .sh_dx(sh_dx), .sh_dy(sh_dy), .hint_b0(hint_b0), .hint_b1(hint_b1), .hint_n0(hint_n0), .hint_n1(hint_n1), .txt_scr(txt_scr), .txt_blink(fc[5]),
                  .t_floor((txt_scr == 5'd24) ? {1'b0, alive} : {2'b00, floor} + 4'd1), .t_m1(m_t), .t_m0(m_o), .t_s1(s_t), .t_s0(s_o),
                  .color(color));

    // renderer มี latency 4 clock (stage 0 พิกัด/ที่อยู่ tile, 1 ROM tile + เลือกชั้น, 2 BRAM, 3 mix) -> หน่วง sync/active เท่ากัน ภาพตรงทั้ง CE_DIV = 1 และ 4
    reg [3:0] hs_d = 4'b1111, vs_d = 4'b1111, act_d = 4'b0000;
    always @(posedge clk) begin
        hs_d  <= {hs_d[2:0], hsync};
        vs_d  <= {vs_d[2:0], vsync};
        act_d <= {act_d[2:0], active};
    end
    always @(posedge clk) if (ce) begin
        {VGA_R, VGA_G, VGA_B} <= act_d[3] ? color : 12'h000;
        VGA_HS <= hs_d[3];
        VGA_VS <= vs_d[3];
    end

    // ---------- 7-seg / LED / RGB ----------
    // [ชั้น] - [HP] - m m . s s   (d7 ซ้ายสุด; DP ที่ d2 = หลังหลักนาทีหน่วย) TITLE = ทุกหลัก '-'
    wire [6:0] seg;
    // ESCAPE: 4 หลักขวาเป็นเวลานับถอยหลัง ss.ff (วินาที . เฟรม) แทนเวลาเล่น (เวลาเล่นยังเดินอยู่เบื้องหลัง)
    wire [31:0] digits = (is_title || is_pro) ? 32'hEEEEEEEE :
                         is_esc   ? {1'b0, {1'b0, floor} + 3'd1, 4'hE, 1'b0, hp, 4'hE, e_s_t, e_s_o, e_f_t, e_f_o} :
                                    {1'b0, {1'b0, floor} + 3'd1, 4'hE, 1'b0, hp, 4'hE, m_t, m_o, s_t, s_o};
    seg7 s7 (.clk(clk), .digits(digits), .dots((is_title || is_pro) ? 8'h00 : (paused && pause_blink) ? 8'h00 : 8'b0000_0100),
             .seg(seg), .an(AN), .dp(DP));
    assign {CG, CF, CE, CD, CC, CB, CA} = seg;

    // LED0-3 = ปุ่มทิศ, LED4-7 = มอนเหลือ (bar), LED8-11 = HP bar (LED8 = HP 1 ...),
    // LED12 = ประตูห้องล็อก, LED13 = มีไอเทมชั้นนี้, LED14 = sprint (SW14), LED15 = WIN; ห้องปริศนา: LED0-3 = หลอด / รอบ Simon
    wire [3:0] mon_bar = {alive >= 3'd4, alive >= 3'd3, alive >= 3'd2, alive >= 3'd1};
    wire [3:0] led_lo = room_led_on ? room_led : {br, bl, bd, bu};
    wire [15:0] led_play = {is_win, sw14, has_item[floor], ~doors_open, hp >= 3'd4, hp >= 3'd3, hp >= 3'd2, hp >= 3'd1,
                            mon_bar, led_lo};
    // ห้องบอส: LED0-7 = HP บอส (bar 8 ดวง ตามสัดส่วน) · ESCAPE: LED ทั้ง 16 ดวงกะพริบ 4 Hz
    assign LED = is_esc ? {16{led_blink_on}} :
                 (room == R_BOSS) ? {led_play[15:8], b_hpbar} : led_play;

    reg [7:0] pwm = 0;
    always @(posedge clk) pwm <= pwm + 1'b1;
    wire dim = (pwm < 8'd16);                     // RGB LED สว่างมาก: duty ~6%
    // สีตามร่าง (เขียว / ฟ้า / ม่วง / ทอง) ขาวตอน EVOLVE — ตารางอยู่ใน game_fsm.v
    assign LED16_R = dim & rgb[2];
    assign LED16_G = dim & rgb[1];
    assign LED16_B = dim & rgb[0];
    assign LED17_R = dim & invuln;                // แดงตอนโดนตี (knockback + อมตะ)
    assign LED17_G = dim & (kd_got != 0);          // W22 diagnostics: a valid PS/2 byte arrived
    assign LED17_B = dim & (kd_clk != 0);          // W22 diagnostics: the PS2_CLK line is moving

    // ---------- เสียง (audio.v) ----------
    // เหตุการณ์ -> pulse 1 clock; ขอบขึ้นของสัญญาณระดับ (มึน, ประตูเปิด, gate เปิด) ตรวจที่นี่
    reg stun_d = 1'b0, doors_d = 1'b1, gate_d = 1'b0;
    always @(posedge clk) begin stun_d <= b_stunned; doors_d <= doors_open; gate_d <= gate_open; end
    reg b_act_d = 1'b0;
    always @(posedge clk) b_act_d <= b_act;
    reg  [1:0] chg_lvl_d = 2'd0;       // W21: charge level last frame (a beep at every step of the boss-3 charge)
    reg        b_tele_d2 = 1'b0;
    always @(posedge clk) begin chg_lvl_d <= b_tele_lvl; b_tele_d2 <= b_tele; end
    wire chg_beep = b_tele & (~b_tele_d2 | (b_tele_lvl != chg_lvl_d));
    wire [13:1] aud_ev = {chg_beep, door_evt, b_act & ~b_act_d, ev_melee, ev_shoot, ev_mdmg | b_dmg, ev_ok, pz_hit,
                          (doors_open & ~doors_d) | (gate_open & ~gate_d), pz_got | sw3_rise,
                          ev_mdie | b_died, b_stunned & ~stun_d, obj_hit | sw4_rise};
    `include "bgm_cfg.vh"
    wire [2:0] bgm_floor = (floor == 2'd0) ? BGM_F1 : (floor == 2'd1) ? BGM_F2 : BGM_F3;
    wire [2:0] bgm_track = is_esc ? BGM_ESC : is_win ? BGM_WIN : (state == S_GAME_OVER) ? BGM_OVER : bgm_floor;
    localparam AUD_TSHIFT = (CE_DIV == 1) ? 2 : (CE_DIV == 2) ? 1 : 0;   // sim CE_DIV = 1: เฟรมสั้นลง 4 เท่า -> ย่อ half-period
    wire [7:0] aud_sample;
    audio #(.TSHIFT(AUD_TSHIFT)) aud (.clk(clk), .rst(rst), .frame_tick(frame_tick), .ev(aud_ev), .shoot_k(ev_shoot_k),
              .simon_note_on(simon_note_on), .simon_note(simon_note), .pause(paused),
              .bgm_en(!is_title && !is_pro), .bgm_track(bgm_track),
              .pwm(AUD_PWM), .sd(AUD_SD), .sample(aud_sample));
endmodule
