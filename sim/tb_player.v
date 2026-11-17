`timescale 1ns/1ps
// ทดสอบ movement/collision/ประตู โดยไม่ต้องรัน VGA (frame_tick ถี่ ๆ)
// รัน: cd mem && iverilog -g2012 -o ../sim/tb_player.vvp ../sim/tb_player.v ../rtl/player.v ../rtl/roms.v && vvp ../sim/tb_player.vvp
module tb_player;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1, tick = 0, up = 0, down = 0, left = 0, right = 0, hold = 0;
    reg [1:0] form = 0; reg [3:0] grid = 0; reg dopen = 1, openL = 0;
    reg load = 0; reg [9:0] lx = 288, ly = 224;
    reg [2:0] spd_ovr = 0; reg freeze = 0;                         // 0 = ใช้ความเร็วตามร่างแบบเดิม (2/2/3/3)
    wire [2:0] spd = (spd_ovr != 0) ? spd_ovr : ((form >= 2) ? 3'd3 : 3'd2);
    wire [9:0] px, py; wire [1:0] facing, pose, ddir; wire devt;
    integer doors = 0; reg [1:0] last_dir;
    integer errors = 0; reg [1:0] maxpose = 0;
    always @(posedge clk) if (pose > maxpose) maxpose = pose;

    player dut(.clk(clk), .rst(rst), .frame_tick(tick), .up(up), .down(down), .left(left), .right(right),
               .hold_facing(hold), .form(form), .speed(spd), .freeze(freeze), .grid(grid), .doors_open(dopen), .open_L(openL),
               .load(load), .load_x(lx), .load_y(ly), .kb_start(1'b0), .kb_dir(2'd0), .blk0(12'd0), .blk1(12'd0), .blk2(12'd0), .blk_en(3'd0), .px(px), .py(py), .facing(facing), .pose(pose),
               .door_evt(devt), .door_dir(ddir));

    always @(posedge clk) if (devt) begin doors = doors + 1; last_dir = ddir; end

    task frames(input integer n); integer i; begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk) tick <= 1; @(posedge clk) tick <= 0;
            repeat (12) @(posedge clk);
        end
    end endtask

    task place(input [3:0] g, input [9:0] x, input [9:0] y); begin
        grid <= g; lx <= x; ly <= y; @(posedge clk) load <= 1; @(posedge clk) load <= 0;
        doors = 0;
    end endtask

    task check(input cond, input [8*48-1:0] msg); begin
        if (cond) $display("PASS  %0s  (px=%0d py=%0d)", msg, px, py);
        else begin $display("FAIL  %0s  (px=%0d py=%0d)", msg, px, py); errors = errors + 1; end
    end endtask

    initial begin
        repeat (3) @(posedge clk); rst <= 0;
        // 1) START ชั้น 1: เดินขึ้นจนชนกำแพงบน -> py ต้องหยุดที่ 28 (hitbox บน = 32)
        place(0, 288, 224); up = 1; frames(200); up = 0;
        check(py == 28, "walk up stops at top wall");
        check(facing == 1, "facing up");
        // 2) เดินขวาเข้าประตู D -> door_evt ทิศขวา
        place(0, 288, 240); right = 1; frames(200); right = 0;
        check(doors >= 1 && last_dir == 3, "right door event");
        // 3) ปิดประตู D -> ต้องชนประตู ไม่มี event
        dopen = 0; place(0, 288, 240); right = 1; frames(200); right = 0; dopen = 1;
        check(doors == 0 && px + 27 < 608, "closed door blocks");
        // 4) ทแยงขึ้น-ขวาชนกำแพงบน -> ยังไถลไปขวาได้
        place(0, 288, 40); up = 1; right = 1; frames(40); up = 0; right = 0;
        check(py == 28 && px > 288, "diagonal slides along wall");
        // 5) corner slide: เสา ## ที่ col 4-5 row 3-4 (x 128..191, y 96..159)
        //    ยืนใต้เสา เหลื่อมขอบขวาเสา 4 px แล้วเดินขึ้น -> ต้องไถลออกขวาจนผ่าน
        place(0, 192 - 4 - 4, 200); up = 1; frames(60); up = 0;
        check(py < 140, "corner slide past pillar edge");
        // 6) หลุม H: ร่าง 1 เดินผ่านไม่ได้, ร่าง 3 ผ่านได้ (ชั้น 3 Combat 1 = grid 10, หลุมแถว 4-5)
        form = 0; place(10, 304, 240); up = 1; frames(100); up = 0;
        check(py >= 164, "form1 blocked by hole");
        form = 2; place(10, 304, 240); up = 1; frames(150); up = 0;
        check(doors >= 1 && last_dir == 1 && py < 32, "form3 flies over hole to top door (frozen)");
        // 7) ประตู L ล็อกถ้า open_L = 0 (Combat 1 ชั้น 1 = grid 4, L ขวา)
        form = 0; openL = 0; place(4, 400, 240); right = 1; frames(150); right = 0;
        check(doors == 0, "boss door L locked");
        openL = 1; place(4, 400, 240); right = 1; frames(150); right = 0;
        check(doors >= 1 && last_dir == 3, "boss door L opens with item");
        // 8) animation ขยับตอนเดิน
        maxpose = 0; place(0, 288, 224); left = 1; frames(40); left = 0;
        check(maxpose == 2, "walk animation uses pose 1 and 2");
        frames(10);
        check(pose == 0, "idle pose when stopped");

        // ---------- speed 4 (sprint ร่าง 3-4) ----------
        spd_ovr = 4; form = 0;
        place(0, 288, 224); up = 1; frames(200); up = 0;
        check(py >= 28 && py <= 31, "spd4: walk up stops at top wall");
        place(0, 288, 240); right = 1; frames(200); right = 0;
        check(doors >= 1 && last_dir == 3, "spd4: right door event");
        dopen = 0; place(0, 288, 240); right = 1; frames(200); right = 0; dopen = 1;
        check(doors == 0 && px + 27 < 608, "spd4: closed door blocks");
        place(0, 288, 40); up = 1; right = 1; frames(40); up = 0; right = 0;
        check(py >= 28 && py <= 31 && px > 288, "spd4: diagonal slides along wall");
        place(0, 192 - 4 - 4, 200); up = 1; frames(60); up = 0;
        check(py < 140, "spd4: corner slide past pillar edge");
        // ชนเสาจากด้านล่าง กึ่งกลางเสา (x 128..191): ต้องหยุดใต้เสา ไม่ทะลุ (ก้นเสา y = 160)
        place(0, 144, 220); up = 1; frames(60); up = 0;
        check(py + 4 >= 160 && py + 4 <= 163, "spd4: no tunnelling into pillar");
        // ผนังขวาไม่ทะลุ (ห้อง 0 แถว 2 ไม่มีประตู): hitbox ขวาต้อง < 608
        place(0, 400, 40); right = 1; frames(120); right = 0;
        check(px + 27 < 608 && px + 27 >= 604, "spd4: right wall no tunnelling");
        form = 0; place(10, 304, 240); up = 1; frames(100); up = 0;
        check(py >= 164, "spd4: form1 still blocked by hole");
        form = 2; place(10, 304, 240); up = 1; frames(150); up = 0;
        check(doors >= 1 && last_dir == 1 && py < 32, "spd4: form3 over hole to top door");
        // ชนซ้ายที่ px = 0 ไม่ wrap (หลัง clamp): เดินซ้ายในห้อง START แถวประตูซ้ายของชั้น 3 (grid 1)
        form = 3; openL = 0;
        place(1, 100, 240); left = 1; frames(100); left = 0;
        check(doors >= 1 && last_dir == 2 && px < 100, "spd4: form4 E door (left edge), no wrap");
        form = 0;
        place(1, 100, 240); left = 1; frames(100); left = 0;
        check(px >= 28 && px < 100, "spd4: left E door closed for form1");
        spd_ovr = 0;
        // ---------- freeze ----------
        place(0, 288, 224); freeze = 1; right = 1; frames(30); right = 0;
        check(px == 288 && py == 224 && pose == 0, "freeze: no movement, idle pose");
        freeze = 0; right = 1; frames(10); right = 0;
        check(px > 288, "unfreeze: moves again");
        $display("errors = %0d", errors);
        $finish;
    end
endmodule
