// W7: ADXL362 accelerometer (Nexys A7 on-board, SPI mode 0, <= 1 MHz). Soft reset -> measurement mode -> burst read of X / Y (8-bit) about 100 times a second.
//   ax / ay : signed 8-bit (about 64 counts = 1 g in the +-2 g range), valid = pulse per new sample
//   ready   : 1 while real samples keep arriving; drops after NODATA_CLKS without a sample, or after DEAD_SAMPLES samples in a row that look like a dead bus (X = Y = 0 or X = Y = -1)
//             = sensor missing / not answering -> top falls back to the buttons
// Timing parameters are overridden by the testbench (fast simulation).
module adxl362 #(
    parameter CLK_DIV     = 50,          // clk / (2 * CLK_DIV) = SCLK: 100 MHz / 100 = 1 MHz
    parameter BOOT_CLKS   = 1_000_000,   // 10 ms after power-up / reset command before the next command
    parameter SAMPLE_CLKS = 1_000_000,   // 100 samples per second
    parameter NODATA_CLKS = 50_000_000,  // 0.5 s without a sample -> not ready
    parameter DEAD_SAMPLES = 32          // this many samples in a row of X = Y = 0 or X = Y = -1 (bus stuck low / high: sensor missing) -> not ready
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ACL_MISO,
    output reg         ACL_MOSI = 1'b0,
    output reg         ACL_SCLK = 1'b0,
    output reg         ACL_CSN  = 1'b1,
    output reg signed [7:0] ax = 0,
    output reg signed [7:0] ay = 0,
    output reg         valid = 1'b0,
    output wire        ready
);
    localparam [3:0] S_BOOT = 0, S_WR1 = 1, S_GAP1 = 2, S_WR2 = 3, S_GAP2 = 4, S_IDLE = 5, S_RD = 6, S_XFER = 7;
    reg [3:0]  st = S_BOOT, nxt = S_BOOT;
    reg [31:0] wait_cnt = 0;
    reg [31:0] sh = 0;                 // transmit shift register (MSB first)
    reg [31:0] rx = 0;
    reg [5:0]  nbits = 0, bitcnt = 0;
    reg [7:0]  div = 0;
    reg [31:0] nodata = 32'hFFFFFFFF;
    reg [7:0]  dead_cnt = 0;
    assign ready = (nodata < NODATA_CLKS) && (dead_cnt < DEAD_SAMPLES);

    always @(posedge clk) begin
        valid <= 1'b0;
        if (rst) begin
            st <= S_BOOT; wait_cnt <= 0; ACL_CSN <= 1'b1; ACL_SCLK <= 1'b0; ACL_MOSI <= 1'b0; nodata <= 32'hFFFFFFFF;
        end else begin
            if (nodata != 32'hFFFFFFFF) nodata <= nodata + 1'b1;
            case (st)
            // (MOSI starts at 0 because the first bit of both commands 0x0A and 0x0B is 0)
            S_BOOT: begin if (wait_cnt >= BOOT_CLKS) begin wait_cnt <= 0; sh <= {8'h0A, 8'h1F, 8'h52, 8'h00}; nbits <= 6'd24; nxt <= S_GAP1; st <= S_XFER; bitcnt <= 0; div <= 0; ACL_CSN <= 1'b0; ACL_MOSI <= 1'b0; end else wait_cnt <= wait_cnt + 1'b1; end
            S_GAP1: begin if (wait_cnt >= BOOT_CLKS) begin wait_cnt <= 0; st <= S_WR2; end else wait_cnt <= wait_cnt + 1'b1; end
            S_WR2:  begin sh <= {8'h0A, 8'h2D, 8'h02, 8'h00}; nbits <= 6'd24; nxt <= S_GAP2; st <= S_XFER; bitcnt <= 0; div <= 0; ACL_CSN <= 1'b0; end
            S_GAP2: begin if (wait_cnt >= BOOT_CLKS) begin wait_cnt <= 0; st <= S_IDLE; end else wait_cnt <= wait_cnt + 1'b1; end
            S_IDLE: begin if (wait_cnt >= SAMPLE_CLKS) begin wait_cnt <= 0; st <= S_RD; end else wait_cnt <= wait_cnt + 1'b1; end
            S_RD:   begin sh <= {8'h0B, 8'h08, 8'h00, 8'h00}; nbits <= 6'd32; nxt <= S_IDLE; st <= S_XFER; bitcnt <= 0; div <= 0; ACL_CSN <= 1'b0; end
            S_XFER: begin
                // first half period: MOSI already driven, SCLK low; rising edge samples MISO, falling edge shifts the next bit
                if (div == CLK_DIV - 1) begin
                    div <= 0;
                    if (!ACL_SCLK) begin                          // rising edge
                        ACL_SCLK <= 1'b1;
                        rx <= {rx[30:0], ACL_MISO};
                        bitcnt <= bitcnt + 1'b1;
                    end else begin                                // falling edge
                        ACL_SCLK <= 1'b0;
                        sh <= {sh[30:0], 1'b0};
                        ACL_MOSI <= sh[30];
                        if (bitcnt == nbits) begin                // all bits clocked: finish
                            ACL_CSN <= 1'b1; ACL_MOSI <= 1'b0; st <= nxt; wait_cnt <= 0;
                            if (nbits == 6'd32) begin             // read: rx[15:8] = X, rx[7:0] = Y
                                ax <= rx[15:8]; ay <= rx[7:0]; valid <= 1'b1; nodata <= 0;
                                if ((rx[15:0] == 16'h0000 || rx[15:0] == 16'hFFFF) && dead_cnt != 8'hFF) dead_cnt <= dead_cnt + 1'b1;
                                else if (!(rx[15:0] == 16'h0000 || rx[15:0] == 16'hFFFF)) dead_cnt <= 0;
                            end
                        end
                    end
                end else div <= div + 1'b1;
            end
            default: st <= S_BOOT;
            endcase
        end
    end
endmodule
