// ROM ทั้งหมดของเกม (โหลดจาก mem/*.mem)
// ใส่ไฟล์ .mem เข้า Vivado project แล้ว $readmemh หาเจอด้วยชื่อไฟล์

// tile map: 13 ห้อง x 300 tile x 4 bit, อ่านแบบ async (distributed ROM)
// ใช้หลาย instance ได้ (renderer 1 + player 2)
module tilemap_rom (
    input  wire [11:0] addr,   // grid*300 + ty*20 + tx
    output wire [3:0]  data
);
    reg [3:0] mem [0:4095];
    initial $readmemh("tilemap.mem", mem);
    assign data = mem[addr];
endmodule

// tileset: 3 ชั้น x 16 tile x 1024 px x 12 bit, อ่านแบบ sync (BRAM)
module tileset_rom (
    input  wire        clk,
    input  wire [15:0] addr,   // (floor*16 + tile)*1024 + y*32 + x
    output reg  [11:0] data
);
    reg [11:0] mem [0:49151];
    initial $readmemh("tileset.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// player: 48 เฟรม x 1024 px x 12 bit (BRAM)
module player_rom (
    input  wire        clk,
    input  wire [15:0] addr,   // frame*1024 + y*32 + x
    output reg  [11:0] data
);
    reg [11:0] mem [0:49151];
    initial $readmemh("player.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule
