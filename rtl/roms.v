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

// มอนต่อห้อง (จาก scripts/build_maps.py): 16 grid x 8 entry x 16 bit, อ่าน async (ROM เล็ก)
// {valid, type[2:0], ty[3:0], 3'b0, tx[4:0]}, address = grid*8 + i
module spawn_rom (
    input  wire [6:0]  addr,
    output wire [15:0] data
);
    reg [15:0] mem [0:127];
    initial $readmemh("monsters.mem", mem);
    assign data = mem[addr];
endmodule

// sprite มอน: 4 เฟรม (A0 A1 B0 B1) x 1024 px x 12 bit (BRAM), address = frame*1024 + y*32 + x
module monster_rom (
    input  wire        clk,
    input  wire [11:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:4095];
    initial $readmemh("monster.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// เอฟเฟกต์ฟันประชิด: 4 เฟรม (ทิศ) x 1024 px x 12 bit (BRAM)
module effect_rom (
    input  wire        clk,
    input  wire [11:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:4095];
    initial $readmemh("effect.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// กระสุน: 8 เฟรม 16x16 x 12 bit (กระสุน 8x8 อยู่มุมซ้ายบนของช่อง), address = frame*256 + y*16 + x
// เฟรม 0 ผู้เล่นร่าง 2, 1 ศัตรู, 2 กระจาย (ร่าง 3), 3 นัดเร็ว (ร่าง 4), 4 ลูกใหญ่ 16x16 (ร่าง 4 ชาร์จ)
module bullet_rom (
    input  wire        clk,
    input  wire [10:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:2047];
    initial $readmemh("bullet.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// ของในห้องปริศนา: 10 เฟรม (ใช้ address 14 bit = 16 เฟรม) x 1024 px x 12 bit (BRAM)
// 0 หลอดดับ 1 หลอดติด 2 คันโยกขึ้น 3 คันโยกลง 4 กล่อง 5 gate ปิด 6 gate เปิด 7-9 ไอเทม 1-3
module puzzle_rom (
    input  wire        clk,
    input  wire [13:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:16383];
    initial $readmemh("puzzle.mem", mem);
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

// ---- animation ROMs for the Human (form 1), instantiated only when the flag in rtl/sprite_cfg.vh is 1 (no BRAM otherwise) ----
// idle: 4 directions x 16 pictures, address = ((dir*16 + k)*1024) + y*32 + x
module player_idle_rom (
    input  wire        clk,
    input  wire [15:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:65535];
    initial $readmemh("player_idle.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// attack: 4 directions x 4 pictures, address = ((dir*4 + k)*1024) + y*32 + x
module player_attack_rom (
    input  wire        clk,
    input  wire [13:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:16383];
    initial $readmemh("player_attack.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// hurt: 4 directions x 4 pictures, same layout as attack
module player_hurt_rom (
    input  wire        clk,
    input  wire [13:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:16383];
    initial $readmemh("player_hurt.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// die: 12 pictures (16 reserved), address = (k*1024) + y*32 + x
module player_die_rom (
    input  wire        clk,
    input  wire [13:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:16383];
    initial $readmemh("player_die.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule

// บอส 3 ตัว x 2 เฟรม = 6 เฟรม x 64x64 x 12 bit (BRAM), address = frame*4096 + y*64 + x
// เฟรม = บอส*2 + (บอส 1, 3: animation, บอส 2: 1 = มึน)
module bossspr_rom (
    input  wire        clk,
    input  wire [14:0] addr,
    output reg  [11:0] data
);
    reg [11:0] mem [0:32767];
    initial $readmemh("boss.mem", mem);
    always @(posedge clk) data <= mem[addr];
endmodule
