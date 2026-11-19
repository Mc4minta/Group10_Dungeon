`timescale 1ns/1ps
// face_lock: lock is high for FRAMES frame_ticks after a press, a new press restarts it, FRAMES = 0 disables it.
// Run: ./scripts/run_sim.sh facelock
module tb_facelock;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1, tick = 0, press = 0;
    wire l24, l0;
    face_lock #(24) d24 (.clk(clk), .rst(rst), .frame_tick(tick), .press(press), .lock(l24));
    face_lock #(0)  d0  (.clk(clk), .rst(rst), .frame_tick(tick), .press(press), .lock(l0));
    integer errors = 0, i, n;
    task frames(input integer k); integer q; begin
        for (q = 0; q < k; q = q + 1) begin @(posedge clk) tick <= 1; @(posedge clk) tick <= 0; repeat (3) @(posedge clk); end
    end endtask
    task chk(input cond, input [255:0] msg); begin
        if (!cond) begin $display("FAIL %0s", msg); errors = errors + 1; end else $display("PASS %0s", msg);
    end endtask
    initial begin
        repeat (4) @(posedge clk); rst <= 0; repeat (2) @(posedge clk);
        chk(l24 == 0, "idle: no lock");
        @(posedge clk) press <= 1; @(posedge clk) press <= 0; @(posedge clk);
        chk(l24 == 1, "press -> lock");
        chk(l0 == 0, "FRAMES=0: never locks");
        frames(23); chk(l24 == 1, "still locked after 23 frames");
        frames(1);  chk(l24 == 0, "released after 24 frames");
        @(posedge clk) press <= 1; @(posedge clk) press <= 0; frames(20);
        @(posedge clk) press <= 1; @(posedge clk) press <= 0; frames(20);
        chk(l24 == 1, "second press restarts the window");
        frames(5);  chk(l24 == 0, "released 24 frames after the second press");
        $display("checks done  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
