`timescale 1ns/1ps
// W25: the charge ball in the real renderer. For every size step 1..4 and every facing the ball must appear in front of the hero (centre
// ORB_DIST px away), grow with the step, and leave every pixel outside its disc untouched.   Run: ./scripts/run_sim.sh orb
module tb_orb;
    reg clk = 0; always #5 clk = ~clk;
    reg [9:0] hc = 0, vc = 0;
    reg [2:0] lvl = 0; reg [1:0] face = 0;
    wire [11:0] color;
    localparam ORB_DIST = 18;
    renderer dut (.hbox_on(1'b0), .dlg_top(1'b0), .mon_face(6'd0), .mic_nums(1'b0), .tgt_on(1'b0), .tgt_x(10'd0), .tgt_y(10'd0), .hint_b0(12'd0), .hint_b1(12'd0), .hint_n0(5'd0), .hint_n1(5'd0), .mic_th_bcd(16'd0), .mic_lv_bcd(16'd0), .mic_on(1'b0), .mic_w(7'd0), .mic_th(7'd0), .mic_hit(1'b0), .chg_lvl(lvl), .facing(face), .boss_fcol(12'hFFF), .chg_w(7'd0), .ov_phase(2'd0), .fade(2'd0), .dlg_on(1'b0), .dlg_b0(12'd0), .dlg_b1(12'd0), .dlg_n0(5'd0), .dlg_n1(5'd0), .dlg_col(12'hFFF), .p_hurt(1'b0), .open_E(1'b0), .brk(8'd0), .clk(clk), .ce(1'b1), .hcount(hc), .vcount(vc), .grid(4'd4), .floor(2'd0), .form(2'd3),
        .doors_open(1'b0), .open_L(1'b0), .screen(3'd0), .hide_player(1'b1), .px(10'd300), .py(10'd200), .pframe(6'd0),
        .p_anim(3'd0), .p_aframe(6'd0), .mon_act(6'd0), .mon_type(6'd0), .mon_flash(6'd0), .mon_x(60'd0), .mon_y(60'd0), .mon_anim(1'b0),
        .pb_act(6'd0), .pb_x(60'd0), .pb_y(60'd0), .pb_kind(12'd0), .p_tint(1'b0), .eb_act(16'd0), .eb_x(160'd0), .eb_y(160'd0),
        .pz_act(9'd0), .pz_x(90'd0), .pz_y(90'd0), .pz_frame(36'd0), .pbox0(12'd0), .pbox1(12'd0), .pbox_en(2'd0),
        .simon_lit_on(1'b0), .simon_lit(2'd0), .simon_wrong(1'b0), .melee_on(1'b0), .melee_dir(2'd0),
        .boss_act(1'b0), .boss_x(10'd0), .boss_y(10'd0), .boss_frame(3'd0), .boss_flash(1'b0),
        .sh_dx(10'd0), .sh_dy(10'd0), .txt_scr(4'd0), .txt_blink(1'b0), .t_floor(4'd0), .t_m1(4'd0), .t_m0(4'd0), .t_s1(4'd0), .t_s0(4'd0),
        .hud_hp(3'd0), .hud_hp_max(3'd0), .hud_b_hp(5'd0), .color(color));
    reg [11:0] base [0:35*35-1];
    integer errors = 0, checks = 0, f, l, x, y, cnt, prev, minx, maxx, miny, maxy, ecx, ecy, bx0, by0;
    task check(input cond, input [8*90-1:0] msg); begin
        checks = checks + 1;
        if (!cond) begin errors = errors + 1; $display("FAIL  %0s (face %0d lvl %0d cnt %0d box %0d..%0d x %0d..%0d)", msg, f, l, cnt, minx, maxx, miny, maxy); end
    end endtask
    task sample(output [11:0] c, input integer sx, input integer sy); begin
        hc = sx; vc = sy; repeat (6) @(posedge clk); #1; c = color;
    end endtask
    reg [11:0] cc;
    initial begin
        for (f = 0; f < 4; f = f + 1) begin
            ecx = 316 + ((f == 3) ? ORB_DIST : 0) - ((f == 2) ? ORB_DIST : 0);      // centre of the ball = hero centre (px + 16, py + 16) + offset
            ecy = 216 + ((f == 0) ? ORB_DIST : 0) - ((f == 1) ? ORB_DIST : 0);
            bx0 = ecx - 17; by0 = ecy - 17;
            lvl = 0; face = f;
            for (y = 0; y < 35; y = y + 1) for (x = 0; x < 35; x = x + 1) begin sample(cc, bx0 + x, by0 + y); base[y * 35 + x] = cc; end
            prev = 0;
            for (l = 1; l <= 4; l = l + 1) begin
                lvl = l; cnt = 0; minx = 999; maxx = -1; miny = 999; maxy = -1;
                for (y = 0; y < 35; y = y + 1) for (x = 0; x < 35; x = x + 1) begin
                    sample(cc, bx0 + x, by0 + y);
                    if (cc !== base[y * 35 + x]) begin
                        cnt = cnt + 1;
                        if (x < minx) minx = x; if (x > maxx) maxx = x; if (y < miny) miny = y; if (y > maxy) maxy = y;
                    end
                end
                check(cnt > prev, "the ball grows with every step");
                check(minx >= 17 - 2 * l - 1 && maxx <= 17 + 2 * l + 1 && miny >= 17 - 2 * l - 1 && maxy <= 17 + 2 * l + 1, "ball stays inside its radius around the centre");
                check(l == 1 || (maxx - minx) >= 2 * l, "ball size fits the step");
                check(cnt > 0 && (minx + maxx) / 2 >= 16 && (minx + maxx) / 2 <= 18 && (miny + maxy) / 2 >= 16 && (miny + maxy) / 2 <= 18, "the ball is centred in front of the hero");
                prev = cnt;
                $display("      facing %0d step %0d: %0d pixels", f, l, cnt);
            end
        end
        $display("orb: checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
