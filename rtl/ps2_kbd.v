// W22: PS/2 keyboard receiver (the Nexys A7 USB-HID port is presented to the FPGA as a PS/2 keyboard on PS2_CLK / PS2_DATA).
// Scan code set 2: frame = start (0), 8 data bits LSB first, odd parity, stop (1); the keyboard drives the clock (about 10-16 kHz) and the data
// bit is valid on the falling clock edge. A key press sends its make code, a release sends F0 + code, arrow keys carry an E0 prefix.
//
// Outputs: level = key held, pulse = one clock on the first make of a key (typematic repeats do not pulse again).
//   walk:  arrows (E0 75 / 72 / 6B / 74) or W A S D (1D / 1B / 1C / 23)
//   atk:   Space (29) or J (3B) or Enter (5A, also E0 5A keypad Enter)      sprint: Left Shift (12) or Right Shift (59)
//   pulses: pause_p = P (4D) or Esc (76)   lock_p = L (4B)   reset_p = R (2D)   clap_p = C (21)
// A frame with a wrong start / parity / stop bit is dropped; a frame that stalls for TIMEOUT clocks is abandoned. Everything is cleared on rst.
module ps2_kbd #(
    parameter TIMEOUT = 200_000,              // 2 ms at 100 MHz: longer than one PS/2 bit (~100 us), so a half frame is dropped
    parameter IDLE_CLR = 200_000_000          // W34: 2 s of silence on the clock while a key is flagged down = released / unplugged -> clear all keys
) (
    input  wire clk,
    input  wire rst,
    input  wire ps2_clk,
    input  wire ps2_data,
    output wire up, down, left, right,        // level
    output wire atk,                          // level (Space / J / Enter)
    output wire sprint,                       // level (Shift)
    output reg  pause_p = 1'b0,               // pulse
    output reg  lock_p  = 1'b0,
    output reg  reset_p = 1'b0,
    output reg  clap_p  = 1'b0,
    output reg  got_key = 1'b0,               // pulse: any valid byte was received (debug / LED)
    output wire clk_act                       // pulse: a falling edge on the keyboard clock (the line is alive, even if the frame is bad)
);
    // ---- synchroniser + falling edge of the keyboard clock ----
    reg [2:0] cs = 3'b111, ds = 3'b111;
    always @(posedge clk) begin cs <= {cs[1:0], ps2_clk}; ds <= {ds[1:0], ps2_data}; end
    wire fall = cs[2] & ~cs[1];
    wire dbit = ds[1];
    assign clk_act = fall;

    // ---- frame shift register ----
    reg [3:0]  bitn = 4'd0;                   // 0 = waiting for the start bit, 1..8 data, 9 parity, 10 stop
    reg [7:0]  sh = 8'd0;
    reg        par = 1'b0;
    reg [17:0] tmo = 18'd0;
    reg        valid = 1'b0;                  // one clock: sh holds a good byte
    always @(posedge clk) begin
        valid <= 1'b0;
        if (rst) begin bitn <= 4'd0; tmo <= 18'd0; end
        else begin
            if (bitn != 0) begin
                tmo <= tmo + 1'b1;
                if (tmo >= TIMEOUT) begin bitn <= 4'd0; tmo <= 18'd0; end
            end
            if (fall) begin
                tmo <= 18'd0;
                case (bitn)
                    4'd0:  if (!dbit) bitn <= 4'd1;                        // start bit must be 0
                    4'd9:  begin par <= dbit; bitn <= 4'd10; end
                    4'd10: begin
                        bitn <= 4'd0;
                        if (dbit && ((^sh) ^ par)) valid <= 1'b1;          // stop = 1 and odd parity
                    end
                    default: begin sh <= {dbit, sh[7:1]}; bitn <= bitn + 1'b1; end
                endcase
            end
        end
    end

    // ---- W34: stuck key guard (a keyboard repeats a held key every 30-100 ms, so a long silence means it was released or unplugged) ----
    reg [27:0] idle = 28'd0;
    reg        clr_all = 1'b0;
    wire       any_down = up | down | left | right | atk | sprint;
    always @(posedge clk) begin
        clr_all <= 1'b0;
        if (rst || fall || !any_down) idle <= 28'd0;
        else if (idle >= IDLE_CLR) begin clr_all <= 1'b1; idle <= 28'd0; end
        else idle <= idle + 1'b1;
    end

    // ---- scan code decoder ----
    reg ext = 1'b0, brk = 1'b0;
    reg k_up_a = 0, k_dn_a = 0, k_lf_a = 0, k_rt_a = 0;       // arrows
    reg k_up_w = 0, k_dn_w = 0, k_lf_w = 0, k_rt_w = 0;       // W A S D
    reg k_sp = 0, k_j = 0, k_en = 0, k_sh = 0;
    reg k_p = 0, k_esc = 0, k_l = 0, k_r = 0, k_c = 0;        // pulse keys: remember "held" so a repeat does not pulse again
    assign up     = k_up_a | k_up_w;
    assign down   = k_dn_a | k_dn_w;
    assign left   = k_lf_a | k_lf_w;
    assign right  = k_rt_a | k_rt_w;
    assign atk    = k_sp | k_j | k_en;
    assign sprint = k_sh;
    wire mk = ~brk;                                           // this code is a make (1) or a break (0)
    always @(posedge clk) begin
        pause_p <= 1'b0; lock_p <= 1'b0; reset_p <= 1'b0; clap_p <= 1'b0; got_key <= 1'b0;
        if (rst || clr_all) begin
            ext <= 1'b0; brk <= 1'b0;
            {k_up_a, k_dn_a, k_lf_a, k_rt_a, k_up_w, k_dn_w, k_lf_w, k_rt_w} <= 8'd0;
            {k_sp, k_j, k_en, k_sh, k_p, k_esc, k_l, k_r, k_c} <= 9'd0;
        end else if (valid) begin
            got_key <= 1'b1;
            if (sh == 8'hE0) ext <= 1'b1;
            else if (sh == 8'hF0) brk <= 1'b1;
            else if (sh == 8'hE1) ext <= 1'b0;                // Pause/Break prefix: ignore
            else begin
                ext <= 1'b0; brk <= 1'b0;
                if (ext) case (sh)
                    8'h75: k_up_a <= mk;
                    8'h72: k_dn_a <= mk;
                    8'h6B: k_lf_a <= mk;
                    8'h74: k_rt_a <= mk;
                    8'h5A: k_en   <= mk;                      // keypad Enter
                    8'h59: k_sh   <= mk;
                    default: ;
                endcase else case (sh)
                    8'h1D: k_up_w <= mk;
                    8'h1B: k_dn_w <= mk;
                    8'h1C: k_lf_w <= mk;
                    8'h23: k_rt_w <= mk;
                    8'h29: k_sp   <= mk;
                    8'h3B: k_j    <= mk;
                    8'h5A: k_en   <= mk;
                    8'h12: k_sh   <= mk;
                    8'h59: k_sh   <= mk;
                    8'h4D: begin k_p   <= mk; if (mk && !k_p)   pause_p <= 1'b1; end
                    8'h76: begin k_esc <= mk; if (mk && !k_esc) pause_p <= 1'b1; end
                    8'h4B: begin k_l   <= mk; if (mk && !k_l)   lock_p  <= 1'b1; end
                    8'h2D: begin k_r   <= mk; if (mk && !k_r)   reset_p <= 1'b1; end
                    8'h21: begin k_c   <= mk; if (mk && !k_c)   clap_p  <= 1'b1; end
                    default: ;
                endcase
            end
        end
    end
endmodule
