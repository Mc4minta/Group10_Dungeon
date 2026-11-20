`timescale 1ns/1ps
// W9a / story text: the real renderer draws the prologue pages (screen 4 = black + text 7..10) and the NEW FORM banners (text 11..13).
// Per text screen: white pixels exist in both text rows, and the prologue background is black everywhere else. Run: ./scripts/run_sim.sh text
module tb_text;
    reg clk = 0; always #5 clk = ~clk;
    reg [9:0] hc = 0, vc = 0;
    reg [2:0] scr = 3'd4; reg [3:0] ts = 4'd7;
    reg dlg_on_r = 0; reg [11:0] dlg_b0_r = 0, dlg_b1_r = 0, dlg_col_r = 12'hFF0; reg [4:0] dlg_n0_r = 0, dlg_n1_r = 0;
    reg [39:0] dlgrom [0:127];
    initial $readmemh("dlg.mem", dlgrom);
    wire [11:0] color;
    renderer dut (.mic_th_bcd(16'd0), .mic_lv_bcd(16'd0), .mic_on(1'b0), .mic_w(7'd0), .mic_th(7'd0), .mic_hit(1'b0), .chg_lvl(3'd0), .facing(2'd0), .boss_fcol(12'hFFF), .chg_w(7'd0), .ov_phase(2'd0), .fade(2'd0), .dlg_on(dlg_on_r), .dlg_b0(dlg_b0_r), .dlg_b1(dlg_b1_r), .dlg_n0(dlg_n0_r), .dlg_n1(dlg_n1_r), .dlg_col(dlg_col_r), .p_hurt(1'b0), .open_E(1'b0), .brk(8'd0), .clk(clk), .ce(1'b1), .hcount(hc), .vcount(vc), .grid(4'd0), .floor(2'd0), .form(2'd0),
        .doors_open(1'b0), .open_L(1'b0), .screen(scr), .hide_player(1'b1), .px(10'd0), .py(10'd0), .pframe(6'd0),
        .p_anim(3'd0), .p_aframe(6'd0), .mon_act(6'd0), .mon_type(6'd0), .mon_flash(6'd0), .mon_x(60'd0), .mon_y(60'd0), .mon_anim(1'b0),
        .pb_act(6'd0), .pb_x(60'd0), .pb_y(60'd0), .pb_kind(12'd0), .p_tint(1'b0), .eb_act(16'd0), .eb_x(160'd0), .eb_y(160'd0),
        .pz_act(9'd0), .pz_x(90'd0), .pz_y(90'd0), .pz_frame(36'd0), .pbox0(12'd0), .pbox1(12'd0), .pbox_en(2'd0),
        .simon_lit_on(1'b0), .simon_lit(2'd0), .simon_wrong(1'b0), .melee_on(1'b0), .melee_dir(2'd0),
        .boss_act(1'b0), .boss_x(10'd0), .boss_y(10'd0), .boss_frame(3'd0), .boss_flash(1'b0),
        .sh_dx(10'd0), .sh_dy(10'd0), .txt_scr(ts), .txt_blink(1'b0), .t_floor(4'd0), .t_m1(4'd0), .t_m0(4'd0), .t_s1(4'd0), .t_s0(4'd0),
        .hud_hp(3'd0), .hud_hp_max(3'd0), .hud_b_hp(5'd0), .color(color));
    integer x, y, k, errors = 0, white0, white1, other;
    task scan(input [3:0] t, input [9:0] y0, input [9:0] y1, input [9:0] y2, input [9:0] y3);
        begin
            ts = t; white0 = 0; white1 = 0; other = 0;
            for (y = 0; y < 480; y = y + 2)
                for (x = 0; x < 640; x = x + 2) begin
                    hc = x; vc = y; repeat (6) @(posedge clk); #1;
                    if (color == 12'hFFF) begin
                        if (y >= y0 && y < y1) white0 = white0 + 1; else if (y >= y2 && y < y3) white1 = white1 + 1; else other = other + 1;
                    end else if (scr == 3'd4 && color != 12'h000) other = other + 1;
                end
            if (white0 < 40 || white1 < 40 || other != 0) begin errors = errors + 1; $display("FAIL text %0d: row0 white %0d row1 white %0d stray %0d", t, white0, white1, other); end
            else $display("PASS  text %0d: row0 %0d px, row1 %0d px, nothing else", t, white0, white1);
        end
    endtask
    initial begin
        scr = 3'd4;
        for (k = 7; k <= 10; k = k + 1) scan(k, 160, 192, 220, 252);          // prologue: scale 4 rows at y 160 and 220
        // NEW FORM banners (drawn over the game in the real top; here on the black screen so only text is white)
        scan(11, 140, 172, 190, 206); scan(12, 140, 172, 190, 206); scan(13, 140, 172, 190, 206);
        // ---- W16 dialogue box over the running game (screen 0): black band y 384..447, 2 yellow lines at y 392 and 416, nothing else in the band ----
        scr = 3'd0; dlg_on_r = 1; ts = 4'd14;
        dlg_b0_r = dlgrom[0][11:0]; dlg_n0_r = dlgrom[0][16:12]; dlg_b1_r = dlgrom[0][28:17]; dlg_n1_r = dlgrom[0][33:29];
        begin : dlgt
            integer yy, xx, t0, t1, stray, nonblack;
            t0 = 0; t1 = 0; stray = 0; nonblack = 0;
            for (yy = 384; yy < 448; yy = yy + 2)
                for (xx = 0; xx < 640; xx = xx + 2) begin
                    hc = xx; vc = yy; repeat (6) @(posedge clk); #1;
                    if (color == 12'hFF0) begin
                        if (yy >= 392 && yy < 408) t0 = t0 + 1; else if (yy >= 416 && yy < 432) t1 = t1 + 1; else stray = stray + 1;
                    end else if (color != 12'h000) nonblack = nonblack + 1;
                end
            if (t0 < 60 || t1 < 60 || stray != 0 || nonblack != 0) begin errors = errors + 1; $display("FAIL dialogue box: line1 %0d line2 %0d stray %0d non-black %0d", t0, t1, stray, nonblack); end
            else $display("PASS  dialogue box: line 1 %0d px, line 2 %0d px, band black everywhere else", t0, t1);
        end
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
