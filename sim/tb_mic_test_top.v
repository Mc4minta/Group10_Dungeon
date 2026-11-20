`timescale 1ns/1ps
// ทดสอบ mic_test_top.v: amplitude / LED bar / peak hold / BTNC ล้าง peak / ตัวนับตบมือ + BTND / TH จากสวิตช์ / TH_DEFAULT
// (holdoff สั้นลงเหลือ 12 หน้าต่างเพื่อให้เทสต์เร็ว; ตัว pdm_mic เองทดสอบด้วยค่าจริงใน tb_pdm_mic)
// รัน: ./scripts/run_sim.sh mictop
module tb_mic_test_top;
    reg clk = 0; always #5 clk = ~clk;
    reg BTNC = 0, BTND = 0; reg [15:0] SW = 0;
    reg [1:0] mode = 0;                  // 0 เงียบ, 1 เสียงดัง
    reg [31:0] rnd = 32'hC0FFEE01;
    real acc = 0.0, tt = 0.0, xin;
    reg m_data = 0;
    wire [15:0] LED; wire LED16_G, LED17_R; wire CA, CB, CC, CD, CE, CF, CG, DP; wire [7:0] AN;
    wire M_CLK, M_LRSEL;

    localparam WIN = 4096 * 40;          // clock ต่อหน้าต่าง
    mic_test_top #(.DEBOUNCE(4), .HOLDOFF(WIN * 12), .FLASH(WIN * 2)) dut (
        .CLK100MHZ(clk), .BTNC(BTNC), .BTND(BTND), .SW(SW), .LED(LED), .LED16_G(LED16_G), .LED17_R(LED17_R),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD), .CE(CE), .CF(CF), .CG(CG), .DP(DP), .AN(AN),
        .M_CLK(M_CLK), .M_DATA(m_data), .M_LRSEL(M_LRSEL));

    always @(negedge M_CLK) begin
        rnd = rnd ^ (rnd << 13); rnd = rnd ^ (rnd >> 17); rnd = rnd ^ (rnd << 5);
        // W4: AC microphone model (first order sigma-delta of a 2 kHz tone when loud, exactly 0.5 when quiet) instead of a DC-biased stream
        tt = tt + 0.4e-6; xin = (mode == 1) ? (0.5 + 0.45 * $sin(6.2831853 * 2000.0 * tt)) : 0.5;
        acc = acc + xin;
        if (acc >= 1.0) begin acc = acc - 1.0; m_data <= 1'b1; end else m_data <= 1'b0;
    end

    integer errors = 0, checks = 0, claps_seen = 0;
    always @(posedge clk) if (dut.clap) claps_seen = claps_seen + 1;
    task check(input cond, input [8*88-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin $display("FAIL  %0s  (amp=%0d peak=%0d claps=%0d)", msg, dut.amp, dut.peak, dut.claps); errors = errors + 1; end
    end endtask
    task wins(input integer n); integer q; begin for (q = 0; q < n; q = q + 1) @(posedge dut.win); repeat (60) @(posedge clk); end endtask
    function [15:0] dec(input [11:0] v); reg [3:0] a0, a1, a2, a3; begin
        a3 = (v / 1000) % 10; a2 = (v / 100) % 10; a1 = (v / 10) % 10; a0 = v % 10; dec = {a3, a2, a1, a0}; end endfunction
    task press(input integer which); begin   // 0 = BTNC, 1 = BTND (กดค้าง), 2 = BTNC ขณะ BTND
        if (which == 0) begin BTNC = 1; repeat (40) @(posedge clk); BTNC = 0; repeat (40) @(posedge clk); end
    end endtask

    integer old_peak;
    initial begin
        repeat (20) @(posedge clk);
        mode = 0; wins(6);
        check(dut.amp < 200 && claps_seen == 0 && dut.claps == 0, "silence: small amplitude, no clap");
        check(dut.peak < 200 && dut.peak + 100 >= dut.amp, "peak follows the quiet noise floor");
        check(LED[15:11] == 0, "LED bar: upper LEDs off in silence");
        check(!LED17_R, "RGB17 (holdoff) off");
        // ตบมือ
        mode = 1; wins(5);
        check(dut.amp > 1000 && LED[8] && LED[9], "loud: amplitude > 1000, LED bar lights up to the 512/640 steps");
        check(dut.bcd_amp == dec(dut.amp), "left 4 digits show the amplitude in decimal (BCD matches)");
        check(claps_seen == 1 && dut.claps == 1, "one clap counted (TH_DEFAULT = 600, holdoff blocks the rest)");
        check(LED17_R || dut.holdoff, "holdoff active after the clap (RGB17)");
        old_peak = dut.peak;
        check(old_peak > 1000, "peak captured the loud level");
        mode = 0; wins(4);
        check(dut.peak == old_peak && dut.amp < 200, "peak holds after the sound stops");
        check(!LED16_G || dut.fl != 0, "RGB16 flash follows clap_pulse");
        // BTNC ล้าง peak
        press(0); wins(3);
        check(dut.peak < 200, "BTNC clears the peak (then follows the quiet floor)");
        // ตัวนับ + BTND
        BTND = 1; repeat (60) @(posedge clk); wins(1);
        check(dut.right == 16'h0001, "BTND held: right 4 digits show the clap count = 1");
        // BTNC + BTND พร้อมกัน = ล้างตัวนับ
        BTNC = 1; repeat (40) @(posedge clk); BTNC = 0; repeat (40) @(posedge clk); wins(1);
        check(dut.claps == 0 && dut.right == 16'h0000, "BTNC while BTND: clap counter cleared");
        BTND = 0; wins(10);                          // พ้น holdoff
        // TH จากสวิตช์: สูงเกินไป = ไม่นับ
        SW[10:0] = 11'd1900; mode = 1; wins(3);
        check(dut.th == 12'd1900 && dut.claps == 0, "SW[10:0] = 1900: burst below threshold is not counted");
        mode = 0; wins(14);
        // TH ต่ำพอ = นับ
        SW[10:0] = 11'd1000; mode = 1; wins(3);
        check(dut.th == 12'd1000 && dut.claps == 1, "SW[10:0] = 1000: same burst now counts");
        mode = 0; wins(2);
        SW[10:0] = 11'd0; repeat (10) @(posedge clk);
        check(dut.th == 12'd600, "all switches down: TH_DEFAULT (600) is used");
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
