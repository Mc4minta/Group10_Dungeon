// On-screen health display: the player's hearts (top left) and the boss health bar (top right, boss room only).
// Everything is drawn at exactly 2x from mem/hud.mem (see sprites/hud.json). The HUD does not shake with the screen.
// Timing = same as the tile path of renderer.v: hcount/vcount in, hud_px comes out 2 clock later together with the renderer's stage-2 data
// (stage 0: find heart / bar + source address -> register, stage 1: register again, stage 2: ROM data). hud_on = pixel is not transparent.
module hud (
    input  wire         clk,
    input  wire [9:0]   hcount, vcount,
    input  wire [2:0]   hp, hp_max,       // player: hearts drawn = hp_max, full = hp
    input  wire         boss_on,          // show the boss bar
    input  wire [1:0]   floor,            // which boss (max HP)
    input  wire [4:0]   b_hp,             // boss HP now
    output wire [11:0]  hud_px,
    output wire         hud_on
);
    `include "params.vh"
    localparam [11:0] C_T = 12'hF0F;
    // fill width in source pixels (0..49) = b_hp * 49 / max, as b_hp * ceil(49*1024/max) >> 10 (no divider)
    localparam [15:0] R1 = (49 * 1024 + BOSS1_HP - 1) / BOSS1_HP;
    localparam [15:0] R2 = (49 * 1024 + BOSS2_HP - 1) / BOSS2_HP;
    localparam [15:0] R3 = (49 * 1024 + BOSS3_HP - 1) / BOSS3_HP;
    wire [15:0] rcp = (floor == 2'd0) ? R1 : (floor == 2'd1) ? R2 : R3;
    reg [5:0] fillw = 0;                                   // 0..49
    reg [20:0] prod;
    always @(posedge clk) begin
        prod  = b_hp * rcp;
        fillw <= (prod[20:10] > 11'd49) ? 6'd49 : prod[15:10];
    end

    // ---------------- stage 0 ----------------
    reg [12:0] a0 = 0, b0 = 0;
    reg        on_h0 = 0, on_b0 = 0, fill0 = 0;
    integer    i;
    reg [9:0]  rx, ry, bx, by;
    reg        hit;
    reg [9:0]  hx;
    always @(posedge clk) begin
        on_h0 <= 1'b0; on_b0 <= 1'b0; fill0 <= 1'b0;
        ry = vcount - HUD_HEART_Y;
        hit = 1'b0; hx = 10'd0;
        for (i = 0; i < 6; i = i + 1) begin
            rx = hcount - (HUD_HEART_X + HUD_HEART_STEP * i);
            if (!hit && rx < 10'd34 && ry < 10'd34 && i < hp_max) begin hit = 1'b1; hx = rx; a0 <= {(i < hp) ? 2'd0 : 2'd1, ry[5:1], 1'b0, hx[5:1]}; end
        end
        // (heart i full when i < hp: page 0, else page 1)
        on_h0 <= hit;
        bx = hcount - HUD_BAR_X; by = vcount - HUD_BAR_Y;
        if (!hit && boss_on && bx < 10'd128 && by < 10'd34) begin
            on_b0 <= 1'b1;
            a0    <= {2'd2, by[5:1], bx[6:1]};                          // frame page
            b0    <= {2'd3, by[5:1], bx[6:1] - 6'd14};                  // fill page, 14 source px right of the frame start
            fill0 <= (bx[6:1] >= 6'd14) && ((bx[6:1] - 6'd14) < fillw);
        end
    end
    // ---------------- stage 1 ----------------
    reg [12:0] a1 = 0, b1 = 0; reg on_h1 = 0, on_b1 = 0, fill1 = 0;
    always @(posedge clk) begin a1 <= a0; b1 <= b0; on_h1 <= on_h0; on_b1 <= on_b0; fill1 <= fill0; end
    // ---------------- stage 2: ROM ----------------
    wire [11:0] da, db;
    hud_rom rom (.clk(clk), .addr_a(a1), .addr_b(b1), .data_a(da), .data_b(db));
    reg on_h2 = 0, on_b2 = 0, fill2 = 0;
    always @(posedge clk) begin on_h2 <= on_h1; on_b2 <= on_b1; fill2 <= fill1; end
    wire use_fill = on_b2 && fill2 && (db != C_T);
    assign hud_px = use_fill ? db : da;
    assign hud_on = (on_h2 || on_b2) && (use_fill || da != C_T);
endmodule
