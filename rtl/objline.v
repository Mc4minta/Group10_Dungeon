// ชั้น object (มอน กระสุน เอฟเฟกต์ฟัน) แบบ line buffer สองชุดสลับกัน
//
// ระหว่างแสดงบรรทัด v: วาด object ทุกตัวที่ทับบรรทัด v+1 ลงบัฟเฟอร์หลัง ทีละพิกเซลต่อ clock
//   ลำดับวาด (ทีหลังทับก่อน): มอน 6 -> กระสุนศัตรู 16 -> กระสุนผู้เล่น 2 -> เอฟเฟกต์ฟัน 1
//   งานต่อบรรทัดสูงสุด ~ 6x32 + 18x8 + 32 + 25 (สแกน) ≈ 395 clock < 800 clock ต่อบรรทัด (CE_DIV = 1)
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
    input  wire [1:0]   pb_act,
    input  wire [19:0]  pb_x, pb_y,
    input  wire [15:0]  eb_act,
    input  wire [159:0] eb_x, eb_y,
    input  wire         melee_on,
    input  wire [1:0]   melee_dir,
    input  wire [9:0]   px, py,
    output reg  [11:0]  obj_px = 12'hF0F
);
    localparam [11:0] C_T = 12'hF0F;
    localparam NOBJ = 25;                    // 0-5 มอน, 6-21 กระสุนศัตรู, 22-23 กระสุนผู้เล่น, 24 ฟัน

    // ---------- line buffer x2 ----------
    reg [11:0] lb0 [0:1023];
    reg [11:0] lb1 [0:1023];
    integer n;
    initial for (n = 0; n < 1024; n = n + 1) begin lb0[n] = C_T; lb1[n] = C_T; end

    // ---------- ตัววาด ----------
    reg        drawing = 1'b0;
    reg        dbuf = 1'b0;                  // บัฟเฟอร์ที่กำลังวาด
    reg [9:0]  tline = 0;                    // บรรทัดที่กำลังวาด
    reg [4:0]  o = 0;                        // object index
    reg        inobj = 1'b0;                 // กำลังวาดคอลัมน์ของ object o
    reg [5:0]  col = 0;
    reg [9:0]  ox = 0;
    reg [4:0]  orow = 0;
    reg [5:0]  osize = 0;
    reg [1:0]  okind = 0;                    // 0 มอน, 1 กระสุน, 2 ฟัน
    reg        oflash = 1'b0;
    reg [1:0]  oframe = 0;                   // มอน: {type, anim}  กระสุน: kind  ฟัน: ทิศ
    // ไปป์ไลน์เขียน (ROM ตอบช้า 1 clock)
    reg        w_on = 1'b0, w_flash = 1'b0;
    reg [1:0]  w_kind = 0;
    reg [9:0]  w_x = 0;

    reg  [11:0] maddr = 0, eaddr = 0;
    reg  [6:0]  baddr = 0;
    wire [11:0] mdat, edat, bdat;
    monster_rom mrom (.clk(clk), .addr(maddr), .data(mdat));
    effect_rom  erom (.clk(clk), .addr(eaddr), .data(edat));
    bullet_rom  brom (.clk(clk), .addr(baddr), .data(bdat));

    // object o: ตำแหน่ง / ขนาด / เปิดอยู่ไหม (mux 1 ตัวต่อ clock)
    reg        s_act;
    reg [9:0]  s_x, s_y;
    reg [5:0]  s_size;
    reg [1:0]  s_kind, s_frame;
    reg        s_flash;
    always @* begin
        s_act = 1'b0; s_x = 0; s_y = 0; s_size = 6'd32; s_kind = 2'd0; s_frame = 0; s_flash = 1'b0;
        if (o < 5'd6) begin
            s_act = mon_act[o]; s_x = mon_x[o*10 +: 10]; s_y = mon_y[o*10 +: 10];
            s_frame = {mon_type[o], mon_anim}; s_flash = mon_flash[o];
        end else if (o < 5'd22) begin
            s_act = eb_act[o - 5'd6]; s_x = eb_x[(o - 5'd6)*10 +: 10]; s_y = eb_y[(o - 5'd6)*10 +: 10];
            s_size = 6'd8; s_kind = 2'd1; s_frame = 2'd1;
        end else if (o < 5'd24) begin
            s_act = pb_act[o - 5'd22]; s_x = pb_x[(o - 5'd22)*10 +: 10]; s_y = pb_y[(o - 5'd22)*10 +: 10];
            s_size = 6'd8; s_kind = 2'd1; s_frame = 2'd0;
        end else begin
            s_act = melee_on; s_kind = 2'd2; s_frame = melee_dir;
            s_x = (melee_dir == 2'd2) ? px - 10'd24 : (melee_dir == 2'd3) ? px + 10'd24 : px;
            s_y = (melee_dir == 2'd0) ? py + 10'd24 : (melee_dir == 2'd1) ? py - 10'd24 : py;
        end
    end
    wire [9:0] s_row = tline - s_y;          // wrap 10 bit: ใช้ได้กับตำแหน่งติดลบ (เช่น py - 24)

    // บรรทัดใหม่เริ่ม (ขอบที่ hcount 799 -> 0): วาดบรรทัด vcount + 2
    wire line_start = ce && (hcount == 10'd799);
    wire [9:0] v2 = (vcount >= 10'd523) ? vcount - 10'd523 : vcount + 10'd2;

    // ---------- พอร์ตเขียน: บัฟเฟอร์ละ 1 พอร์ต (วาด ถ้าเป็นบัฟเฟอร์หลัง / ล้าง ถ้าเป็นบัฟเฟอร์หน้า) ----------
    wire [11:0] w_src = (w_kind == 2'd0) ? (w_flash ? 12'hFFF : mdat) : (w_kind == 2'd1) ? bdat : edat;
    wire        w_opq = (w_kind == 2'd0) ? (mdat != C_T) : (w_kind == 2'd1) ? (bdat != C_T) : (edat != C_T);
    wire        dw    = w_on && w_opq;                                    // วาดพิกเซลทึบ
    wire        cl    = ce && (hcount < 10'd640) && (vcount < 10'd480);   // ล้างพิกเซลที่อ่านแล้ว
    wire        we0   = (dw && !dbuf) || (cl && !vcount[0]);
    wire        we1   = (dw &&  dbuf) || (cl &&  vcount[0]);
    wire [9:0]  wa0   = (dw && !dbuf) ? w_x : hcount;
    wire [9:0]  wa1   = (dw &&  dbuf) ? w_x : hcount;
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
            o <= 0; inobj <= 1'b0;
        end else if (drawing) begin
            if (!inobj) begin
                if (s_act && s_row < {4'd0, s_size}) begin
                    inobj <= 1'b1; col <= 0;
                    ox <= s_x; orow <= s_row[4:0]; osize <= s_size;
                    okind <= s_kind; oframe <= s_frame; oflash <= s_flash;
                end else begin
                    if (o == NOBJ - 1) drawing <= 1'b0;
                    o <= o + 1'b1;
                end
            end else begin
                // อ่าน ROM คอลัมน์ col, เขียนใน clock ถัดไป
                maddr <= {oframe, orow, col[4:0]};
                eaddr <= {oframe, orow, col[4:0]};
                baddr <= {oframe[0], orow[2:0], col[2:0]};
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
    always @(posedge clk) begin
        q0 <= lb0[hcount];
        q1 <= lb1[hcount];
        qsel <= vcount[0];
        obj_px <= qsel ? q1 : q0;            // หน่วงอีก 1 clock ให้ตรงกับ ROM ของ renderer
    end
endmodule
