// W16 / W31: dialogue boxes. Messages come from docs/STORY.md (scripts/build_story.py -> mem/dlg.mem + rtl/dlg_cfg.vh).
//
// ev[]   : one-clock pulses of game events (order = story.EVENTS, localparams EV_* in dlg_cfg.vh)
// A message is shown once per game: when its trigger (an event, or the end of the message it follows) fires it is put into a FIFO of 8
// (W31: shown in the order it happened, not in ID order); the oldest one is shown at the bottom of the screen (the renderer draws a black band + two lines).
//   W31: EVERY box freezes the game (block = 1) and the top module ignores the player while it is open (except pause):
//   timed message  : closes by itself after DLG_FRAMES frames (2.5 s, counted while the game is frozen) or when the player presses advance
//   blocking (!)   : waits for advance (BTNC / Space / Enter)
// en = messages may be shown now (PLAY / maze, not paused); while en = 0 the timer and the message wait.
// Entries whose trigger is  hint:<name>  are never shown here: they are one-line texts for the hint strip, read through hint_idx / hb0.. (W32).
module dialog (
    input  wire        clk,
    input  wire        rst,
    input  wire        restart,        // new game: forget what was shown
    input  wire        frame_tick,
    input  wire        en,
    input  wire [63:0] ev,
    input  wire        advance,        // BTNC rise (or the auto-repeat of a long press)
    output wire        show,
    output wire        block,
    output wire [11:0] b0, b1,         // text ROM addresses of line 1 / line 2
    output wire [4:0]  n0, n1,         // characters in each line
    output wire [1:0]  spk,            // 0 Player, 1 Voice, 2 System
    input  wire [6:0]  hint_idx,       // W32: which hint text to read (index in dlg.mem, HINT_* in dlg_cfg.vh)
    output wire [11:0] hb0, hb1,
    output wire [4:0]  hn0, hn1
);
    `include "params.vh"
    `include "dlg_cfg.vh"

    reg [39:0] rom [0:127];
    initial $readmemh("dlg.mem", rom);
    wire [39:0] hent = rom[hint_idx];
    assign hb0 = hent[11:0];  assign hn0 = hent[16:12];
    assign hb1 = hent[28:17]; assign hn1 = hent[33:29];

    reg [127:0] pend = 128'd0, done = 128'd0, fin = 128'd0, stg = 128'd0;   // pend = staged or queued (so it is not triggered twice)
    reg         active = 1'b0;
    reg [6:0]   cur = 7'd0, scan = 7'd0;
    reg [8:0]   tmr = 9'd0;
    // FIFO of the next messages
    reg [6:0]   q0 = 0, q1 = 0, q2 = 0, q3 = 0, q4 = 0, q5 = 0, q6 = 0, q7 = 0;
    reg [2:0]   rp = 3'd0, wp = 3'd0;
    reg [3:0]   qn = 4'd0;
    function [6:0] qread(input [2:0] p);
        case (p) 3'd0: qread = q0; 3'd1: qread = q1; 3'd2: qread = q2; 3'd3: qread = q3;
                 3'd4: qread = q4; 3'd5: qread = q5; 3'd6: qread = q6; default: qread = q7; endcase
    endfunction
    wire [39:0] ent = rom[cur];
    assign b0 = ent[11:0];  assign n0 = ent[16:12];
    assign b1 = ent[28:17]; assign n1 = ent[33:29];
    assign spk = ent[35:34];
    wire blk_entry = ent[36];
    assign show  = active && en;
    assign block = active && en;                       // W31: every message freezes the game

    wire [127:0] trig = dlg_trigs(ev, fin);
    wire [127:0] newt = trig & ~done & ~pend;
    wire         push = stg[scan] && (qn < 4'd8);
    wire         pop  = !active && en && (qn != 4'd0);
    always @(posedge clk) begin
        fin <= 128'd0;
        if (rst || restart) begin
            pend <= 128'd0; done <= 128'd0; stg <= 128'd0; active <= 1'b0; scan <= 7'd0; tmr <= 9'd0; rp <= 3'd0; wp <= 3'd0; qn <= 4'd0;
        end else begin
            pend <= pend | newt;
            stg  <= (stg | newt) & ~(push ? (128'd1 << scan) : 128'd0);
            if (NDLG != 0) scan <= (scan >= NDLG - 1) ? 7'd0 : scan + 7'd1;
            if (push) begin
                case (wp) 3'd0: q0 <= scan; 3'd1: q1 <= scan; 3'd2: q2 <= scan; 3'd3: q3 <= scan;
                          3'd4: q4 <= scan; 3'd5: q5 <= scan; 3'd6: q6 <= scan; default: q7 <= scan; endcase
                wp <= wp + 3'd1;
            end
            qn <= qn + (push ? 4'd1 : 4'd0) - (pop ? 4'd1 : 4'd0);
            if (pop) begin
                cur <= qread(rp); rp <= rp + 3'd1; active <= 1'b1; tmr <= 9'd0;
                done[qread(rp)] <= 1'b1;
            end else if (active) begin
                if (en && advance) begin active <= 1'b0; fin[cur] <= 1'b1; end             // a press closes any box
                else if (!blk_entry && en && frame_tick) begin
                    if (tmr == DLG_FRAMES - 1) begin active <= 1'b0; fin[cur] <= 1'b1; end   // timed box: 2.5 s
                    else tmr <= tmr + 9'd1;
                end
            end
        end
    end
endmodule
