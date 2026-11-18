// ชั้น object (มอน กระสุน เอฟเฟกต์ฟัน) แบบ line buffer สองชุดสลับกัน
//
// ระหว่างแสดงบรรทัด v: วาด object ทุกตัวที่ทับบรรทัด v+1 ลงบัฟเฟอร์หลัง ทีละพิกเซลต่อ clock
//   ลำดับวาด (ทีหลังทับก่อน): ของปริศนา 9 -> มอน 6 -> กระสุนศัตรู 16 -> กระสุนผู้เล่น 2 -> เอฟเฟกต์ฟัน 1
//   งานต่อบรรทัดสูงสุด ~ 6x32 + 18x8 + 32 + 4x32 (ของปริศนาแถวเดียวกัน) + 34 (สแกน) ≈ 530 clock < 800 (CE_DIV = 1)
// บัฟเฟอร์หน้า (บรรทัด v) อ่านที่ hcount แล้วเขียน F0F (โปร่งใส) ทับตอน ce ให้สะอาดสำหรับรอบถัดไป
//   (RAM อ่านก่อนเขียนใน clock เดียวกัน -> ได้ค่าเก่า)
// เอาต์พุต obj_px ตรงเวลากับข้อมูล ROM ของ renderer (2 clock หลัง hcount/vcount)
//
// ไม่มีการเทียบตำแหน่งแบบขนานต่อพิกเซล: ต่อ clock ทำงานกับ object ตัวเดียว (ดีทั้งต่อ timing บนบอร์ดและความเร็ว Verilator)
module objline (
    input  wire         clk,
    input  wire         ce,
    input  wire [9:0]   hcount, vcount,
    input  wire [5:0]   mon_act, mon_type, mon_flash,
    input  wire [59:0]  mon_x, mon_y,
    input  wire         mon_anim,
    input  wire [5:0]   pb_act,
    input  wire [59:0]  pb_x, pb_y,
    input  wire [11:0]  pb_kind,           // 0 ร่าง 2, 1 กระจาย, 2 เร็ว, 3 ลูกใหญ่ 16x16
    input  wire [15:0]  eb_act,
    input  wire [159:0] eb_x, eb_y,
    input  wire [8:0]   pz_act,
    input  wire [89:0]  pz_x, pz_y,
    input  wire [35:0]  pz_frame,
    input  wire         melee_on,
    input  wire [1:0]   melee_dir,
    input  wire         boss_act,          // บอส 64x64 (slot บอส)
    input  wire [9:0]   boss_x, boss_y,
    input  wire [2:0]   boss_frame,        // 0-5 = บอส*2 + เฟรม
    input  wire         boss_flash,
    input  wire [9:0]   sh_dx, sh_dy,      // จอสั่น: offset (two's complement 10 bit) ของพิกัดภาพ (ไม่ยุ่ง sync)
    input  wire [9:0]   px, py,
    output reg  [11:0]  obj_px = 12'hF0F
);
    localparam [11:0] C_T = 12'hF0F;
    localparam NOBJ = 39;                    // 0-8 ปริศนา, 9-14 มอน, 15 บอส, 16-31 กระสุนศัตรู, 32-37 กระสุนผู้เล่น, 38 ฟัน

    // ---------- line buffer x2 ----------
    reg [11:0] lb0 [0:1023];
    reg [11:0] lb1 [0:1023];
    integer n;
    initial for (n = 0; n < 1024; n = n + 1) begin lb0[n] = C_T; lb1[n] = C_T; end

    // ---------- ตัววาด ----------
    reg        drawing = 1'b0;
    reg        dbuf = 1'b0;                  // บัฟเฟอร์ที่กำลังวาด
    reg [9:0]  tline = 0;                    // บรรทัดที่กำลังวาด
    reg [5:0]  o = 0;                        // object index
    reg        inobj = 1'b0;                 // กำลังวาดคอลัมน์ของ object o
    reg [6:0]  col = 0;
    reg [9:0]  ox = 0;
    reg [5:0]  orow = 0;
    reg [6:0]  osize = 0;
    reg [2:0]  okind = 0;                    // 0 มอน, 1 กระสุน, 2 ฟัน, 3 ปริศนา, 4 บอส
    reg        oflash = 1'b0;
    reg [3:0]  oframe = 0;                   // มอน: {type, anim}  กระสุน: kind  ฟัน: ทิศ  ปริศนา: เฟรม 0-9
    // ไปป์ไลน์เขียน (ROM ตอบช้า 1 clock)
    reg        w_on = 1'b0, w_flash = 1'b0;
    reg [2:0]  w_kind = 0;
    reg [9:0]  w_x = 0;

    reg  [11:0] maddr = 0, eaddr = 0;
    reg  [10:0] baddr = 0;
    reg  [13:0] paddr = 0;
    reg  [14:0] gaddr = 0;
    wire [11:0] mdat, edat, bdat, pdat, gdat;
    monster_rom mrom (.clk(clk), .addr(maddr), .data(mdat));
    effect_rom  erom (.clk(clk), .addr(eaddr), .data(edat));
    bullet_rom  brom (.clk(clk), .addr(baddr), .data(bdat));
    puzzle_rom  prom (.clk(clk), .addr(paddr), .data(pdat));
    bossspr_rom grom (.clk(clk), .addr(gaddr), .data(gdat));

    // object o: ตำแหน่ง / ขนาด / เปิดอยู่ไหม (mux 1 ตัวต่อ clock)
    reg        s_act;
    reg [9:0]  s_x, s_y;
    reg [6:0]  s_size;
    reg [2:0]  s_kind;
    reg [3:0]  s_frame;
    reg        s_flash;
    reg [9:0] s_row;                         // คิดเฉพาะตอนสแกน (ไม่เป็น logic ทุก clock)
    reg       sel_v = 1'b0;                  // 1 = เลือก object แล้ว รอเทียบแถว
    reg       q_act = 1'b0, q_flash = 1'b0; reg [9:0] q_x = 0, q_y = 0; reg [6:0] q_size = 0; reg [2:0] q_kind = 0; reg [3:0] q_frame = 0;

    // บรรทัดใหม่เริ่ม (ขอบที่ hcount 799 -> 0): วาดบรรทัด vcount + 2
    wire line_start = ce && (hcount == 10'd799);
    wire [9:0] v2 = (vcount >= 10'd523) ? vcount - 10'd523 : vcount + 10'd2;

    // ---------- พอร์ตเขียน: บัฟเฟอร์ละ 1 พอร์ต (วาด ถ้าเป็นบัฟเฟอร์หลัง / ล้าง ถ้าเป็นบัฟเฟอร์หน้า) ----------
    wire [11:0] w_raw = (w_kind == 3'd0) ? mdat : (w_kind == 3'd1) ? bdat : (w_kind == 3'd2) ? edat :
                        (w_kind == 3'd3) ? pdat : gdat;
    wire [11:0] w_src = ((w_kind == 3'd0 || w_kind == 3'd4) && w_flash) ? 12'hFFF : w_raw;
    wire        w_opq = (w_raw != C_T);
    wire        dw    = w_on && w_opq;                                    // วาดพิกเซลทึบ
    // ล้างช้ากว่าตำแหน่งอ่าน 3 พิกเซล (จอสั่นอ่านที่ hcount + dx, dx = -2..+2): x = hcount - 3
    wire [9:0]  ca    = hcount - 10'd3;
    wire        cl    = ce && (hcount >= 10'd3) && (ca < 10'd640) && (vcount < 10'd480);
    wire        we0   = (dw && !dbuf) || (cl && !vcount[0]);
    wire        we1   = (dw &&  dbuf) || (cl &&  vcount[0]);
    wire [9:0]  wa0   = (dw && !dbuf) ? w_x : ca;
    wire [9:0]  wa1   = (dw &&  dbuf) ? w_x : ca;
    wire [11:0] wd0   = (dw && !dbuf) ? w_src : C_T;
    wire [11:0] wd1   = (dw &&  dbuf) ? w_src : C_T;
    always @(posedge clk) begin
        if (we0) lb0[wa0] <= wd0;
        if (we1) lb1[wa1] <= wd1;
    end

    always @(posedge clk) begin
        w_on <= 1'b0;
        // ---------- สแกน + วาด ----------
        if (line_start) begin
            drawing <= (v2 < 10'd480);
            tline <= v2; dbuf <= v2[0];
            o <= 0; inobj <= 1'b0; sel_v <= 1'b0;
        end else if (drawing) begin
            if (!inobj && !sel_v) begin
                // state A: เลือก object o (mux 39 ทาง) -> register (ยังไม่เทียบแถว)
                s_act = 1'b0; s_x = 0; s_y = 0; s_size = 7'd32; s_kind = 3'd0; s_frame = 0; s_flash = 1'b0;
                if (o < 6'd9) begin
                    s_act = pz_act[o]; s_x = pz_x[o*10 +: 10]; s_y = pz_y[o*10 +: 10];
                    s_kind = 3'd3; s_frame = pz_frame[o*4 +: 4];
                end else if (o < 6'd15) begin
                    s_act = mon_act[o - 6'd9]; s_x = mon_x[(o - 6'd9)*10 +: 10]; s_y = mon_y[(o - 6'd9)*10 +: 10];
                    s_frame = {2'b00, mon_type[o - 6'd9], mon_anim}; s_flash = mon_flash[o - 6'd9];
                end else if (o == 6'd15) begin
                    s_act = boss_act; s_x = boss_x; s_y = boss_y; s_size = 7'd64; s_kind = 3'd4;
                    s_frame = {1'b0, boss_frame}; s_flash = boss_flash;
                end else if (o < 6'd32) begin
                    s_act = eb_act[o - 6'd16]; s_x = eb_x[(o - 6'd16)*10 +: 10]; s_y = eb_y[(o - 6'd16)*10 +: 10];
                    s_size = 7'd8; s_kind = 3'd1; s_frame = 4'd1;
                end else if (o < 6'd38) begin
                    s_act = pb_act[o - 6'd32]; s_x = pb_x[(o - 6'd32)*10 +: 10]; s_y = pb_y[(o - 6'd32)*10 +: 10];
                    s_kind = 3'd1;
                    case (pb_kind[(o - 6'd32)*2 +: 2])
                        2'd0: begin s_size = 7'd8;  s_frame = 4'd0; end
                        2'd1: begin s_size = 7'd8;  s_frame = 4'd2; end
                        2'd2: begin s_size = 7'd8;  s_frame = 4'd3; end
                        default: begin s_size = 7'd16; s_frame = 4'd4; end
                    endcase
                end else begin
                    s_act = melee_on; s_kind = 3'd2; s_frame = {2'b00, melee_dir};
                    s_x = (melee_dir == 2'd2) ? px - 10'd24 : (melee_dir == 2'd3) ? px + 10'd24 : px;
                    s_y = (melee_dir == 2'd0) ? py + 10'd24 : (melee_dir == 2'd1) ? py - 10'd24 : py;
                end
                q_act <= s_act; q_x <= s_x; q_y <= s_y; q_size <= s_size; q_kind <= s_kind; q_frame <= s_frame; q_flash <= s_flash;
                sel_v <= 1'b1;
            end else if (!inobj) begin
                // state B: เทียบแถวของ object ที่เลือกไว้ (ลบ + compare)
                sel_v <= 1'b0;
                s_row = tline + sh_dy - q_y;   // wrap 10 bit: ใช้ได้กับตำแหน่งติดลบ (เช่น py - 24) + จอสั่นแนวตั้ง
                if (q_act && s_row < {3'd0, q_size}) begin
                    inobj <= 1'b1; col <= 0;
                    ox <= q_x; orow <= s_row[5:0]; osize <= q_size;
                    okind <= q_kind; oframe <= q_frame; oflash <= q_flash;
                end else begin
                    if (o == NOBJ - 1) drawing <= 1'b0;
                    o <= o + 1'b1;
                end
            end else begin
                // อ่าน ROM คอลัมน์ col, เขียนใน clock ถัดไป
                maddr <= {oframe[1:0], orow[4:0], col[4:0]};
                eaddr <= {oframe[1:0], orow[4:0], col[4:0]};
                baddr <= {oframe[2:0], orow[3:0], col[3:0]};
                paddr <= {oframe, orow[4:0], col[4:0]};
                gaddr <= {oframe[2:0], orow, col[5:0]};
                w_on <= ((ox + col) < 10'd640);                // 10 bit wrap: x ติดลบ (เช่น 1000 + 30) ได้ 6
                w_x <= ox + col; w_kind <= okind; w_flash <= oflash;
                col <= col + 1'b1;
                if (col == osize - 1) begin
                    inobj <= 1'b0;
                    if (o == NOBJ - 1) drawing <= 1'b0;
                    o <= o + 1'b1;
                end
            end
        end
    end

    // ---------- อ่านบัฟเฟอร์หน้า (อ่านก่อนเขียนใน clock เดียวกัน) ----------
    reg [11:0] q0 = C_T, q1 = C_T;
    reg        qsel = 1'b0;
    wire [9:0] ra = hcount + sh_dx;          // จอสั่นแนวนอน
    reg        rok = 1'b1;
    always @(posedge clk) begin
        q0 <= lb0[ra];
        q1 <= lb1[ra];
        qsel <= vcount[0];
        rok <= (ra < 10'd640);
        obj_px <= !rok ? C_T : qsel ? q1 : q0;   // หน่วงอีก 1 clock ให้ตรงกับ ROM ของ renderer
    end
endmodule
