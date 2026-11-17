// ไมค์ PDM บนบอร์ด (ADMP421) -> clap_pulse
//
//   M_CLK   = 100 MHz / MIC_CLK_DIV = 2.5 MHz (low ครึ่งแรก, high ครึ่งหลังของคาบ)
//   M_LRSEL = 0 (ช่องซ้าย): ADMP421 ส่ง bit หลังขอบขาลงของ M_CLK และค้างไว้จนถึงขอบขาขึ้น
//             -> อ่านที่ขอบขาขึ้น (Nexys A7 reference manual: L/R select ต่ำ = ข้อมูลใช้ได้ตอนขอบขาขึ้น)
//             เราอ่านจาก M_DATA ที่ผ่าน sync 2 FF แล้ว ตรงจังหวะที่ M_CLK ขึ้น + 2 clock (ชดเชย 2 FF)
//   นับ bit 1 ใน MIC_WINDOW sample (4096 = 1.64 ms) -> amplitude = |ones - 2048|
//   amplitude > MIC_TH -> clap_pulse 1 clock แล้วไม่สนอีก MIC_HOLDOFF clock (200 ms)
//   (เสียงเงียบ PDM ใกล้ 50% ones: amplitude ~ 0..100; เสียงตบมือใกล้ไมค์ทำให้ความหนาแน่นเบี้ยวมาก)
module pdm_mic #(
    parameter CLK_DIV = 40,
    parameter WINDOW  = 4096,
    parameter TH      = 600,
    parameter HOLDOFF = 20000000
) (
    input  wire        clk,
    input  wire        rst,
    output reg         m_clk = 1'b0,
    input  wire        m_data,
    output wire        m_lrsel,
    output reg         clap_pulse = 1'b0,
    output reg  [11:0] amplitude = 0       // ค่าล่าสุด (debug / LED)
);
    assign m_lrsel = 1'b0;

    reg [5:0]  div = 0;
    reg        d0 = 1'b0, d1 = 1'b0;      // sync 2 FF
    reg [12:0] nsamp = 0, ones = 0;
    reg [24:0] hold = 0;
    wire [12:0] half = WINDOW / 2;

    always @(posedge clk) begin
        d0 <= m_data;
        d1 <= d0;
        clap_pulse <= 1'b0;
        if (hold != 0) hold <= hold - 1'b1;

        if (rst) begin
            div <= 0; m_clk <= 1'b0; nsamp <= 0; ones <= 0; hold <= 0;
        end else begin
            div <= (div == CLK_DIV - 1) ? 6'd0 : div + 1'b1;
            if (div == CLK_DIV / 2 - 1) m_clk <= 1'b1;              // ขอบขาขึ้น
            if (div == CLK_DIV - 1)     m_clk <= 1'b0;              // ขอบขาลง
            if (div == CLK_DIV / 2 + 1) begin                       // ขาขึ้น + 2 clock: ค่าที่ผ่าน 2 FF
                if (nsamp == WINDOW - 1) begin
                    amplitude <= ((ones + d1) > half) ? (ones + d1 - half) : (half - ones - d1);
                    if ((((ones + d1) > half) ? (ones + d1 - half) : (half - ones - d1)) > TH && hold == 0) begin
                        clap_pulse <= 1'b1;
                        hold <= HOLDOFF;
                    end
                    nsamp <= 0; ones <= 0;
                end else begin
                    nsamp <= nsamp + 1'b1;
                    ones <= ones + d1;
                end
            end
        end
    end
endmodule
