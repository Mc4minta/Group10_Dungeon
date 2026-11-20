// player_frame: chooses WHICH extra animation picture (if any) is drawn for the player. Visual only: it reads game signals and
// never changes any game state. All flags (IDLE_ANIM_EN ...) come from the generated rtl/sprite_cfg.vh; flag off = anim_sel stays 0 = the
// normal 48-frame ROM picture (pframe in top.v), so the old behaviour is exactly preserved.
//
// anim_sel: 0 = normal picture, 1 = idle loop, 2 = attack, 3 = hurt, 4 = death.   Only the Human (form 1, form = 0) has these pictures.
// Priority: death > hurt > attack > idle loop > normal (walking pictures).
// aframe  : picture number inside the animation ROM
//           idle   {facing, k[3:0]}  k = 0..15     attack {form[1:0], dir, k[1:0]} (form 0 Human melee_dir, 1 Orc / 2 Angel the facing at the shot)
//           hurt   {facing, k[1:0]}  k = 0..3      die    {2'b00, k[3:0]}     k = 0..11 (last one is held)
module player_frame (
    input  wire       clk, rst, frame_tick,
    input  wire [1:0] form, facing, melee_dir,
    input  wire       moving, melee_on, invuln, dead, active,   // active = not the title screen
    input  wire       shoot,                                    // pulse: the player fired a bullet (objects.ev_shoot) - W14
    output wire [2:0] anim_sel,
    output wire [5:0] aframe,
    output wire       hurt_flash                                // W14: red flash of the sprite right after a hit (all forms)
);
    `include "params.vh"
    `include "sprite_cfg.vh"

    localparam ATT_DIV  = (MELEE_FRAMES + 3) / 4;                // melee-active frames per attack picture (4 pictures)
    localparam HURT_LEN = 4 * HURT_STEP;                         // frames the hurt pictures are shown (then the normal picture + blink)

    wire human = (form == 2'd0) && active;
    wire orc   = (form == 2'd1) && active && ATK_F2_EN;
    wire angel = (form == 2'd2) && active && ATK_F3_EN;
    wire shotf = orc || angel;                                   // forms 2 / 3: attack pictures when they shoot or swing (W14)

    // ---- attack of forms 2 / 3: starts on a shot (latched until the next frame tick) or when a melee swing starts; 4 pictures x SHOT_STEP frames
    reg       shoot_lat = 1'b0, mel_d = 1'b0, sact = 1'b0;
    reg [4:0] scnt = 5'd0;
    reg [1:0] sface = 2'd0;
    always @(posedge clk) begin
        if (rst) begin shoot_lat <= 1'b0; mel_d <= 1'b0; sact <= 1'b0; scnt <= 5'd0; end
        else begin
            if (shoot) shoot_lat <= 1'b1;
            if (frame_tick) begin
                mel_d <= melee_on;
                if (shoot_lat || (melee_on && !mel_d)) begin
                    sact <= 1'b1; scnt <= 5'd0; shoot_lat <= 1'b0;
                    sface <= (melee_on && !mel_d) ? melee_dir : facing;
                end else if (sact) begin
                    if (scnt == 4 * SHOT_STEP - 1) sact <= 1'b0; else scnt <= scnt + 5'd1;
                end
            end
        end
    end
    wire [4:0] sq     = scnt / SHOT_STEP;
    wire [1:0] shot_k = (sq > 5'd3) ? 2'd3 : sq[1:0];

    // ---- attack: frames since the melee box appeared
    reg [4:0] mcnt = 5'd0;
    always @(posedge clk) begin
        if (rst) mcnt <= 5'd0;
        else if (frame_tick) mcnt <= melee_on ? ((mcnt == 5'd31) ? mcnt : mcnt + 5'd1) : 5'd0;
    end
    wire [4:0] att_q = mcnt / ATT_DIV;
    wire [1:0] att_k = (att_q > 5'd3) ? 2'd3 : att_q[1:0];

    // ---- hurt: frames since the hit (invuln starts with the knockback)
    reg [6:0] hcnt = 7'd0;
    always @(posedge clk) begin
        if (rst) hcnt <= 7'd0;
        else if (frame_tick) hcnt <= invuln ? ((hcnt == 7'd127) ? hcnt : hcnt + 7'd1) : 7'd0;
    end
    wire       hurt_show = invuln && (hcnt < HURT_LEN);
    wire [6:0] hurt_q    = hcnt / HURT_STEP;
    wire [1:0] hurt_k    = (hurt_q > 7'd3) ? 2'd3 : hurt_q[1:0];

    // ---- death: frames since GAME OVER, last picture is held
    reg [8:0] dcnt = 9'd0;
    always @(posedge clk) begin
        if (rst) dcnt <= 9'd0;
        else if (frame_tick) dcnt <= dead ? ((dcnt >= 9'd11 * DEATH_STEP) ? dcnt : dcnt + 9'd1) : 9'd0;
    end
    wire [8:0] die_q = dcnt / DEATH_STEP;
    wire [3:0] die_k = (die_q > 9'd11) ? 4'd11 : die_q[3:0];

    // ---- idle loop: starts from picture 0 whenever the player has just stopped; restarts after any move / attack / hit
    wire idle_ok = !moving && !melee_on && !invuln && !dead;
    reg [5:0] isub = 6'd0;
    reg [3:0] ik   = 4'd0;
    always @(posedge clk) begin
        if (rst || !idle_ok) begin isub <= 6'd0; ik <= 4'd0; end
        else if (frame_tick) begin
            if (isub == IDLE_STEP - 1) begin isub <= 6'd0; ik <= ik + 4'd1; end
            else isub <= isub + 6'd1;
        end
    end

    wire sel_die    = DEATH_ANIM_EN  && human && dead;
    wire sel_hurt   = HURT_ANIM_EN   && human && hurt_show;
    wire sel_attack = ATK_F1_EN      && human && melee_on;
    wire sel_shot   = shotf && sact;                             // W14
    wire sel_idle   = IDLE_ANIM_EN   && human && idle_ok;

    assign anim_sel = sel_die ? 3'd4 : sel_hurt ? 3'd3 : (sel_attack || sel_shot) ? 3'd2 : sel_idle ? 3'd1 : 3'd0;
    assign aframe   = sel_die    ? {2'b00, die_k} :
                      sel_hurt   ? {facing, hurt_k} :
                      sel_attack ? {2'b00, melee_dir, att_k} :
                      sel_shot   ? {form, sface, shot_k} :        // attack ROM address {form 0 Human / 1 Orc / 2 Angel, dir, k}
                                   {facing, ik};
    assign hurt_flash = HURT_FLASH_EN && active && invuln && (hcnt < FLASH_FRAMES);
endmodule
