`timescale 1ns/1ps
// จำลองทั้งระบบแล้วบันทึกภาพจาก VGA ออกเป็น .ppm (เปิดดูด้วยโปรแกรมภาพ หรือแปลง PNG)
// รัน: cd mem && iverilog -g2012 -o ../sim/tb_top.vvp ../sim/tb_top.v ../rtl/*.v && vvp ../sim/tb_top.vvp
module tb_top;
    reg clk = 0; always #5 clk = ~clk;
    reg rstn = 0;
    reg BTNC = 0, BTNU = 0, BTND = 0, BTNL = 0, BTNR = 0;
    reg [15:0] SW = 0;
    wire [3:0] R, G, B; wire HS, VS;
    top #(.DEBOUNCE(4)) dut (.CLK100MHZ(clk), .CPU_RESETN(rstn), .BTNC(BTNC), .BTNU(BTNU), .BTND(BTND),
        .BTNL(BTNL), .BTNR(BTNR), .SW(SW), .LED(), .LED16_R(), .LED16_G(), .LED16_B(),
        .LED17_R(), .LED17_G(), .LED17_B(), .CA(), .CB(), .CC(), .CD(), .CE(), .CF(), .CG(), .DP(), .AN(),
        .VGA_R(R), .VGA_G(G), .VGA_B(B), .VGA_HS(HS), .VGA_VS(VS), .AUD_PWM(), .AUD_SD());

    reg [11:0] img [0:640*480-1];
    reg [9:0] h0, v0; reg act0, cap = 0;
    integer hs_low = 0, hs_len = 0, f, i;

    always @(posedge clk) if (dut.ce) begin h0 <= dut.hcount; v0 <= dut.vcount; act0 <= dut.active; end
    // ค่า VGA ที่ register ตอน ce = สีของ (h0, v0)
    always @(negedge clk) if (cap && dut.ce_cnt == 2'd0 && act0) img[v0*640 + h0] = {R, G, B};

    // นับความกว้าง hsync (ต้อง = 96 pixel)
    always @(posedge clk) if (dut.ce) begin
        if (!HS) hs_low = hs_low + 1;
        else if (hs_low != 0) begin hs_len = hs_low; hs_low = 0; end
    end

    task grab(input [8*32-1:0] name); begin
        @(posedge dut.frame_tick); cap = 1;          // ต้นเฟรมถัดไป = เริ่ม vblank -> รอ y=0
        @(posedge dut.frame_tick); cap = 0;
        f = $fopen(name, "w");
        $fwrite(f, "P3\n640 480\n15\n");
        for (i = 0; i < 640*480; i = i + 1) $fwrite(f, "%0d %0d %0d\n", img[i][11:8], img[i][7:4], img[i][3:0]);
        $fclose(f);
        $display("saved %0s  hsync width = %0d px", name, hs_len);
    end endtask

    initial begin
        repeat (10) @(posedge clk); rstn = 1;
        // เกมเริ่มที่ TITLE -> กด BTNC เริ่มเล่น (DEBOUNCE = 4)
        repeat (20) @(posedge clk);
        if (dut.state !== 3'd0) $display("FAIL: expected TITLE after reset, state=%0d", dut.state);
        BTNC = 1; repeat (40) @(posedge clk); BTNC = 0; repeat (40) @(posedge clk);
        if (dut.state !== 3'd1) $display("FAIL: expected PLAY after BTNC, state=%0d", dut.state);
        grab("../sim/frame_start_f1.ppm");
        // ห้อง Combat 1 ชั้น 2, ร่าง 2, ปิดประตู D
        force dut.floor = 2'd1; force dut.room = 3'd1; force dut.form = 2'd1; SW[2] = 1;
        @(posedge clk); force dut.pl.px = 10'd300; force dut.pl.py = 10'd250;
        grab("../sim/frame_c1_f2.ppm");
        // ห้อง Simon ชั้น 3, ร่าง 4
        force dut.floor = 2'd2; force dut.room = 3'd3; force dut.form = 2'd3; SW[2] = 0;
        force dut.pl.px = 10'd100; force dut.pl.py = 10'd300;
        grab("../sim/frame_simon_f3.ppm");
        $finish;
    end
endmodule
