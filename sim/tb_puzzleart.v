`timescale 1ns/1ps
// Check mem/puzzle.mem through the real puzzle_rom: the 10 used frames load without X and each has opaque pixels.
// Run: ./scripts/run_sim.sh puzzleart
module tb_puzzleart;
    reg clk = 0; always #5 clk = ~clk;
    reg [13:0] addr = 0; wire [11:0] data;
    puzzle_rom dut(.clk(clk), .addr(addr), .data(data));
    integer f, p, errors = 0, xs = 0, empty = 0, opaque;
    initial begin
        for (f = 0; f < 10; f = f + 1) begin
            opaque = 0;
            for (p = 0; p < 1024; p = p + 1) begin
                addr = f * 1024 + p;
                @(posedge clk); #1; @(posedge clk); #1;
                if (^data === 1'bx) xs = xs + 1;
                else if (data != 12'hF0F) opaque = opaque + 1;
            end
            if (opaque == 0) begin $display("FAIL frame %0d fully transparent", f); empty = empty + 1; end
        end
        errors = xs + empty;
        if (xs) $display("FAIL %0d words are X (short file?)", xs);
        $display("puzzle: 10 frames checked, empty = %0d, X words = %0d", empty, xs);
        $display("checks = 10  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
