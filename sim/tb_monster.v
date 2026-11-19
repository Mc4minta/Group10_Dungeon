`timescale 1ns/1ps
// Check mem/monster.mem through the real monster_rom: 4 frames (A0 A1 B0 B1) load without X,
// each frame has opaque pixels AND key-colour (F0F) background. Run: ./scripts/run_sim.sh monster
module tb_monster;
    reg clk = 0; always #5 clk = ~clk;
    reg [11:0] addr = 0; wire [11:0] data;
    monster_rom dut(.clk(clk), .addr(addr), .data(data));
    integer f, p, errors = 0, xs = 0, empty = 0, nokey = 0, opaque, keyc;
    initial begin
        for (f = 0; f < 4; f = f + 1) begin
            opaque = 0; keyc = 0;
            for (p = 0; p < 1024; p = p + 1) begin
                addr = f * 1024 + p;
                @(posedge clk); #1; @(posedge clk); #1;
                if (^data === 1'bx) xs = xs + 1;
                else if (data == 12'hF0F) keyc = keyc + 1;
                else opaque = opaque + 1;
            end
            if (opaque == 0) begin $display("FAIL frame %0d fully transparent", f); empty = empty + 1; end
            if (keyc == 0)   begin $display("FAIL frame %0d has no key colour", f); nokey = nokey + 1; end
        end
        errors = xs + empty + nokey;
        if (xs) $display("FAIL %0d words are X (short file?)", xs);
        $display("monster: 4 frames checked, empty = %0d, no-key = %0d, X words = %0d", empty, nokey, xs);
        $display("checks = 4  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
