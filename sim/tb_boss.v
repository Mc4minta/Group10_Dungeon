`timescale 1ns/1ps
// ทดสอบบอส: boss.v + objects.v + player.v + game_fsm.v + world.v (frame_tick ทุก 800 clock)
//   HP / การเดินแต่ละตัว, บอส 2 อยู่ในวงรั้ว, มึน 120 + cooldown 300, คาบยิง 120 / 60, ห้องล็อก,
//   บอสตาย -> FLOOR_CLEAR -> ชั้นถัดไป, บอส 3 ตาย -> ESCAPE -> ประตู E -> WIN, หมดเวลา -> GAME_OVER, ตายแล้วตายเลย
// รัน: ./scripts/run_sim.sh boss
module tb_boss;
    `include "params.vh"
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;
    localparam TICK = 800;
    integer tc = 0; reg tick = 0; integer frame_no = 0;
    always @(posedge clk) begin
        tc <= (tc == TICK - 1) ? 0 : tc + 1;
        tick <= (tc == TICK - 1);
        if (tick) frame_no <= frame_no + 1;
    end

    reg up = 0, down = 0, left = 0, right = 0, atk_press = 0, atk_hold = 0, fsm_btnc = 0, clap = 0;
    reg tb_load = 0; reg [9:0] lx = 40, ly = 240;

    wire [2:0] state, hp, hp_max, speed, rgb; wire [1:0] form, damage;
    wire restart, next_floor, freeze, fsm_hide; wire [3:0] m_t, m_o, s_t, s_o, es1, es0, ef1, ef0; wire banner;
    wire [1:0] floor; wire [2:0] room; wire [3:0] grid; wire w_load, exit_evt; wire [9:0] w_lx, w_ly;
    wire [9:0] px, py; wire [1:0] facing, pose, door_dir; wire door_evt;
    wire doors_open, obj_hit, kb_start, invuln, blink, obj_busy, melee_on, mon_anim;
    wire [1:0] kb_dir, melee_dir, pb_act; wire [2:0] alive;
    wire [5:0] mon_act, mon_type, mon_flash; wire [59:0] mon_x, mon_y;
    wire [19:0] pb_x, pb_y; wire [15:0] eb_act; wire [159:0] eb_x, eb_y;
    wire b_act, b_flash, b_stun, b_fire, b_died, b_anim, b_busy, b_dmg; wire [9:0] b_x, b_y;
    wire [1:0] b_kind, b_amt; wire [2:0] b_dead; wire [4:0] b_hp; wire [7:0] b_bar;

    wire ld = w_load | tb_load;
    wire run = (state == 3'd1) || (state == 3'd4);

    world wld (.clk(clk), .rst(rst), .restart(restart), .next_floor(next_floor), .door_evt(door_evt), .door_dir(door_dir),
               .floor(floor), .room(room), .grid(grid), .load(w_load), .load_x(w_lx), .load_y(w_ly), .exit_evt(exit_evt));
    game_fsm fsm (.clk(clk), .rst(rst), .frame_tick(tick), .btnc_rise(fsm_btnc), .got_item(1'b0),
                  .take_hit(obj_hit), .floor_done(b_died && b_kind != 2), .exit_evt(exit_evt),
                  .escape_start(b_died && b_kind == 2), .exit_direct(1'b0), .sprint(1'b0),
                  .state(state), .restart(restart), .next_floor(next_floor), .form(form), .hp(hp),
                  .hp_max(hp_max), .speed(speed), .damage(damage), .rgb(rgb), .freeze(freeze),
                  .hide_player(fsm_hide), .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o),
                  .e_s_t(es1), .e_s_o(es0), .e_f_t(ef1), .e_f_o(ef0), .esc_banner(banner));
    player pl (.clk(clk), .rst(rst), .frame_tick(tick), .up(up), .down(down), .left(left), .right(right),
               .hold_facing(atk_hold), .form(form), .speed(speed), .freeze(freeze), .grid(grid),
               .doors_open(doors_open), .open_L(1'b1), .load(ld), .load_x(tb_load ? lx : w_lx), .load_y(tb_load ? ly : w_ly),
               .blk0(12'd0), .blk1(12'd0), .blk2(12'd0), .blk_en(3'd0),
               .kb_start(kb_start), .kb_dir(kb_dir), .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir));
    objects ob (.clk(clk), .rst(rst), .frame_tick(tick), .run(run), .restart(restart),
                .room_load(ld), .floor(floor), .room(room), .grid(grid), .open_L(1'b1),
                .px(px), .py(py), .facing(facing), .form(form), .damage(damage),
                .atk_press(atk_press), .atk_hold(atk_hold), .dbg_clear(1'b0),
                .blk0(12'd0), .blk1(12'd0), .blk2(12'd0), .blk_en(3'd0),
                .boss_act(b_act), .boss_x(b_x), .boss_y(b_y), .boss_fire(b_fire), .boss_dmg(b_dmg), .boss_dmg_amt(b_amt),
                .doors_open(doors_open), .alive(alive), .hit(obj_hit), .kb_start(kb_start), .kb_dir(kb_dir),
                .invuln(invuln), .player_blink(blink), .busy(obj_busy),
                .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y),
                .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir));
    boss bs (.clk(clk), .rst(rst), .frame_tick(tick), .run(run), .restart(restart), .room_load(ld),
             .floor(floor), .room(room), .grid(grid), .px(px), .py(py), .dmg(b_dmg), .dmg_amt(b_amt), .clap(clap),
             .act(b_act), .bx(b_x), .by(b_y), .kind(b_kind), .flash(b_flash), .stunned(b_stun), .fire(b_fire),
             .died(b_died), .dead(b_dead), .hp(b_hp), .hp_bar(b_bar), .anim(b_anim), .busy(b_busy));

    integer errors = 0, checks = 0, fires = 0, nexts = 0, lastfire = -1, per_ok = 1, nper = 0, exits = 0;
    always @(posedge clk) begin
        if (b_fire) begin
            if (lastfire >= 0) begin nper = frame_no - lastfire; end
            lastfire = frame_no; fires = fires + 1;
        end
        if (next_floor) nexts = nexts + 1;
    end
    task check(input cond, input [8*96-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin
            $display("FAIL  %0s  (f%0d state=%0d floor=%0d room=%0d boss act=%b kind=%0d hp=%0d at %0d,%0d)",
                     msg, frame_no, state, floor, room, b_act, b_kind, b_hp, b_x, b_y);
            errors = errors + 1;
        end
    end endtask
    task frames(input integer n); integer q; begin
        for (q = 0; q < n; q = q + 1) @(posedge tick);
        repeat (2) @(posedge clk);
        while (obj_busy || b_busy) @(posedge clk);
        repeat (5) @(posedge clk);
    end endtask
    // พาไปห้อง (floor f, room r) แล้ววางผู้เล่นที่ (x, y)
    task go_room(input [1:0] f, input [2:0] r, input [9:0] x, input [9:0] y); begin
        while (obj_busy || b_busy) @(posedge clk);
        wld.floor = f; wld.room = r; lx = x; ly = y;
        @(posedge clk) tb_load <= 1; @(posedge clk) tb_load <= 0;
        repeat (40) @(posedge clk);
        while (obj_busy || b_busy) @(posedge clk);
    end endtask
    task safe; begin while (obj_busy || b_busy) @(posedge clk); fsm.hp = 3'd4; ob.hurt_cnt = 7'd100; end endtask
    task press; begin @(posedge clk); atk_press <= 1; @(posedge clk); atk_press <= 0; end endtask
    task do_clap; begin @(posedge clk); clap <= 1; @(posedge clk); clap <= 0; end endtask

    integer n, x0, y0, inring, moved_x, moved_y, sx0, sy0, hp0;
    initial begin
        repeat (5) @(posedge clk); rst <= 0; repeat (5) @(posedge clk);
        @(posedge clk) fsm_btnc <= 1; @(posedge clk) fsm_btnc <= 0;
        frames(3);
        check(state == 1 && floor == 0 && room == 0, "game started: floor 1 START");

        // ================= บอส 1 =================
        go_room(0, 4, 40, 240);
        check(b_act && b_kind == 0 && b_hp == BOSS1_HP && b_x == 304 && b_y == 208, "boss 1 spawns at B with HP 10");
        frames(2);
        check(!doors_open, "boss room locks while boss alive");
        x0 = b_x;
        for (n = 0; n < 40; n = n + 1) begin safe; frames(1); end
        check(x0 - b_x >= 18 && x0 - b_x <= 21, "boss 1 chases slowly: ~1 px every 2 frames");
        $display("      boss 1 moved %0d px in 40 frames", x0 - b_x);
        check(fires == 0 && eb_act == 0, "boss 1 never shoots");
        // ยิงด้วยร่าง 2 (ดาเมจ 1)
        fsm.form = 2'd1;
        right = 1; frames(1); right = 0;
        hp0 = b_hp;
        press;
        for (n = 0; n < 90 && b_hp == hp0; n = n + 1) begin safe; frames(1); end
        check(b_hp == hp0 - 1 && (b_flash || bs.fl != 0), "player bullet hits boss 1: HP -1, flashes");
        frames(1);
        check(b_bar == {b_hp*8 > 7*BOSS1_HP, b_hp*8 > 6*BOSS1_HP, b_hp*8 > 5*BOSS1_HP, b_hp*8 > 4*BOSS1_HP,
                        b_hp*8 > 3*BOSS1_HP, b_hp*8 > 2*BOSS1_HP, b_hp*8 > BOSS1_HP, b_hp != 0}, "boss HP bar = ceil(HP*8/maxHP) LEDs");
        // ชนตัว: ผู้เล่นโดน HP -1 + knockback
        while (obj_busy || b_busy) @(posedge clk);
        ob.hurt_cnt = 0; fsm.hp = 3'd3;
        lx = b_x + 16; ly = b_y + 16; @(posedge clk) begin end
        while (obj_busy || b_busy) @(posedge clk);
        pl.px = b_x + 16; pl.py = b_y + 20;
        frames(2);
        check(hp == 2 && invuln, "boss contact: player HP -1 (knockback + invulnerable)");
        // เหลือ HP 1 แล้วยิงอีกนัด -> ตาย -> FLOOR_CLEAR -> ชั้นถัดไป
        go_room(0, 4, 40, 240);
        check(b_act && b_hp == BOSS1_HP && b_x == 304, "re-entering (only possible via debug: doors are locked) respawns the boss at B with full HP");
        while (b_busy) @(posedge clk);
        bs.hp = 5'd1;
        right = 1; frames(1); right = 0; nexts = 0;
        press;
        for (n = 0; n < 90 && b_act; n = n + 1) begin safe; frames(1); end
        frames(2);
        check(!b_act && b_dead[0] && state == 3'd3, "boss 1 HP 0 -> removed, dead[0], FLOOR_CLEAR");
        check(doors_open, "boss room unlocks after the boss dies");
        frames(125);
        check(nexts == 1 && floor == 1 && room == 0 && state == 1, "FLOOR_CLEAR -> next_floor -> floor 2 START");
        go_room(0, 4, 40, 240);
        check(!b_act && doors_open, "defeated boss 1 stays defeated (room open)");

        // ================= บอส 2 =================
        go_room(1, 4, 40, 240);
        check(b_act && b_kind == 1 && b_hp == BOSS2_HP && grid == 3, "boss 2 spawns in the fence room with HP 16");
        inring = 1; sx0 = b_x; sy0 = b_y; moved_x = 0; moved_y = 0; fires = 0; lastfire = -1; per_ok = 1;
        for (n = 0; n < 400; n = n + 1) begin
            safe; frames(1);
            if (b_x + 8 < 160 || b_x + 56 > 480 || b_y + 8 < 128 || b_y + 56 > 352) inring = 0;
            if (b_x != sx0) moved_x = 1;
            if (b_y != sy0) moved_y = 1;
            if (fires >= 2 && nper != BOSS2_FIRE) per_ok = 0;
        end
        check(inring, "boss 2 stays inside the fence ring (400 frames)");
        check(moved_x && moved_y, "boss 2 moves diagonally (both axes)");
        check(fires >= 3 && per_ok, "boss 2 fires every 120 frames");
        $display("      boss 2 fired %0d times, last period %0d", fires, nper);
        // ตบมือ -> มึน 120 เฟรม
        do_clap; frames(2);
        check(b_stun, "clap -> boss 2 stunned");
        x0 = b_x; y0 = b_y; fires = 0;
        for (n = 0; n < 100; n = n + 1) begin safe; frames(1); end
        check(b_stun && b_x == x0 && b_y == y0 && fires == 0, "stunned: no movement, no shots");
        for (n = 0; n < 25 && b_stun; n = n + 1) begin safe; frames(1); end
        check(!b_stun && n >= 17 && n <= 21, "stun ends after 120 frames");
        do_clap; frames(2);
        check(!b_stun, "clap during the 300-frame cooldown is ignored");
        for (n = 0; n < 300; n = n + 1) begin safe; frames(1); end
        do_clap; frames(2);
        check(b_stun, "after the cooldown a clap stuns again");
        // ยิงทะลุรั้ว: ผู้เล่นร่าง 3 (ดาเมจ 2) อยู่นอกวง ยิงเข้าไปตอนบอสมึน
        fsm.form = 2'd2;
        while (obj_busy || b_busy) @(posedge clk);
        lx = 10'd40; ly = b_y + 20; @(posedge clk) begin end
        go_room(1, 4, 40, b_y + 20);
        // (go_room spawn ใหม่ = บอสกลับจุดเกิด: ยิงจากแถวเดียวกับบอสหลังเข้าห้องใหม่)
        hp0 = b_hp; while (b_busy) @(posedge clk);
        bs.stn = STUN_FRAMES + STUN_COOLDOWN;              // ให้บอสมึนอยู่กับที่
        lx = 10'd40; ly = b_y + 20;
        @(posedge clk) tb_load <= 0;
        pl.py = b_y + 20; pl.px = 10'd40;
        right = 1; frames(1); right = 0;
        press;
        for (n = 0; n < 80 && b_hp == hp0; n = n + 1) begin safe; frames(1); end
        check(b_hp == hp0 - 2, "player bullet passes the fence and hits boss 2 (damage 2)");
        // บอส 2 ตาย -> FLOOR_CLEAR -> ชั้น 3
        while (b_busy) @(posedge clk);
        bs.hp = 5'd2; nexts = 0;
        frames(16); press;
        for (n = 0; n < 80 && b_act; n = n + 1) begin safe; frames(1); end
        frames(128);
        check(b_dead[1] && nexts == 1 && floor == 2, "boss 2 dead -> FLOOR_CLEAR -> floor 3");

        // ================= บอส 1 / 3 ไม่สนตบมือ, บอส 3 =================
        go_room(2, 4, 40, 240);
        check(b_act && b_kind == 2 && b_hp == BOSS3_HP && grid == 2, "boss 3 spawns with HP 24 (floor 3 boss room)");
        do_clap; frames(2);
        check(!b_stun, "clap does nothing to boss 3");
        x0 = b_x; fires = 0; lastfire = -1; per_ok = 1;
        for (n = 0; n < 10; n = n + 1) begin safe; frames(1); end
        check(x0 - b_x >= 18 && x0 - b_x <= 20, "boss 3 chases fast: 2 px/frame");
        for (n = 0; n < 200; n = n + 1) begin safe; frames(1); if (fires >= 2 && nper != BOSS3_FIRE) per_ok = 0; end
        check(fires >= 3 && per_ok, "boss 3 fires every 60 frames");
        // บอส 3 ตาย -> ESCAPE
        while (b_busy) @(posedge clk);
        bs.hp = 5'd1;
        go_room(2, 4, 40, 240);
        while (b_busy) @(posedge clk);
        bs.hp = 5'd1;
        right = 1; frames(1); right = 0; press;
        for (n = 0; n < 80 && b_act; n = n + 1) begin safe; frames(1); end
        frames(2);
        check(b_dead[2] && state == 3'd4 && !freeze, "boss 3 dead -> ESCAPE (player not frozen)");
        // วิ่งไปประตู E ในห้อง START ชั้น 3 (ร่าง 4 ผ่าน E ได้)
        fsm.form = 2'd3;
        go_room(2, 0, 100, 240);
        safe; left = 1; frames(60); left = 0; frames(2);
        check(state == 3'd5, "reach the E door during ESCAPE -> WIN");

        // ================= ESCAPE หมดเวลา =================
        @(posedge clk) fsm_btnc <= 1; @(posedge clk) fsm_btnc <= 0; frames(2);   // WIN -> TITLE
        @(posedge clk) fsm_btnc <= 1; @(posedge clk) fsm_btnc <= 0; frames(3);   // TITLE -> PLAY (restart)
        check(b_dead == 0 && floor == 0, "restart: all bosses alive again");
        go_room(2, 4, 40, 240);
        while (b_busy) @(posedge clk);
        bs.hp = 5'd1; fsm.form = 2'd1;
        right = 1; frames(1); right = 0; press;
        for (n = 0; n < 80 && b_act; n = n + 1) begin safe; frames(1); end
        frames(2);
        check(state == 3'd4, "ESCAPE again");
        for (n = 0; n < 1900 && state == 3'd4; n = n + 1) begin safe; frames(1); end
        check(state == 3'd6 && n >= 1795 && n <= 1801, "ESCAPE countdown hits 0 -> GAME_OVER");
        $display("      ESCAPE timed out after %0d frames", n);

        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
