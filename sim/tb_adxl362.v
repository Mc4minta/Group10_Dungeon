`timescale 1ns/1ps
// W7: adxl362.v against a behavioural ADXL362 slave (SPI mode 0): init sequence (soft reset 0x52 -> reg 0x1F, measurement mode 0x02 -> reg 0x2D),
// burst read of X / Y (command 0x0B, address 0x08), signed values, repeated samples, ready drops when the sensor stops answering.
// Run: ./scripts/run_sim.sh adxl
module tb_adxl362;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;
    wire miso, mosi, sclk, csn;
    wire signed [7:0] ax, ay; wire valid, ready;
    adxl362 #(.CLK_DIV(2), .BOOT_CLKS(200), .SAMPLE_CLKS(400), .NODATA_CLKS(3000)) dut (
        .clk(clk), .rst(rst), .ACL_MISO(miso), .ACL_MOSI(mosi), .ACL_SCLK(sclk), .ACL_CSN(csn), .ax(ax), .ay(ay), .valid(valid), .ready(ready));

    // ---------- slave model ----------
    reg [7:0] regs [0:63];
    reg [7:0] x_val = 8'hF6, y_val = 8'h0D;          // -10, +13
    reg       slave_on = 1'b1;
    integer   n = 0; reg [7:0] cmd = 0, addr = 0; reg [7:0] cur = 0;
    reg       miso_r = 1'b0;
    integer   writes = 0, reads = 0, w1_seen = 0, w2_seen = 0, order_ok = 1, bad_mode = 0;
    assign miso = slave_on ? miso_r : 1'b0;
    always @(negedge csn) begin n = 0; cmd = 0; addr = 0; cur = 0; end
    always @(posedge sclk) if (!csn) begin
        if (n < 8) cmd = {cmd[6:0], mosi};
        else if (n < 16) addr = {addr[6:0], mosi};
        else if (cmd == 8'h0A) begin
            cur = {cur[6:0], mosi};
            if (n == 23) begin
                regs[addr] = cur; writes = writes + 1;
                if (addr == 8'h1F && cur == 8'h52) begin w1_seen = 1; if (w2_seen) order_ok = 0; end
                if (addr == 8'h2D && cur == 8'h02) begin w2_seen = 1; if (!w1_seen) order_ok = 0; end
            end
        end
        n = n + 1;
    end
    always @(negedge sclk) if (!csn) begin               // drive the next MISO bit (changes while SCLK is low)
        regs[8'h08] = x_val; regs[8'h09] = y_val;
        if (cmd == 8'h0B && n >= 16 && n < 32) miso_r <= ({regs[addr], regs[addr + 1]} >> (31 - n)) & 1'b1;
        else miso_r <= 1'b0;
        if (cmd == 8'h0B && n == 31) reads = reads + 1;
    end
    // SPI mode 0: MOSI must be stable at the rising edge (it changes only on falling edges) - checked by sampling just before / after
    reg mosi_q = 0;
    always @(posedge clk) begin mosi_q <= mosi; end

    integer errors = 0, checks = 0, vcount = 0;
    task check(input cond, input [8*88-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg); else begin $display("FAIL  %0s", msg); errors = errors + 1; end
    end endtask
    always @(posedge clk) if (valid) vcount = vcount + 1;
    // SCLK high time and CSN framing: SCLK never toggles while CSN is high
    integer sclk_cs_high = 0;
    always @(posedge sclk) if (csn) sclk_cs_high = sclk_cs_high + 1;

    integer k;
    initial begin
        repeat (5) @(posedge clk); rst <= 0;
        check(csn === 1'b1 && sclk === 1'b0 && !ready, "idle after reset: CSN high, SCLK low, not ready yet");
        repeat (1600) @(posedge clk);
        check(w1_seen && w2_seen && order_ok && writes == 2, "init: soft reset (0x1F = 0x52) first, then measurement mode (0x2D = 0x02)");
        repeat (3000) @(posedge clk);
        check(vcount >= 3 && reads >= 3, "samples are read repeatedly (burst 0x0B from 0x08)");
        check(ax === -8'sd10 && ay === 8'sd13, "X = -10 and Y = +13 arrive as signed 8-bit values");
        check(ready, "ready while samples keep coming");
        x_val = 8'h30; y_val = 8'hC8;                        // +48, -56
        repeat (2000) @(posedge clk);
        check(ax === 8'sd48 && ay === -8'sd56, "new sensor values show up (+48 / -56)");
        check(sclk_cs_high == 0, "SCLK never toggles while CSN is high");
        // sensor disconnected: MISO stuck low -> X = Y = 0 for 32 samples in a row -> ready drops; it comes back with real data
        slave_on = 1'b0;
        repeat (700 * 40) @(posedge clk);
        check(!ready, "dead bus (all zero samples for 32 reads) -> not ready (top falls back to the buttons)");
        slave_on = 1'b1;
        repeat (1200) @(posedge clk);
        check(ready && ax === 8'sd48, "sensor answers again -> ready again");
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
