`timescale 1ns/1ps
// The four animation ROMs load completely (no X) and every picture that the game can show has opaque pixels
// (the last death picture is allowed to be empty: the soul has left). Run: ./scripts/run_sim.sh animroms
module tb_anim_roms;
    reg clk = 0; always #5 clk = ~clk;
    reg [15:0] a_idle = 0; reg [13:0] a_atk = 0, a_hurt = 0, a_die = 0;
    wire [11:0] d_idle, d_atk, d_hurt, d_die;
    player_idle_rom   ri (.clk(clk), .addr(a_idle), .data(d_idle));
    player_attack_rom ra (.clk(clk), .addr(a_atk),  .data(d_atk));
    player_hurt_rom   rh (.clk(clk), .addr(a_hurt), .data(d_hurt));
    player_die_rom    rd (.clk(clk), .addr(a_die),  .data(d_die));
    integer f, p, errors = 0, xs = 0, e_idle = 0, e_atk = 0, e_hurt = 0, e_die = 0, o_i, o_a, o_h, o_d;
    initial begin
        for (f = 0; f < 64; f = f + 1) begin                       // idle: 4 dirs x 16
            o_i = 0;
            for (p = 0; p < 1024; p = p + 1) begin
                a_idle = f * 1024 + p; @(posedge clk); #1; @(posedge clk); #1;
                if (^d_idle === 1'bx) xs = xs + 1; else if (d_idle != 12'hF0F) o_i = o_i + 1;
            end
            if (o_i == 0) begin $display("FAIL idle picture %0d empty", f); e_idle = e_idle + 1; end
        end
        for (f = 0; f < 16; f = f + 1) begin                       // attack and hurt: 4 dirs x 4
            o_a = 0; o_h = 0;
            for (p = 0; p < 1024; p = p + 1) begin
                a_atk = f * 1024 + p; a_hurt = f * 1024 + p; @(posedge clk); #1; @(posedge clk); #1;
                if (^d_atk === 1'bx) xs = xs + 1; else if (d_atk != 12'hF0F) o_a = o_a + 1;
                if (^d_hurt === 1'bx) xs = xs + 1; else if (d_hurt != 12'hF0F) o_h = o_h + 1;
            end
            if (o_a == 0) begin $display("FAIL attack picture %0d empty", f); e_atk = e_atk + 1; end
            if (o_h == 0) begin $display("FAIL hurt picture %0d empty", f); e_hurt = e_hurt + 1; end
        end
        for (f = 0; f < 11; f = f + 1) begin                       // die: pictures 0..10 must show something (11 may be empty)
            o_d = 0;
            for (p = 0; p < 1024; p = p + 1) begin
                a_die = f * 1024 + p; @(posedge clk); #1; @(posedge clk); #1;
                if (^d_die === 1'bx) xs = xs + 1; else if (d_die != 12'hF0F) o_d = o_d + 1;
            end
            if (o_d == 0) begin $display("FAIL die picture %0d empty", f); e_die = e_die + 1; end
        end
        errors = xs + e_idle + e_atk + e_hurt + e_die;
        if (xs) $display("FAIL %0d words are X (short file?)", xs);
        $display("anim ROMs: idle empty = %0d, attack empty = %0d, hurt empty = %0d, die empty = %0d, X words = %0d", e_idle, e_atk, e_hurt, e_die, xs);
        $display("checks = 4  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
