`timescale 1ns/1ps
// Check mem/tileset.mem through the real tileset_rom: all 49152 words load (no X = file is complete),
// and not (almost) every tile is a single flat colour (= blank / zero-filled file). A few flat tiles are legal
// art (e.g. the hole, a plain plate) and are only reported as NOTE. Run: ./scripts/run_sim.sh tileset
module tb_tileset;
    reg clk = 0; always #5 clk = ~clk;
    reg [15:0] addr = 0; wire [11:0] data;
    tileset_rom dut(.clk(clk), .addr(addr), .data(data));
    integer t, p, xs = 0, errors = 0, flat = 0;
    reg [11:0] first; reg differs;
    initial begin
        for (t = 0; t < 48; t = t + 1) begin
            differs = 0;
            for (p = 0; p < 1024; p = p + 1) begin
                addr = t * 1024 + p;
                @(posedge clk); #1;
                @(posedge clk); #1;
                if (^data === 1'bx) xs = xs + 1;
                else begin
                    if (p == 0) first = data;
                    else if (data != first) differs = 1;
                end
            end
            if (!differs && (t % 16) != 5) begin
                $display("NOTE tile %0d (floor %0d tile id %0d) is one flat colour", t, t / 16 + 1, t % 16);
                flat = flat + 1;
            end
        end
        errors = xs + ((flat > 9) ? flat : 0);   // more than 3 flat tiles per floor = blank file
        if (xs) $display("FAIL %0d words are X (short file?)", xs);
        $display("tileset: 48 tiles checked, flat = %0d, X words = %0d", flat, xs);
        $display("checks = 48  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
