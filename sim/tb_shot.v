`timescale 1ns/1ps
// Screenshot tool: renders ONE full frame of the real renderer to a PPM (no game logic). Scenario by plusargs:
//   +grid=N +floor=N +scr=N (0 game, 1 title, 4 prologue, 5 maze) +px= +py= +pf= (player picture = form*12 + facing*3 + pose) +hp= +hpmax=
//   +m0t= +m0x= +m0y= ... +m5t/x/y (monster type 0 A 1 B, position)   +bact=1 +bx= +by= +bf= (boss, frame = kind*2 + k)
//   +pz0f= +pz0x= +pz0y= (puzzle object / key / ball)   +doors=1 +openl=1 +phase=N +fade=N +out=file.ppm
// Run via scripts/make_shots.sh
module tb_shot;
    reg clk = 0; always #5 clk = ~clk;
    reg [9:0] hc = 0, vc = 0;
    integer grid = 0, floor = 0, scr = 0, px = 0, py = 0, pf = 0, hp = 0, hpmax = 0, bact = 0, bx = 0, by = 0, bf = 0, doors = 0, openl = 0, phase = 0, fade = 0;
    integer pz0f = -1, pz0x = 0, pz0y = 0;
    integer mt [0:5]; integer mx [0:5]; integer my [0:5]; integer ma [0:5];
    reg [5:0] mon_act = 0, mon_type = 0; reg [59:0] mon_x = 0, mon_y = 0;
    reg [8:0] pz_act = 0; reg [89:0] pz_x = 0, pz_y = 0; reg [35:0] pz_frame = 0;
    reg [1:0] fl; reg [3:0] gr;
    wire [11:0] color;
    renderer dut (.mic_th_bcd(16'd0), .mic_lv_bcd(16'd0), .mic_on(1'b0), .mic_w(7'd0), .mic_th(7'd0), .mic_hit(1'b0), .chg_lvl(3'd0), .facing(2'd0), .boss_fcol(12'hFFF), .chg_w(7'd0), .ov_phase(2'd0), .fade(2'd0), .dlg_on(1'b0), .dlg_b0(12'd0), .dlg_b1(12'd0), .dlg_n0(5'd0), .dlg_n1(5'd0), .dlg_col(12'hFFF), .p_hurt(1'b0), .open_E(1'b0), .brk(8'd0),
        .clk(clk), .ce(1'b1), .hcount(hc), .vcount(vc), .grid(gr), .floor(fl), .form(2'd0),
        .doors_open(doors != 0), .open_L(openl != 0), .screen(scr[2:0]), .hide_player(1'b0), .px(px[9:0]), .py(py[9:0]), .pframe(pf[5:0]),
        .p_anim(3'd0), .p_aframe(6'd0), .mon_act(mon_act), .mon_type(mon_type), .mon_flash(6'd0), .mon_x(mon_x), .mon_y(mon_y), .mon_anim(1'b0),
        .pb_act(6'd0), .pb_x(60'd0), .pb_y(60'd0), .pb_kind(12'd0), .p_tint(1'b0), .eb_act(16'd0), .eb_x(160'd0), .eb_y(160'd0),
        .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame), .pbox0(12'd0), .pbox1(12'd0), .pbox_en(2'd0),
        .simon_lit_on(1'b0), .simon_lit(2'd0), .simon_wrong(1'b0), .melee_on(1'b0), .melee_dir(2'd0),
        .boss_act(bact != 0), .boss_x(bx[9:0]), .boss_y(by[9:0]), .boss_frame(bf[2:0]), .boss_flash(1'b0),
        .sh_dx(10'd0), .sh_dy(10'd0), .txt_scr(scr == 1 ? 4'd1 : 4'd0), .txt_blink(1'b0), .t_floor(4'd1), .t_m1(4'd0), .t_m0(4'd0), .t_s1(4'd0), .t_s0(4'd0),
        .hud_hp(hp[2:0]), .hud_hp_max(hpmax[2:0]), .hud_b_hp(5'd10), .color(color));
    integer x, y, fd, k, r, tmp, fr;
    // the colour on the bus at (x, y) is the pixel (x - 4, y): save pixels whose own coordinates are inside the 640 x 480 window
    function lat_ok(input integer xx, input integer yy); lat_ok = (xx >= 4) && (xx < 644) && (yy < 480); endfunction reg [8*200-1:0] outp; reg [8*32-1:0] fmt;
    initial begin
        for (k = 0; k < 6; k = k + 1) begin mt[k] = 0; mx[k] = 0; my[k] = 0; ma[k] = 0; end
        r = $value$plusargs("grid=%d", grid); r = $value$plusargs("floor=%d", floor); r = $value$plusargs("scr=%d", scr);
        r = $value$plusargs("px=%d", px); r = $value$plusargs("py=%d", py); r = $value$plusargs("pf=%d", pf);
        r = $value$plusargs("hp=%d", hp); r = $value$plusargs("hpmax=%d", hpmax);
        r = $value$plusargs("bact=%d", bact); r = $value$plusargs("bx=%d", bx); r = $value$plusargs("by=%d", by); r = $value$plusargs("bf=%d", bf);
        r = $value$plusargs("doors=%d", doors); r = $value$plusargs("openl=%d", openl);
        r = $value$plusargs("pz0f=%d", pz0f); r = $value$plusargs("pz0x=%d", pz0x); r = $value$plusargs("pz0y=%d", pz0y);
        for (k = 0; k < 6; k = k + 1) begin
            $sformat(fmt, "m%0dx=%%d", k);
            if ($value$plusargs(fmt, tmp)) begin
                mx[k] = tmp; ma[k] = 1;
                $sformat(fmt, "m%0dy=%%d", k); if ($value$plusargs(fmt, tmp)) my[k] = tmp;
                $sformat(fmt, "m%0dt=%%d", k); if ($value$plusargs(fmt, tmp)) mt[k] = tmp;
            end
        end
        if (!$value$plusargs("out=%s", outp)) outp = "shot.ppm";
        gr = grid; fl = floor;
        for (k = 0; k < 6; k = k + 1) begin
            mon_act[k] = ma[k]; mon_type[k] = mt[k]; mon_x[k*10 +: 10] = mx[k]; mon_y[k*10 +: 10] = my[k];
        end
        if (scr == 1) begin pz_act = 9'd3; pz_x = {70'd0, 10'd512, 10'd96}; pz_y = {70'd0, 10'd208, 10'd208}; pz_frame = {28'd0, 4'd0, 4'd0}; end
        if (pz0f >= 0) begin pz_act = 9'd1; pz_x[9:0] = pz0x; pz_y[9:0] = pz0y; pz_frame[3:0] = pz0f; end
        // real raster scan (800 x 525, one pixel per clock) so the object line buffers fill like on the board; the second frame is saved
        fd = $fopen(outp, "w");
        $fwrite(fd, "P3 640 480 15 ");
        for (fr = 0; fr < 2; fr = fr + 1)
            for (y = 0; y < 525; y = y + 1)
                for (x = 0; x < 800; x = x + 1) begin
                    hc = x; vc = y; @(posedge clk); #1;
                    // the renderer has a 4-clock latency: the colour now belongs to the pixel 4 clocks ago
                    if (fr == 1 && lat_ok(x, y)) $fwrite(fd, "%0d %0d %0d ", color[11:8], color[7:4], color[3:0]);
                end
        $fclose(fd);
        $finish;
    end
endmodule
