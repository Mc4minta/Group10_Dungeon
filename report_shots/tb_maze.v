// ground truth for the maze physics: drives rtl/maze.v (button mode) with one key per frame from keys.hex (0 none,1 U,2 D,3 L,4 R)
// prints "frame bx by goal" after every frame.  Run: see maze_check.sh
`timescale 1ns/1ps
module tb_maze;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;
    reg tick = 0; integer tc = 0;
    always @(posedge clk) begin tc <= (tc == 79) ? 0 : tc + 1; tick <= (tc == 79); end
    reg start = 0, run = 1, bu = 0, bd = 0, bl = 0, br = 0;
    wire [9:0] bx, by; wire goal;
    maze dut (.clk(clk), .rst(rst), .frame_tick(tick), .run(run), .start(start), .ax(8'sd0), .ay(8'sd0), .sample_valid(1'b0),
              .use_btn(1'b1), .bu(bu), .bd(bd), .bl(bl), .br(br), .bx(bx), .by(by), .goal(goal));
    reg [7:0] keys [0:4095];
    integer i, n, g;
    initial begin
        for (i = 0; i < 4096; i = i + 1) keys[i] = 0;
        $readmemh("keys.hex", keys);
        if (!$value$plusargs("N=%d", n)) n = 300;
        g = 0;
        repeat (5) @(posedge clk); rst <= 0; repeat (5) @(posedge clk);
        @(posedge clk) start <= 1; @(posedge clk) start <= 0; repeat (4) @(posedge clk);
        for (i = 0; i < n; i = i + 1) begin
            bu <= (keys[i] == 1); bd <= (keys[i] == 2); bl <= (keys[i] == 3); br <= (keys[i] == 4);
            @(posedge tick); repeat (40) @(posedge clk);
            $display("%0d %0d %0d %0d", i + 1, bx, by, g);
        end
        $finish;
    end
    always @(posedge clk) if (goal) g <= 1;
endmodule
