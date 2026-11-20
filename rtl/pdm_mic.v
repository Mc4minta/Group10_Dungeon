// PDM microphone on the board (ADMP421) -> clap_pulse + amplitude (for the on-screen mic meter)
//
//   M_CLK   = 100 MHz / MIC_CLK_DIV = 2.5 MHz (low first half, high second half of the period)
//   M_LRSEL = 0 (left channel): the ADMP421 drives its bit after the falling edge of M_CLK and holds it until the rising edge
//             -> read at the rising edge; M_DATA goes through a 2 FF synchroniser, so it is sampled at M_CLK rising + 2 clocks.
//
//   W4 FIX (20/11): the first version looked at |ones - 2048| over a whole 1.64 ms window = the DC level of the PDM stream. A real microphone signal is
//   AC: the density of ones swings around 50 % at the sound frequency, so the average over 1.64 ms is about 0 for any sound, and the detector could
//   never fire on the board (the simulation fed a DC-biased stream, which hid the problem). Now:
//     1. the PDM stream is cut into blocks of 64 samples (25.6 us); ones per block (0..64) = a 39 kHz audio sample (a CIC-like decimator),
//     2. a slow average (time constant 128 blocks = 3.3 ms) is the DC level (the microphone's resting density), and
//        env = |block - DC| (0..64) is the instantaneous loudness with the DC removed,
//     3. the peak of env over one window (WINDOW / 64 blocks = 64 blocks = 1.64 ms) x 64 = amplitude (0..4095; a silent mic reads 0..2 x 64, a clap
//        close to the board reads several hundred to 2000),
//     4. amplitude > TH -> clap_pulse (1 clock), then ignored for HOLDOFF clocks (200 ms).
module pdm_mic #(
    parameter CLK_DIV = 40,
    parameter WINDOW  = 4096,
    parameter TH      = 448,
    parameter HOLDOFF = 20000000
) (
    input  wire        clk,
    input  wire        rst,
    output reg         m_clk = 1'b0,
    input  wire        m_data,
    output wire        m_lrsel,
    output reg         clap_pulse = 1'b0,
    output reg  [11:0] amplitude = 0,      // latest window peak (debug / LED / mic meter)
    output reg         win_pulse = 1'b0,   // one clock every time amplitude is updated (every WINDOW samples)
    output wire        holdoff,            // 1 during the 200 ms after a clap
    input  wire [11:0] th_dyn,             // adjustable threshold (used when use_dyn = 1)
    input  wire        use_dyn
);
    assign m_lrsel = 1'b0;

    localparam BLK  = 64;                   // PDM samples per block
    localparam NBLK = WINDOW / BLK;         // blocks per window

    reg [5:0]  div = 0;
    reg        d0 = 1'b0, d1 = 1'b0;        // sync 2 FF
    reg [6:0]  bcnt = 0, bones = 0;         // sample / ones counters inside a block
    reg [6:0]  wcnt = 0;                    // blocks inside the window
    reg [16:0] dc = 17'd32768;              // DC level of the block count, x1024 (start at 32 = half of 64)
    reg [6:0]  pk = 0;                      // peak env in this window
    reg [24:0] hold = 0;
    wire [11:0] th_eff = use_dyn ? th_dyn : TH;
    assign holdoff = (hold != 0);

    // block finished on this clock (valid when div hits the sample point)
    wire [6:0]  total  = bones + d1;                           // 0..64 ones in the block
    wire [16:0] blk_s  = {total, 10'd0};                       // x1024
    wire [16:0] diff   = (blk_s > dc) ? blk_s - dc : dc - blk_s;
    wire [6:0]  env    = diff[16:10];                          // |block - DC| in ones (0..64)
    wire [6:0]  pk_new = (env > pk) ? env : pk;
    wire [12:0] amp_w  = {pk_new, 6'd0};                       // x64
    wire [11:0] amp_n  = (amp_w > 13'd4095) ? 12'd4095 : amp_w[11:0];
    wire [16:0] dc_step = diff >> 7;

    always @(posedge clk) begin
        d0 <= m_data;
        d1 <= d0;
        clap_pulse <= 1'b0;
        win_pulse <= 1'b0;
        if (hold != 0) hold <= hold - 1'b1;

        if (rst) begin
            div <= 0; m_clk <= 1'b0; bcnt <= 0; bones <= 0; wcnt <= 0; pk <= 0; hold <= 0; dc <= 17'd32768;
        end else begin
            div <= (div == CLK_DIV - 1) ? 6'd0 : div + 1'b1;
            if (div == CLK_DIV / 2 - 1) m_clk <= 1'b1;              // rising edge
            if (div == CLK_DIV - 1)     m_clk <= 1'b0;              // falling edge
            if (div == CLK_DIV / 2 + 1) begin                       // rising edge + 2 clocks: the value that went through the 2 FF
                if (bcnt == BLK - 1) begin                          // block done
                    bcnt <= 0; bones <= 0;
                    dc <= (blk_s > dc) ? dc + dc_step : dc - dc_step;
                    if (wcnt == NBLK - 1) begin                     // window done
                        amplitude <= amp_n;
                        win_pulse <= 1'b1;
                        if (amp_n > th_eff && hold == 0) begin
                            clap_pulse <= 1'b1;
                            hold <= HOLDOFF;
                        end
                        wcnt <= 0; pk <= 0;
                    end else begin
                        wcnt <= wcnt + 1'b1; pk <= pk_new;
                    end
                end else begin
                    bcnt <= bcnt + 1'b1;
                    bones <= bones + d1;
                end
            end
        end
    end
endmodule
