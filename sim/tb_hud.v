`timescale 1ns/1ps
// hud.v against mem/hud.mem: every pixel of the hearts area and the boss-bar area is compared with the expected ROM pixel.
// Run: ./scripts/run_sim.sh hud
module tb_hud;
    `include "params.vh"
    reg clk = 0; always #5 clk = ~clk;
    reg [9:0] hc = 0, vc = 0; reg [2:0] hp = 4, hpm = 4; reg bon = 0; reg [1:0] fl = 0; reg [4:0] bhp = 0;
    wire [11:0] px; wire on;
    hud dut (.clk(clk), .hcount(hc), .vcount(vc), .hp(hp), .hp_max(hpm), .boss_on(bon), .floor(fl), .b_hp(bhp), .hud_px(px), .hud_on(on));
    reg [11:0] rom [0:8191];
    initial $readmemh("hud.mem", rom);
    integer errors = 0, checks = 0, x, y, i, sx, sy, fw, rcp, maxhp, exp_on, k;
    reg [11:0] exp_px, f;

    task sample; begin repeat (4) @(posedge clk); #1; end endtask
    task scan_area(input integer x0, input integer x1, input integer y0, input integer y1, input integer mode);
        begin
            for (y = y0; y < y1; y = y + 1)
                for (x = x0; x < x1; x = x + 1) begin
                    hc = x; vc = y; sample;
                    exp_on = 0; exp_px = 12'hF0F;
                    if (mode == 0) begin                       // hearts
                        for (i = 0; i < 6; i = i + 1)
                            if (!exp_on && x >= HUD_HEART_X + HUD_HEART_STEP*i && x < HUD_HEART_X + HUD_HEART_STEP*i + 34 && y >= HUD_HEART_Y && y < HUD_HEART_Y + 34 && i < hpm) begin
                                sx = (x - HUD_HEART_X - HUD_HEART_STEP*i) / 2; sy = (y - HUD_HEART_Y) / 2;
                                exp_px = rom[((i < hp) ? 0 : 1) * 2048 + sy * 64 + sx];
                                exp_on = (exp_px != 12'hF0F);
                            end
                    end else if (bon && x >= HUD_BAR_X && x < HUD_BAR_X + 128 && y >= HUD_BAR_Y && y < HUD_BAR_Y + 34) begin
                        sx = (x - HUD_BAR_X) / 2; sy = (y - HUD_BAR_Y) / 2;
                        exp_px = rom[2 * 2048 + sy * 64 + sx];
                        if (sx >= 14 && (sx - 14) < fw) begin f = rom[3 * 2048 + sy * 64 + (sx - 14)]; if (f != 12'hF0F) exp_px = f; end
                        exp_on = (exp_px != 12'hF0F);
                    end
                    checks = checks + 1;
                    if (on !== exp_on[0] || (exp_on && px !== exp_px)) begin
                        errors = errors + 1;
                        if (errors < 6) $display("FAIL mode %0d at (%0d,%0d): on=%b px=%h expected on=%0d px=%h", mode, x, y, on, px, exp_on, exp_px);
                    end
                end
        end
    endtask
    function integer fillw(input integer h, input integer mx);
        integer r, p;
        begin r = (49 * 1024 + mx - 1) / mx; p = (h * r) >> 10; fillw = (p > 49) ? 49 : p; end
    endfunction
    integer n_full, n_part;
    initial begin
        // hearts: several hp / hp_max combinations
        hpm = 4; hp = 4; scan_area(0, 200, 0, 44, 0);
        hp = 3; scan_area(0, 200, 0, 44, 0);
        hp = 1; scan_area(0, 200, 0, 44, 0);
        hp = 0; scan_area(0, 200, 0, 44, 0);
        hpm = 3; hp = 2; scan_area(0, 200, 0, 44, 0);
        // boss off: nothing drawn in the bar area
        bon = 0; scan_area(496, 640, 0, 44, 1);
        // boss on: floor 1 / 2 / 3 at full, half, 1 hp, 0 hp
        bon = 1;
        for (k = 0; k < 3; k = k + 1) begin
            fl = k; maxhp = (k == 0) ? BOSS1_HP : (k == 1) ? BOSS2_HP : BOSS3_HP;
            bhp = maxhp; fw = fillw(maxhp, maxhp); scan_area(496, 640, 0, 44, 1);
            if (fw != 49) begin errors = errors + 1; $display("FAIL full boss bar width %0d != 49", fw); end
            bhp = maxhp / 2; fw = fillw(maxhp / 2, maxhp); scan_area(496, 640, 0, 44, 1);
            bhp = 1; fw = fillw(1, maxhp); scan_area(496, 640, 0, 44, 1);
            bhp = 0; fw = 0; scan_area(496, 640, 0, 44, 1);
        end
        // everything outside the two areas stays transparent
        hc = 300; vc = 200; sample; checks = checks + 1; if (on) begin errors = errors + 1; $display("FAIL pixel in the middle of the map is drawn"); end
        $display("hud: %0d pixels checked, errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
