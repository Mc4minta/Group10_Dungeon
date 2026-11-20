`timescale 1ns/1ps
// W22: PS/2 keyboard receiver (rtl/ps2_kbd.v). The testbench plays the keyboard: it sends scan code set 2 frames (start, 8 data bits LSB first,
// odd parity, stop) with a ~12 kHz clock, and checks the held levels / pulses.   Run: ./scripts/run_sim.sh ps2
module tb_ps2;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;                              // 100 MHz
    reg pc = 1, pd = 1;
    wire up, down, left, right, atk, sprint, pause_p, lock_p, reset_p, clap_p, got_key;
    ps2_kbd #(.TIMEOUT(20_000)) dut (.clk(clk), .rst(rst), .ps2_clk(pc), .ps2_data(pd), .up(up), .down(down), .left(left), .right(right),
                                     .atk(atk), .sprint(sprint), .pause_p(pause_p), .lock_p(lock_p), .reset_p(reset_p), .clap_p(clap_p), .got_key(got_key));
    integer errors = 0, checks = 0, np = 0, nl = 0, nr = 0, nc = 0;
    always @(posedge clk) begin
        if (pause_p) np = np + 1;
        if (lock_p)  nl = nl + 1;
        if (reset_p) nr = nr + 1;
        if (clap_p)  nc = nc + 1;
    end
    task check(input cond, input [8*80-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg); else begin $display("FAIL  %0s", msg); errors = errors + 1; end
    end endtask
    // one PS/2 bit: data set while the clock is high, then the clock falls (bit valid) and rises again
    task bitx(input b); begin
        pd = b; #20000; pc = 0; #40000; pc = 1; #20000;
    end endtask
    task send_raw(input [7:0] c, input badpar, input badstop); integer i; begin
        bitx(1'b0);                                    // start
        for (i = 0; i < 8; i = i + 1) bitx(c[i]);
        bitx(badpar ? (^c) : ~(^c));                   // odd parity
        bitx(badstop ? 1'b0 : 1'b1);                   // stop
        pd = 1; #50000;
    end endtask
    task send(input [7:0] c); begin send_raw(c, 1'b0, 1'b0); end endtask
    task make(input [7:0] c);      begin send(c); end endtask
    task release_k(input [7:0] c); begin send(8'hF0); send(c); end endtask
    task make_e(input [7:0] c);      begin send(8'hE0); send(c); end endtask
    task release_e(input [7:0] c);   begin send(8'hE0); send(8'hF0); send(c); end endtask
    initial begin
        #200 rst = 0; #200;
        check(!up && !down && !left && !right && !atk && !sprint, "idle: nothing held");
        // WASD
        make(8'h1D); check(up && !down, "W held = up");
        make(8'h1C); check(up && left, "W + A = diagonal up-left");
        release_k(8'h1D); check(!up && left, "release W: only left");
        release_k(8'h1C); check(!left, "release A: idle");
        make(8'h1B); make(8'h23); check(down && right, "S + D = down-right");
        release_k(8'h1B); release_k(8'h23);
        // arrows (E0 prefix)
        make_e(8'h75); check(up, "arrow up (E0 75)");
        make_e(8'h6B); check(left, "arrow left (E0 6B)");
        release_e(8'h75); release_e(8'h6B); check(!up && !left, "arrows released (E0 F0 code)");
        make_e(8'h72); make_e(8'h74); check(down && right, "arrow down + right");
        release_e(8'h72); release_e(8'h74);
        // numpad 8 (no E0) must not move
        make(8'h75); check(!up, "keypad 8 (75 without E0) is ignored");
        release_k(8'h75);
        // attack / sprint
        make(8'h29); check(atk, "Space = attack");
        release_k(8'h29); check(!atk, "Space released");
        make(8'h3B); check(atk, "J = attack"); release_k(8'h3B);
        make(8'h5A); check(atk, "Enter = attack / start"); release_k(8'h5A); check(!atk, "Enter released");
        make(8'h12); check(sprint, "Left Shift = sprint"); release_k(8'h12); check(!sprint, "Shift released");
        // two keys at once + typematic repeats (the same make again) stay held
        make(8'h29); make(8'h1D); make(8'h29); make(8'h29);
        check(atk && up, "Space + W together, repeated makes keep them held");
        release_k(8'h29); release_k(8'h1D);
        // pulse keys: one pulse per press, repeats do not pulse again
        np = 0; nl = 0; nr = 0; nc = 0;
        make(8'h4D); make(8'h4D); make(8'h4D); check(np == 1, "P: one pause pulse for a held key (repeats ignored)");
        release_k(8'h4D); make(8'h4D); check(np == 2, "P again after release: second pulse");
        release_k(8'h4D);
        make(8'h76); check(np == 3, "Esc = pause pulse"); release_k(8'h76);
        make(8'h4B); check(nl == 1, "L = auto-lock pulse"); release_k(8'h4B);
        make(8'h2D); check(nr == 1, "R = reset pulse"); release_k(8'h2D);
        make(8'h21); check(nc == 1, "C = clap pulse"); release_k(8'h21);
        // bad frames are dropped: wrong parity, wrong stop bit
        send_raw(8'h1D, 1'b1, 1'b0); check(!up, "wrong parity: frame ignored");
        send_raw(8'h1D, 1'b0, 1'b1); check(!up, "wrong stop bit: frame ignored");
        make(8'h1D); check(up, "a good frame still works after bad ones"); release_k(8'h1D);
        // a half frame (clock stops) times out and the next frame is read cleanly
        bitx(1'b0); bitx(1'b1); bitx(1'b1); bitx(1'b0);       // 4 bits then silence
        #(20_000 * 10 + 400000);                               // longer than TIMEOUT
        make(8'h1D); check(up, "after a stalled half frame the next frame is received");
        // reset clears everything
        rst = 1; #100; rst = 0; #100;
        check(!up && !atk && !sprint, "reset clears the held keys");
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
