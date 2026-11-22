// สร้างโดย scripts/build_maps.py จาก maps/*.txt — อย่าแก้มือ (แก้แมพแล้วรันสคริปต์ใหม่)
localparam [3:0] G_LB = 4'd6, G_SOKO = 4'd9, G_SIMON = 4'd12;
localparam [4:0] ITEM0_TX = 5'd10;  localparam [3:0] ITEM0_TY = 4'd8;
localparam [4:0] ITEM1_TX = 5'd16;  localparam [3:0] ITEM1_TY = 4'd7;
localparam [4:0] ITEM2_TX = 5'd10;  localparam [3:0] ITEM2_TY = 4'd7;
localparam [4:0] LEVER0_TX = 5'd4;  localparam [3:0] LEVER0_TY = 4'd11;
localparam [4:0] LEVER1_TX = 5'd8;  localparam [3:0] LEVER1_TY = 4'd11;
localparam [4:0] LEVER2_TX = 5'd12;  localparam [3:0] LEVER2_TY = 4'd11;
localparam [4:0] LEVER3_TX = 5'd16;  localparam [3:0] LEVER3_TY = 4'd11;
localparam [4:0] BULB0_TX = 5'd4;  localparam [3:0] BULB0_TY = 4'd13;
localparam [4:0] BULB1_TX = 5'd8;  localparam [3:0] BULB1_TY = 4'd13;
localparam [4:0] BULB2_TX = 5'd12;  localparam [3:0] BULB2_TY = 4'd13;
localparam [4:0] BULB3_TX = 5'd16;  localparam [3:0] BULB3_TY = 4'd13;
localparam [4:0] BOX0_TX = 5'd8;  localparam [3:0] BOX0_TY = 4'd5;
localparam [4:0] PLATE0_TX = 5'd6;  localparam [3:0] PLATE0_TY = 4'd9;
localparam [4:0] BOX1_TX = 5'd11;  localparam [3:0] BOX1_TY = 4'd6;
localparam [4:0] PLATE1_TX = 5'd8;  localparam [3:0] PLATE1_TY = 4'd9;
localparam [4:0] GATE_TX = 5'd13;  localparam [3:0] GATE_TY = 4'd7;
localparam [4:0] BOSSA_TX = 5'd10;  localparam [3:0] BOSSA_TY = 4'd7;   // ห้องบอสชั้น 1, 3 (grid 2)
localparam [4:0] BOSSB_TX = 5'd9;  localparam [3:0] BOSSB_TY = 4'd7;   // ห้องบอสชั้น 2 (grid 3)
