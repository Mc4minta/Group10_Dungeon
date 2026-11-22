`timescale 1ns/1ps
// Simon room (floor 3) in the real renderer: every plate is a 2x2-tile block drawn as ONE big plate = the 32x32 plate picture of tile 12..15
// sampled at half size. Compared pixel by pixel with mem/tileset.mem + mem/tilemap.mem. Run: ./scripts/run_sim.sh simonplate
module tb_simonplate;
    reg clk = 0; always #5 clk = ~clk;
    reg [9:0] hc = 0, vc = 0;
    wire [11:0] color;
    renderer dut (.hbox_on(1'b0), .dlg_top(1'b0), .mon_face(6'd0), .mic_nums(1'b0), .tgt_on(1'b0), .tgt_x(10'd0), .tgt_y(10'd0), .hint_b0(12'd0), .hint_b1(12'd0), .hint_n0(5'd0), .hint_n1(5'd0), .mic_th_bcd(16'd0), .mic_lv_bcd(16'd0), .mic_on(1'b0), .mic_w(7'd0), .mic_th(7'd0), .mic_hit(1'b0), .chg_lvl(3'd0), .facing(2'd0), .boss_fcol(12'hFFF), .chg_w(7'd0), .ov_phase(2'd0), .fade(2'd0), .dlg_on(1'b0), .dlg_b0(12'd0), .dlg_b1(12'd0), .dlg_n0(5'd0), .dlg_n1(5'd0), .dlg_col(12'hFFF), .p_hurt(1'b0), .open_E(1'b0), .brk(8'd0), .clk(clk), .ce(1'b1), .hcount(hc), .vcount(vc), .grid(4'd12), .floor(2'd2), .form(2'd0),
        .doors_open(1'b0), .open_L(1'b0), .screen(3'd0), .hide_player(1'b1), .px(10'd0), .py(10'd0), .pframe(6'd0),
        .p_anim(3'd0), .p_aframe(6'd0), .mon_act(6'd0), .mon_type(6'd0), .mon_flash(6'd0), .mon_x(60'd0), .mon_y(60'd0), .mon_anim(1'b0),
        .pb_act(6'd0), .pb_x(60'd0), .pb_y(60'd0), .pb_kind(12'd0), .p_tint(1'b0), .eb_act(16'd0), .eb_x(160'd0), .eb_y(160'd0),
        .pz_act(9'd0), .pz_x(90'd0), .pz_y(90'd0), .pz_frame(36'd0), .pbox0(12'd0), .pbox1(12'd0), .pbox_en(2'd0),
        .simon_lit_on(1'b0), .simon_lit(2'd0), .simon_wrong(1'b0), .melee_on(1'b0), .melee_dir(2'd0),
        .boss_act(1'b0), .boss_x(10'd0), .boss_y(10'd0), .boss_frame(3'd0), .boss_flash(1'b0),
        .sh_dx(10'd0), .sh_dy(10'd0), .txt_scr(4'd0), .txt_blink(1'b0), .t_floor(4'd0), .t_m1(4'd0), .t_m0(4'd0), .t_s1(4'd0), .t_s0(4'd0),
        .hud_hp(3'd0), .hud_hp_max(3'd0), .hud_b_hp(5'd0), .color(color));
    `include "vig.vh"
    reg [7:0]  omap [0:4095];
    reg [3:0]  tmap [0:4095];
    reg [11:0] tset [0:49151];
    initial begin $readmemh("tilemap.mem", tmap); $readmemh("overlay.mem", omap); $readmemh("tileset.mem", tset); end
    integer x, y, errors = 0, checks = 0, tid, tx, ty, lx, ly, sx, sy;
    reg [11:0] exp;
    initial begin
        for (y = 0; y < 480; y = y + 4)
            for (x = 0; x < 640; x = x + 4) begin
                hc = x; vc = y;
                repeat (6) @(posedge clk); #1;
                tx = x / 32; ty = y / 32;
                tid = tmap[12 * 300 + ty * 20 + tx];
                lx = x % 32; ly = y % 32;
                if (tid >= 12) begin sx = ((tx % 2) * 32 + lx) / 2; sy = ((ty % 2) * 32 + ly) / 2; exp = tset[(2 * 16 + tid) * 1024 + sy * 32 + sx]; end
                else exp = tset[(2 * 16 + tid) * 1024 + ly * 32 + lx];
                if (tid >= 12 && exp == 12'hF0F) exp = tset[(2 * 16 + 1) * 1024 + ly * 32 + lx];   // see-through plate corner shows the floor
                exp = vig_shade(exp, x, y, 0);                                                     // the renderer's vignette
                if (omap[12 * 300 + ty * 20 + tx][3:0] == 4'd0) begin     // (wall torches / shields are checked by ovrender)
                checks = checks + 1;
                if (color !== exp) begin errors = errors + 1; if (errors < 6) $display("FAIL (%0d,%0d) tile %0d: got %h expected %h", x, y, tid, color, exp); end end
            end
        $display("simonplate: %0d pixels checked, errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
