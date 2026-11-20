`timescale 1ns/1ps
// ทดสอบ parameter DEBUG ของ top.v: สวิตช์ debug (SW0 SW1 SW2 SW3 SW4) ทำงานเฉพาะ DEBUG = 1, SW13 ทำงานเสมอ
// รัน: ./scripts/run_sim.sh debug
module tb_debug;
    reg clk = 0; always #5 clk = ~clk;
    reg rstn = 0;
    reg [15:0] SW = 0;
    integer errors = 0, checks = 0;
    integer r1 [0:4];   // นับ pulse ของ DEBUG = 1: sw1 sw2 sw3 sw4 sw13
    integer r0 [0:4];   // DEBUG = 0

    top #(.DEBOUNCE(4), .DEBUG(1), .PROLOGUE(0)) d1 (.ACL_MISO(1'b0), .CLK100MHZ(clk), .CPU_RESETN(rstn), .BTNC(1'b0), .BTNU(1'b0), .BTND(1'b0),
        .BTNL(1'b0), .BTNR(1'b0), .SW(SW), .LED(), .LED16_R(), .LED16_G(), .LED16_B(), .LED17_R(), .LED17_G(), .LED17_B(),
        .CA(), .CB(), .CC(), .CD(), .CE(), .CF(), .CG(), .DP(), .AN(), .VGA_R(), .VGA_G(), .VGA_B(), .VGA_HS(), .VGA_VS(),
        .AUD_PWM(), .AUD_SD(), .M_CLK(), .M_DATA(1'b0), .M_LRSEL());
    top #(.DEBOUNCE(4), .DEBUG(0), .PROLOGUE(0)) d0 (.ACL_MISO(1'b0), .CLK100MHZ(clk), .CPU_RESETN(rstn), .BTNC(1'b0), .BTNU(1'b0), .BTND(1'b0),
        .BTNL(1'b0), .BTNR(1'b0), .SW(SW), .LED(), .LED16_R(), .LED16_G(), .LED16_B(), .LED17_R(), .LED17_G(), .LED17_B(),
        .CA(), .CB(), .CC(), .CD(), .CE(), .CF(), .CG(), .DP(), .AN(), .VGA_R(), .VGA_G(), .VGA_B(), .VGA_HS(), .VGA_VS(),
        .AUD_PWM(), .AUD_SD(), .M_CLK(), .M_DATA(1'b0), .M_LRSEL());

    integer t;
    initial for (t = 0; t < 5; t = t + 1) begin r1[t] = 0; r0[t] = 0; end
    always @(posedge clk) begin
        if (d1.sw1_rise) r1[0] = r1[0] + 1;  if (d0.sw1_rise) r0[0] = r0[0] + 1;
        if (d1.sw2_rise) r1[1] = r1[1] + 1;  if (d0.sw2_rise) r0[1] = r0[1] + 1;
        if (d1.sw3_rise) r1[2] = r1[2] + 1;  if (d0.sw3_rise) r0[2] = r0[2] + 1;
        if (d1.sw4_rise) r1[3] = r1[3] + 1;  if (d0.sw4_rise) r0[3] = r0[3] + 1;
        if (d1.sw13_rise) r1[4] = r1[4] + 1; if (d0.sw13_rise) r0[4] = r0[4] + 1;
    end

    task check(input cond, input [8*80-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin $display("FAIL  %0s", msg); errors = errors + 1; end
    end endtask
    task toggle(input integer b); begin
        SW[b] = 1; repeat (40) @(posedge clk); SW[b] = 0; repeat (40) @(posedge clk);
    end endtask

    initial begin
        repeat (10) @(posedge clk); rstn = 1; repeat (10) @(posedge clk);
        toggle(1); toggle(2); toggle(3); toggle(4); toggle(13);
        check(r1[0] == 1 && r1[1] == 1 && r1[2] == 1 && r1[3] == 1, "DEBUG = 1: SW1 SW2 SW3 SW4 give one pulse each");
        check(r0[0] == 0 && r0[1] == 0 && r0[2] == 0 && r0[3] == 0, "DEBUG = 0: SW1 SW2 SW3 SW4 do nothing");
        check(r1[4] == 1 && r0[4] == 1, "SW13 (box reset) works in both builds");
        SW[0] = 1; repeat (5) @(posedge clk);
        check(d1.open_L == 1 && d0.open_L == 0, "SW0 opens the boss door only when DEBUG = 1");
        SW[0] = 0;
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
