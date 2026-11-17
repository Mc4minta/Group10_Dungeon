`timescale 1ns/1ps
// ทดสอบ game_fsm.v เดี่ยว ๆ (frame_tick ถี่: ทุก 4 clock)
// รัน: ./scripts/run_sim.sh fsm
module tb_game_fsm;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1, btnc = 0, item = 0, hit = 0, fdone = 0, ext = 0, sprint = 0;
    wire [2:0] state, hp, hp_max, speed, rgb; wire [1:0] form, damage;
    wire restart, next_floor, freeze, hide;
    wire [3:0] m_t, m_o, s_t, s_o;

    localparam TITLE = 0, PLAY = 1, EVOLVE = 2, CLEAR = 3, ESCAPE = 4, WIN = 5, OVER = 6;

    reg [1:0] c = 0; reg tick = 0;
    always @(posedge clk) begin c <= c + 1; tick <= (c == 2'd3); end

    game_fsm dut (.clk(clk), .rst(rst), .frame_tick(tick), .btnc_rise(btnc), .got_item(item),
                  .take_hit(hit), .floor_done(fdone), .exit_evt(ext), .sprint(sprint),
                  .state(state), .restart(restart), .next_floor(next_floor), .form(form), .hp(hp),
                  .hp_max(hp_max), .speed(speed), .damage(damage), .rgb(rgb), .freeze(freeze),
                  .hide_player(hide), .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o));

    integer errors = 0, checks = 0;
    integer ev_ticks, cl_ticks, restarts = 0, nexts = 0, vis = 0, hid = 0;
    always @(posedge clk) begin
        if (restart) restarts = restarts + 1;
        if (next_floor) nexts = nexts + 1;
    end

    task check(input cond, input [8*56-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin $display("FAIL  %0s  (state=%0d form=%0d hp=%0d time=%0d%0d.%0d%0d)", msg, state, form, hp, m_t, m_o, s_t, s_o); errors = errors + 1; end
    end endtask

    task pulse_btnc; begin @(posedge clk); btnc <= 1; @(posedge clk); btnc <= 0; repeat (2) @(posedge clk); end endtask
    task pulse_item; begin @(posedge clk); item <= 1; @(posedge clk); item <= 0; repeat (2) @(posedge clk); end endtask
    task pulse_hit;  begin @(posedge clk); hit  <= 1; @(posedge clk); hit  <= 0; repeat (2) @(posedge clk); end endtask
    task pulse_fdone; begin @(posedge clk); fdone <= 1; @(posedge clk); fdone <= 0; repeat (2) @(posedge clk); end endtask
    task pulse_exit; begin @(posedge clk); ext <= 1; @(posedge clk); ext <= 0; repeat (2) @(posedge clk); end endtask
    task wait_ticks(input integer n); integer i; begin for (i = 0; i < n; i = i + 1) @(posedge tick); @(posedge clk); end endtask
    function [15:0] tm(input dummy); tm = {m_t, m_o, s_t, s_o}; endfunction

    // monitor: นับ frame_tick ที่ DUT เห็นตอนอยู่ใน EVOLVE / FLOOR_CLEAR (sample ก่อน NBA เหมือน DUT)
    reg hide_prev = 0; integer tog = 0;
    always @(posedge clk) begin
        if (state == EVOLVE) begin
            if (tick) ev_ticks = ev_ticks + 1;
            if (hide) hid = hid + 1; else vis = vis + 1;
            if (hide !== hide_prev) tog = tog + 1;
        end
        if (state == CLEAR && tick) cl_ticks = cl_ticks + 1;
        hide_prev <= hide;
    end

    // รัน EVOLVE หนึ่งรอบ
    task do_evolve; begin
        ev_ticks = 0; vis = 0; hid = 0; tog = 0;
        pulse_item;
        while (state == EVOLVE) @(posedge clk);
        repeat (2) @(posedge clk);
    end endtask

    integer i, t0;
    reg [15:0] t_snap;
    initial begin
        repeat (4) @(posedge clk); rst <= 0; repeat (2) @(posedge clk);
        check(state == TITLE && freeze, "reset -> TITLE (frozen)");
        wait_ticks(80);
        check(tm(0) == 16'h0000, "timer stopped in TITLE");

        // ---------- TITLE -> PLAY ----------
        restarts = 0;
        pulse_btnc;
        check(state == PLAY && !freeze, "BTNC in TITLE -> PLAY");
        check(restarts == 1, "restart pulsed once");
        check(form == 0 && hp == 3 && hp_max == 3, "form 1, HP full (3)");
        check(speed == 2 && damage == 1 && rgb == 3'b010, "form 1 table: spd 2 dmg 1 green");

        // ---------- sprint ----------
        sprint = 1; @(posedge clk); #1;
        check(speed == 3, "sprint on: speed 2 -> 3");
        sprint = 0; @(posedge clk); #1;
        check(speed == 2, "sprint off: speed back to 2");

        // ---------- timer 00:59 -> 01:00 ----------
        wait_ticks(60);
        check(tm(0) == 16'h0001, "timer 00:01 after 60 frames");
        wait_ticks(58 * 60);
        check(tm(0) == 16'h0059, "timer reaches 00:59");
        wait_ticks(60);
        check(tm(0) == 16'h0100, "timer rolls 00:59 -> 01:00");

        // ---------- evolve x3 ----------
        do_evolve;
        check(ev_ticks == 60, "EVOLVE #1 lasts exactly 60 frames");
        check(tog == 14 && vis > hid && hid > 0, "EVOLVE blink: 4 frames visible / 4 hidden (14 toggles)");
        check(state == PLAY && form == 1 && hp == 3 && hp == hp_max, "form 2, HP refilled to 3");
        check(speed == 2 && rgb == 3'b011, "form 2 table: spd 2 cyan");
        pulse_hit;                                   // 3 -> 2
        check(hp == 2, "take_hit: HP 3 -> 2");
        do_evolve;
        check(ev_ticks == 60, "EVOLVE #2 lasts exactly 60 frames");
        check(state == PLAY && form == 2 && hp == 4 && hp_max == 4, "form 3, HP refilled to 4");
        check(speed == 3 && damage == 2 && rgb == 3'b101, "form 3 table: spd 3 dmg 2 purple");
        do_evolve;
        check(ev_ticks == 60, "EVOLVE #3 lasts exactly 60 frames");
        check(state == PLAY && form == 3 && hp == 4, "form 4, HP 4");
        check(speed == 3 && damage == 2 && rgb == 3'b110, "form 4 table: spd 3 dmg 2 gold");
        sprint = 1; @(posedge clk); #1;
        check(speed == 4, "sprint form 4: speed 4");
        sprint = 0;
        pulse_item; wait_ticks(5);
        check(state == PLAY && form == 3, "got_item at form 4 ignored");

        // EVOLVE: white RGB + frozen + ไม่โดนตีระหว่างนั้น: ทดสอบด้วยร่างใหม่หลัง restart ด้านล่าง

        // ---------- timer outside play states stops ----------
        // ---------- FLOOR_CLEAR ----------
        nexts = 0; cl_ticks = 0;
        pulse_fdone;
        check(state == CLEAR && freeze, "floor_done -> FLOOR_CLEAR (frozen)");
        t_snap = tm(0);
        while (state == CLEAR) @(posedge clk);
        check(cl_ticks == 120, "FLOOR_CLEAR lasts exactly 120 frames");
        repeat (3) @(posedge clk);
        check(nexts == 1 && state == PLAY, "next_floor pulsed once, back to PLAY");
        check(tm(0) != t_snap, "timer runs during FLOOR_CLEAR");

        // ---------- GAME_OVER ----------
        pulse_hit; pulse_hit; pulse_hit;
        check(hp == 1 && state == PLAY, "HP 4 -> 1 after 3 hits (form 4 hp 4)");
        pulse_hit;
        check(hp == 0 && state == OVER && freeze, "HP 0 -> GAME_OVER");
        t_snap = tm(0);
        wait_ticks(150);
        check(tm(0) == t_snap, "timer stopped in GAME_OVER");
        pulse_btnc;
        check(state == TITLE, "BTNC in GAME_OVER -> TITLE");

        // ---------- second game: reset values, EVOLVE white, hits ignored while evolving ----------
        pulse_btnc;
        check(state == PLAY && form == 0 && hp == 3 && tm(0) == 16'h0000, "new game: form 1, HP 3, timer 00:00");
        pulse_item; @(posedge clk);
        check(state == EVOLVE && rgb == 3'b111 && freeze, "EVOLVE: RGB white, player frozen");
        pulse_hit;
        check(hp == 3, "take_hit ignored during EVOLVE");
        wait_ticks(70);
        check(state == PLAY && form == 1, "EVOLVE finished");

        // ---------- WIN ----------
        pulse_exit;
        check(state == WIN && freeze, "exit_evt -> WIN");
        t_snap = tm(0);
        wait_ticks(100);
        check(tm(0) == t_snap, "timer stopped in WIN");
        pulse_btnc;
        check(state == TITLE, "BTNC in WIN -> TITLE");
        pulse_btnc;
        check(state == PLAY, "TITLE -> PLAY again");

        // ---------- timer saturation 99:59 ----------
        dut.m_t = 9; dut.m_o = 9; dut.s_t = 5; dut.s_o = 9; dut.tick60 = 6'd58;
        wait_ticks(5);
        check(tm(0) == 16'h9959, "timer saturates at 99:59");
        wait_ticks(130);
        check(tm(0) == 16'h9959, "timer stays 99:59");

        // ---------- BTNC ใน PLAY ไม่ทำอะไร ----------
        pulse_btnc;
        check(state == PLAY && form == 0, "BTNC in PLAY does not change state/form");

        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
