// W5 overlay layer state: which breakable blocks are already broken (13 rooms x 8 blocks, survives leaving a room, cleared on a new game)
// brk = the 8 bits of the CURRENT room (grid); set / set_idx = pulse from objects.v when a bullet / melee hits an unbroken block
module overlay (
    input  wire       clk,
    input  wire       rst,
    input  wire       restart,
    input  wire [3:0] grid,
    input  wire       set,
    input  wire [2:0] set_idx,
    output wire [7:0] brk
);
    reg [127:0] all = 128'd0;
    always @(posedge clk)
        if (rst || restart) all <= 128'd0;
        else if (set) all[{grid, set_idx}] <= 1'b1;
    assign brk = all[{grid, 3'd0} +: 8];
endmodule
