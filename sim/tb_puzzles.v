`timescale 1ns/1ps
// ทดสอบ puzzles.v ร่วมกับ player.v + objects.v + game_fsm.v (frame_tick ทุก 600 clock)
//   Light Bulb (grid 6), Sokoban (grid 9) เล่นตามคำตอบของ scripts/solve_sokoban.py, Simon (grid 12),
//   ไอเทม -> EVOLVE + has_item -> ประตู L, สถานะค้างเมื่อออก/กลับห้อง, restart ล้างหมด
// รัน: ./scripts/run_sim.sh puzzles
module tb_puzzles;
    `include "sokoban_solution.vh"
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;

    localparam TICK = 600;
    integer tc = 0; reg tick = 0; integer frame_no = 0;
    always @(posedge clk) begin
        tc <= (tc == TICK - 1) ? 0 : tc + 1;
        tick <= (tc == TICK - 1);
        if (tick) frame_no <= frame_no + 1;
    end

    // ---------- DUT ----------
    reg up = 0, down = 0, left = 0, right = 0, atk_press = 0, atk_hold = 0;
    reg fsm_btnc = 0, item_dbg = 0, soko_reset = 0, restart_tb = 0;
    reg [1:0] floor = 0; reg [2:0] room = 0; reg [3:0] grid = 0;
    reg p_load = 0, o_load = 0; reg [9:0] lx = 288, ly = 224;

    wire [2:0] state, hp, hp_max, speed, rgb; wire [1:0] form, damage;
    wire restart, next_floor, freeze, fsm_hide; wire [3:0] m_t, m_o, s_t, s_o;
    wire [9:0] px, py; wire [1:0] facing, pose, door_dir; wire door_evt;
    wire doors_open, obj_hit, kb_start, invuln, blink, obj_busy, melee_on, mon_anim;
    wire [1:0] kb_dir, melee_dir; wire [5:0] pb_act; wire [11:0] pb_kind; wire charged; wire [2:0] alive;
    wire [5:0] mon_act, mon_type, mon_flash; wire [59:0] mon_x, mon_y;
    wire [59:0] pb_x, pb_y; wire [15:0] eb_act; wire [159:0] eb_x, eb_y;
    wire pz_got, pz_hit, pz_busy, lit_on, wrong, note_on, led_on, lb_ok, gate_open, sm_ok;
    wire [1:0] lit, note, pbox_en; wire [3:0] room_led, bulbs;
    wire [2:0] has_item, blk_en; wire [11:0] blk0, blk1, blk2, pbox0, pbox1;
    wire [8:0] pz_act; wire [89:0] pz_x, pz_y; wire [35:0] pz_frame;
    wire [9:0] dseq; wire [2:0] dsm; wire [1:0] dround;

    game_fsm #(.PROLOGUE(0)) fsm (.clk(clk), .rst(rst), .frame_tick(tick), .btnc_rise(fsm_btnc), .got_item(pz_got | item_dbg),
                  .take_hit(obj_hit | pz_hit), .floor_done(1'b0), .exit_evt(1'b0), .escape_start(1'b0), .exit_direct(1'b1), .sprint(1'b0), .key_get(1'b0), .goal(1'b0), .kill(1'b0),
                  .state(state), .restart(restart), .next_floor(next_floor), .form(form), .hp(hp),
                  .hp_max(hp_max), .speed(speed), .damage(damage), .rgb(rgb), .freeze(freeze),
                  .hide_player(fsm_hide), .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o));

    player pl (.open_E(form == 2'd3), .brk(8'd0), .clk(clk), .rst(rst), .frame_tick(tick), .up(up), .down(down), .left(left), .right(right),
               .hold_facing(atk_hold), .form(form), .speed(speed), .freeze(freeze), .grid(grid),
               .doors_open(doors_open), .open_L(has_item[floor]), .load(p_load), .load_x(lx), .load_y(ly),
               .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
               .kb_start(kb_start), .kb_dir(kb_dir), .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir));

    objects ob (.brk(8'd0), .brk_set(), .brk_idx(), .clk(clk), .rst(rst), .frame_tick(tick), .run(state == 3'd1), .restart(restart | restart_tb),
                .room_load(o_load), .floor(floor), .room(room), .grid(grid), .open_L(has_item[floor]),
                .px(px), .py(py), .facing(facing), .form(form), .damage(damage),
                .atk_press(atk_press), .atk_hold(atk_hold), .dbg_clear(1'b0),
                .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
                .boss_act(1'b0), .boss_x(10'd0), .boss_y(10'd0), .boss_fire(1'b0), .summon(1'b0), .boss_dmg(), .boss_dmg_amt(), .boss_dmg_big(),
                .doors_open(doors_open), .alive(alive), .hit(obj_hit), .kb_start(kb_start), .kb_dir(kb_dir),
                .invuln(invuln), .player_blink(blink), .busy(obj_busy),
                .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .pb_kind(pb_kind), .charged(charged),
                .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir));

    puzzles #(.SEED(16'h0000)) pz (.clk(clk), .rst(rst), .frame_tick(tick), .run(state == 3'd1),
                .restart(restart | restart_tb), .room_load(o_load), .floor(floor), .grid(grid), .px(px), .py(py),
                .up(up), .down(down), .left(left), .right(right), .melee_on(melee_on), .melee_dir(melee_dir),
                .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .soko_reset(soko_reset),
                .got_item(pz_got), .hit(pz_hit), .has_item(has_item),
                .blk0(blk0), .blk1(blk1), .blk2(blk2), .blk_en(blk_en),
                .pz_act(pz_act), .pz_x(pz_x), .pz_y(pz_y), .pz_frame(pz_frame),
                .pbox0(pbox0), .pbox1(pbox1), .pbox_en(pbox_en),
                .simon_lit_on(lit_on), .simon_lit(lit), .simon_wrong(wrong), .simon_note_on(note_on), .simon_note(note),
                .room_led(room_led), .room_led_on(led_on),
                .bulbs(bulbs), .lb_ok(lb_ok), .gate_open(gate_open), .sm_ok(sm_ok), .busy(pz_busy),
                .dbg_seq(dseq), .dbg_sm(dsm), .dbg_round(dround));

    // ---------- monitors ----------
    integer errors = 0, checks = 0, gots = 0, hits = 0, doors = 0;
    always @(posedge clk) begin
        if (pz_got) gots = gots + 1;
        if (pz_hit) hits = hits + 1;
        if (door_evt) doors = doors + 1;
    end
    task check(input cond, input [8*96-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin
            $display("FAIL  %0s  (frame %0d px=%0d py=%0d hp=%0d state=%0d bulbs=%b sm=%0d)", msg, frame_no, px, py, hp, state, bulbs, dsm);
            errors = errors + 1;
        end
    end endtask
    task frames(input integer n); integer q; begin
        for (q = 0; q < n; q = q + 1) @(posedge tick);
        repeat (2) @(posedge clk);
        while (obj_busy || pz_busy) @(posedge clk);
        repeat (5) @(posedge clk);
    end endtask
    task press; begin @(posedge clk); atk_press <= 1; @(posedge clk); atk_press <= 0; end endtask
    task place(input [9:0] x, input [9:0] y); begin
        lx <= x; ly <= y; @(posedge clk) p_load <= 1; @(posedge clk) p_load <= 0; repeat (2) @(posedge clk);
    end endtask
    task enter(input [3:0] g, input [1:0] f, input [2:0] r, input [9:0] x, input [9:0] y); begin
        grid <= g; floor <= f; room <= r; lx <= x; ly <= y;
        @(posedge clk) begin p_load <= 1; o_load <= 1; end
        @(posedge clk) begin p_load <= 0; o_load <= 0; end
        repeat (40) @(posedge clk);
        while (obj_busy || pz_busy) @(posedge clk);
        repeat (5) @(posedge clk);                       // ถ้าเข้าห้องตอนกำลังประมวลผลเฟรม: รอให้งานเข้าห้องเสร็จด้วย
        while (obj_busy || pz_busy) @(posedge clk);
        repeat (2) @(posedge clk);
    end endtask
    task wait_play; integer q; begin
        for (q = 0; q < 200 && state != 3'd1; q = q + 1) frames(1);
    end endtask
    task heal; begin while (pz_busy || obj_busy) @(posedge clk); fsm.hp = fsm.hp_max; end endtask

    // ---------- Light Bulb: หาเซตคันโยกที่ตีน้อยสุด ----------
    reg [3:0] M [0:3];
    initial begin M[0] = 4'b0111; M[1] = 4'b1011; M[2] = 4'b1101; M[3] = 4'b1110; end
    function [3:0] xorset(input [3:0] sel);
        integer z; begin xorset = 0; for (z = 0; z < 4; z = z + 1) if (sel[z]) xorset = xorset ^ M[z]; end
    endfunction
    function [2:0] pop4(input [3:0] v); pop4 = v[0] + v[1] + v[2] + v[3]; endfunction
    function [3:0] best(input [3:0] pat);     // เซตคันโยกที่ทำให้ pat -> 1111 ด้วยจำนวนครั้งน้อยสุด
        integer z; reg [2:0] bp; begin
            best = 0; bp = 7;
            for (z = 0; z < 16; z = z + 1)
                if ((pat ^ xorset(z)) == 4'b1111 && pop4(z) < bp) begin best = z; bp = pop4(z); end
        end
    endfunction

    // หันขึ้นแล้วฟันคันโยก k (ยืนแถว 2 ใต้คันโยก)
    task hit_lever(input integer k); reg [4:0] tx; begin
        tx = (k == 0) ? 4 : (k == 1) ? 8 : (k == 2) ? 12 : 16;
        place({tx, 5'd0}, 10'd70);
        up = 1; frames(1); up = 0;
        press; frames(10); frames(12);          // ฟัน 8 เฟรม + cooldown 20
    end endtask

    // ---------- Sokoban: เดิน/ดันทีละช่อง (กดค้างจนผู้เล่นตรงช่องเป้าหมาย) ----------
    integer rec_n = 0;
    reg [8*2048-1:0] rec;                    // สคริปต์ Verilator ที่บันทึก (เฟรมนับจากเข้าห้อง)
    integer rec_base = 0;
    task go(input [7:0] c); reg [9:0] tx, ty; integer q, f0; reg [7:0] kc; begin
        tx = px; ty = py;
        case (c)
            "U", "u": begin ty = py - 32; up = 1;    kc = "U"; end
            "D", "d": begin ty = py + 32; down = 1;  kc = "D"; end
            "L", "l": begin tx = px - 32; left = 1;  kc = "L"; end
            default:  begin tx = px + 32; right = 1; kc = "R"; end
        endcase
        f0 = frame_no;
        for (q = 0; q < 80 && !(px == tx && py == ty); q = q + 1) frames(1);
        up = 0; down = 0; left = 0; right = 0;
        $sformat(rec, "%0s%0s%c:%0d:%0d", rec, (rec_n == 0) ? "" : ",", kc, f0 - rec_base, frame_no - rec_base - 1);
        rec_n = rec_n + 1;
        if (!(px == tx && py == ty)) begin
            $display("FAIL  move %c did not reach (%0d,%0d), at (%0d,%0d)", c, tx, ty, px, py);
            errors = errors + 1;
        end
    end endtask

    // ---------- Simon: ยืนบนแผ่น / ลงจากแผ่น ----------
    task step_plate(input [1:0] n); reg [9:0] x, y; begin
        x = n[0] ? 10'd392 : 10'd200;     // q (6,4) w (12,4) e (6,9) r (12,9): จุดกลาง (x+16, y+16) อยู่ใน tile
        y = n[1] ? 10'd296 : 10'd136;
        place(x, y); frames(3);
    end endtask
    task step_off; begin place(10'd96, 10'd224); frames(3); end endtask
    task wait_input; integer q; begin
        for (q = 0; q < 900 && dsm != 3'd4; q = q + 1) frames(1);
    end endtask

    integer n, i, ok, distinct, pat_seen, before_bulbs, sel, hp0;
    reg [15:0] seen;
    reg [9:0] seq;
    reg [4:0] b0x0, b1x0; reg [3:0] b0y0, b1y0;
    initial begin
        repeat (5) @(posedge clk); rst <= 0;
        repeat (5) @(posedge clk);

        // ================= Light Bulb: คณิต GF(2) =================
        ok = 1;
        for (n = 0; n < 16; n = n + 1) begin
            if ((n ^ xorset(best(n))) != 4'b1111) ok = 0;
        end
        check(ok, "every bulb pattern is solvable with masks 0111/1011/1101/1110 (invertible over GF(2))");
        ok = 1;
        for (n = 0; n < 16; n = n + 1) for (i = n + 1; i < 16; i = i + 1) if (xorset(n) == xorset(i)) ok = 0;
        check(ok, "the 16 lever subsets give 16 different XOR results (unique solution)");

        // เริ่มเกม
        @(posedge clk) fsm_btnc <= 1; @(posedge clk) fsm_btnc <= 0;
        enter(0, 0, 0, 288, 224); frames(2);
        check(state == 1, "game in PLAY");

        // ================= Light Bulb: สุ่มรูปแบบ (ต้องตี >= 2 ครั้ง) =================
        ok = 1; seen = 0;
        for (n = 0; n < 40; n = n + 1) begin
            @(posedge clk) restart_tb <= 1; @(posedge clk) restart_tb <= 0;
            repeat (n * 37 + 3) @(posedge clk);          // ให้ LFSR ต่างกันแต่ละรอบ
            enter(6, 0, 3, 40, 240);
            if (!pz.lb_init || pop4(best(bulbs)) < 2) begin ok = 0; $display("      gen %0d: init=%b bulbs=%b", n, pz.lb_init, bulbs); end
            seen[bulbs] = 1'b1;
        end
        distinct = pop4(seen[3:0]) + pop4(seen[7:4]) + pop4(seen[11:8]) + pop4(seen[15:12]);
        check(ok, "40 random start patterns all need >= 2 lever hits");
        check(distinct >= 5 && !seen[15] && !seen[8] && !seen[4] && !seen[2] && !seen[1],
              "start patterns vary; 1111 and 1-hit patterns never generated");
        $display("      %0d different start patterns seen", distinct);
        repeat (70) @(posedge clk);                       // LED / sprite อัปเดตทุก 64 clock
        check(led_on && room_led == bulbs, "LED0-3 show the bulbs in this room");
        check(pz_act[8:0] == 9'h0FF, "levers + bulbs drawn, item hidden while unsolved");

        // ตีคันโยก a ด้วยฟันประชิด: XOR 0111, ครั้งเดียวต่อการฟัน
        before_bulbs = bulbs;
        hit_lever(0);
        check(bulbs == (before_bulbs ^ 4'b0111) && pz.levers[0] == 1, "melee on lever a: bulbs ^= 0111 once, lever flips");
        hit_lever(0);
        check(bulbs == before_bulbs && pz.levers[0] == 0, "second hit on lever a toggles back");
        // กระสุน (ร่าง 2): ยิงขึ้นใส่คันโยก b ครั้งเดียวต่อกระสุน
        @(posedge clk) item_dbg <= 1; @(posedge clk) item_dbg <= 0;
        frames(62); wait_play;
        check(form == 1, "form 2 (shooter) for the bullet test");
        before_bulbs = bulbs;
        place(10'd256, 10'd200); up = 1; frames(1); up = 0;
        press; frames(40);
        check(bulbs == (before_bulbs ^ 4'b1011), "player bullet through lever b: bulbs ^= 1011 exactly once");
        // แก้ให้ครบ: คำนวณเซตคันโยกที่ต้องตี แล้วยิงทีละคัน
        sel = best(bulbs);
        $display("      bulbs=%b -> hit levers %b", bulbs, sel[3:0]);
        for (n = 0; n < 4; n = n + 1) if (sel[n]) begin
            place({n == 0 ? 5'd4 : n == 1 ? 5'd8 : n == 2 ? 5'd12 : 5'd16, 5'd0}, 10'd200);
            up = 1; frames(1); up = 0; press; frames(40);
        end
        frames(2);
        check(bulbs == 4'b1111 && lb_ok, "Light Bulb solved: all 4 bulbs on");
        check(pz_act[8] && pz_frame[35:32] == 4'd7, "item 1 appears at I when solved");
        gots = 0;
        place(10'd320, 10'd200); down = 1; frames(30); down = 0; frames(2);
        check(gots == 1 && has_item[0] && state == 3'd2, "walk over item 1: got_item -> EVOLVE, has_item[0] = 1");
        frames(65); wait_play;
        check(form == 2 && !pz_act[8], "evolved to form 3, item gone");
        // ประตู L ชั้น 1 เปิดแล้ว (C1 ชั้น 1 = grid 4, L ขวา)
        enter(4, 0, 1, 40, 240);
        while (pz_busy || obj_busy) @(posedge clk);
        ob.m_act = 0;                                     // ห้องนี้ไม่ใช่เรื่องของ tb นี้: เอามอนออก
        frames(2); doors = 0;
        place(10'd540, 10'd240); right = 1; frames(40); right = 0;
        check(doors >= 1 && door_dir == 3, "boss door L opens with has_item[0] (no SW0)");
        // ออกแล้วกลับเข้าห้องปริศนา: ยัง solved, ไม่มีไอเทมซ้ำ
        enter(6, 0, 3, 40, 240); frames(2);
        check(lb_ok && bulbs == 4'b1111 && !pz_act[8] && has_item[0], "Light Bulb state kept after leaving and coming back");

        // ================= Sokoban: กติกาการดัน =================
        heal;
        fsm.form = 2'd1;                                  // ร่าง 2 ความเร็ว 2 px/เฟรม (ตรงตาม tile ทุก 16 เฟรม)
        enter(9, 1, 3, 40, 240); frames(2);
        b0x0 = pz.b0x; b0y0 = pz.b0y; b1x0 = pz.b1x; b1y0 = pz.b1y;
        check(b0x0 == 8 && b0y0 == 5 && b1x0 == 11 && b1y0 == 6 && !gate_open, "boxes at start (8,5) (11,6), gate closed");
        // ดันขวาใส่กำแพง: (9,5) = #
        place(10'd224, 10'd160); right = 1; frames(12); right = 0;
        check(pz.b0x == 8 && pz.b0y == 5 && px + 27 < 256, "box against wall does not move; box blocks player");
        // ทแยงไม่ดัน: ยืนเหนือกล่อง กดลง + ขวา
        place(10'd256, 10'd128); down = 1; right = 1; frames(12); down = 0; right = 0;
        check(pz.b0x == 8 && pz.b0y == 5, "diagonal input does not push");
        // ดันลง: (8,6) ว่าง
        place(10'd256, 10'd128); down = 1; frames(4); down = 0; frames(10);
        check(pz.b0x == 8 && pz.b0y == 6, "straight push down moves the box 1 tile");
        check(pz.sc0 == 0, "slide finished after 8 frames");
        // ดันขวาไปชนกล่องอีกใบ: กล่อง 0 ที่ (9,6), ผู้เล่น (8,6) -> (10,6) แล้ว (11,6) = กล่อง 1
        while (pz_busy) @(posedge clk);
        pz.b0x = 5'd9; pz.b0y = 4'd6;
        place(10'd256, 10'd192); right = 1; frames(60); right = 0; frames(10);
        check(pz.b0x == 10 && pz.b0y == 6, "box stops next to the other box (box cannot push box)");
        // gate กั้น: วางกล่อง 1 ที่ (12,7) แล้วดันขวาเข้า gate (13,7)
        while (pz_busy) @(posedge clk);
        pz.b1x = 5'd12; pz.b1y = 4'd7;
        place(10'd352, 10'd224); right = 1; frames(20); right = 0; frames(4);
        check(pz.b1x == 12 && pz.b1y == 7, "box cannot be pushed into the closed gate");
        place(10'd384, 10'd256);                          // (12,8) ใต้ gate
        while (pz_busy) @(posedge clk);
        pz.b1x = 5'd11; pz.b1y = 4'd6;
        place(10'd384, 10'd224); right = 1; frames(20); right = 0;
        check(px + 27 < 416, "closed gate blocks the player");
        // SW13 รีเซ็ต
        @(posedge clk) soko_reset <= 1; @(posedge clk) soko_reset <= 0; frames(1);
        check(pz.b0x == 8 && pz.b0y == 5 && pz.b1x == 11 && pz.b1y == 6, "SW13 resets both boxes to start");

        // ================= Sokoban: เล่นตามคำตอบ solver =================
        place(10'd32, 10'd224);                           // ช่อง (1,7) ตรง tile (จุดเริ่มของ solver)
        frames(2);
        rec_base = frame_no; rec_n = 0; rec = 0;
        for (n = 0; n < SOKO_N; n = n + 1) go(SOKO_MOVES[8*(SOKO_N - 1 - n) +: 8]);
        frames(12);
        check(gate_open, "solver solution (24 pushes) replayed as button presses opens the gate");
        $display("      replay took %0d frames; Verilator script (frames from standing at (1,7)):", frame_no - rec_base);
        $display("SCRIPT %0s", rec);
        check(pbox_en == 2'b11, "both boxes resting on plates show tile 11");
        @(posedge clk) soko_reset <= 1; @(posedge clk) soko_reset <= 0; frames(1);
        check(gate_open && pbox_en == 2'b11, "SW13 ignored once the gate is open");
        // gate เปิดแล้ว = กล่องล็อก: ถ้ายังไม่ล็อก การดันนี้จะเลื่อนกล่องได้
        place(10'd224, 10'd288); right = 1; frames(20); right = 0; frames(10);   // ยืน (7,9) ระหว่างแผ่น ดันกล่อง (8,9) ไป (9,9) ที่ว่าง
        check(pz.b0x == 6 && pz.b0y == 9 && pz.b1x == 8 && pz.b1y == 9 || pz.b0x == 8 && pz.b1x == 6,
              "after the gate opens the boxes are locked (pushing does nothing)");
        // ผ่าน gate ไปเก็บไอเทม 2
        gots = 0;
        place(10'd384, 10'd224); right = 1; frames(70); right = 0; frames(2);
        check(gots == 1 && has_item[1], "walk through the open gate, pick item 2: has_item[1]");
        frames(65); wait_play;
        // ออก/กลับ: กล่องยังอยู่บนแผ่น, gate เปิด
        enter(8, 1, 2, 300, 400);
        enter(9, 1, 3, 40, 240); frames(2);
        check(gate_open && pbox_en == 2'b11 && !pz_act[8], "Sokoban state kept after leaving and coming back");

        // ================= Simon =================
        heal;
        enter(12, 2, 3, 40, 240);
        wait_input;
        seq = dseq;
        check(dsm == 3'd4 && dround == 0, "Simon shows round 1 then waits for input");
        $display("      Simon sequence (first plate = bits 1:0): %b", seq);
        // ยืนนิ่งบนแผ่นที่ถูก: นับครั้งเดียว
        step_plate(seq[1:0]); frames(10);
        check(pz.sidx == 1, "standing still on a plate counts once");
        step_off;
        // เหยียบผิด: HP -1, เล่นรอบเดิมใหม่
        hp0 = hp; hits = 0;
        step_plate(seq[3:2] ^ 2'd1); frames(2);
        check(hits == 1 && hp == hp0 - 1 && dsm == 3'd6 && wrong, "wrong plate: HP -1 (no knockback), red flash");
        check(!kb_start && !invuln, "Simon mistake has no knockback / invulnerability");
        step_off; wait_input;
        check(dround == 0 && pz.sidx == 0, "same round replayed after a mistake");
        heal;
        // เล่นถูกครบ 3 รอบ (3, 4, 5 แผ่น)
        for (i = 0; i < 3; i = i + 1) begin
            wait_input;
            for (n = 0; n < 3 + i; n = n + 1) begin step_plate(seq[2*n +: 2]); step_off; end
            frames(2);
        end
        frames(50);
        check(sm_ok && pz_act[8] && pz_frame[35:32] == 4'd9, "3 rounds done: Simon solved, item 3 appears");
        check(room_led[2:0] == 3'b111, "LED0-2 show 3 rounds done");
        gots = 0;
        place(10'd320, 10'd190); down = 1; frames(20); down = 0; frames(2);
        check(gots == 1 && has_item[2], "item 3 picked: has_item[2]");
        frames(65); wait_play;
        enter(11, 2, 2, 300, 400); enter(12, 2, 3, 40, 240); frames(60);
        check(sm_ok && dsm == 3'd7 && !pz_act[8], "Simon stays solved after leaving and coming back");

        // ================= restart ล้างทุกอย่าง =================
        @(posedge clk) restart_tb <= 1; @(posedge clk) restart_tb <= 0; frames(1);
        check(has_item == 0 && !lb_ok && !pz.lb_init && !gate_open && !sm_ok && !pz.seq_init &&
              pz.b0x == 8 && pz.b0y == 5 && pz.b1x == 11 && pz.b1y == 6, "restart resets all puzzles and items");

        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
