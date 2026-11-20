`timescale 1ns/1ps
// W7: maze.v: start tile, button control, wall stops (the ball box never overlaps a wall tile), goal pulse, tilt control with calibration + dead zone.
// Uses the real mem/maze.mem. Run: ./scripts/run_sim.sh maze
module tb_maze;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;
    reg tick = 0; integer tc = 0;
    always @(posedge clk) begin tc <= (tc == 79) ? 0 : tc + 1; tick <= (tc == 79); end
    reg start = 0, run = 1, use_btn = 1, bu = 0, bd = 0, bl = 0, br = 0, sample_valid = 0;
    reg signed [7:0] ax = 0, ay = 0;
    wire [9:0] bx, by; wire goal;
    maze dut (.clk(clk), .rst(rst), .frame_tick(tick), .run(run), .start(start), .ax(ax), .ay(ay), .sample_valid(sample_valid),
              .use_btn(use_btn), .bu(bu), .bd(bd), .bl(bl), .br(br), .bx(bx), .by(by), .goal(goal));

    reg [1:0] mz [0:511];
    initial $readmemh("maze.mem", mz);
    function wall(input [9:0] x, input [9:0] y); wall = (mz[(y / 32) * 20 + (x / 32)] == 2'd1); endfunction
    integer errors = 0, checks = 0, inwall = 0, goals = 0;
    task check(input cond, input [8*88-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg); else begin $display("FAIL  %0s  (ball at %0d,%0d)", msg, bx, by); errors = errors + 1; end
    end endtask
    always @(posedge clk) begin
        if (wall(bx, by) || wall(bx + 19, by) || wall(bx, by + 19) || wall(bx + 19, by + 19)) inwall = inwall + 1;
        if (goal) goals = goals + 1;
    end
    task frames(input integer n); integer q; begin for (q = 0; q < n; q = q + 1) @(posedge tick); repeat (40) @(posedge clk); end endtask
    task do_start; begin @(posedge clk) start <= 1; @(posedge clk) start <= 0; repeat (4) @(posedge clk); end endtask
    task sample(input signed [7:0] x, input signed [7:0] y); begin
        @(posedge clk) begin ax <= x; ay <= y; sample_valid <= 1; end @(posedge clk) sample_valid <= 0; repeat (4) @(posedge clk);
    end endtask
    integer k, x0, y0;
    initial begin
        repeat (5) @(posedge clk); rst <= 0; repeat (5) @(posedge clk);
        do_start;
        check(bx == 38 && by == 38, "start: ball box on the start tile (1,1), centred");
        // ---- buttons: right along row 1 stops at the wall of tile 2 ----
        br = 1; frames(80); br = 0;
        check(bx == 44 && by == 38, "right: the ball rolls to the wall (x = 2*32 - 20 = 44) and stops");
        frames(30);
        check(bx == 44, "friction / wall: it stays there");
        // ---- down column 1 until the wall below row 7 ----
        bl = 1; frames(40); bl = 0;
        check(bx == 32, "left: back against the wall of tile 0 (x = 32)");
        bd = 1; frames(120); bd = 0;
        check(by == 236, "down: stops on the wall of row 8 (y = 8*32 - 20 = 236)");
        check(inwall == 0, "the ball box never overlapped a wall tile (checked every clock so far)");
        // ---- goal ----
        do_start;
        force dut.px16 = (17 * 32 + 6) * 16; force dut.py16 = (13 * 32 + 6) * 16;
        repeat (4) @(posedge clk); release dut.px16; release dut.py16;
        goals = 0; frames(3);
        check(goals >= 1, "ball centre on the goal tile -> goal pulse");
        do_start; goals = 0; frames(5);
        check(goals == 0, "no goal on the start tile");
        // ---- tilt: calibration with a constant offset, then flat = no movement ----
        use_btn = 0;
        do_start;
        for (k = 0; k < 32; k = k + 1) sample(8'sd50, -8'sd20);
        for (k = 0; k < 10; k = k + 1) begin sample(8'sd51, -8'sd21); frames(1); end
        check(bx == 38 && by == 38, "tilt: the calibrated offset and the dead zone keep a flat board still (+-1 count)");
        // tilt right: +40 counts -> accelerates right
        for (k = 0; k < 6; k = k + 1) begin sample(8'sd90, -8'sd20); frames(1); end
        check(bx > 38, "tilt right (+40 counts): the ball rolls right");
        x0 = bx;
        for (k = 0; k < 30; k = k + 1) begin sample(8'sd50, -8'sd20); frames(1); end
        check(bx >= x0 && bx <= 44, "back to flat: it coasts to a stop (no wall crossing)");
        // tilt down from a fresh start (needs the corridor below the start tile)
        do_start;
        for (k = 0; k < 32; k = k + 1) sample(8'sd0, 8'sd0);
        for (k = 0; k < 30; k = k + 1) begin sample(8'sd0, 8'sd48); frames(1); end
        check(by > 100, "tilt (Y +48): the ball rolls down the corridor");
        check(inwall == 0, "still never inside a wall");
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
