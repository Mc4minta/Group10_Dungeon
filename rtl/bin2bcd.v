// แปลงเลขฐานสอง 14 bit (0..9999 ใช้งาน) เป็น BCD 4 หลัก แบบ shift-add-3 ทีละบิต (14 clock) — ไม่มี logic ยาวใน clock เดียว
// ใส่ค่าเข้า `bin` ค้างไว้ได้ตลอด: แปลงซ้ำต่อเนื่อง ผลลัพธ์ `bcd` อัปเดตทุก ~16 clock (ค่าเปลี่ยนช้า ไม่เป็นปัญหา)
module bin2bcd (
    input  wire        clk,
    input  wire [13:0] bin,
    output reg  [15:0] bcd = 16'd0
);
    reg [13:0] sh  = 14'd0;
    reg [15:0] acc = 16'd0;
    reg [3:0]  n   = 4'd0;
    wire [15:0] adj = {acc[15:12] > 4'd4 ? acc[15:12] + 4'd3 : acc[15:12],
                       acc[11:8]  > 4'd4 ? acc[11:8]  + 4'd3 : acc[11:8],
                       acc[7:4]   > 4'd4 ? acc[7:4]   + 4'd3 : acc[7:4],
                       acc[3:0]   > 4'd4 ? acc[3:0]   + 4'd3 : acc[3:0]};
    always @(posedge clk) begin
        if (n == 4'd0) begin
            sh <= bin; acc <= 16'd0; n <= 4'd1;
        end else if (n <= 4'd14) begin
            acc <= {adj[14:0], sh[13]};
            sh  <= {sh[12:0], 1'b0};
            n   <= n + 1'b1;
        end else begin
            bcd <= acc; n <= 4'd0;
        end
    end
endmodule
