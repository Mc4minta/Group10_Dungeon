// synchronizer 2 FF + debounce + rising edge
// CNT_MAX = 1_000_000 -> 10 ms ที่ 100 MHz (simulation ใส่ค่าเล็ก ๆ ได้)
module debounce #(
    parameter CNT_MAX = 1_000_000
) (
    input  wire clk,
    input  wire in,
    output reg  level = 0,   // ค่าหลัง debounce
    output wire rise         // pulse 1 clock ตอนกด
);
    reg s0 = 0, s1 = 0, prev = 0;
    reg [$clog2(CNT_MAX+1)-1:0] cnt = 0;

    always @(posedge clk) begin
        s0 <= in;
        s1 <= s0;
        if (s1 == level) begin
            cnt <= 0;
        end else if (cnt == CNT_MAX) begin
            level <= s1;
            cnt   <= 0;
        end else begin
            cnt <= cnt + 1'b1;
        end
        prev <= level;
    end
    assign rise = level & ~prev;
endmodule
