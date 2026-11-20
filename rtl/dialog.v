// W16: dialogue boxes. Messages come from docs/STORY.md (scripts/build_story.py -> mem/dlg.mem + rtl/dlg_cfg.vh).
//
// ev[]   : one-clock pulses of game events (order = story.EVENTS, localparams EV_* in dlg_cfg.vh)
// A message is shown once per game: when its trigger (an event, or the end of the message it follows) fires it becomes "pending";
// the oldest pending message is shown at the bottom of the screen (the renderer draws a black band + the two lines):
//   timed message  : DLG_FRAMES game frames, then it disappears by itself (the game keeps running)
//   blocking (!)   : the game is frozen (block = 1) until the player presses BTNC (advance)
// en = messages may be shown now (PLAY / maze, not paused); while en = 0 the timer and the message wait.
module dialog (
    input  wire        clk,
    input  wire        rst,
    input  wire        restart,        // new game: forget what was shown
    input  wire        frame_tick,
    input  wire        en,
    input  wire [63:0] ev,
    input  wire        advance,        // BTNC rise
    output wire        show,
    output wire        block,
    output wire [11:0] b0, b1,         // text ROM addresses of line 1 / line 2
    output wire [4:0]  n0, n1,         // characters in each line
    output wire [1:0]  spk             // 0 Player, 1 Voice, 2 System
);
    `include "params.vh"
    `include "dlg_cfg.vh"

    reg [39:0] rom [0:127];
    initial $readmemh("dlg.mem", rom);

    reg [127:0] pend = 128'd0, done = 128'd0, fin = 128'd0;
    reg         active = 1'b0;
    reg [6:0]   cur = 7'd0, scan = 7'd0;
    reg [8:0]   tmr = 9'd0;
    wire [39:0] ent = rom[cur];
    assign b0 = ent[11:0];  assign n0 = ent[16:12];
    assign b1 = ent[28:17]; assign n1 = ent[33:29];
    assign spk = ent[35:34];
    wire blk_entry = ent[36];
    assign show  = active && en;
    assign block = active && en && blk_entry;

    wire [127:0] trig = dlg_trigs(ev, fin);
    reg  [127:0] pend_n;
    always @(posedge clk) begin
        fin <= 128'd0;
        if (rst || restart) begin
            pend <= 128'd0; done <= 128'd0; active <= 1'b0; scan <= 7'd0; tmr <= 9'd0;
        end else begin
            pend_n = pend | (trig & ~done);
            if (!active) begin
                if (NDLG != 0) scan <= (scan >= NDLG - 1) ? 7'd0 : scan + 7'd1;
                if (en && NDLG != 0 && pend_n[scan] && !done[scan]) begin
                    active <= 1'b1; cur <= scan; tmr <= 9'd0;
                    pend_n[scan] = 1'b0; done[scan] <= 1'b1;
                end
            end else if (blk_entry) begin
                if (en && advance) begin active <= 1'b0; fin[cur] <= 1'b1; end
            end else if (en && frame_tick) begin
                if (tmr == DLG_FRAMES - 1) begin active <= 1'b0; fin[cur] <= 1'b1; end
                else tmr <= tmr + 9'd1;
            end
            pend <= pend_n;
        end
    end
endmodule
