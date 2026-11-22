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
    input  wire         mic_on,           // W4: show the clap meter (boss 1 fight)
    input  wire [6:0]   mic_w,            // W4: sound level in px (0..120)
    input  wire [6:0]   mic_th,           // W4: clap threshold in px (0..120)
    input  wire         mic_hit,          // W4: a clap was detected (flash)
    input  wire         mic_nums,         // W36: show the numbers (settings page only)
    input  wire [15:0]  mic_th_bcd,       // W4: threshold as 4 decimal digits (BCD) for the number under the meter
    input  wire [15:0]  mic_lv_bcd,       // W4: live level as 4 decimal digits (BCD)
    input  wire [6:0]   chg_w,            // W21: boss 3 charge bar fill (px, 0..120); 0 = the bar is hidden
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
    // 3 x 5 pixel digits (+ T, L) drawn at 2x: 15 bit pattern, row 0 in the top bits
    function [14:0] glyph(input [3:0] c);
        case (c)
            4'd0: glyph = 15'b111_101_101_101_111;  4'd1: glyph = 15'b010_110_010_010_111;
            4'd2: glyph = 15'b111_001_111_100_111;  4'd3: glyph = 15'b111_001_111_001_111;
            4'd4: glyph = 15'b101_101_111_001_001;  4'd5: glyph = 15'b111_100_111_001_111;
            4'd6: glyph = 15'b111_100_111_101_111;  4'd7: glyph = 15'b111_001_010_010_010;
            4'd8: glyph = 15'b111_101_111_101_111;  4'd9: glyph = 15'b111_101_111_001_111;
            4'd10: glyph = 15'b111_010_010_010_010;  // T
            default: glyph = 15'b100_100_100_100_111; // L
        endcase
    endfunction
    reg        mbd0 = 0, mbd1 = 0, mbd2 = 0;                                                    // W36: frame of the bar
    reg        mt0 = 0;                                                                         // W4: a pixel of the numbers under the meter
    reg [9:0]  nx, ny; reg [2:0] nch; reg [3:0] ncode; reg [14:0] npat; reg [3:0] nrow; reg [1:0] ncol;
    reg        mb0 = 0, mf0 = 0, mm0 = 0, mh0 = 0; reg [11:0] mc0 = 0;                          // W4 mic meter
    reg        cb0 = 0, cf0 = 0; reg [11:0] cc0 = 0;                 // W21 charge bar: in the bar box / filled, fill colour
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
        // W21 charge bar: 128 x 8 box under the boss bar (dark border, fill grows left to right, colour ramps yellow -> orange -> red)
        cb0 <= (chg_w != 0) && (hcount - HUD_BAR_X) < 10'd128 && (vcount - (HUD_BAR_Y + 10'd38)) < 10'd8;
        cf0 <= ((hcount - HUD_BAR_X) >= 10'd4) && ((hcount - HUD_BAR_X) < 10'd4 + chg_w) && ((vcount - (HUD_BAR_Y + 10'd38)) >= 10'd2) && ((vcount - (HUD_BAR_Y + 10'd38)) < 10'd6);
        // W4 mic meter: 128 x 8 box under the charge bar: fill = sound level (green, red once it passes the threshold), white line = the threshold, yellow background = clap detected
        mb0 <= mic_on && (hcount - HUD_BAR_X) < 10'd128 && (vcount - (HUD_BAR_Y + 10'd54)) < 10'd8;
        mf0 <= ((hcount - HUD_BAR_X) >= 10'd4) && ((hcount - HUD_BAR_X) < 10'd4 + mic_w) && ((vcount - (HUD_BAR_Y + 10'd54)) >= 10'd2) && ((vcount - (HUD_BAR_Y + 10'd54)) < 10'd6);
        mm0 <= ((hcount - HUD_BAR_X) >= 10'd4 + mic_th) && ((hcount - HUD_BAR_X) < 10'd6 + mic_th);
        mh0 <= mic_hit;
        mbd0 <= ((hcount - HUD_BAR_X) == 10'd0) || ((hcount - HUD_BAR_X) == 10'd127) || ((vcount - (HUD_BAR_Y + 10'd54)) == 10'd0) || ((vcount - (HUD_BAR_Y + 10'd54)) == 10'd7);
        // numbers: 'T nnnn' at the left, 'L nnnn' at the right, 8 px per character (6 px glyph at 2x), 10 px high, under the meter
        ny = vcount - (HUD_BAR_Y + 10'd64); nx = hcount - HUD_BAR_X;
        mt0 <= 1'b0;
        if (mic_on && mic_nums && ny < 10'd10 && nx < 10'd120) begin
            nch = (nx[6:0] >= 7'd64) ? ((nx[6:0] - 7'd64) >> 3) : (nx[6:0] >> 3);        // character 0..4 inside each half
            ncode = (nx[6:0] >= 7'd64) ? ((nch == 0) ? 4'd11 : (nch == 1) ? mic_lv_bcd[15:12] : (nch == 2) ? mic_lv_bcd[11:8] : (nch == 3) ? mic_lv_bcd[7:4] : mic_lv_bcd[3:0])
                                       : ((nch == 0) ? 4'd10 : (nch == 1) ? mic_th_bcd[15:12] : (nch == 2) ? mic_th_bcd[11:8] : (nch == 3) ? mic_th_bcd[7:4] : mic_th_bcd[3:0]);
            ncol = ((nx[2:0]) >> 1);
            nrow = ny[3:0] >> 1;                                                         // 0..4
            npat = glyph(ncode);
            if (nch < 3'd5 && ncol < 2'd3 && nrow < 4'd5) mt0 <= npat[14 - (nrow * 3 + ncol)];
        end
        mc0 <= (mic_w >= mic_th) ? 12'hF22 : 12'h4D4;
        cc0 <= (chg_w < 7'd40) ? 12'hFE2 : (chg_w < 7'd90) ? 12'hF82 : 12'hF22;
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
    reg cb1 = 0, cf1 = 0, cb2 = 0, cf2 = 0; reg [11:0] cc1 = 0, cc2 = 0;
    reg mt1 = 0, mt2 = 0;
    reg mb1 = 0, mf1 = 0, mm1 = 0, mh1 = 0, mb2 = 0, mf2 = 0, mm2 = 0, mh2 = 0; reg [11:0] mc1 = 0, mc2 = 0;
    always @(posedge clk) begin a1 <= a0; b1 <= b0; on_h1 <= on_h0; on_b1 <= on_b0; fill1 <= fill0; cb1 <= cb0; cf1 <= cf0; cc1 <= cc0; mb1 <= mb0; mf1 <= mf0; mm1 <= mm0; mh1 <= mh0; mc1 <= mc0; mt1 <= mt0; mbd1 <= mbd0; end
    // ---------------- stage 2: ROM ----------------
    wire [11:0] da, db;
    hud_rom rom (.clk(clk), .addr_a(a1), .addr_b(b1), .data_a(da), .data_b(db));
    reg on_h2 = 0, on_b2 = 0, fill2 = 0;
    always @(posedge clk) begin on_h2 <= on_h1; on_b2 <= on_b1; fill2 <= fill1; cb2 <= cb1; cf2 <= cf1; cc2 <= cc1; mb2 <= mb1; mf2 <= mf1; mm2 <= mm1; mh2 <= mh1; mc2 <= mc1; mt2 <= mt1; mbd2 <= mbd1; end
    wire use_fill = on_b2 && fill2 && (db != C_T);
    // W36: black bar with a grey frame, green level (white for 0.3 s after a clap), red vertical trigger line
    assign hud_px = mt2 ? 12'hFFF : mb2 ? (mm2 ? 12'hF22 : mf2 ? (mh2 ? 12'hFFF : 12'h4D4) : mbd2 ? 12'h666 : 12'h000) : cb2 ? (cf2 ? cc2 : 12'h210) : use_fill ? db : da;
    assign hud_on = mt2 || mb2 || cb2 || ((on_h2 || on_b2) && (use_fill || da != C_T));
endmodule
