`timescale 1ns/1ps
// ทดสอบ objects.v + player.v (knockback) + game_fsm.v (HP) ร่วมกัน, frame_tick ทุก 400 clock
// รัน: ./scripts/run_sim.sh objects
// ห้อง: grid 0 = START ชั้น 1 (ไม่มีมอน), grid 4 = C1 ชั้น 1 (มอน A 3 ตัว), grid 7 = C1 ชั้น 2 (ป้อม 4 + A 2, รั้ว F)
module tb_objects;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;

    // ---------- frame tick ----------
    localparam TICK = 400;
    integer tc = 0; reg tick = 0; integer frame_no = 0;
    always @(posedge clk) begin
        tc <= (tc == TICK - 1) ? 0 : tc + 1;
        tick <= (tc == TICK - 1);
        if (tick) frame_no <= frame_no + 1;
    end

    // ---------- DUT ----------
    reg up = 0, down = 0, left = 0, right = 0;
    reg atk_press = 0, atk_hold = 0;
    reg fsm_btnc = 0, item = 0;
    reg [1:0] floor = 0; reg [2:0] room = 0; reg [3:0] grid = 0;
    reg p_load = 0, o_load = 0, restart_tb = 0; reg [9:0] lx = 288, ly = 224;
    reg open_L = 0;

    wire [2:0] state, hp, hp_max, speed, rgb; wire [1:0] form, damage;
    wire restart, next_floor, freeze, fsm_hide;
    wire [3:0] m_t, m_o, s_t, s_o;
    wire [9:0] px, py; wire [1:0] facing, pose, door_dir; wire door_evt;
    wire doors_open, hit, kb_start, invuln, blink, busy, melee_on, mon_anim;
    wire [1:0] kb_dir, melee_dir, pb_act; wire [2:0] alive;
    wire [5:0] mon_act, mon_type, mon_flash; wire [59:0] mon_x, mon_y;
    wire [19:0] pb_x, pb_y; wire [15:0] eb_act; wire [159:0] eb_x, eb_y;

    game_fsm fsm (.clk(clk), .rst(rst), .frame_tick(tick), .btnc_rise(fsm_btnc), .got_item(item),
                  .take_hit(hit), .floor_done(1'b0), .exit_evt(1'b0), .sprint(1'b0),
                  .state(state), .restart(restart), .next_floor(next_floor), .form(form), .hp(hp),
                  .hp_max(hp_max), .speed(speed), .damage(damage), .rgb(rgb), .freeze(freeze),
                  .hide_player(fsm_hide), .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o));

    player pl (.clk(clk), .rst(rst), .frame_tick(tick), .up(up), .down(down), .left(left), .right(right),
               .hold_facing(atk_hold), .form(form), .speed(speed), .freeze(freeze), .grid(grid),
               .doors_open(doors_open), .open_L(open_L), .load(p_load), .load_x(lx), .load_y(ly),
               .kb_start(kb_start), .kb_dir(kb_dir), .blk0(12'd0), .blk1(12'd0), .blk2(12'd0), .blk_en(3'd0), .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir));

    objects dut (.clk(clk), .rst(rst), .frame_tick(tick), .run(state == 3'd1), .restart(restart | restart_tb),
                 .room_load(o_load), .floor(floor), .room(room), .grid(grid), .open_L(open_L),
                 .px(px), .py(py), .facing(facing), .form(form), .damage(damage),
                 .atk_press(atk_press), .atk_hold(atk_hold), .dbg_clear(1'b0),
                 .blk0(12'd0), .blk1(12'd0), .blk2(12'd0), .blk_en(3'd0),
                 .doors_open(doors_open), .alive(alive), .hit(hit), .kb_start(kb_start), .kb_dir(kb_dir),
                 .invuln(invuln), .player_blink(blink), .busy(busy),
                 .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                 .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y),
                 .eb_act(eb_act), .eb_x(eb_x), .eb_y(eb_y), .melee_on(melee_on), .melee_dir(melee_dir));

    // ---------- monitors ----------
    integer errors = 0, checks = 0;
    integer hits = 0, doors = 0, kbs = 0;
    integer busy_len = 0, busy_max = 0;
    always @(posedge clk) begin
        if (hit) hits = hits + 1;
        if (door_evt) doors = doors + 1;
        if (kb_start) kbs = kbs + 1;
        if (busy) busy_len = busy_len + 1;
        else begin
            if (busy_len > busy_max) busy_max = busy_len;
            busy_len = 0;
        end
    end

    task check(input cond, input [8*96-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin
            $display("FAIL  %0s  (frame %0d px=%0d py=%0d hp=%0d alive=%0d doors_open=%0b)",
                     msg, frame_no, px, py, hp, alive, doors_open);
            errors = errors + 1;
        end
    end endtask

    // รอ n frame_tick แล้วรอให้ objects ประมวลผลเสร็จ
    task frames(input integer n); integer q; begin
        for (q = 0; q < n; q = q + 1) @(posedge tick);
        repeat (2) @(posedge clk);
        while (busy) @(posedge clk);
        repeat (20) @(posedge clk);
    end endtask
    task press; begin @(posedge clk); atk_press <= 1; @(posedge clk); atk_press <= 0; end endtask
    // วางผู้เล่น (ไม่ spawn มอน)
    task place(input [3:0] g, input [9:0] x, input [9:0] y); begin
        grid <= g; lx <= x; ly <= y;
        @(posedge clk) p_load <= 1; @(posedge clk) p_load <= 0;
        repeat (2) @(posedge clk);
    end endtask
    // เข้าห้อง: วางผู้เล่น + spawn มอนของห้อง
    task enter(input [3:0] g, input [1:0] f, input [2:0] r, input [9:0] x, input [9:0] y); begin
        grid <= g; floor <= f; room <= r; lx <= x; ly <= y;
        @(posedge clk) begin p_load <= 1; o_load <= 1; end
        @(posedge clk) begin p_load <= 0; o_load <= 0; end
        repeat (20) @(posedge clk);
        while (busy) @(posedge clk);
    end endtask
    task clear_all; begin
        while (busy) @(posedge clk);
        dut.m_act = 0; dut.p_act = 0; dut.e_act = 0; dut.melee_cnt = 0; dut.cool = 0; dut.hurt_cnt = 0;
    end endtask
    // วางมอนเอง (slot s)
    task put_mon(input integer s, input typ, input [9:0] x, input [9:0] y, input [2:0] h); begin
        while (busy) @(posedge clk);
        dut.m_act[s] = 1; dut.m_typ[s] = typ; dut.m_xv[(s)*10 +: 10] = x; dut.m_yv[(s)*10 +: 10] = y; dut.m_hpv[(s)*3 +: 3] = h;
        dut.m_flv[(s)*4 +: 4] = 0; dut.m_tmrv[(s)*9 +: 9] = 9'd500;                       // ป้อมไม่ยิงระหว่างทดสอบ
    end endtask
    task put_eb(input integer s, input [9:0] x, input [9:0] y, input [1:0] d); begin
        while (busy) @(posedge clk);
        dut.e_act[s] = 1; dut.e_xv[(s)*10 +: 10] = x; dut.e_yv[(s)*10 +: 10] = y; dut.e_dirv[(s)*2 +: 2] = d;
    end endtask
    task heal; begin while (busy) @(posedge clk); fsm.hp = fsm.hp_max; end endtask

    // ---------- ป้อมยิง: บันทึกเฟรมที่แต่ละ slot ยิง ----------
    integer fire_frame [0:5][0:3];
    integer fire_cnt [0:5];
    integer fire_bul [0:5];
    integer t;
    reg [15:0] eb_prev = 0;
    reg in_fire = 0;
    always @(posedge clk) begin
        eb_prev <= eb_act;
        if (dut.st == 4'd6) begin                       // S_FIRE
            if (!in_fire) begin
                if (fire_cnt[dut.i] < 4) fire_frame[dut.i][fire_cnt[dut.i]] = frame_no;
                fire_cnt[dut.i] = fire_cnt[dut.i] + 1;
            end
        end
        in_fire <= (dut.st == 4'd6);
    end
    integer fire_i; reg [15:0] rising;
    always @(posedge clk) begin
        rising = eb_act & ~eb_prev;
        if (rising != 0)
            for (t = 0; t < 16; t = t + 1) if (rising[t]) fire_bul[fire_i] = fire_bul[fire_i] + 1;
        if (dut.st == 4'd6) fire_i = dut.i;
    end

    integer n, max_pb, last_spawn, gap_ok, spawns, x0, minx, maxy_seen, miny, ok, d0;
    reg [1:0] pb_prev;
    initial begin
        for (n = 0; n < 6; n = n + 1) begin fire_cnt[n] = 0; fire_bul[n] = 0; end
        fire_i = 0;
        repeat (5) @(posedge clk); rst <= 0;
        repeat (5) @(posedge clk);
        // เริ่มเกม: TITLE -> PLAY
        @(posedge clk) fsm_btnc <= 1; @(posedge clk) fsm_btnc <= 0;
        enter(0, 0, 0, 288, 224);
        frames(2);
        check(state == 1 && alive == 0 && doors_open, "PLAY in START: no monsters, doors open");

        // ================= 1. AABB ขอบแตะ vs ซ้อน (กระสุนศัตรูวิ่งลง) =================
        // hitbox ผู้เล่น x 292..315 y 228..251
        clear_all; hits = 0;
        put_eb(0, 284, 233, 0);              // หลังเดิน 3 px: y 236, x 284..291 แตะขอบซ้าย
        frames(1);
        check(hits == 0, "AABB: bullet touching left edge (x+8 == hitbox x) -> no hit");
        clear_all;
        put_eb(0, 292, 217, 0);              // หลังเดิน: y 220..227 แตะขอบบน
        frames(1);
        check(hits == 0, "AABB: bullet touching top edge -> no hit");
        clear_all;
        put_eb(0, 292, 218, 0);              // หลังเดิน: y 221..228 ซ้อน 1 px
        frames(1);
        check(hits == 1 && eb_act[0] == 0, "AABB: 1 px overlap from above -> hit, bullet removed");
        // knockback จากด้านบน -> ถอยลง
        check(kbs == 1 && kb_dir == 0, "knockback direction away from source (down)");
        // ================= 2. hurt: HP-1, knockback 16 px, อมตะ 60 เฟรม =================
        check(hp == 2, "hurt: HP 3 -> 2 via game_fsm take_hit");
        frames(8);
        check(px == 288 && py == 240, "knockback: moved 16 px away over 8 frames");
        check(invuln, "still invulnerable after knockback");
        put_eb(0, 292, py + 4, 0);           // กระสุนทับตัวช่วงอมตะ
        frames(1);
        check(hits == 1 && eb_act[0] == 1, "no damage while invulnerable (bullet passes)");
        dut.e_act = 0;
        ok = 0; d0 = 0;
        for (n = 0; n < 70 && invuln; n = n + 1) begin
            frames(1);
            if (blink) ok = ok + 1; else d0 = d0 + 1;
        end
        // หลังโดน: 8 เฟรม knockback + 60 อมตะ = 68 (นับไปแล้ว 9 เฟรม)
        check(n == 68 - 9, "invulnerable lasts KB 8 + 60 frames");
        check(ok > 20 && d0 > 20, "player sprite blinks while invulnerable");
        hits = 0;
        put_eb(0, 292, py + 4, 0);
        frames(1);
        check(hits == 1, "damage again after invulnerability ends");
        heal; clear_all; frames(70); hits = 0; clear_all;

        // knockback ชนกำแพง: ยืนชิดกำแพงซ้าย โดนจากขวา
        place(0, 30, 224); frames(1);
        put_eb(0, 30 + 26, 224 + 10, 2);     // กระสุนวิ่งซ้ายเข้าขวาของ hitbox
        frames(10);
        check(hits == 1 && px + 4 >= 32 && px <= 30, "knockback into wall: stops at wall (no tunnelling)");
        heal; clear_all; frames(70); clear_all; hits = 0;

        // knockback เข้าประตูที่เปิด: ไม่เปลี่ยนห้อง หยุดที่ขอบประตู
        doors = 0;
        place(0, 570, 240); frames(1);
        put_eb(0, 560, 250, 3);              // จากซ้าย -> ถอยขวาไปทางประตู D (x 608)
        frames(12);
        check(hits == 1 && doors == 0 && px + 27 < 608, "knockback toward open door: no door event, stops at wall");
        heal; clear_all; frames(70); clear_all; hits = 0;

        // ชนตัวมอน A: ถอยออกจากมอน
        place(0, 288, 224); frames(1);
        put_mon(0, 0, 250, 224, 2);          // มอน A อยู่ซ้าย เดินเข้ามา
        frames(20);
        check(hits == 1 && kb_dir == 3, "monster contact: HP-1, knockback right (away from monster)");
        heal; clear_all; frames(70); clear_all; hits = 0;

        // ================= 3. ฟันประชิด: โดนเฉพาะข้างหน้า =================
        place(0, 288, 224); frames(1);
        check(facing == 0 && form == 0, "form 1 facing down");
        put_mon(0, 1, 288, 250, 3);          // หน้า (ล่าง): hitbox y 254.. ทับกล่อง y 252..267
        put_mon(1, 1, 288, 190, 3);          // หลัง (บน)
        put_mon(2, 1, 330, 224, 3);          // ข้าง (ขวา)
        press; frames(1);
        check(melee_on && dut.m_hpv[(0)*3 +: 3] == 2, "melee hits monster in front (HP 3 -> 2)");
        check(dut.m_hpv[(1)*3 +: 3] == 3 && dut.m_hpv[(2)*3 +: 3] == 3, "melee does not hit behind / beside");
        check(mon_flash != 0 || dut.m_flv[(0)*4 +: 4] != 0, "hit monster flashes");
        frames(8);
        check(!melee_on && dut.m_hpv[(0)*3 +: 3] == 2, "one hit per swing, hit box gone after 8 frames");
        press; frames(1);
        check(dut.m_hpv[(0)*3 +: 3] == 2, "cooldown: press again too early does nothing");
        frames(12); press; frames(1);
        check(dut.m_hpv[(0)*3 +: 3] == 1, "after 20-frame cooldown melee hits again");
        frames(20); press; frames(1);
        check(dut.mon_act[0] == 0, "HP 0 -> monster removed");
        clear_all;

        // ================= 4. ยิง (ร่าง 2) =================
        @(posedge clk) item <= 1; @(posedge clk) item <= 0;
        frames(62);
        check(form == 1 && state == 1, "evolved to form 2");
        place(0, 288, 224);
        right = 1; frames(1); right = 0; frames(1);
        check(facing == 3, "facing right");
        // กดค้าง: ไม่เกิน 2 นัด, ยิงซ้ำทุก 15 เฟรม
        max_pb = 0; last_spawn = -1; gap_ok = 1; spawns = 0; pb_prev = pb_act; x0 = 0;
        atk_hold = 1;
        for (n = 0; n < 160; n = n + 1) begin
            frames(1);
            if (pb_act[0] + pb_act[1] > max_pb) max_pb = pb_act[0] + pb_act[1];
            if ((pb_act & ~pb_prev) != 0) begin
                // นัดที่ 2 ห่าง 15 เฟรมพอดี; ถ้า 2 นัดยังบินอยู่ต้องรอ slot ว่าง (ห่าง >= 15)
                if (spawns == 1 && frame_no - last_spawn != 15) gap_ok = 0;
                if (spawns >= 1 && frame_no - last_spawn < 15) gap_ok = 0;
                $display("      spawn at frame %0d (pb_act=%b)", frame_no, pb_act); last_spawn = frame_no; spawns = spawns + 1;
            end
            pb_prev = pb_act;
        end
        atk_hold = 0;
        check(max_pb == 2, "max 2 player bullets on screen");
        check(gap_ok && spawns >= 3, "hold BTNC: refire after 15-frame cooldown (waits for a free slot)");
        frames(60); clear_all;
        // กระสุนชนกำแพงบน: หยุดก่อน tile # (ศูนย์กลาง y >= 32)
        place(0, 288, 224);
        up = 1; frames(1); up = 0; frames(1);
        press; miny = 999;
        for (n = 0; n < 80 && (n < 2 || pb_act != 0); n = n + 1) begin
            frames(1);
            if (pb_act[0] && pb_y[9:0] < miny) miny = pb_y[9:0];
            if (pb_act[1] && pb_y[19:10] < miny) miny = pb_y[19:10];
        end
        check(pb_act == 0 && miny + 4 >= 32 && miny + 4 < 40, "player bullet stops at # wall");
        // ผ่านรั้ว F: grid 7 แถว 2 รั้วที่ col 4 (x 128..159) แล้วกำแพง col 0
        place(7, 250, 50);
        left = 1; frames(1); left = 0; frames(1);
        press; minx = 999;
        for (n = 0; n < 100 && (n < 2 || pb_act != 0); n = n + 1) begin
            frames(1);
            if (pb_act[0] && pb_x[9:0] < minx) minx = pb_x[9:0];
            if (pb_act[1] && pb_x[19:10] < minx) minx = pb_x[19:10];
        end
        check(minx < 128 && minx + 4 >= 32 && pb_act == 0, "player bullet flies through fence F, stops at wall");
        // ผ่านหลุม H: grid 10 แถว 4-5 เป็นหลุม ยิงขึ้นจากแถว 6
        place(10, 304, 200);
        up = 1; frames(1); up = 0; frames(1);
        press; miny = 999;
        for (n = 0; n < 100 && (n < 2 || pb_act != 0); n = n + 1) begin
            frames(1);
            if (pb_act[0] && pb_y[9:0] < miny) miny = pb_y[9:0];
            if (pb_act[1] && pb_y[19:10] < miny) miny = pb_y[19:10];
        end
        check(miny < 128 && pb_act == 0, "player bullet flies over holes H");
        // กระสุนผู้เล่นฆ่ามอน: ดาเมจร่าง 2 = 1, มอน A HP 2 -> 2 นัด
        place(0, 288, 224); clear_all;
        right = 1; frames(1); right = 0;
        put_mon(0, 1, 420, 224, 2);
        atk_hold = 1; frames(70); atk_hold = 0;
        check(mon_act[0] == 0, "player bullets (damage 1) kill HP-2 monster");
        clear_all;

        // ================= 5. มอน A ไม่ทะลุกำแพง =================
        // เสา ## grid 0 col 4-5 row 3-4 (x 128..191, y 96..159), ผู้เล่นอยู่เหนือเสา มอนอยู่ใต้เสา
        place(0, 144, 40); frames(1);
        put_mon(0, 0, 144, 190, 2);
        ok = 1;
        for (n = 0; n < 120; n = n + 1) begin
            frames(1);
            if (dut.m_xv[(0)*10 +: 10] + 4 < 192 && dut.m_xv[(0)*10 +: 10] + 28 > 128 && dut.m_yv[(0)*10 +: 10] + 4 < 160 && dut.m_yv[(0)*10 +: 10] + 28 > 96) ok = 0;
        end
        check(ok && dut.m_yv[(0)*10 +: 10] == 156, "monster A stops under pillar (never overlaps wall)");
        // มอนทแยง: ผู้เล่นขวาบน มอนซ้ายล่างของเสา
        clear_all;
        put_mon(0, 0, 60, 200, 2);
        ok = 1;
        for (n = 0; n < 200; n = n + 1) begin
            frames(1);
            if (dut.m_xv[(0)*10 +: 10] + 4 < 192 && dut.m_xv[(0)*10 +: 10] + 28 > 128 && dut.m_yv[(0)*10 +: 10] + 4 < 160 && dut.m_yv[(0)*10 +: 10] + 28 > 96) ok = 0;
            if (dut.m_xv[(0)*10 +: 10] + 4 < 32 || dut.m_yv[(0)*10 +: 10] + 4 < 32) ok = 0;
        end
        check(ok, "monster A diagonal chase never enters wall tiles");
        clear_all; heal; hits = 0;

        // ================= 6. ห้อง Combat ล็อก + ป้อมยิง =================
        // grid 7 = C1 ชั้น 2: ป้อม slot 0, 1, 4, 5 (phase 0, 30, 60, 90) + มอน A slot 2, 3
        enter(7, 1, 1, 40, 240);
        check(alive == 6 && !doors_open, "enter C1 floor 2 with 6 monsters: doors locked");
        check(mon_type == 6'b110011, "spawn types from monsters.mem (T T S S T T)");
        // กันผู้เล่นตาย: อมตะตลอดการทดสอบป้อม
        for (n = 0; n < 6; n = n + 1) begin fire_cnt[n] = 0; fire_bul[n] = 0; end
        d0 = frame_no;
        for (n = 0; n < 420; n = n + 1) begin
            while (busy) @(posedge clk);
            dut.hurt_cnt = 7'd100; fsm.hp = 3'd3;
            dut.m_act[2] = 0; dut.m_act[3] = 0;          // เอามอน A ออก (ไม่ให้บังกระสุน)
            frames(1);
        end
        check(fire_frame[0][0] - d0 == 60, "turret 0 first shot 60 frames after entering");
        check(fire_frame[1][0] - fire_frame[0][0] == 30 && fire_frame[4][0] - fire_frame[1][0] == 30 &&
              fire_frame[5][0] - fire_frame[4][0] == 30, "turrets phase-shifted by 30 frames");
        check(fire_frame[0][1] - fire_frame[0][0] == 120 && fire_frame[0][2] - fire_frame[0][1] == 120 &&
              fire_frame[5][1] - fire_frame[5][0] == 120, "each turret fires every 120 frames");
        check(fire_bul[0] == 4 * fire_cnt[0] && fire_bul[1] == 4 * fire_cnt[1], "each shot = 4 bullets");
        $display("      turret first shots (frames after entry): %0d %0d %0d %0d",
                 fire_frame[0][0] - d0, fire_frame[1][0] - d0, fire_frame[4][0] - d0, fire_frame[5][0] - d0);
        check(!doors_open && alive == 4, "still locked while turrets alive");
        // ล้างทีละตัว: ยังล็อกจนตัวสุดท้าย
        while (busy) @(posedge clk);
        dut.m_act[0] = 0; dut.m_act[1] = 0; dut.m_act[4] = 0;
        frames(1);
        check(!doors_open && alive == 1, "1 monster left: still locked");
        while (busy) @(posedge clk);
        dut.m_hpv[(5)*3 +: 3] = 1; dut.hurt_cnt = 0;
        // ฆ่าตัวสุดท้ายด้วยกระสุนผู้เล่นจริง: ยืนตรงแนวป้อม (17,13) = (544,416) แล้วยิงลง
        place(7, 544, 330); dut.e_act = 0;
        down = 1; frames(1); down = 0;
        dut.hurt_cnt = 7'd100;
        press;
        for (n = 0; n < 60 && alive != 0; n = n + 1) begin
            while (busy) @(posedge clk);
            dut.hurt_cnt = 7'd100;
            frames(1);
        end
        frames(1);
        check(alive == 0 && doors_open, "last monster dies (shot) -> doors open");
        check(dut.cleared[1 * 5 + 1] == 1, "room marked cleared");
        // ออกแล้วกลับมา: ไม่ respawn
        enter(8, 1, 2, 300, 400);
        check(alive == 4 && !doors_open, "other combat room (C2 floor 2) locks with its own monsters");
        enter(7, 1, 1, 40, 240);
        check(alive == 0 && doors_open, "come back to cleared room: no respawn, doors open");
        // ห้องที่ไม่ใช่ combat ไม่ล็อก
        enter(6, 0, 3, 40, 240);
        check(doors_open, "puzzle room never locks");
        // restart ล้าง cleared
        @(posedge clk) restart_tb <= 1; @(posedge clk) restart_tb <= 0;
        enter(7, 1, 1, 40, 240);
        check(alive == 6 && !doors_open && dut.cleared == 0, "restart clears cleared bits: monsters respawn");

        // ================= 7. เวลา vblank =================
        $display("      objects busy max = %0d clocks per frame (budget 36000)", busy_max);
        check(busy_max < 36000, "objects update fits in vblank (CE_DIV = 1)");

        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
