// W7/W16: the boss-3 key as a visible floor item. Boss 3 dies -> the key appears where the boss stood (boss room, floor 3) and stays there until
// the player walks over it (pick = one-clock pulse -> game_fsm.key_get -> has_key -> door E opens). Cleared on a new game.
module keyitem (
    input  wire       clk,
    input  wire       rst,
    input  wire       restart,
    input  wire       died3,             // pulse: boss 3 died
    input  wire [9:0] bx, by,            // boss top-left (64x64 sprite) at death
    input  wire [9:0] px, py,            // player top-left (32x32 sprite)
    input  wire [1:0] floor,
    input  wire [2:0] room,
    input  wire       play,              // state PLAY (nothing is picked up in cut-scenes)
    output wire       vis,               // draw the key (it is lying in THIS room)
    output reg  [9:0] kx = 10'd0, ky = 10'd0,   // key sprite top-left (32x32)
    output reg        pick = 1'b0
);
    localparam R_BOSS = 3'd4;
    reg on = 1'b0;
    assign vis = on && floor == 2'd2 && room == R_BOSS;
    wire [10:0] dx = ({1'b0, px} > {1'b0, kx}) ? {1'b0, px} - {1'b0, kx} : {1'b0, kx} - {1'b0, px};
    wire [10:0] dy = ({1'b0, py} > {1'b0, ky}) ? {1'b0, py} - {1'b0, ky} : {1'b0, ky} - {1'b0, py};
    wire near = (dx < 11'd24) && (dy < 11'd24);          // sprites overlap by about a third
    always @(posedge clk) begin
        pick <= 1'b0;
        if (rst || restart) on <= 1'b0;
        else if (died3) begin on <= 1'b1; kx <= bx + 10'd16; ky <= by + 10'd16; end
        else if (vis && play && near) begin on <= 1'b0; pick <= 1'b1; end
    end
endmodule
