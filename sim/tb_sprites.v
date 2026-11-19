`timescale 1ns/1ps
// ตรวจ mem/player.mem ผ่าน player_rom จริง: ไม่มี X, ทุกเฟรมมีพิกเซลที่ไม่ใช่สีคีย์ (F0F),
// มีสีคีย์ในแต่ละเฟรม (พื้นหลังโปร่งใส), ไม่มี word ที่เป็น X
// รัน: ./scripts/run_sim.sh sprites
module tb_sprites;
    reg clk = 0; always #5 clk = ~clk;
    reg [15:0] addr = 0; wire [11:0] data;
    player_rom dut(.clk(clk), .addr(addr), .data(data));
    integer f, p, errors = 0, empty = 0, nokey = 0, xs = 0;
    integer opaque, keyc;
    initial begin
        for (f = 0; f < 48; f = f + 1) begin
            opaque = 0; keyc = 0;
            for (p = 0; p < 1024; p = p + 1) begin
                addr = f * 1024 + p;
                @(posedge clk); #1;   // 1 clock latency (BRAM)
                @(posedge clk); #1;
                if (^data === 1'bx) xs = xs + 1;
                else if (data == 12'hF0F) keyc = keyc + 1;
                else opaque = opaque + 1;
            end
            if (opaque == 0) begin $display("FAIL frame %0d fully transparent", f); empty = empty + 1; end
            if (keyc == 0)   begin $display("FAIL frame %0d has no key colour pixel", f); nokey = nokey + 1; end
        end
        errors = xs + empty + nokey;
        if (xs) $display("FAIL %0d words are X (short file?)", xs);
        $display("sprites: 48 frames checked, empty = %0d, no-key = %0d, X words = %0d", empty, nokey, xs);
        $display("checks = 48  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
