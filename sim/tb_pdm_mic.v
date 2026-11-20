`timescale 1ns/1ps
// ทดสอบ pdm_mic.v ด้วยค่าจริง (M_CLK 2.5 MHz, หน้าต่าง 4096 sample, holdoff 200 ms = 20,000,000 clock)
//   เงียบ (สุ่ม ~50% ones) -> ไม่มี clap · เสียงดัง (~90% ones) -> clap 1 ครั้ง
//   ดังอีกครั้งภายใน 200 ms -> ไม่มี · หลัง 200 ms -> clap อีกครั้ง
// รัน: ./scripts/run_sim.sh mic
module tb_pdm_mic;
    `include "params.vh"
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;
    reg loud = 0;
    reg [31:0] rnd = 32'h1234_5678;
    reg m_data = 0;
    wire m_clk, m_lrsel, clap;
    wire [11:0] amp;
    integer claps = 0, errors = 0, checks = 0;
    integer max_quiet = 0;
    real t_first, t_second;

    pdm_mic #(.CLK_DIV(MIC_CLK_DIV), .WINDOW(MIC_WINDOW), .TH(MIC_TH), .HOLDOFF(MIC_HOLDOFF)) dut (
        .clk(clk), .rst(rst), .m_clk(m_clk), .m_data(m_data), .m_lrsel(m_lrsel), .clap_pulse(clap), .amplitude(amp),
        .win_pulse(), .holdoff(), .th_dyn(12'd0), .use_dyn(1'b0));

    // ไมค์จำลอง: เปลี่ยน bit ที่ขอบขาลงของ M_CLK (ADMP421 ช่องซ้าย) ความน่าจะเป็น 50% หรือ 90%
    // W4: a REAL microphone signal is AC: first order sigma-delta of 0.5 + 0.45 * sin(2 pi 2 kHz t) when loud, exactly 0.5 (bits 0101..) when quiet.
    // (the old test fed a DC-biased 90 % stream, which hid that the detector could not see a real sound)
    real acc = 0.0, tt = 0.0, xin;
    always @(negedge m_clk) begin
        tt = tt + 0.4e-6;                                   // one M_CLK period = 0.4 us
        xin = loud ? (0.5 + 0.45 * $sin(6.2831853 * 2000.0 * tt)) : 0.5;
        acc = acc + xin;
        if (acc >= 1.0) begin acc = acc - 1.0; m_data <= 1'b1; end else m_data <= 1'b0;
    end
    always @(posedge clk) begin
        if (clap) begin
            claps = claps + 1;
            $display("      clap at %0.3f ms (amplitude %0d)", $realtime / 1e6, amp);
        end
        if (!loud && amp > max_quiet && $realtime > 5e6) max_quiet = amp;
    end

    task check(input cond, input [8*80-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin $display("FAIL  %0s  (claps=%0d)", msg, claps); errors = errors + 1; end
    end endtask
    task ms(input integer n); integer q; begin for (q = 0; q < n; q = q + 1) #1_000_000; end endtask

    initial begin
        #100 rst = 0;
        check(m_lrsel == 0, "M_LRSEL = 0 (left channel)");
        ms(30);
        check(claps == 0, "30 ms of silence: no clap");
        $display("      max amplitude while quiet = %0d (TH = %0d)", max_quiet, MIC_TH);
        loud = 1; ms(100); loud = 0;               // ตบมือ 100 ms
        check(claps == 1, "loud burst (100 ms): exactly one clap_pulse");
        ms(20);
        loud = 1; ms(30); loud = 0;                // ตบมือซ้ำ ~150 ms หลังครั้งแรก (ยังอยู่ใน 200 ms)
        check(claps == 1, "second burst inside 200 ms: ignored");
        ms(120);                                   // พ้น 200 ms แล้ว
        loud = 1; ms(30); loud = 0;
        check(claps == 2, "burst after 200 ms: another clap_pulse");
        ms(10);
        check(claps == 2, "back to silence: no extra clap");
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
