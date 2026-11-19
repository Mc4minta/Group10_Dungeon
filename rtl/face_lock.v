// face_lock: after a BTNC press (press = 1-clock pulse) keep "lock" high for FRAMES frame_ticks,
// so the player can tap-attack and step back without turning away (one-handed play on the board).
// FRAMES = 0 disables it (lock stays 0).
module face_lock #(
    parameter FRAMES = 24
)(
    input  wire clk, rst, frame_tick, press,
    output wire lock
);
    reg [7:0] cnt = 8'd0;
    always @(posedge clk) begin
        if (rst) cnt <= 8'd0;
        else if (press) cnt <= FRAMES;
        else if (frame_tick && cnt != 8'd0) cnt <= cnt - 8'd1;
    end
    assign lock = (cnt != 8'd0);
endmodule
