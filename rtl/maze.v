// W7: Ball in a Maze. A ball (20x20 box, fixed point 1/16 px) rolls through the maze in mem/maze.mem (20x15 tiles: 0 floor, 1 wall, 2 goal, 3 start)
// driven by the board tilt (ADXL362 X / Y, offset calibrated on the first 32 samples when the maze starts, dead zone) or by the four buttons
// (use_btn = SW10 or the sensor is not answering). Physics per frame_tick: v += a, friction v -= v/16, speed clamp, move one axis at a time
// with a 4-corner wall check (the axis speed is zeroed when blocked), goal = ball centre on the goal tile.
module maze #(
    parameter DEADZONE   = 3,            // |tilt| below this counts as flat (8-bit counts, about 64 per g)
    parameter TILT_SHIFT = 2,            // acceleration = tilt >> TILT_SHIFT  (1/16 px per frame^2)
    parameter BTN_ACC    = 8,            // acceleration from a held button
    parameter MAXV       = 96,           // speed clamp (1/16 px per frame) = 6 px / frame
    parameter SIGN_X     = 1,            // 1 / 0: invert the X axis (board mounting; fix on the board, see params.vh)
    parameter SIGN_Y     = 1,
    parameter CAL_N      = 32
) (
    input  wire              clk,
    input  wire              rst,
    input  wire              frame_tick,
    input  wire              run,                // maze phase (game_fsm ESCAPE)
    input  wire              start,              // pulse: maze begins -> ball on the start tile, re-calibrate
    input  wire signed [7:0] ax, ay,             // accelerometer samples
    input  wire              sample_valid,
    input  wire              use_btn,
    input  wire              bu, bd, bl, br,
    output wire [9:0]        bx, by,             // top-left of the ball box in pixels
    output reg               goal = 1'b0         // pulse: the ball reached the goal
);
    localparam [13:0] START16 = (14'd32 + 14'd6) * 14'd16;      // tile (1, 1) + 6 px: ball box centred in the 32 px tile
    localparam BS = 20;                                         // ball box size

    reg [13:0] px16 = START16, py16 = START16;
    reg signed [11:0] vx = 0, vy = 0;
    assign bx = px16[13:4];
    assign by = py16[13:4];

    // ---------- tilt calibration (average of the first CAL_N samples after start) ----------
    reg [5:0]  cal_n = 0;
    reg signed [15:0] sumx = 0, sumy = 0;
    reg signed [7:0]  offx = 0, offy = 0;
    wire calibrated = (cal_n >= CAL_N);
    always @(posedge clk) begin
        if (rst || start) begin cal_n <= 0; sumx <= 0; sumy <= 0; offx <= 0; offy <= 0; end
        else if (sample_valid && !calibrated) begin
            sumx <= sumx + ax; sumy <= sumy + ay; cal_n <= cal_n + 1'b1;
            if (cal_n == CAL_N - 1) begin offx <= (sumx + ax) >>> 5; offy <= (sumy + ay) >>> 5; end
        end
    end
    // latest tilt, zero inside the dead zone
    reg signed [8:0] tx = 0, ty = 0;
    wire signed [8:0] dx = ax - offx, dy = ay - offy;
    always @(posedge clk) if (sample_valid) begin
        tx <= (!calibrated) ? 9'sd0 : (dx > -DEADZONE && dx < DEADZONE) ? 9'sd0 : dx;
        ty <= (!calibrated) ? 9'sd0 : (dy > -DEADZONE && dy < DEADZONE) ? 9'sd0 : dy;
    end
    wire signed [11:0] acc_tx = (SIGN_X != 0) ? (tx >>> TILT_SHIFT) : -(tx >>> TILT_SHIFT);
    wire signed [11:0] acc_ty = (SIGN_Y != 0) ? (ty >>> TILT_SHIFT) : -(ty >>> TILT_SHIFT);
    wire signed [11:0] acc_bx = br ? BTN_ACC : bl ? -BTN_ACC : 0;
    wire signed [11:0] acc_by = bd ? BTN_ACC : bu ? -BTN_ACC : 0;
    wire signed [11:0] accx = use_btn ? acc_bx : acc_tx;
    wire signed [11:0] accy = use_btn ? acc_by : acc_ty;

    // ---------- wall ROM ----------
    reg  [8:0] ma = 0;
    wire [1:0] md;
    maze_rom mrom (.addr(ma), .data(md));
    function [8:0] tile_addr(input [9:0] x, input [9:0] y);      // pixel -> tile index (row * 20 + col)
        tile_addr = ({4'd0, y[8:5]} << 4) + ({4'd0, y[8:5]} << 2) + {4'd0, x[9:5]};
    endfunction

    // ---------- per-frame FSM ----------
    localparam [3:0] M_IDLE = 0, M_VEL = 1, M_XSET = 2, M_XGET = 3, M_XEND = 4, M_YSET = 5, M_YGET = 6, M_YEND = 7, M_GOAL = 8, M_GOAL2 = 9;
    reg [3:0]  st = M_IDLE;
    reg [1:0]  c = 0;
    reg        blk = 1'b0;
    reg [13:0] n16 = 0;
    reg signed [11:0] nv;
    wire [9:0] nxi = n16[13:4];
    wire [9:0] cx = (c[0]) ? nxi + BS - 1 : nxi;                    // corners: c0 (x0,y0) c1 (x1,y0) c2 (x0,y1) c3 (x1,y1)
    wire [9:0] cy = (c[1]) ? by + BS - 1 : by;
    wire [9:0] cxy = (c[0]) ? bx + BS - 1 : bx;                    // Y-axis phase: x fixed, y moves
    wire [9:0] cyy = (c[1]) ? nxi + BS - 1 : nxi;

    always @(posedge clk) begin
        goal <= 1'b0;
        if (rst || start) begin
            px16 <= START16; py16 <= START16; vx <= 0; vy <= 0; st <= M_IDLE;
        end else case (st)
            M_IDLE: if (frame_tick && run) st <= M_VEL;
            M_VEL: begin
                // v = (v + a) - (v + a) / 16, clamped
                nv = vx + accx; nv = nv - (nv >>> 4);
                vx <= (nv > MAXV) ? MAXV : (nv < -MAXV) ? -MAXV : nv;
                nv = vy + accy; nv = nv - (nv >>> 4);
                vy <= (nv > MAXV) ? MAXV : (nv < -MAXV) ? -MAXV : nv;
                st <= M_XSET; c <= 0; blk <= 1'b0;
                n16 <= px16 + {{2{vx[11]}}, vx} ;                  // (uses the old vx for one frame: fine, friction is smooth)
            end
            M_XSET: begin ma <= tile_addr(cx, cy); st <= M_XGET; end
            M_XGET: begin
                if (md == 2'd1) blk <= 1'b1;
                if (c == 2'd3) st <= M_XEND; else begin c <= c + 1'b1; st <= M_XSET; end
            end
            M_XEND: begin
                if (blk) vx <= 0; else px16 <= n16;
                n16 <= py16 + {{2{vy[11]}}, vy};
                st <= M_YSET; c <= 0; blk <= 1'b0;
            end
            M_YSET: begin ma <= tile_addr(cxy, cyy); st <= M_YGET; end
            M_YGET: begin
                if (md == 2'd1) blk <= 1'b1;
                if (c == 2'd3) st <= M_YEND; else begin c <= c + 1'b1; st <= M_YSET; end
            end
            M_YEND: begin
                if (blk) vy <= 0; else py16 <= n16;
                st <= M_GOAL;
            end
            M_GOAL: begin ma <= tile_addr(bx + BS / 2, by + BS / 2); st <= M_GOAL2; end
            M_GOAL2: begin if (md == 2'd2) goal <= 1'b1; st <= M_IDLE; end
            default: st <= M_IDLE;
        endcase
    end
endmodule
