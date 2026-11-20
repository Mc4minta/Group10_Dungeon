`timescale 1ns/1ps
// W5: overlay art in the real renderer (room 4 = floor 1 combat room with Z / Y). Every sampled pixel = the overlay picture where it is not see-through,
// otherwise the tileset pixel. With every block broken (brk = FF) the breakable blocks show only the floor. Run: ./scripts/run_sim.sh ovrender
module tb_ovrender;
    reg clk = 0; always #5 clk = ~clk;
    reg [9:0] hc = 0, vc = 0;
    reg [7:0] brk_r = 8'h00; reg [2:0] scr_r = 3'd0; reg [1:0] floor_r = 2'd0; reg [3:0] grid_r = 4'd4;

    wire [11:0] color;
    renderer dut (.dlg_top(1'b0), .mon_face(6'd0), .mic_nums(1'b0), .tgt_on(1'b0), .tgt_x(10'd0), .tgt_y(10'd0), .hint_b0(12'd0), .hint_b1(12'd0), .hint_n0(5'd0), .hint_n1(5'd0), .mic_th_bcd(16'd0), .mic_lv_bcd(16'd0), .mic_on(1'b0), .mic_w(7'd0), .mic_th(7'd0), .mic_hit(1'b0), .chg_lvl(3'd0), .facing(2'd0), .boss_fcol(12'hFFF), .chg_w(7'd0), .ov_phase(2'd0), .fade(2'd0), .dlg_on(1'b0), .dlg_b0(12'd0), .dlg_b1(12'd0), .dlg_n0(5'd0), .dlg_n1(5'd0), .dlg_col(12'hFFF), .p_hurt(1'b0), .open_E(1'b0), .brk(brk_r), .clk(clk), .ce(1'b1), .hcount(hc), .vcount(vc), .grid(grid_r), .floor(floor_r), .form(2'd0),
        .doors_open(1'b0), .open_L(1'b0), .screen(scr_r), .hide_player(1'b1), .px(10'd0), .py(10'd0), .pframe(6'd0),
        .p_anim(3'd0), .p_aframe(6'd0), .mon_act(6'd0), .mon_type(6'd0), .mon_flash(6'd0), .mon_x(60'd0), .mon_y(60'd0), .mon_anim(1'b0),
        .pb_act(6'd0), .pb_x(60'd0), .pb_y(60'd0), .pb_kind(12'd0), .p_tint(1'b0), .eb_act(16'd0), .eb_x(160'd0), .eb_y(160'd0),
        .pz_act(9'd0), .pz_x(90'd0), .pz_y(90'd0), .pz_frame(36'd0), .pbox0(12'd0), .pbox1(12'd0), .pbox_en(2'd0),
        .simon_lit_on(1'b0), .simon_lit(2'd0), .simon_wrong(1'b0), .melee_on(1'b0), .melee_dir(2'd0),
        .boss_act(1'b0), .boss_x(10'd0), .boss_y(10'd0), .boss_frame(3'd0), .boss_flash(1'b0),
        .sh_dx(10'd0), .sh_dy(10'd0), .txt_scr(4'd0), .txt_blink(1'b0), .t_floor(4'd0), .t_m1(4'd0), .t_m0(4'd0), .t_s1(4'd0), .t_s0(4'd0),
        .hud_hp(3'd0), .hud_hp_max(3'd0), .hud_b_hp(5'd0), .color(color));
    `include "vig.vh"
    reg [3:0]  tmap [0:4095];
    reg [7:0]  omap [0:4095];
    reg [11:0] tset [0:49151];
    reg [11:0] otile [0:16383];
    reg [1:0]  mzm [0:511];
    initial begin $readmemh("tilemap.mem", tmap); $readmemh("overlay.mem", omap); $readmemh("tileset.mem", tset); $readmemh("ovtile.mem", otile); $readmemh("maze.mem", mzm); end
    integer x, y, errors = 0, checks = 0, tid, tx, ty, lx, ly, pass, seen = 0, pic;
    reg [11:0] exp; reg [7:0] o; reg shown;
    initial begin
        for (pass = 0; pass < 2; pass = pass + 1) begin
            brk_r = pass ? 8'hFF : 8'h00;
            for (y = 0; y < 480; y = y + 4)
                for (x = 0; x < 640; x = x + 4) begin
                    hc = x; vc = y;
                    repeat (6) @(posedge clk); #1;
                    tx = x / 32; ty = y / 32; lx = x % 32; ly = y % 32;
                    tid = tmap[4 * 300 + ty * 20 + tx]; o = omap[4 * 300 + ty * 20 + tx];
                    exp = tset[tid * 1024 + ly * 32 + lx];
                    pic = -1;
                    if (o[3:0] == 1 && !brk_r[o[6:4]]) pic = 0; else if (o[3:0] == 2) pic = 1; else if (o[3:0] == 3) pic = 2;
                    else if (o[3:0] == 4) pic = 3; else if (o[3:0] == 5) pic = 7; else if (o[3:0] == 6) pic = 8; else if (o[3:0] == 7) pic = 9;
                    shown = 0;
                    if (pic >= 0 && otile[pic * 1024 + ly * 32 + lx] != 12'hF0F) begin exp = otile[pic * 1024 + ly * 32 + lx]; shown = 1; end
                    if (!(shown && o[3:0] >= 4 && o[3:0] <= 6)) exp = vig_shade(exp, x, y, 0);           // torches are light sources: not darkened
                    if (shown) seen = seen + 1;
                    checks = checks + 1;
                    if (color !== exp) begin errors = errors + 1; if (errors < 6) $display("FAIL (%0d,%0d) tile %0d ov %h: got %h expected %h", x, y, tid, o, color, exp); end
                end
            if (pass == 0) $display("      pass 0 (nothing broken): %0d overlay pixels checked", seen);
        end
        // W7: maze screen (screen 5): tiles from maze_rom (wall / floor / goal plate) in floor-3 art, overlay art off
        scr_r = 3'd5; floor_r = 2'd2; grid_r = 4'd1; brk_r = 8'h00;
        for (y = 0; y < 480; y = y + 4)
            for (x = 0; x < 640; x = x + 4) begin
                hc = x; vc = y;
                repeat (6) @(posedge clk); #1;
                tx = x / 32; ty = y / 32; lx = x % 32; ly = y % 32;
                tid = (mzm[ty * 20 + tx] == 2'd1) ? 0 : (mzm[ty * 20 + tx] == 2'd2) ? 7 : 1;
                exp = vig_shade(tset[(2 * 16 + tid) * 1024 + ly * 32 + lx], x, y, 0);
                checks = checks + 1;
                if (color !== exp) begin errors = errors + 1; if (errors < 6) $display("FAIL maze (%0d,%0d) tile %0d: got %h expected %h", x, y, tid, color, exp); end
            end
        check_seen;
        $display("ovrender: %0d pixels checked, errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
    task check_seen; begin
        if (seen < 100) begin errors = errors + 1; $display("FAIL: overlay art is not visible in room 4 (%0d pixels)", seen); end
    end endtask
endmodule
