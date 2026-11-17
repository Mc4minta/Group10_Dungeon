// P4: ปริศนา 3 ห้อง + ไอเทม (+ P1.6 ดันกล่อง)
//
//   ชั้น 1 Light Bulb (grid 6): ตีคันโยก a-d (ฟันประชิด หรือกระสุนผู้เล่นทับกล่อง 32x32 ของคันโยก, 1 ครั้งต่อการโดน 1 ที)
//          -> หลอด 4 ดวง XOR mask ของคันโยก, ครบ 4 ดวงติด = solved; รูปแบบเริ่มต้นจาก LFSR ตอนเข้าห้องครั้งแรก
//          (ตัดแบบที่ติดครบอยู่แล้ว และแบบที่ตีทีเดียวจบ = ต้องตีอย่างน้อย 2 ครั้ง)
//   ชั้น 2 Sokoban (grid 9): กล่อง 2, แผ่น 2, gate; เดินตรงแกนเดียวชนกล่อง + ช่องถัดไปเป็นพื้น/แผ่น -> กล่องเลื่อน 1 ช่อง
//          แผ่นครบ 2 แผ่น = gate เปิด (ค้าง); SW13 = รีเซ็ตกล่อง (เฉพาะห้องนี้ ตอน gate ยังปิด)
//   ชั้น 3 Simon (grid 12): โชว์ลำดับ 3 / 4 / 5 แผ่น (prefix ของลำดับเดียวกันจาก LFSR) -> ผู้เล่นเหยียบตาม
//          ผิด = HP -1 (take_hit ไม่มี knockback) + แผ่นแดงแล้วโชว์รอบเดิมใหม่; ครบ 3 รอบ = solved
//   ไอเทม I: โผล่เมื่อ solved (Sokoban: มีตั้งแต่แรกแต่อยู่หลัง gate) เดินทับ -> got_item (EVOLVE) + has_item[floor]
//
// สถานะทุกอย่างค้างไว้เมื่อออกจากห้อง (ยกเว้น Simon ที่ยังไม่จบ: กลับมาเริ่มโชว์รอบปัจจุบันใหม่), restart ล้างหมด
// ทำงานต่อเฟรมทีละขั้น (FSM ~ 15 clock) เริ่มหลัง frame_tick PUZZLE_DELAY clock (ให้ objects.v ขยับกระสุนเสร็จก่อน)
module puzzles #(
    parameter [15:0] SEED = 16'd0            // 0 = สุ่มจาก LFSR ที่วิ่งตลอด (แต่ละเกมไม่เหมือนกัน), อื่น ๆ = ค่าคงที่ (ทดสอบ)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,
    input  wire        run,                  // state PLAY
    input  wire        restart,              // เกมใหม่: ล้างปริศนา + ไอเทมทั้งหมด
    input  wire        room_load,            // world.load (เข้าห้อง)
    input  wire [1:0]  floor,
    input  wire [3:0]  grid,
    input  wire [9:0]  px, py,
    input  wire        up, down, left, right,
    input  wire        melee_on,
    input  wire [1:0]  melee_dir,
    input  wire [1:0]  pb_act,
    input  wire [19:0] pb_x, pb_y,
    input  wire        soko_reset,           // SW13 rise
    output reg         got_item = 1'b0,      // pulse -> game_fsm (EVOLVE)
    output reg         hit = 1'b0,           // pulse -> game_fsm take_hit (Simon ผิด)
    output wire [2:0]  has_item,             // [floor] -> ประตู L ชั้นนั้นเปิด
    // ช่องที่กันการเดิน (address tile แบบเดียวกับ tilemap_rom รวม grid แล้ว): กล่อง 0, กล่อง 1, gate
    output reg  [11:0] blk0 = 0, blk1 = 0, blk2 = 0,
    output reg  [2:0]  blk_en = 0,
    // ให้ objline: sprite ปริศนา 9 ช่อง
    output reg  [8:0]  pz_act = 0,
    output reg  [89:0] pz_x = 0, pz_y = 0,
    output reg  [35:0] pz_frame = 0,
    // ให้ renderer: แผ่นที่มีกล่องวางนิ่ง -> วาด tile 11, Simon สว่าง / แดง
    output reg  [11:0] pbox0 = 0, pbox1 = 0,
    output reg  [1:0]  pbox_en = 0,
    output wire        simon_lit_on,
    output wire [1:0]  simon_lit,
    output wire        simon_wrong,
    output wire        simon_note_on,        // ให้ P6 ต่อเสียง
    output wire [1:0]  simon_note,
    // LED0-3 ในห้องปริศนา
    output reg  [3:0]  room_led = 0,
    output reg         room_led_on = 0,
    // สถานะ (ทดสอบ / debug)
    output reg  [3:0]  bulbs = 4'd0,
    output reg         lb_ok = 1'b0,
    output reg         gate_open = 1'b0,
    output reg         sm_ok = 1'b0,
    output wire        busy,
    output wire [9:0]  dbg_seq,              // debug: ลำดับ Simon (2 bit ต่อแผ่น, แผ่นแรก = bit 1:0)
    output wire [2:0]  dbg_sm,
    output wire [1:0]  dbg_round
);
    `include "params.vh"
    `include "puzzle_layout.vh"

    localparam [10:0] OFS = 11'd64;
    localparam BOX_STEP = 32 / BOX_SLIDE_FRAMES;

    function [11:0] tad(input [3:0] g, input [4:0] tx, input [3:0] ty);
        tad = g * 12'd300 + ty * 12'd20 + tx;
    endfunction
    function ovl(input [10:0] ax, input [10:0] ay, input [6:0] aw, input [6:0] ah,
                 input [10:0] bx, input [10:0] by, input [6:0] bw, input [6:0] bh);
        ovl = (ax < bx + bw) && (bx < ax + aw) && (ay < by + bh) && (by < ay + ah);
    endfunction

    // ---------- LFSR วิ่งทุก clock (x^16 + x^14 + x^13 + x^11 + 1) ----------
    reg [15:0] lfsr = 16'hACE1;
    always @(posedge clk) lfsr <= {1'b0, lfsr[15:1]} ^ (lfsr[0] ? 16'hB400 : 16'h0000);
    reg [15:0] g = 16'h0001;                 // ตัวสุ่มตอนสร้างรูปแบบ
    function [15:0] step(input [15:0] v);
        step = {1'b0, v[15:1]} ^ (v[0] ? 16'hB400 : 16'h0000);
    endfunction

    // ---------- tile ROM (ปลายทางกล่อง / จุดกลางผู้เล่นใน Simon) ----------
    reg  [11:0] ta = 0;
    wire [3:0]  td;
    tilemap_rom rom (.addr(ta), .data(td));

    // ---------- state ----------
    reg [2:0]  picked = 0;
    reg        lb_init = 1'b0;
    reg [3:0]  levers = 0;
    reg [3:0]  mel_used = 0;
    reg [7:0]  pb_used = 0;                  // [j*4 + k] กระสุน j โดนคันโยก k แล้ว
    reg [4:0]  b0x = BOX0_TX, b1x = BOX1_TX;
    reg [3:0]  b0y = BOX0_TY, b1y = BOX1_TY;
    reg [4:0]  sc0 = 0, sc1 = 0;             // เฟรมเลื่อนที่เหลือ
    reg [1:0]  sd0 = 0, sd1 = 0;             // ทิศเลื่อน 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา
    // Simon
    localparam [2:0] SM_IDLE = 3'd0, SM_PRE = 3'd1, SM_ON = 3'd2, SM_GAP = 3'd3, SM_IN = 3'd4,
                     SM_OK = 3'd5, SM_WRONG = 3'd6, SM_DONE = 3'd7;
    reg [2:0]  sm = SM_IDLE;
    reg [1:0]  round = 0;
    reg [2:0]  sidx = 0;
    reg [7:0]  stmr = 0;
    reg [9:0]  seq = 0;
    reg        seq_init = 1'b0;
    reg        on_prev = 1'b0;
    reg        lit_on = 1'b0;
    reg [1:0]  lit = 0;
    reg [4:0]  fb = 0;                       // เวลาสว่างตอนเหยียบถูก


    // ---------- ไอเทมของชั้นนี้ ----------
    function [3:0] f_item_grid(input [1:0] f); f_item_grid = (f == 2'd0) ? G_LB : (f == 2'd1) ? G_SOKO : G_SIMON; endfunction
    function [4:0] f_item_tx(input [1:0] f);   f_item_tx = (f == 2'd0) ? ITEM0_TX : (f == 2'd1) ? ITEM1_TX : ITEM2_TX; endfunction
    function [3:0] f_item_ty(input [1:0] f);   f_item_ty = (f == 2'd0) ? ITEM0_TY : (f == 2'd1) ? ITEM1_TY : ITEM2_TY; endfunction
    function       f_item_vis(input [1:0] f);  f_item_vis = (f == 2'd0) ? lb_ok : (f == 2'd1) ? 1'b1 : sm_ok; endfunction

    // ---------- FSM ต่อเฟรม ----------
    localparam [3:0] P_IDLE = 4'd0, P_DLY = 4'd1, P_GEN = 4'd2, P_LEV = 4'd3, P_PUSHA = 4'd4, P_PUSHB = 4'd5,
                     P_SLIDE = 4'd6, P_SIM0 = 4'd7, P_SIM1 = 4'd8, P_ITEM = 4'd9;
    reg [3:0]  st = P_IDLE;
    reg [8:0]  dly = 0;
    reg [1:0]  k = 0;
    reg        enter_req = 1'b0;
    reg [4:0]  dx = 0;  reg [3:0] dy = 0;    // ปลายทางกล่องที่กำลังตรวจ
    reg [1:0]  ddir = 0;
    reg        dbox = 1'b0;
    assign busy = (st != P_IDLE);

    // ตัวช่วย (reg ชั่วคราว): คิดเฉพาะตอนประมวลผลต่อเฟรม (st >= P_GEN) ไม่เป็น logic ที่ต้องคิดทุก clock
    reg [4:0]  lvx, ctx, kbx, nbx, item_tx;
    reg [3:0]  lvy, lmask, cty, kby, nby, item_grid, item_ty;
    reg [10:0] lvpx, lvpy, mbx, mby;
    reg [6:0]  mbw, mbh;
    reg        one_axis_r, one_axis_l, one_axis_d, one_axis_u, in_one, sliding, item_vis;
    reg [1:0]  in_dir, note_i;
    reg [2:0]  slen;
    reg hit_m, hit_b0, hit_b1;
    function touch(input [4:0] bx, input [3:0] by, input [1:0] d);
        reg [10:0] bxl, byt, pr, pl, pd, pu;
        begin
            bxl = {1'b0, bx, 5'd0}; byt = {2'b00, by, 5'd0};
            pr = {1'b0, px} + 11'd28;  pl = {1'b0, px} + 11'd4;
            pd = {1'b0, py} + 11'd28;  pu = {1'b0, py} + 11'd4;
            case (d)
                2'd3: touch = (cty == by) && (bxl >= pr) && (bxl - pr <= 11'd3);
                2'd2: touch = (cty == by) && (pl >= bxl + 11'd32) && (pl - (bxl + 11'd32) <= 11'd3);
                2'd0: touch = (ctx == bx) && (byt >= pd) && (byt - pd <= 11'd3);
                default: touch = (ctx == bx) && (pu >= byt + 11'd32) && (pu - (byt + 11'd32) <= 11'd3);
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (st >= P_GEN) begin
            lvx = (k == 0) ? LEVER0_TX : (k == 1) ? LEVER1_TX : (k == 2) ? LEVER2_TX : LEVER3_TX;
            lvy = (k == 0) ? LEVER0_TY : (k == 1) ? LEVER1_TY : (k == 2) ? LEVER2_TY : LEVER3_TY;
            lmask = (k == 0) ? LB_MASK0 : (k == 1) ? LB_MASK1 : (k == 2) ? LB_MASK2 : LB_MASK3;
            lvpx = {1'b0, lvx, 5'd0} + OFS;
            lvpy = {2'b00, lvy, 5'd0} + OFS;
            // hit box ฟัน (เหมือน objects.v)
            mbx = (melee_dir == 2'd2) ? {1'b0, px} + OFS - 11'd12 :
                  (melee_dir == 2'd3) ? {1'b0, px} + OFS + 11'd28 : {1'b0, px} + OFS + 11'd4;
            mby = (melee_dir == 2'd0) ? {1'b0, py} + OFS + 11'd28 :
                  (melee_dir == 2'd1) ? {1'b0, py} + OFS - 11'd12 : {1'b0, py} + OFS + 11'd4;
            mbw = melee_dir[1] ? 7'd16 : 7'd24;
            mbh = melee_dir[1] ? 7'd24 : 7'd16;
            // ดันกล่อง: ผู้เล่นชิดกล่องตามทิศที่กด (ห่าง 0..3 px) และจุดกลางอยู่แถว/คอลัมน์เดียวกัน
            one_axis_r = right && !left && !up && !down;
            one_axis_l = left && !right && !up && !down;
            one_axis_d = down && !up && !left && !right;
            one_axis_u = up && !down && !left && !right;
            ctx = px[9:5] + ((px[4:0] >= 5'd16) ? 5'd1 : 5'd0);    // คอลัมน์ของจุดกลาง (px + 16)
            cty = py[8:5] + ((py[4:0] >= 5'd16) ? 4'd1 : 4'd0);
            in_dir = one_axis_d ? 2'd0 : one_axis_u ? 2'd1 : one_axis_l ? 2'd2 : 2'd3;
            in_one = one_axis_d | one_axis_u | one_axis_l | one_axis_r;
            kbx = k[0] ? b1x : b0x;
            kby = k[0] ? b1y : b0y;
            nbx = (in_dir == 2'd2) ? kbx - 5'd1 : (in_dir == 2'd3) ? kbx + 5'd1 : kbx;
            nby = (in_dir == 2'd1) ? kby - 4'd1 : (in_dir == 2'd0) ? kby + 4'd1 : kby;
            sliding = (sc0 != 0) || (sc1 != 0);
            slen = (round == 2'd0) ? SIMON_LEN0 : (round == 2'd1) ? SIMON_LEN1 : SIMON_LEN2;
            note_i = seq[sidx*2 +: 2];
            item_grid = f_item_grid(floor); item_tx = f_item_tx(floor); item_ty = f_item_ty(floor);
            item_vis = f_item_vis(floor);
        end
        got_item <= 1'b0;
        hit <= 1'b0;
        if (room_load) enter_req <= 1'b1;
        if (!melee_on) mel_used <= 0;
        if (!pb_act[0]) pb_used[3:0] <= 4'd0;
        if (!pb_act[1]) pb_used[7:4] <= 4'd0;

        if (rst || restart) begin
            picked <= 0; lb_init <= 1'b0; lb_ok <= 1'b0; bulbs <= 0; levers <= 0;
            b0x <= BOX0_TX; b0y <= BOX0_TY; b1x <= BOX1_TX; b1y <= BOX1_TY; sc0 <= 0; sc1 <= 0;
            gate_open <= 1'b0;
            sm <= SM_IDLE; round <= 0; sidx <= 0; seq_init <= 1'b0; sm_ok <= 1'b0; lit_on <= 1'b0; fb <= 0;
            st <= P_IDLE;
        end else begin
            // SW13: รีเซ็ตกล่อง (เฉพาะห้อง Sokoban ตอน gate ยังปิด)
            if (soko_reset && grid == G_SOKO && !gate_open) begin
                b0x <= BOX0_TX; b0y <= BOX0_TY; b1x <= BOX1_TX; b1y <= BOX1_TY; sc0 <= 0; sc1 <= 0;
            end
            case (st)
            P_IDLE:
                if (enter_req) begin
                    enter_req <= 1'b0;
                    // Simon: เข้าห้อง = เริ่มโชว์รอบปัจจุบัน, ออกห้อง = หยุด
                    if (grid == G_SIMON && !sm_ok) begin
                        if (!seq_init) begin
                            seq <= (SEED != 0) ? (SEED[9:0] ^ 10'h2B5) : lfsr[9:0];
                            seq_init <= 1'b1;
                        end
                        sm <= SM_PRE; stmr <= SIMON_PRE - 1; sidx <= 0; lit_on <= 1'b0; fb <= 0;
                    end else if (!sm_ok) begin
                        sm <= SM_IDLE; lit_on <= 1'b0;
                    end
                    if (grid == G_LB && !lb_init) begin
                        g <= (SEED != 0) ? SEED : lfsr;
                        st <= P_GEN;
                    end
                end else if (frame_tick && run) begin
                    dly <= PUZZLE_DELAY;
                    st <= P_DLY;
                end
            P_DLY: begin
                dly <= dly - 1'b1;
                if (dly <= 1) begin k <= 0; st <= P_LEV; end
            end
            // ---- Light Bulb: สุ่มรูปแบบที่ต้องตี >= 2 ครั้ง ----
            P_GEN: begin
                if (g[3:0] != 4'b1111 && g[3:0] != 4'b1000 && g[3:0] != 4'b0100 &&
                    g[3:0] != 4'b0010 && g[3:0] != 4'b0001) begin
                    bulbs <= g[3:0]; levers <= 0; lb_init <= 1'b1;
                    st <= P_IDLE;
                end else g <= step(g);
            end
            // ---- Light Bulb: คันโยก k ----
            P_LEV: begin
                hit_m  = melee_on && !mel_used[k] && ovl(mbx, mby, mbw, mbh, lvpx, lvpy, 7'd32, 7'd32);
                hit_b0 = pb_act[0] && !pb_used[k] &&
                         ovl({1'b0, pb_x[9:0]} + OFS, {1'b0, pb_y[9:0]} + OFS, 7'd8, 7'd8, lvpx, lvpy, 7'd32, 7'd32);
                hit_b1 = pb_act[1] && !pb_used[4 + k] &&
                         ovl({1'b0, pb_x[19:10]} + OFS, {1'b0, pb_y[19:10]} + OFS, 7'd8, 7'd8, lvpx, lvpy, 7'd32, 7'd32);
                if (grid == G_LB && lb_init && !lb_ok && (hit_m || hit_b0 || hit_b1)) begin
                    levers[k] <= ~levers[k];
                    bulbs <= bulbs ^ lmask;
                end
                if (hit_m)  mel_used[k] <= 1'b1;
                if (hit_b0) pb_used[k] <= 1'b1;
                if (hit_b1) pb_used[4 + k] <= 1'b1;
                if (k == 2'd3) begin k <= 0; st <= P_PUSHA; end
                else k <= k + 1'b1;
            end
            // ---- Sokoban: ตรวจดันกล่อง k ----
            P_PUSHA: begin
                if (grid == G_LB && lb_init && bulbs == 4'b1111) lb_ok <= 1'b1;
                if (grid == G_SOKO && !sliding && in_one && touch(kbx, kby, in_dir)) begin
                    dx <= nbx; dy <= nby; ddir <= in_dir; dbox <= k[0];
                    ta <= tad(grid, nbx, nby);
                    st <= P_PUSHB;
                end else if (k == 2'd1) st <= P_SLIDE;
                else k <= 2'd1;
            end
            P_PUSHB: begin
                // ปลายทาง: พื้น / แผ่น, ไม่ใช่กล่องอีกใบ, ไม่ใช่ gate, ไม่ออกนอกห้อง
                if ((td == 4'h1 || td == 4'h7) && dx < 5'd20 && dy < 4'd15 &&
                    !(dx == GATE_TX && dy == GATE_TY) &&
                    !(dbox ? (dx == b0x && dy == b0y) : (dx == b1x && dy == b1y))) begin
                    if (dbox) begin b1x <= dx; b1y <= dy; sc1 <= BOX_SLIDE_FRAMES; sd1 <= ddir; end
                    else      begin b0x <= dx; b0y <= dy; sc0 <= BOX_SLIDE_FRAMES; sd0 <= ddir; end
                end
                st <= P_SLIDE;
            end
            P_SLIDE: begin
                if (sc0 != 0) sc0 <= sc0 - 1'b1;
                if (sc1 != 0) sc1 <= sc1 - 1'b1;
                if (!gate_open && sc0 == 0 && sc1 == 0 &&
                    ((b0x == PLATE0_TX && b0y == PLATE0_TY && b1x == PLATE1_TX && b1y == PLATE1_TY) ||
                     (b0x == PLATE1_TX && b0y == PLATE1_TY && b1x == PLATE0_TX && b1y == PLATE0_TY)))
                    gate_open <= 1'b1;
                ta <= tad(grid, ctx, cty);                  // จุดกลางผู้เล่น (Simon)
                st <= P_SIM1;
            end
            // ---- Simon ----
            P_SIM1: begin
                if (fb != 0) begin
                    fb <= fb - 1'b1;
                    if (fb == 1) lit_on <= 1'b0;
                end
                case (sm)
                SM_PRE: if (stmr == 0) begin sm <= SM_ON; sidx <= 0; stmr <= SIMON_ON - 1; end
                        else stmr <= stmr - 1'b1;
                SM_ON: begin
                    lit_on <= 1'b1; lit <= note_i;
                    if (stmr == 0) begin lit_on <= 1'b0; sm <= SM_GAP; stmr <= SIMON_GAP - 1; end
                    else stmr <= stmr - 1'b1;
                end
                SM_GAP: if (stmr == 0) begin
                            if (sidx == slen - 1) begin
                                sm <= SM_IN; sidx <= 0;
                                on_prev <= (td >= 4'hC);             // ยืนบนแผ่นอยู่แล้วไม่นับ
                            end else begin sidx <= sidx + 1'b1; sm <= SM_ON; stmr <= SIMON_ON - 1; end
                        end else stmr <= stmr - 1'b1;
                SM_IN: begin
                    on_prev <= (td >= 4'hC);
                    if (td >= 4'hC && !on_prev) begin                // ก้าวขึ้นแผ่นใหม่
                        if (td[1:0] == note_i) begin
                            lit_on <= 1'b1; lit <= td[1:0]; fb <= SIMON_FEEDBACK;
                            if (sidx == slen - 1) begin sm <= SM_OK; stmr <= SIMON_PRE - 1; end
                            else sidx <= sidx + 1'b1;
                        end else begin
                            hit <= 1'b1;
                            lit_on <= 1'b0; fb <= 0;
                            sm <= SM_WRONG; stmr <= SIMON_WRONG - 1;
                        end
                    end
                end
                SM_OK: if (stmr == 0) begin
                           if (round == 2'd2) begin sm <= SM_DONE; sm_ok <= 1'b1; end
                           else begin round <= round + 1'b1; sidx <= 0; sm <= SM_ON; stmr <= SIMON_ON - 1; end
                       end else stmr <= stmr - 1'b1;
                SM_WRONG: if (stmr == 0) begin sidx <= 0; sm <= SM_ON; stmr <= SIMON_ON - 1; end
                          else stmr <= stmr - 1'b1;
                default: ;
                endcase
                st <= P_ITEM;
            end
            // ---- ไอเทม: เดินทับ (hitbox ผู้เล่น x ช่องกลาง 16x16 ของ tile I) ----
            P_ITEM: begin
                if (grid == item_grid && item_vis && !picked[floor] &&
                    ovl({1'b0, px} + OFS + 11'd4, {1'b0, py} + OFS + 11'd4, 7'd24, 7'd24,
                        {1'b0, item_tx, 5'd0} + OFS + 11'd8, {2'b00, item_ty, 5'd0} + OFS + 11'd8, 7'd16, 7'd16)) begin
                    picked[floor] <= 1'b1;
                    got_item <= 1'b1;
                end
                st <= P_IDLE;
            end
            default: st <= P_IDLE;
            endcase
        end
    end

    assign has_item = picked;
    assign dbg_seq = seq;
    assign dbg_sm = sm;
    assign dbg_round = round;


    // ---------- Simon ----------
    assign simon_lit_on = lit_on && (grid == G_SIMON);
    assign simon_lit = lit;
    assign simon_wrong = (sm == SM_WRONG) && (grid == G_SIMON);
    assign simon_note_on = simon_lit_on;
    assign simon_note = lit;


    // ---------- sprite ปริศนา (เฟรมใน puzzle.mem) ----------
    // 0 หลอดดับ 1 หลอดติด 2 คันโยกขึ้น 3 คันโยกลง 4 กล่อง 5 gate ปิด 6 gate เปิด 7-9 ไอเทม 1-3
    function [9:0] bpos(input [4:0] t, input [4:0] sc, input [1:0] d, input horiz);
        reg [9:0] base, off;
        begin
            base = {t, 5'd0};
            off  = sc * BOX_STEP;
            if (horiz) bpos = (d == 2'd3) ? base - off : (d == 2'd2) ? base + off : base;
            else       bpos = (d == 2'd0) ? base - off : (d == 2'd1) ? base + off : base;
        end
    endfunction
    // คำนวณใหม่ทุก 64 clock (ค่าเปลี่ยนแค่ตอนประมวลผลต่อเฟรม / เข้าห้อง / SW13) -> ไม่เป็น logic ที่ต้องคิดทุก clock
    // (หน่วงไม่เกิน 64 clock: ไม่ถึง 1 บรรทัดภาพ และเสร็จก่อนเฟรมถัดไปเสมอ)
    reg [5:0] ucnt = 0;
    always @(posedge clk) begin : pz_upd
        reg [8:0] a_; reg [89:0] x_, y_; reg [35:0] f_;
        reg on_p0, on_p1; reg [1:0] rdone;
        reg [3:0] item_grid; reg [4:0] item_tx; reg [3:0] item_ty; reg item_vis;
        ucnt <= ucnt + 1'b1;
        if (ucnt == 0) begin
            on_p0 = (b0x == PLATE0_TX && b0y == PLATE0_TY) || (b0x == PLATE1_TX && b0y == PLATE1_TY);
            on_p1 = (b1x == PLATE0_TX && b1y == PLATE0_TY) || (b1x == PLATE1_TX && b1y == PLATE1_TY);
            item_grid = f_item_grid(floor); item_tx = f_item_tx(floor); item_ty = f_item_ty(floor);
            item_vis = f_item_vis(floor);
            // กันการเดิน: กล่อง 2 + gate (ตอนปิด)
            blk0 <= tad(G_SOKO, b0x, b0y);
            blk1 <= tad(G_SOKO, b1x, b1y);
            blk2 <= tad(G_SOKO, GATE_TX, GATE_TY);
            blk_en <= {!gate_open, 1'b1, 1'b1};
            // แผ่นมีกล่องวางนิ่ง -> tile 11
            pbox0 <= tad(G_SOKO, b0x, b0y);
            pbox1 <= tad(G_SOKO, b1x, b1y);
            pbox_en <= {sc1 == 0 && on_p1, sc0 == 0 && on_p0};
            // LED0-3 ในห้องปริศนา: หลอด / รอบ Simon ที่ผ่าน
            rdone = sm_ok ? 2'd3 : round;
            room_led_on <= (grid == G_LB) || (grid == G_SIMON);
            room_led <= (grid == G_LB) ? bulbs : {1'b0, rdone == 2'd3, rdone >= 2'd2, rdone >= 2'd1};
            a_ = 0; x_ = 0; y_ = 0; f_ = 0;
            if (grid == G_LB) begin
                a_[7:0] = 8'hFF;
                x_[0*10 +: 10] = {LEVER0_TX, 5'd0}; y_[0*10 +: 10] = {1'b0, LEVER0_TY, 5'd0}; f_[0*4 +: 4] = 4'd2 + levers[0];
                x_[1*10 +: 10] = {LEVER1_TX, 5'd0}; y_[1*10 +: 10] = {1'b0, LEVER1_TY, 5'd0}; f_[1*4 +: 4] = 4'd2 + levers[1];
                x_[2*10 +: 10] = {LEVER2_TX, 5'd0}; y_[2*10 +: 10] = {1'b0, LEVER2_TY, 5'd0}; f_[2*4 +: 4] = 4'd2 + levers[2];
                x_[3*10 +: 10] = {LEVER3_TX, 5'd0}; y_[3*10 +: 10] = {1'b0, LEVER3_TY, 5'd0}; f_[3*4 +: 4] = 4'd2 + levers[3];
                x_[4*10 +: 10] = {BULB0_TX, 5'd0};  y_[4*10 +: 10] = {1'b0, BULB0_TY, 5'd0};  f_[4*4 +: 4] = {3'd0, bulbs[3]};
                x_[5*10 +: 10] = {BULB1_TX, 5'd0};  y_[5*10 +: 10] = {1'b0, BULB1_TY, 5'd0};  f_[5*4 +: 4] = {3'd0, bulbs[2]};
                x_[6*10 +: 10] = {BULB2_TX, 5'd0};  y_[6*10 +: 10] = {1'b0, BULB2_TY, 5'd0};  f_[6*4 +: 4] = {3'd0, bulbs[1]};
                x_[7*10 +: 10] = {BULB3_TX, 5'd0};  y_[7*10 +: 10] = {1'b0, BULB3_TY, 5'd0};  f_[7*4 +: 4] = {3'd0, bulbs[0]};
            end else if (grid == G_SOKO) begin
                a_[0] = !(sc0 == 0 && on_p0);   // วางนิ่งบนแผ่น = tile 11 แทน
                x_[0*10 +: 10] = bpos(b0x, sc0, sd0, 1'b1); y_[0*10 +: 10] = bpos({1'b0, b0y}, sc0, sd0, 1'b0);
                f_[0*4 +: 4] = 4'd4;
                a_[1] = !(sc1 == 0 && on_p1);
                x_[1*10 +: 10] = bpos(b1x, sc1, sd1, 1'b1); y_[1*10 +: 10] = bpos({1'b0, b1y}, sc1, sd1, 1'b0);
                f_[1*4 +: 4] = 4'd4;
                a_[2] = 1'b1;
                x_[2*10 +: 10] = {GATE_TX, 5'd0}; y_[2*10 +: 10] = {1'b0, GATE_TY, 5'd0};
                f_[2*4 +: 4] = gate_open ? 4'd6 : 4'd5;
            end
            if (grid == item_grid && item_vis && !picked[floor]) begin
                a_[8] = 1'b1;
                x_[8*10 +: 10] = {item_tx, 5'd0}; y_[8*10 +: 10] = {1'b0, item_ty, 5'd0};
                f_[8*4 +: 4] = 4'd7 + floor;
            end
            pz_act <= a_; pz_x <= x_; pz_y <= y_; pz_frame <= f_;
        end
    end
endmodule
