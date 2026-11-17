// 7-segment 8 หลัก สแกนทีละหลัก (active-low ทั้ง segment และ anode)
// ค่าต่อหลัก 4 bit: 0-9 ตัวเลข, E = '-', F = ดับ
// dots[7:0]: จุดทศนิยมต่อหลัก (active-high เข้า, dp ออก active-low ไป DP)
module seg7 (
    input  wire        clk,
    input  wire [31:0] digits,      // {d7, d6, ..., d0}, d7 = ซ้ายสุด
    input  wire [7:0]  dots,        // จุดต่อหลัก, bit 7 = d7
    output reg  [6:0]  seg = 7'h7F, // {CG,CF,CE,CD,CC,CB,CA}
    output reg  [7:0]  an  = 8'hFF,
    output reg         dp  = 1'b1   // active-low
);
    reg [16:0] cnt = 0;             // 100 MHz / 2^17 ~ 763 Hz ต่อหลัก
    reg [2:0]  sel = 0;
    always @(posedge clk) begin
        cnt <= cnt + 1'b1;
        if (cnt == 0) sel <= sel + 1'b1;
    end

    wire [3:0] d = digits[sel*4 +: 4];
    always @(posedge clk) begin
        an <= ~(8'b1 << sel);
        dp <= ~dots[sel];
        case (d)          //   gfedcba (active-low)
            4'h0: seg <= 7'b1000000;
            4'h1: seg <= 7'b1111001;
            4'h2: seg <= 7'b0100100;
            4'h3: seg <= 7'b0110000;
            4'h4: seg <= 7'b0011001;
            4'h5: seg <= 7'b0010010;
            4'h6: seg <= 7'b0000010;
            4'h7: seg <= 7'b1111000;
            4'h8: seg <= 7'b0000000;
            4'h9: seg <= 7'b0010000;
            4'hE: seg <= 7'b0111111;   // '-'
            default: seg <= 7'b1111111;
        endcase
    end
endmodule
