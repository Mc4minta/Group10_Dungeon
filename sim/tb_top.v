`timescale 1ns/1ps
// จำลองทั้งระบบแล้วบันทึกภาพจาก VGA ออกเป็น .ppm (เปิดดูด้วยโปรแกรมภาพ หรือแปลง PNG)
// รัน: cd mem && iverilog -g2012 -o ../sim/tb_top.vvp ../sim/tb_top.v ../rtl/*.v && vvp ../sim/tb_top.vvp
module tb_top;
    `include "params.vh"      // HP1 follows the game parameters, so the display checks follow the tuning
    localparam [7:0] HP_CH  = "0" + HP1;          // start HP as a character
    localparam [7:0] HP1_CH = "0" + (HP1 - 1);    // HP after one hit
    reg clk = 0; always #5 clk = ~clk;
    reg rstn = 0;
    reg BTNC = 0, BTNU = 0, BTND = 0, BTNL = 0, BTNR = 0;
    reg [15:0] SW = 0;
    wire [3:0] R, G, B; wire HS, VS;
    wire [15:0] LED; wire CA, CB, CC, CD, CE, CF, CG, DP; wire [7:0] AN; wire AUD_PWM, AUD_SD;

    // ---------- ถอดรหัส 7-seg ที่สแกนอยู่ (AN active-low + segment active-low) ----------
    reg [7:0] shown [0:7]; reg dps [0:7];
    integer dk;
    initial for (dk = 0; dk < 8; dk = dk + 1) begin shown[dk] = "?"; dps[dk] = 1'bx; end
    function [7:0] seg_char(input [6:0] sg);
        case (sg)
            7'h40: seg_char = "0"; 7'h79: seg_char = "1"; 7'h24: seg_char = "2"; 7'h30: seg_char = "3";
            7'h19: seg_char = "4"; 7'h12: seg_char = "5"; 7'h02: seg_char = "6"; 7'h78: seg_char = "7";
            7'h00: seg_char = "8"; 7'h10: seg_char = "9"; 7'h3F: seg_char = "-"; 7'h7F: seg_char = " ";
            default: seg_char = "?";
        endcase
    endfunction
    always @(posedge clk) for (dk = 0; dk < 8; dk = dk + 1)
        if (AN == ~(8'd1 << dk)) begin shown[dk] <= seg_char({CG, CF, CE, CD, CC, CB, CA}); dps[dk] <= ~DP; end
    integer disp_err = 0, disp_chk = 0;
    task dchk(input cond, input [8*72-1:0] msg); begin
        disp_chk = disp_chk + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin $display("FAIL  %0s  7seg=%c%c%c%c%c%c%c%c LED=%b", msg, shown[7], shown[6], shown[5], shown[4], shown[3], shown[2], shown[1], shown[0], LED); disp_err = disp_err + 1; end
    end endtask
    integer pwm_edges = 0; reg pwm_q = 0;
    top #(.DEBOUNCE(4), .PROLOGUE(0)) dut (.CLK100MHZ(clk), .CPU_RESETN(rstn), .BTNC(BTNC), .BTNU(BTNU), .BTND(BTND),
        .BTNL(BTNL), .BTNR(BTNR), .SW(SW), .LED(LED), .LED16_R(), .LED16_G(), .LED16_B(),
        .LED17_R(), .LED17_G(), .LED17_B(), .CA(CA), .CB(CB), .CC(CC), .CD(CD), .CE(CE), .CF(CF), .CG(CG), .DP(DP), .AN(AN),
        .VGA_R(R), .VGA_G(G), .VGA_B(B), .VGA_HS(HS), .VGA_VS(VS), .AUD_PWM(AUD_PWM), .AUD_SD(AUD_SD), .M_CLK(), .M_DATA(1'b0), .M_LRSEL());

    reg [11:0] img [0:640*480-1];
    reg [9:0] h0, v0; reg act0, cap = 0;
    integer hs_low = 0, hs_len = 0, f, i, nwhite;

    // renderer + sync มี latency 4 clock (= 1 พิกเซลที่ CE_DIV = 4): ค่า RGB ที่ ce ถัดไปเป็นของพิกเซลก่อนหน้า -> หน่วงพิกัดอีก 1 ce
    reg [9:0] h1, v1; reg act1;
    always @(posedge clk) if (dut.ce) begin h1 <= dut.hcount; v1 <= dut.vcount; act1 <= dut.active; h0 <= h1; v0 <= v1; act0 <= act1; end
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
        // หน้า TITLE: ชื่อเกม (ฟอนต์ 4x) ต้องมีพิกเซลขาวในแถว 96..127 กลางจอ
        grab("../sim/frame_title.ppm");
        dchk(shown[7] == "-" && shown[6] == "-" && shown[5] == "-" && shown[4] == "-" &&
             shown[3] == "-" && shown[2] == "-" && shown[1] == "-" && shown[0] == "-", "TITLE: 7-seg shows --------");
        dchk(dps[0] === 1'b0 && dps[2] === 1'b0 && dps[7] === 1'b0, "TITLE: no decimal points");
        dchk(AUD_SD === 1'b1, "AUD_SD = 1 on TITLE");
        nwhite = 0;
        for (i = 96 * 640; i < 128 * 640; i = i + 1) if (img[i] == 12'hFFF) nwhite = nwhite + 1;
        if (nwhite < 400) $display("FAIL: title text missing (%0d white pixels in rows 96..127)", nwhite);
        else $display("PASS  title text drawn: %0d white pixels in rows 96..127", nwhite);
        BTNC = 1; repeat (40) @(posedge clk); BTNC = 0; repeat (40) @(posedge clk);
        if (dut.state !== 3'd1) $display("FAIL: expected PLAY after BTNC, state=%0d", dut.state);
        grab("../sim/frame_start_f1.ppm");
        // ---------- ตรวจ 7-seg / LED / เสียง จากขา output จริง (ต้องแตะ scan ครบทุกหลัก: 1 รอบ ~ 1M clock) ----------
        repeat (1_200_000) @(posedge clk);
        dchk(shown[7] == "1" && shown[6] == "-" && shown[5] == HP_CH && shown[4] == "-" &&
             shown[3] == "0" && shown[2] == "0" && shown[1] == "0" && shown[0] == "0", "PLAY start: 7-seg shows 1-HP1-00.00");
        dchk(dps[2] === 1'b1 && dps[7] === 1'b0 && dps[3] === 1'b0 && dps[1] === 1'b0 && dps[0] === 1'b0, "decimal point only on digit 2 (mm.ss)");
        dchk(LED[8] === (HP1 >= 1) && LED[9] === (HP1 >= 2) && LED[10] === (HP1 >= 3) && LED[11] === (HP1 >= 4), "HP LEDs 8-11 show HP1");
        dchk(!LED[14], "LED14 (sprint) off");
        SW[14] = 1; repeat (200) @(posedge clk);
        dchk(LED[14], "SW14 on -> LED14 on (sprint)");
        SW[14] = 0; repeat (200) @(posedge clk);
        dchk(!LED[14], "SW14 off -> LED14 off");
        // W15 pause: SW15 ยก -> timer / ตำแหน่ง / HP ไม่เปลี่ยน, ข้อความ PAUSED, ปล่อยแล้วเดินต่อ
        begin : pause_case
            reg [7:0] s0, s1; reg [9:0] px0; integer fsm_t;
            repeat (1_200_000) @(posedge clk);
            SW[15] = 1; repeat (200) @(posedge clk);
            dchk(dut.paused, "SW15 on in PLAY -> paused");
            dchk(dut.txt_scr == 3'd6, "paused: text screen 6 (PAUSED)");
            s0 = {dut.fsm.m_t, dut.fsm.m_o}; fsm_t = dut.fsm.tick60; px0 = dut.px;
            BTNR = 1; repeat (3_000_000) @(posedge clk); BTNR = 0;       // ~ 3 เฟรม+ ระหว่างหยุด: เดินไม่ได้, timer ไม่เดิน
            dchk(dut.px == px0 && dut.fsm.tick60 == fsm_t, "paused: player does not move and the timer does not advance");
            SW[15] = 0; repeat (200) @(posedge clk);
            dchk(!dut.paused && dut.txt_scr == 3'd0, "SW15 off -> running again, no text");
            BTNR = 1; repeat (3_000_000) @(posedge clk); BTNR = 0;
            dchk(dut.px != px0, "after pause the player moves again");
        end
        SW[4] = 1; repeat (1_200_000) @(posedge clk);              // debug take_hit
        dchk(shown[5] == HP1_CH && LED[8] === (HP1 - 1 >= 1) && LED[9] === (HP1 - 1 >= 2) && LED[10] === (HP1 - 1 >= 3) && LED[11] === (HP1 - 1 >= 4), "after SW4 hit: HP digit HP1-1, HP LEDs follow");
        SW[4] = 0;
        dchk(AUD_SD === 1'b1, "AUD_SD = 1 (amplifier enabled)");
        pwm_edges = 0; pwm_q = AUD_PWM;
        repeat (100_000) begin @(posedge clk); if (AUD_PWM !== pwm_q) pwm_edges = pwm_edges + 1; pwm_q = AUD_PWM; end
        dchk(pwm_edges > 400, "AUD_PWM toggles during PLAY (390 kHz carrier)");
        // ห้อง Combat 1 ชั้น 2, ร่าง 2, ปิดประตู D
        force dut.floor = 2'd1; force dut.room = 3'd1; force dut.form = 2'd1; SW[2] = 1;
        @(posedge clk); force dut.pl.px = 10'd300; force dut.pl.py = 10'd250;
        grab("../sim/frame_c1_f2.ppm");
        // ห้อง Simon ชั้น 3, ร่าง 4
        force dut.floor = 2'd2; force dut.room = 3'd3; force dut.form = 2'd3; SW[2] = 0;
        force dut.pl.px = 10'd100; force dut.pl.py = 10'd300;
        grab("../sim/frame_simon_f3.ppm");
        $display("display checks = %0d  errors = %0d", disp_chk, disp_err);
        if (disp_err != 0) $display("FAIL: display assertions");
        $finish;
    end
endmodule
