// สร้างโดย scripts/solve_sokoban.py --vh — อย่าแก้มือ
// ดันน้อยสุด 24 ครั้ง, 80 ก้าว (ตัวเล็ก = ก้าวที่ดันกล่อง), เริ่มที่ช่อง (1, 7)
localparam SOKO_PUSHES = 24;
localparam SOKO_N = 80;
localparam [8*80-1:0] SOKO_MOVES = "DRRRRRDRRRRUUULLuLUrrURddddddURRDDLlllULLDDRuLUrDRRURUUUURddRDlULddURRDDLllllDLu";
