// ตัวทดสอบไมค์แยก (ไม่มีเกม) สำหรับจูน threshold บนบอร์ดจริง — ดู docs/BOARD_DAY.md
//   LED0-15      = แถบ amplitude แบบ log คร่าว ๆ (ขีด 4 8 16 32 64 128 256 384 512 640 768 1024 1280 1536 1792 2000)
//   7-seg ซ้าย 4 หลัก = amplitude ปัจจุบัน (ฐานสิบ, 0..2048), ขวา 4 หลัก = peak ตั้งแต่กด BTNC ครั้งล่าสุด
//   ค้างกด BTND: ขวา 4 หลัก = จำนวนครั้งที่ตบมือ (clap_pulse); BTNC + BTND พร้อมกัน = ล้างตัวนับ
//   threshold TH = SW[10:0] (0..2047); ถ้าสวิตช์ลงหมด (SW[10:0] = 0) ใช้ TH_DEFAULT
//   RGB16 เขียวกะพริบ ~200 ms ตอนตบมือ, RGB17 แดงตอนอยู่ใน holdoff (200 ms หลังตบมือ)
//   amplitude อัปเดตทุก 4096 sample = 1.64 ms
module mic_test_top #(
    parameter DEBOUNCE   = 1_000_000,
    parameter MIC_WINDOW = 4096,
    parameter HOLDOFF    = 20_000_000,    // 200 ms
    parameter TH_DEFAULT = 600,           // เท่า MIC_TH ในเกม; เป็นค่าเดาจากโมเดลในสิมูเลเตอร์ -> ปรับหน้างาน
    parameter FLASH      = 20_000_000
) (
    input  wire        CLK100MHZ,
    input  wire        BTNC, BTND,
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire        LED16_G,
    output wire        LED17_R,
    output wire        CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0]  AN,
    output wire        M_CLK,
    input  wire        M_DATA,
    output wire        M_LRSEL
);
    wire clk = CLK100MHZ;

    wire c_lvl, c_rise, d_lvl;
    debounce #(DEBOUNCE) d_c (.clk(clk), .in(BTNC), .level(c_lvl), .rise(c_rise));
    debounce #(DEBOUNCE) d_d (.clk(clk), .in(BTND), .level(d_lvl), .rise());

    wire [10:0] sw_th = SW[10:0];
    wire [11:0] th = (sw_th == 11'd0) ? TH_DEFAULT : {1'b0, sw_th};

    wire        clap, holdoff, win;
    wire [11:0] amp;
    pdm_mic #(.WINDOW(MIC_WINDOW), .HOLDOFF(HOLDOFF)) mic (
        .clk(clk), .rst(1'b0), .m_clk(M_CLK), .m_data(M_DATA), .m_lrsel(M_LRSEL),
        .clap_pulse(clap), .amplitude(amp), .win_pulse(win), .holdoff(holdoff),
        .th_dyn(th), .use_dyn(1'b1));

    // ---------- peak + จำนวนครั้ง ----------
    reg [11:0] peak = 12'd0;
    reg [13:0] claps = 14'd0;
    always @(posedge clk) begin
        if (c_rise && !d_lvl) peak <= 12'd0;
        else if (win && amp > peak) peak <= amp;
        if (c_rise && d_lvl) claps <= 14'd0;
        else if (clap && claps != 14'd9999) claps <= claps + 1'b1;
    end

    // ---------- LED bar ----------
    assign LED = {amp >= 12'd2000, amp >= 12'd1792, amp >= 12'd1536, amp >= 12'd1280,
                  amp >= 12'd1024, amp >= 12'd768, amp >= 12'd640, amp >= 12'd512,
                  amp >= 12'd384, amp >= 12'd256, amp >= 12'd128, amp >= 12'd64,
                  amp >= 12'd32, amp >= 12'd16, amp >= 12'd8, amp >= 12'd4};

    // ---------- 7-seg ----------
    wire [15:0] bcd_amp, bcd_peak, bcd_cnt;
    bin2bcd b_a (.clk(clk), .bin({2'b00, amp}),  .bcd(bcd_amp));
    bin2bcd b_p (.clk(clk), .bin({2'b00, peak}), .bcd(bcd_peak));
    bin2bcd b_c (.clk(clk), .bin(claps),         .bcd(bcd_cnt));
    wire [15:0] right = d_lvl ? bcd_cnt : bcd_peak;
    wire [31:0] digits = {bcd_amp, right};
    seg7 s7 (.clk(clk), .digits(digits), .dots(d_lvl ? 8'b0000_0001 : 8'h00), .seg({CG, CF, CE, CD, CC, CB, CA}), .an(AN), .dp(DP));

    // ---------- RGB LED (สว่างมาก: duty ~6%) ----------
    reg [7:0] pwm = 8'd0;
    always @(posedge clk) pwm <= pwm + 1'b1;
    wire dim = (pwm < 8'd16);
    reg [24:0] fl = 25'd0;
    always @(posedge clk) begin
        if (clap) fl <= FLASH;
        else if (fl != 0) fl <= fl - 1'b1;
    end
    assign LED16_G = dim & (fl != 0);
    assign LED17_R = dim & holdoff;
endmodule
