// สร้างโดย scripts/make_font.py — อย่าแก้มือ (ชื่อเกมแก้ที่ GAME_NAME ในสคริปต์)
// บรรทัดข้อความ: หน้าจอ s (1..6) บรรทัด l (0..1): Y, X, W(px), H(px), S (0 = 2x, 1 = 4x), B (ที่อยู่ใน text.mem), K (กะพริบ)
localparam [9:0] T10_Y = 10'd96, T10_X = 10'd208, T10_W = 10'd224, T10_H = 10'd32; localparam T10_S = 1, T10_B = 0, T10_K = 0;
localparam [9:0] T11_Y = 10'd360, T11_X = 10'd240, T11_W = 10'd160, T11_H = 10'd16; localparam T11_S = 0, T11_B = 7, T11_K = 1;
localparam [9:0] T20_Y = 10'd176, T20_X = 10'd112, T20_W = 10'd416, T20_H = 10'd32; localparam T20_S = 1, T20_B = 17, T20_K = 0;
localparam [9:0] T21_Y = 10'd0, T21_X = 10'd0, T21_W = 10'd0, T21_H = 10'd0; localparam T21_S = 0, T21_B = 0, T21_K = 0;
localparam [9:0] T30_Y = 10'd40, T30_X = 10'd208, T30_W = 10'd224, T30_H = 10'd32; localparam T30_S = 1, T30_B = 30, T30_K = 0;
localparam [9:0] T31_Y = 10'd0, T31_X = 10'd0, T31_W = 10'd0, T31_H = 10'd0; localparam T31_S = 0, T31_B = 0, T31_K = 0;
localparam [9:0] T40_Y = 10'd160, T40_X = 10'd208, T40_W = 10'd224, T40_H = 10'd32; localparam T40_S = 1, T40_B = 37, T40_K = 0;
localparam [9:0] T41_Y = 10'd260, T41_X = 10'd240, T41_W = 10'd160, T41_H = 10'd32; localparam T41_S = 1, T41_B = 44, T41_K = 0;
localparam [9:0] T50_Y = 10'd160, T50_X = 10'd176, T50_W = 10'd288, T50_H = 10'd32; localparam T50_S = 1, T50_B = 49, T50_K = 0;
localparam [9:0] T51_Y = 10'd300, T51_X = 10'd240, T51_W = 10'd160, T51_H = 10'd16; localparam T51_S = 0, T51_B = 58, T51_K = 1;
localparam [9:0] T60_Y = 10'd208, T60_X = 10'd224, T60_W = 10'd192, T60_H = 10'd32; localparam T60_S = 1, T60_B = 68, T60_K = 0;
localparam [9:0] T61_Y = 10'd0, T61_X = 10'd0, T61_W = 10'd0, T61_H = 10'd0; localparam T61_S = 0, T61_B = 0, T61_K = 0;
