`timescale 1ns/1ps
// ทดสอบ world.v: ประตูทุกบานทุกชั้น, grid, จุดเกิด, restart, next_floor, exit_evt
// รัน: ./scripts/run_sim.sh world
module tb_world;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1, restart = 0, next_floor = 0, door_evt = 0; reg [1:0] door_dir = 0;
    wire [1:0] floor; wire [2:0] room; wire [3:0] grid; wire load, exit_evt;
    wire [9:0] load_x, load_y;
    integer errors = 0, checks = 0, exits = 0, loads = 0;

    world dut (.clk(clk), .rst(rst), .restart(restart), .retry(1'b0), .next_floor(next_floor),
               .door_evt(door_evt), .door_dir(door_dir), .floor(floor), .room(room), .grid(grid),
               .load(load), .load_x(load_x), .load_y(load_y), .exit_evt(exit_evt));

    localparam START = 0, C1 = 1, C2 = 2, PUZ = 3, BOSS = 4;
    localparam DN = 0, UP = 1, LF = 2, RT = 3;

    always @(posedge clk) begin
        if (exit_evt) exits = exits + 1;
        if (load) loads = loads + 1;
    end

    function [3:0] exp_grid(input [1:0] f, input [2:0] r);
        case (r)
            START: exp_grid = (f == 2) ? 1 : 0;
            C1:    exp_grid = 4 + f * 3;
            C2:    exp_grid = 5 + f * 3;
            PUZ:   exp_grid = 6 + f * 3;
            default: exp_grid = (f == 1) ? 3 : 2;
        endcase
    endfunction

    // ส่ง door_evt หนึ่ง pulse แล้วเช็คห้อง + จุดเกิด
    task door(input [1:0] dir, input [2:0] exp_room, input [9:0] ex, input [9:0] ey, input [8*40-1:0] msg);
        reg ok;
        begin
            @(posedge clk); door_evt <= 1; door_dir <= dir;
            @(posedge clk); door_evt <= 0; #1;        // world เห็น door_evt ที่ขอบนี้ -> เอาต์พุตอัปเดตแล้ว (load อยู่ 1 clock)
            ok = (room == exp_room) && (grid == exp_grid(floor, exp_room)) && load && load_x == ex && load_y == ey;
            checks = checks + 1;
            if (!ok) begin
                errors = errors + 1;
                $display("FAIL  f%0d %0s: room=%0d grid=%0d load=%0b at (%0d,%0d)  expected room=%0d grid=%0d at (%0d,%0d)",
                         floor + 1, msg, room, grid, load, load_x, load_y, exp_room, exp_grid(floor, exp_room), ex, ey);
            end
            @(posedge clk);
        end
    endtask

    task pulse_restart; begin @(posedge clk); restart <= 1; @(posedge clk); restart <= 0; @(posedge clk); #1; end endtask
    task pulse_next;    begin @(posedge clk); next_floor <= 1; @(posedge clk); next_floor <= 0; @(posedge clk); #1; end endtask

    task expect_state(input [1:0] f, input [2:0] r, input [8*40-1:0] msg); begin
        checks = checks + 1;
        if (floor != f || room != r || grid != exp_grid(f, r)) begin
            errors = errors + 1;
            $display("FAIL  %0s: floor=%0d room=%0d grid=%0d", msg, floor, room, grid);
        end
    end endtask

    integer f;
    initial begin
        repeat (3) @(posedge clk); rst <= 0;
        @(posedge clk); #1;
        // หลัง reset: ชั้น 1 START, load ที่ P
        expect_state(0, START, "after reset");
        for (f = 0; f < 3; f = f + 1) begin
            if (f == 0) pulse_restart; else pulse_next;
            expect_state(f, START, "floor entry");
            checks = checks + 1;
            if (!(grid == exp_grid(f, START))) begin errors = errors + 1; $display("FAIL grid START f%0d", f + 1); end
            // START -> C1 (ประตูขวา)
            door(RT, C1, 40, 240, "START->C1");
            // C1 บน -> C2 ล่าง, C2 บน -> C1 ล่าง
            door(UP, C2, 304, 408, "C1 top->C2");
            door(DN, C1, 304, 40,  "C2 bottom->C1");
            // C1 ขวา (L) -> BOSS, BOSS -> C1
            door(RT, BOSS, 40, 240, "C1->BOSS");
            door(LF, C1, 568, 240, "BOSS->C1");
            // C1 ซ้าย -> START
            door(LF, START, 568, 240, "C1->START");
            // กลับไปทาง C2 -> PUZ
            door(RT, C1, 40, 240, "START->C1 (again)");
            door(UP, C2, 304, 408, "C1->C2");
            door(RT, PUZ, 40, 240, "C2 right->PUZ");
            door(LF, C2, 568, 240, "PUZ->C2");
            door(DN, C1, 304, 40,  "C2->C1 (down)");
            door(LF, START, 568, 240, "C1->START (final)");
        end
        // ชั้น 3 (ตอนนี้ floor = 2) START ซ้าย = ประตู E -> exit_evt, ไม่ load
        pulse_restart; pulse_next; pulse_next;
        expect_state(2, START, "floor 3 START");
        exits = 0; loads = 0;
        @(posedge clk); door_evt <= 1; door_dir <= LF; @(posedge clk); door_evt <= 0; repeat (3) @(posedge clk);
        checks = checks + 1;
        if (exits != 1 || loads != 0) begin errors = errors + 1; $display("FAIL exit_evt exits=%0d loads=%0d", exits, loads); end
        expect_state(2, START, "stay in START after exit");

        // next_floor จากชั้น 3 -> วนกลับชั้น 1
        pulse_next;
        expect_state(0, START, "next_floor wraps 3->1");
        checks = checks + 1;
        if (!(load_x == 288 && load_y == 224)) begin errors = errors + 1; $display("FAIL spawn after wrap"); end

        // restart จากกลางเกม: ชั้น 2 ห้อง BOSS -> restart
        pulse_next;                                   // ชั้น 2
        door(RT, C1, 40, 240, "to C1");
        door(RT, BOSS, 40, 240, "to BOSS");
        pulse_restart;
        expect_state(0, START, "restart -> floor 1 START");
        checks = checks + 1;
        if (!(load_x == 288 && load_y == 224)) begin errors = errors + 1; $display("FAIL spawn after restart"); end

        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
