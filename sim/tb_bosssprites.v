`timescale 1ns/1ps
// Check mem/boss.mem through the real bossspr_rom: 6 used frames (3 bosses x 2) of 64x64 load without X,
// each has opaque pixels and key-colour (F0F) background. Run: ./scripts/run_sim.sh bosssprites
module tb_bosssprites;
    reg clk = 0; always #5 clk = ~clk;
    reg [14:0] addr = 0; wire [11:0] data;
    bossspr_rom dut(.clk(clk), .addr(addr), .data(data));
    integer f, p, errors = 0, xs = 0, empty = 0, nokey = 0, opaque, keyc;
    initial begin
        for (f = 0; f < 8; f = f + 1) begin
            opaque = 0; keyc = 0;
            for (p = 0; p < 4096; p = p + 1) begin
                addr = f * 4096 + p;
                @(posedge clk); #1; @(posedge clk); #1;
                if (^data === 1'bx) xs = xs + 1;
                else if (data == 12'hF0F) keyc = keyc + 1;
                else opaque = opaque + 1;
            end
            if (f < 6 && opaque == 0) begin $display("FAIL frame %0d fully transparent", f); empty = empty + 1; end
            if (f < 6 && keyc == 0)   begin $display("FAIL frame %0d has no key colour", f); nokey = nokey + 1; end
        end
        errors = xs + empty + nokey;
        if (xs) $display("FAIL %0d words are X (short file?)", xs);
        $display("boss: 6 frames checked, empty = %0d, no-key = %0d, X words = %0d", empty, nokey, xs);
        $display("checks = 6  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
