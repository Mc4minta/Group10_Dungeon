`timescale 1ns/1ps
// W16: dialog.v with the real mem/dlg.mem + rtl/dlg_cfg.vh generated from docs/STORY.md:
// blocking message (BTNC to continue), timed message (disappears), after:<ID> chains, "once per game", waits while en = 0, restart forgets.
// Run: ./scripts/run_sim.sh dialog
module tb_dialog;
    `include "params.vh"
    `include "dlg_cfg.vh"
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1, restart = 0, en = 1, advance = 0, tick = 0;
    reg [63:0] ev = 64'd0;
    wire show, block; wire [11:0] b0, b1; wire [4:0] n0, n1; wire [1:0] spk;
    dialog dut (.clk(clk), .rst(rst), .restart(restart), .frame_tick(tick), .en(en), .ev(ev), .advance(advance),
                .show(show), .block(block), .b0(b0), .b1(b1), .n0(n0), .n1(n1), .spk(spk));
    reg [5:0] txt [0:4095];
    initial $readmemh("text.mem", txt);
    integer errors = 0, checks = 0;
    task check(input cond, input [8*88-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg); else begin $display("FAIL  %0s  (show=%b block=%b n0=%0d spk=%0d)", msg, show, block, n0, spk); errors = errors + 1; end
    end endtask
    function [7:0] ch(input [5:0] c);
        ch = (c < 10) ? "0" + c : (c < 36) ? "A" + (c - 10) : (c == 36) ? " " : (c == 37) ? "-" : (c == 38) ? ":" : (c == 39) ? "!" : ".";
    endfunction
    // text of line 1 as a string (up to 20 chars, left aligned in a 160-bit vector)
    reg [8*20-1:0] s0; integer k;
    task read0; begin s0 = 0; for (k = 0; k < n0; k = k + 1) s0 = s0 | (ch(txt[b0 + k]) << (8 * (19 - k))); end endtask
    task pulse(input integer e); begin @(posedge clk) ev[e] <= 1; @(posedge clk) ev[e] <= 0; repeat (NDLG + 4) @(posedge clk); end endtask
    task press; begin @(posedge clk) advance <= 1; @(posedge clk) advance <= 0; repeat (NDLG + 4) @(posedge clk); end endtask
    task ticks(input integer n); integer q; begin for (q = 0; q < n; q = q + 1) begin @(posedge clk) tick <= 1; @(posedge clk) tick <= 0; repeat (2) @(posedge clk); end end endtask
    initial begin
        repeat (4) @(posedge clk); rst <= 0; repeat (4) @(posedge clk);
        check(!show && !block, "nothing shown at the start");
        // ---- start: F1-01 is blocking (Player = white) ----
        pulse(EV_START);
        read0;
        check(show && block && spk == 2'd0, "event start -> F1-01 appears, blocking, speaker Player");
        check(s0 >> (8 * (20 - 17)) == "GASP! WHERE AM I!", "F1-01 text is read from the text ROM");
        check(n1 == 5'd19, "line 2 length = 19 (WHAT IS THIS PLACE!)");
        ticks(400);
        check(show && block, "a blocking message waits for BTNC (no timeout)");
        press;
        check(!show && !block, "BTNC closes it");
        pulse(EV_START);
        check(!show, "each message is shown once per game");
        // ---- timed message, then a blocking chain ----
        pulse(EV_FIRST_ATTACK);
        read0;
        check(show && !block && s0 >> (8 * (20 - 18)) == "I DONT GET IT YET.", "first_attack -> F1-02, timed (not blocking)");
        ticks(DLG_FRAMES - 3);
        check(show, "still shown just before DLG_FRAMES");
        ticks(6);
        read0;
        check(show && block && s0 >> (8 * (20 - 11)) == "BRAVE HERO!" && spk == 2'd1, "F1-02 ends -> its chain F1-03 (after:F1-02!) appears, blocking, speaker Voice");
        press; read0;
        check(show && block && s0 >> (8 * (20 - 15)) == "YOU MEAN... ME!", "BTNC -> F1-04 (Player)");
        press; press; press; press; press; press; press; press;
        read0;
        check(show && block && s0 >> (8 * (20 - 18)) == "FIGHT. SOLVE. WIN." , "the chain reaches F1-12");
        press;
        check(!show, "chain finished");
        // ---- en = 0: pending messages wait ----
        en = 0;
        pulse(EV_LOCK_F1C1);
        check(!show, "en = 0: nothing is shown");
        ticks(5);
        en = 1; repeat (NDLG + 6) @(posedge clk); read0;
        check(show && !block && s0 >> (8 * (20 - 12)) == "SPIKES ROSE!" && spk == 2'd2, "en = 1: the waiting F1-13 appears (System = cyan code 2)");
        ticks(DLG_FRAMES + 3);
        check(!show, "timed message gone");
        // ---- two events at once are queued, shown one after the other ----
        @(posedge clk) begin ev[EV_CLEAR_F1C1] <= 1; ev[EV_LOCK_F1C2] <= 1; end @(posedge clk) ev <= 64'd0;
        repeat (NDLG + 6) @(posedge clk);
        check(show, "a message appears");
        ticks(DLG_FRAMES + 3);
        check(show, "the second queued message follows the first");
        ticks(DLG_FRAMES + 3);
        check(!show, "queue empty");
        // ---- new game forgets ----
        @(posedge clk) restart <= 1; @(posedge clk) restart <= 0; repeat (4) @(posedge clk);
        pulse(EV_START);
        check(show && block, "after restart F1-01 can appear again");
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
