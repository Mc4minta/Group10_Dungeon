`timescale 1ns/1ps
// ทดสอบ objects.v + player.v (knockback) + game_fsm.v (HP) ร่วมกัน, frame_tick ทุก 400 clock
// รัน: ./scripts/run_sim.sh objects
// ห้อง: grid 0 = START ชั้น 1 (ไม่มีมอน), grid 4 = C1 ชั้น 1 (มอน A 3 ตัว), grid 7 = C1 ชั้น 2 (ป้อม 4 + A 2, รั้ว F)
module tb_objects;
    `include "params.vh"      // HP1, INV_FRAMES, KB_FRAMES, MON_A_MOVE_EVERY come from the game parameters
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
    reg fsm_btnc = 0, item = 0, summon_t = 0, auto_t = 0;
    wire lock_use_w; wire [1:0] lock_face_w;
    reg [1:0] floor = 0; reg [2:0] room = 0; reg [3:0] grid = 0;
    reg p_load = 0, o_load = 0, restart_tb = 0; reg [9:0] lx = 288, ly = 224;
    reg open_L = 0;

    wire [2:0] state, hp, hp_max, speed, rgb; wire [1:0] form, damage;
    wire restart, next_floor, freeze, fsm_hide;
    wire [3:0] m_t, m_o, s_t, s_o;
    wire [9:0] px, py; wire [1:0] facing, pose, door_dir; wire door_evt;
    wire doors_open, hit, kb_start, invuln, blink, busy, melee_on, mon_anim;
    wire [1:0] kb_dir, melee_dir; wire [5:0] pb_act; wire [11:0] pb_kind; wire charged; wire [2:0] alive;
    wire [5:0] mon_act, mon_type, mon_flash; wire [59:0] mon_x, mon_y;
    wire [59:0] pb_x, pb_y; wire [15:0] eb_act; wire [159:0] eb_x, eb_y;

    game_fsm #(.PROLOGUE(0)) fsm (.clk(clk), .rst(rst), .frame_tick(tick), .btnc_rise(fsm_btnc), .got_item(item),
                  .take_hit(hit), .floor_done(1'b0), .exit_evt(1'b0), .escape_start(1'b0), .exit_direct(1'b1), .sprint(1'b0), .key_get(1'b0), .goal(1'b0), .kill(1'b0),
                  .state(state), .restart(restart), .next_floor(next_floor), .form(form), .hp(hp),
                  .hp_max(hp_max), .speed(speed), .damage(damage), .rgb(rgb), .freeze(freeze),
                  .hide_player(fsm_hide), .m_t(m_t), .m_o(m_o), .s_t(s_t), .s_o(s_o));

    wire [7:0] brk_w; wire bset; wire [2:0] bidx;
    overlay ovl_i (.clk(clk), .rst(rst), .restart(restart | restart_tb), .grid(grid), .set(bset), .set_idx(bidx), .brk(brk_w));
    player pl (.open_E(form == 2'd3), .brk(brk_w), .clk(clk), .rst(rst), .frame_tick(tick), .up(up), .down(down), .left(left), .right(right),
               .hold_facing(atk_hold), .form(form), .speed(speed), .freeze(freeze), .grid(grid),
               .doors_open(doors_open), .open_L(open_L), .load(p_load), .load_x(lx), .load_y(ly),
               .kb_start(kb_start), .kb_dir(kb_dir), .blk0(12'd0), .blk1(12'd0), .blk2(12'd0), .blk_en(3'd0), .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(door_evt), .door_dir(door_dir));

    objects dut (.brk(brk_w), .brk_set(bset), .brk_idx(bidx), .clk(clk), .rst(rst), .frame_tick(tick), .run(state == 3'd1), .restart(restart | restart_tb),
                 .room_load(o_load), .floor(floor), .room(room), .grid(grid), .open_L(open_L),
                 .px(px), .py(py), .facing(facing), .form(form), .damage(damage),
                 .atk_press(atk_press), .atk_hold(atk_hold), .dbg_clear(1'b0),
                 .blk0(12'd0), .blk1(12'd0), .blk2(12'd0), .blk_en(3'd0),
                 .boss_act(1'b0), .boss_x(10'd0), .boss_y(10'd0), .boss_fire(1'b0), .auto_lock(auto_t), .lock_use(lock_use_w), .lock_face(lock_face_w), .summon(summon_t), .boss_dmg(), .boss_dmg_amt(), .boss_dmg_big(),
                 .doors_open(doors_open), .alive(alive), .hit(hit), .kb_start(kb_start), .kb_dir(kb_dir),
                 .invuln(invuln), .player_blink(blink), .busy(busy),
                 .mon_act(mon_act), .mon_type(mon_type), .mon_flash(mon_flash), .mon_x(mon_x), .mon_y(mon_y),
                 .mon_anim(mon_anim), .pb_act(pb_act), .pb_x(pb_x), .pb_y(pb_y), .pb_kind(pb_kind), .charged(charged),
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
    // W5: write an overlay entry into every tilemap_rom copy (objects x4, player x2) so the tests do not depend on the map files
    task set_ov(input [11:0] a, input [7:0] v); begin
        while (busy) @(posedge clk);
        dut.rom_a.omem[a] = v; dut.rom_b.omem[a] = v; dut.rom_t.omem[a] = v; dut.rom_m.omem[a] = v;
        pl.rom_a.omem[a] = v; pl.rom_b.omem[a] = v;
    end endtask

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

    function [2:0] pop6(input [5:0] v); pop6 = v[0] + v[1] + v[2] + v[3] + v[4] + v[5]; endfunction
    // tile ใต้จุดกลางกระสุน slot s (ขนาด sz)
    function [3:0] tile_at(input [3:0] g, input [9:0] x, input [9:0] y);
        tile_at = ob_tile(g * 300 + y[8:5] * 20 + x[9:5]);
    endfunction
    function [3:0] ob_tile(input integer a); ob_tile = dut.rom_a.mem[a]; endfunction
    integer nb_big, wall_bad, fence_seen, kills0, cnt3, d_ok, n2;
    integer n, max_pb, last_spawn, gap_ok, spawns, x0, minx, maxy_seen, miny, ok, d0;
    reg [5:0] pb_prev;
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
        // hitbox ผู้เล่น (ที่โดนตี) = HURT_BOX 16 กลาง sprite: x 296..311 y 232..247
        clear_all; hits = 0;
        put_eb(0, 288, 233, 0);              // หลังเดิน 3 px: y 236, x 288..295 แตะขอบซ้าย
        frames(1);
        check(hits == 0, "AABB: bullet touching left edge (x+8 == hitbox x) -> no hit");
        clear_all;
        put_eb(0, 296, 221, 0);              // หลังเดิน: y 224..231 แตะขอบบน
        frames(1);
        check(hits == 0, "AABB: bullet touching top edge -> no hit");
        clear_all;
        put_eb(0, 296, 222, 0);              // หลังเดิน: y 225..232 ซ้อน 1 px
        frames(1);
        check(hits == 1 && eb_act[0] == 0, "AABB: 1 px overlap from above -> hit, bullet removed");
        // knockback จากด้านบน -> ถอยลง
        check(kbs == 1 && kb_dir == 0, "knockback direction away from source (down)");
        // ================= 2. hurt: HP-1, knockback 16 px, อมตะ 60 เฟรม =================
        check(hp == HP1 - 1, "hurt: HP -1 via game_fsm take_hit");
        frames(8);
        check(px == 288 && py == 240, "knockback: moved 16 px away over 8 frames");
        check(invuln, "still invulnerable after knockback");
        put_eb(0, 292, py + 4, 0);           // กระสุนทับตัวช่วงอมตะ
        frames(1);
        check(hits == 1 && eb_act[0] == 1, "no damage while invulnerable (bullet passes)");
        dut.e_act = 0;
        ok = 0; d0 = 0;
        for (n = 0; n < KB_FRAMES + INV_FRAMES + 10 && invuln; n = n + 1) begin
            frames(1);
            if (blink) ok = ok + 1; else d0 = d0 + 1;
        end
        // หลังโดน: 8 เฟรม knockback + 60 อมตะ = 68 (นับไปแล้ว 9 เฟรม)
        check(n == KB_FRAMES + INV_FRAMES - 9, "invulnerable lasts KB_FRAMES + INV_FRAMES");
        check(ok > 20 && d0 > 20, "player sprite blinks while invulnerable");
        hits = 0;
        put_eb(0, 292, py + 4, 0);
        frames(1);
        check(hits == 1, "damage again after invulnerability ends");
        heal; clear_all; frames(INV_FRAMES + 10); hits = 0; clear_all;

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
        frames(20 * MON_A_MOVE_EVERY);      // monster A moves every MON_A_MOVE_EVERY frames
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
            if (pop6(pb_act) > max_pb) max_pb = pop6(pb_act);
            if ((pb_act & ~pb_prev) != 0) begin
                // ยิงซ้ำทุก 15 เฟรม (6 slot พอ ไม่ต้องรอ)
                if (spawns >= 1 && frame_no - last_spawn != 15) gap_ok = 0;
                $display("      spawn at frame %0d (pb_act=%b)", frame_no, pb_act); last_spawn = frame_no; spawns = spawns + 1;
            end
            pb_prev = pb_act;
        end
        atk_hold = 0;
        check(max_pb >= 3 && max_pb <= 6, "form 2 hold: several bullets in flight, never more than 6 slots");
        check(gap_ok && spawns >= 5, "hold BTNC: refire every 15 frames");
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

        // ================= 8. อาวุธต่อร่าง / ฟันทุกร่าง / กระสุนชนกัน (P6) =================
        enter(0, 0, 0, 288, 224); clear_all; heal; frames(2);
        // --- ร่าง 3: กระจาย 3 ทาง ---
        while (busy) @(posedge clk); fsm.form = 2'd2;
        right = 1; frames(1); right = 0; frames(16); clear_all;
        press; frames(1);
        cnt3 = 0; d_ok = 0;
        for (n = 0; n < 6; n = n + 1) if (pb_act[n]) begin
            cnt3 = cnt3 + 1;
            if (dut.p_dirv[n*3 +: 3] == 3) d_ok = d_ok | 1;
            if (dut.p_dirv[n*3 +: 3] == 7) d_ok = d_ok | 2;
            if (dut.p_dirv[n*3 +: 3] == 5) d_ok = d_ok | 4;
        end
        check(cnt3 == 3 && d_ok == 7 && pb_kind[1:0] == 2'd1, "form 3 press: 3 bullets right / up-right / down-right");
        // ทแยงไม่ทะลุกำแพง: ตามดูทุกเฟรมว่าจุดกลางไม่อยู่ใน #
        wall_bad = 0;
        for (n = 0; n < 120 && pb_act != 0; n = n + 1) begin
            frames(1);
            for (n2 = 0; n2 < 6; n2 = n2 + 1)
                if (pb_act[n2] && tile_at(0, pb_x[n2*10 +: 10] + 4, pb_y[n2*10 +: 10] + 4) == 0) wall_bad = 1;
        end
        check(!wall_bad && pb_act == 0, "spread / diagonal bullets never enter # tiles, all stop at walls");
        // ทแยงผ่านรั้ว F: ห้อง grid 7 (รั้วมุมซ้ายบน), ยิงกระจายหันซ้ายจาก (200, 112)
        place(7, 200, 112); clear_all;
        left = 1; frames(1); left = 0; frames(16); clear_all;
        fence_seen = 0; wall_bad = 0;
        press;
        for (n = 0; n < 120 && (n < 2 || pb_act != 0); n = n + 1) begin
            frames(1);
            for (n2 = 0; n2 < 6; n2 = n2 + 1) if (pb_act[n2]) begin
                if (tile_at(7, pb_x[n2*10 +: 10] + 4, pb_y[n2*10 +: 10] + 4) == 6) fence_seen = fence_seen + 1;
                if (tile_at(7, pb_x[n2*10 +: 10] + 4, pb_y[n2*10 +: 10] + 4) == 0) wall_bad = 1;
            end
        end
        check(fence_seen > 0 && !wall_bad, "diagonal bullets fly over fences F, stop at #");
        // slot: กดค้างนาน -> ไม่เกิน 6
        place(0, 288, 224); clear_all; max_pb = 0;
        right = 1; frames(1); right = 0;
        atk_hold = 1;
        for (n = 0; n < 100; n = n + 1) begin frames(1); if (pop6(pb_act) > max_pb) max_pb = pop6(pb_act); end
        atk_hold = 0; frames(80); clear_all;
        check(max_pb == 6, "form 3 hold: player bullets fill all 6 slots, never more");
        // --- ร่าง 4: กด = นัดเร็ว, กดค้าง 45 เฟรม = ลูกใหญ่ ---
        while (busy) @(posedge clk); fsm.form = 2'd3;
        place(0, 288, 224); right = 1; frames(1); right = 0; frames(16); clear_all;
        @(posedge clk) begin atk_press <= 1; atk_hold <= 1; end @(posedge clk) atk_press <= 0;
        frames(1);
        check(pop6(pb_act) == 1 && pb_kind[1:0] == 2'd2, "form 4 press: one fast shot (tap)");
        x0 = pb_x[9:0]; frames(1);
        check(pb_x[9:0] - x0 == dut.TAP_SPEED, "tap shot moves 6 px/frame");
        frames(43); atk_hold = 0; frames(2);      // ค้าง 44 เฟรมหลังนัดเร็ว
        nb_big = 0; for (n = 0; n < 6; n = n + 1) if (pb_act[n] && pb_kind[n*2 +: 2] == 3) nb_big = nb_big + 1;
        check(nb_big == 0, "held 44 frames: released without a big shot");
        frames(20); clear_all;
        @(posedge clk) begin atk_press <= 1; atk_hold <= 1; end @(posedge clk) atk_press <= 0;
        frames(1);
        check(dut.chg_lvl == 3'd1, "W25: the charge ball appears at once (step 1)");
        frames(24); check(dut.chg_lvl == 3'd2, "W25: after about half the charge: step 2");
        frames(10); check(dut.chg_lvl == 3'd3, "W25: after about 3/4: step 3");
        frames(11);                              // ค้าง 45 เฟรมหลังนัดเร็ว
        check(charged && dut.chg_lvl == 3'd4, "held 45 frames: charged (player flashes), ball at full size");
        atk_hold = 0; frames(2);
        check(dut.chg_lvl == 3'd0, "W25: the ball is gone after the release");
        nb_big = 0; for (n = 0; n < 6; n = n + 1) if (pb_act[n] && pb_kind[n*2 +: 2] == 3) nb_big = nb_big + 1;
        check(nb_big == 1 && !charged, "release after 45 frames: one big 16x16 shot");
        clear_all;
        // W3: ลูกใหญ่หยุดเมื่อโดน: ฆ่ามอนตัวแรก ตัวที่สองไม่โดน ลูกหายไป
        place(0, 100, 224); right = 1; frames(1); right = 0; frames(16); clear_all;
        put_mon(0, 1, 260, 224, 3);
        put_mon(1, 1, 360, 224, 3);
        dut.hurt_cnt = 7'd100;
        @(posedge clk) begin atk_press <= 1; atk_hold <= 1; end @(posedge clk) atk_press <= 0;
        frames(1); frames(45); atk_hold = 0;
        for (n = 0; n < 80; n = n + 1) begin while (busy) @(posedge clk); dut.hurt_cnt = 7'd100; frames(1); end
        check(dut.m_act[0] == 1'b0, "big shot (damage 4) kills the first monster");
        check(dut.m_act[1] == 1'b1 && dut.m_hpv[1*3 +: 3] == 3'd3, "W3: big shot stops on hit, the second monster behind is untouched");
        nb_big = 0; for (n = 0; n < 6; n = n + 1) if (pb_act[n] && pb_kind[n*2 +: 2] == 3) nb_big = nb_big + 1;
        check(nb_big == 0, "W3: big shot is gone after the hit");
        clear_all;
        // --- ฟันอัตโนมัติร่าง 2-4 เมื่อมีศัตรูในกล่องหน้าตัว ---
        for (n2 = 1; n2 <= 3; n2 = n2 + 1) begin
            while (busy) @(posedge clk); fsm.form = n2;
            place(0, 288, 224); clear_all; frames(25);   // พ้น cooldown
            right = 1; frames(1); right = 0; frames(25);
            put_mon(0, 1, 318, 224, 3);                  // อยู่ในกล่องฟันด้านขวา (x 316..331)
            dut.hurt_cnt = 7'd100;
            press; frames(1);
            check(melee_on && pb_act == 0 && dut.m_hpv[2:0] < 3, "forms 2-4: enemy in front box -> melee instead of shooting");
            clear_all; frames(25);
            press; frames(1);
            check(!melee_on && pb_act != 0, "forms 2-4: nobody in front -> shoot");
            clear_all;
        end
        // --- กระสุนชนกัน ---
        while (busy) @(posedge clk); fsm.form = 2'd1;
        place(0, 100, 224); right = 1; frames(1); right = 0; frames(20); clear_all;
        put_eb(0, 300, 236, 2);
        dut.hurt_cnt = 7'd100;
        press;
        for (n = 0; n < 40 && (eb_act[0] || pb_act != 0); n = n + 1) begin while (busy) @(posedge clk); dut.hurt_cnt = 7'd100; frames(1); end
        check(eb_act[0] == 0 && pb_act == 0 && n < 30, "player bullet + enemy bullet collide: both disappear");
        clear_all; heal;

        // ================= 9. W13 form 3 AOE split + W11 boss 2 summon =================
        begin : w13
            integer nch, dmask, maxch, hp_a, hp_b;
            while (busy) @(posedge clk); fsm.form = 2'd2;
            enter(0, 0, 0, 288, 224); clear_all; heal;
            right = 1; frames(1); right = 0; frames(16); clear_all;
            put_mon(0, 1, 420, 224, 7);                // turrets (type B) stand still, tmr 500 = never fire
            put_mon(1, 1, 420, 288, 7);                // below the first: the child going down hits it
            hp_a = 7; hp_b = 7; maxch = 0; dmask = 0;
            dut.hurt_cnt = 7'd100;
            press;
            for (n = 0; n < 70; n = n + 1) begin
                frames(1); dut.hurt_cnt = 7'd100;
                nch = 0;
                for (n2 = 0; n2 < 6; n2 = n2 + 1)
                    if (pb_act[n2] && dut.p_child[n2]) begin nch = nch + 1; dmask = dmask | (1 << dut.p_dirv[n2*3 +: 3]); end
                if (nch > maxch) maxch = nch;
            end
            hp_a = dut.m_hpv[2:0]; hp_b = dut.m_hpv[5:3];
            check(hp_a == 7 - DMG3 - 0 || hp_a < 7, "split: the parent bullet hit monster 1");
            check(maxch == 4 && dmask[3:0] == 4'b1111, "split: a hit makes 4 child bullets (down, up, left, right)");
            check(hp_b < 7, "split: the child going down hits the monster below it");
            check(pb_act == 0, "split: children expire after SPLIT_LIFE frames / stop at walls");
            clear_all;
            // no recursive split: 2 monsters in a row, only the parent splits (never more than 4 children alive)
            check(maxch <= 4, "split: children never split again");
            // W11 summon: BOSS2_MINIONS type-A monsters at the SUMMON tiles, slot limit 6
            enter(3, 1, 4, 100, 100); clear_all; heal;
            @(posedge clk) summon_t <= 1; @(posedge clk) summon_t <= 0; frames(1);
            check(alive == BOSS2_MINIONS && dut.m_act[BOSS2_MINIONS-1:0] == 3'b111, "summon pulse: 3 minions spawn");
            check(dut.m_typ[2:0] == 3'b000 && dut.m_hpv[2:0] == MON_A_HP, "summoned minions are type A with full HP");
            check(dut.m_xv[9:0] + 8 >= {SUMMON0_TX, 5'd0} && dut.m_xv[9:0] <= {SUMMON0_TX, 5'd0} + 8 && dut.m_yv[9:0] + 8 >= {1'b0, SUMMON0_TY, 5'd0} && dut.m_yv[9:0] <= {1'b0, SUMMON0_TY, 5'd0} + 8, "minion 1 appears on the SUMMON0 tile (then starts chasing)");
            dut.hurt_cnt = 7'd100;
            @(posedge clk) summon_t <= 1; @(posedge clk) summon_t <= 0; frames(1);
            check(alive == 6, "second summon fills the remaining 3 slots");
            @(posedge clk) summon_t <= 1; @(posedge clk) summon_t <= 0; frames(1);
            check(alive == 6, "third summon: no free slot, nothing breaks");
            clear_all;
        end

        // ================= 10. W5 overlay: breakable block, spike trap, solid decoration =================
        begin : w5
            integer hits0, maxx, nn;
            localparam [11:0] T0 = 0;                           // grid 0
            while (busy) @(posedge clk); fsm.form = 2'd1;
            enter(0, 0, 0, 288, 224); clear_all; heal;
            right = 1; frames(1); right = 0; frames(16); clear_all; heal;
            // breakable block idx 0 at tile (12, 7): a shot stops at it and breaks it
            set_ov(7 * 20 + 12, 8'h01);
            check(brk_w == 8'h00, "no block broken yet");
            press; maxx = 0;
            for (nn = 0; nn < 40; nn = nn + 1) begin frames(1); if (pb_act[0] && pb_x[9:0] > maxx) maxx = pb_x[9:0]; end
            check(brk_w[0] == 1'b1, "W5: a bullet hitting a breakable block breaks it");
            check(maxx > 0 && maxx <= 384, "W5: the unbroken block stopped the bullet before tile 12");
            clear_all; heal;
            press; maxx = 0;
            for (nn = 0; nn < 25; nn = nn + 1) begin frames(1); if (pb_act[0] && pb_x[9:0] > maxx) maxx = pb_x[9:0]; end
            check(maxx > 400, "W5: after it broke, bullets fly through the tile");
            // persistence: leave the room and come back, state kept; new game clears it
            enter(1, 0, 1, 288, 224);
            check(brk_w == 8'h00, "other room has its own (empty) block state");
            enter(0, 0, 0, 288, 224);
            check(brk_w[0] == 1'b1, "broken block stays broken after leaving and re-entering the room");
            @(posedge clk) restart_tb <= 1; @(posedge clk) restart_tb <= 0; repeat (4) @(posedge clk);
            check(brk_w == 8'h00, "new game: all blocks are back");
            // melee breaks a block (idx 1 at tile (10, 7) = centre of the human's right-hand swing box)
            while (busy) @(posedge clk); fsm.form = 2'd0;
            enter(0, 0, 0, 288, 224); clear_all; heal;
            right = 1; frames(1); right = 0; frames(16); clear_all; heal;
            set_ov(7 * 20 + 10, 8'h11);
            press; frames(4);
            check(brk_w[1] == 1'b1, "W5: a melee swing breaks the block in front of the player");
            // solid decoration (code 3) blocks the player; trap (code 2) hurts
            set_ov(7 * 20 + 10, 8'h03);
            place(0, 200, 224); clear_all; heal;
            right = 1; frames(40); right = 0;
            check(px > 240 && px + 24 <= 320, "W5: a solid decoration stops the player (tile 10 is a wall for him)");
            set_ov(7 * 20 + 10, 8'h00);
            set_ov(7 * 20 + 9, 8'h02);
            while (busy) @(posedge clk); fsm.form = 2'd0;
            place(0, 288, 224); clear_all; heal; dut.hurt_cnt = 7'd0;
            hits0 = hits; frames(3);
            check(hits == hits0 + 1, "W5: standing on a spike trap hurts the player once (form 1)");
            frames(3);
            check(hits == hits0 + 1, "W5: the trap cannot chain-hit during invulnerability");
            while (busy) @(posedge clk); fsm.form = 2'd2;
            place(0, 288, 224); clear_all; heal; dut.hurt_cnt = 7'd0;
            hits0 = hits; frames(4);
            check(hits == hits0 + 1, "W39b: every form is hurt by a spike trap (form 3 included)");
            set_ov(7 * 20 + 9, 8'h00);
            clear_all; heal;
        end

        // ================= 10b. W19 timed spike traps (overlay code 8 = phase A, 9 = phase B): safe / warning / up, 2 damage =================
        begin : w19
            integer hp0, hits0;
            set_ov(7 * 20 + 9, 8'h08);
            while (busy) @(posedge clk); fsm.form = 2'd0;
            // down: safe
            place(0, 288, 224); clear_all; heal; dut.hurt_cnt = 7'd0; dut.trap_grace = 6'd0; dut.trap_t = 8'd10;
            hits0 = hits; frames(3);
            check(hits == hits0 && dut.trap_a == 2'd0, "W19: spikes down = safe");
            // warning: still safe
            dut.trap_t = 8'd95; frames(3);
            check(hits == hits0 && dut.trap_a == 2'd1, "W19: warning phase = safe");
            // up: 2 damage once
            dut.trap_t = 8'd125; hp0 = fsm.hp;
            frames(3);
            check(hits == hits0 + 2 && dut.trap_a == 2'd2, "W19: spikes up hurt (2 hit pulses)");
            check(fsm.hp == hp0 - 2, "W19: the timed trap takes 2 HP");
            frames(3);
            check(hits == hits0 + 2, "W19: no chain hit during invulnerability");
            // rising under a standing player
            clear_all; heal; place(0, 288, 224); dut.trap_t = 8'd117; hits0 = hits; frames(6);
            check(hits == hits0 + 2, "W19: spikes rising under a standing player hurt him");
            // the cycle wraps and the spikes go down again
            clear_all; heal; place(0, 288, 224); dut.trap_t = TRAP_LOOP - 2; frames(4);
            check(dut.trap_t < 8'd10 && dut.trap_a == 2'd0, "W19: the cycle wraps to spikes down");
            // grace after entering a room: up phase but safe
            clear_all; heal; place(0, 288, 224); dut.trap_t = 8'd125; dut.trap_grace = 6'd40; hits0 = hits; frames(3);
            check(hits == hits0 && dut.trap_a == 2'd0, "W19: spikes stay safe during the room-entry grace");
            // phase B is half a loop behind: t = 40 -> A down, B up
            set_ov(7 * 20 + 9, 8'h09);
            clear_all; heal; place(0, 288, 224); dut.trap_grace = 6'd0; dut.trap_t = 8'd40; hits0 = hits; frames(3);
            check(hits == hits0 + 2 && dut.trap_a == 2'd0 && dut.trap_b == 2'd2, "W19: group B is up while group A is down");
            // form 3 flies over
            while (busy) @(posedge clk); fsm.form = 2'd2;
            clear_all; heal; place(0, 288, 224); dut.trap_t = 8'd40; hits0 = hits; frames(3);
            check(hits == hits0 + 2, "W39b: form 3 is hurt by timed spikes too (2 HP)");
            while (busy) @(posedge clk); fsm.form = 2'd0;
            set_ov(7 * 20 + 9, 8'h00);
            clear_all; heal;
        end

        // ================= 11. W18 auto-lock (SW9): attacks aim at the nearest enemy in 8 directions =================
        begin : w18
            integer nn, dmask, nact;
            // helper: after a press, which directions do the live player bullets have? (bit d of dmask)
            while (busy) @(posedge clk); fsm.form = 2'd1;
            enter(0, 0, 0, 288, 224); clear_all; heal;
            right = 1; frames(1); right = 0; frames(16); clear_all; heal;
            // A) lock OFF: the shot goes where the hero faces (right = 3) although an enemy is up-left
            auto_t = 0; put_mon(0, 1, 200, 150, 7); dut.hurt_cnt = 7'd100;
            press; frames(1); dmask = 0; for (nn = 0; nn < 6; nn = nn + 1) if (pb_act[nn]) dmask = dmask | (1 << dut.p_dirv[nn*3 +: 3]);
            check(dmask == (1 << 3) && !lock_use_w, "W18 off: the shot follows the facing (right)");
            clear_all; heal;
            // B) lock ON: the same enemy up-left -> diagonal up-left (6)
            auto_t = 1; put_mon(0, 1, 200, 150, 7); dut.hurt_cnt = 7'd100;
            press; frames(1); dmask = 0; for (nn = 0; nn < 6; nn = nn + 1) if (pb_act[nn]) dmask = dmask | (1 << dut.p_dirv[nn*3 +: 3]);
            check(lock_use_w && dmask == (1 << 6), "W18 on: enemy up-left -> the shot flies up-left (diagonal)");
            check(dut.p_free[0] && $signed(dut.p_vxv[3:0]) == -4 && $signed(dut.p_vyv[3:0]) == -3, "W18 level 2: free angle: the shot toward (-88, -74) flies (-4, -3) px per frame");
            frames(3);
            check(pb_act != 0 && pb_x[9:0] < 10'd300 && pb_y[9:0] < 10'd236, "W18 level 2: the free-angle shot is moving up-left");
            clear_all; heal;
            // C) enemy straight above, hero faces right -> shot goes up
            put_mon(0, 1, 288, 120, 7); dut.hurt_cnt = 7'd100;
            press; frames(1); dmask = 0; for (nn = 0; nn < 6; nn = nn + 1) if (pb_act[nn]) dmask = dmask | (1 << dut.p_dirv[nn*3 +: 3]);
            check(dmask == (1 << 1) && lock_face_w == 2'd1, "W18: enemy straight above -> shot up, hero turns up (lock_face = 1)");
            clear_all; heal;
            // D) out of range (> LOCK_RANGE): no lock, facing used
            put_mon(0, 1, 40, 40, 7); dut.hurt_cnt = 7'd100;
            press; frames(1); dmask = 0; for (nn = 0; nn < 6; nn = nn + 1) if (pb_act[nn]) dmask = dmask | (1 << dut.p_dirv[nn*3 +: 3]);
            check(!lock_use_w && dmask == (1 << 3), "W18: enemy beyond LOCK_RANGE is ignored");
            clear_all; heal;
            // E) two enemies: the nearest one wins (above, 54 px) over the far one (left, 188 px)
            put_mon(0, 1, 100, 224, 7); put_mon(1, 1, 288, 170, 7); dut.hurt_cnt = 7'd100;
            press; frames(1); dmask = 0; for (nn = 0; nn < 6; nn = nn + 1) if (pb_act[nn]) dmask = dmask | (1 << dut.p_dirv[nn*3 +: 3]);
            check(dmask == (1 << 1), "W18: the nearest enemy is chosen");
            clear_all; heal;
            // F) no enemy at all: facing
            dut.hurt_cnt = 7'd100; press; frames(1); dmask = 0; for (nn = 0; nn < 6; nn = nn + 1) if (pb_act[nn]) dmask = dmask | (1 << dut.p_dirv[nn*3 +: 3]);
            check(!lock_use_w && dmask == (1 << 3), "W18: nobody to lock -> facing");
            clear_all; heal;
            // G) the boss counts as a target too (boss_act is tied to 0 in this testbench: skipped)
            // H) form 3 spread is centred on the target: up + its two ring neighbours (up-left, up-right)
            while (busy) @(posedge clk); fsm.form = 2'd2;
            put_mon(0, 1, 288, 120, 7); dut.hurt_cnt = 7'd100;
            press; frames(1); dmask = 0; for (nn = 0; nn < 6; nn = nn + 1) if (pb_act[nn]) dmask = dmask | (1 << dut.p_dirv[nn*3 +: 3]);
            check(dmask == ((1 << 1) | (1 << 6) | (1 << 7)), "W18 + form 3: the 3-way spread is centred on the target (up, up-left, up-right)");
            clear_all; heal;
            // I) human melee: the swing turns toward the enemy above although the hero faces right
            while (busy) @(posedge clk); fsm.form = 2'd0;
            put_mon(0, 1, 288, 190, 7); dut.hurt_cnt = 7'd100;
            press; frames(1);
            check(melee_dir == 2'd1, "W18: the melee swing goes up (toward the enemy)");
            clear_all; heal;
            auto_t = 0; put_mon(0, 1, 288, 190, 7); dut.hurt_cnt = 7'd100;
            press; frames(1);
            check(melee_dir == 2'd3, "W18 off: the melee swing follows the facing (right)");
            clear_all; heal;
            auto_t = 0;
        end

        // ================= 7. เวลา vblank =================
        $display("      objects busy max = %0d clocks per frame (budget 36000)", busy_max);
        check(busy_max < 36000, "objects update fits in vblank (CE_DIV = 1)");

        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
