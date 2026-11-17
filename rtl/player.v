// Feature 1: Movement FSM + collision กับ tile map
// - เดิน 8 ทิศ อัปเดตครั้งเดียวต่อ frame_tick
// - แยกแกน x แล้ว y (ชนกำแพงแนวทแยงแล้วไถล)
// - corner sliding: เหลื่อมมุมไม่เกิน 8 px เลื่อนเข้าช่องให้ 1 px/เฟรม
// - hitbox 24x24 = พิกเซล 4..27 ของ sprite 32x32
// - เดินเข้าประตูที่เปิด -> door_evt + door_dir (top เปลี่ยนห้อง)
// TODO P1.6 ดันกล่อง, P3 HURT/knockback
module player (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,
    input  wire        up, down, left, right,  // level หลัง debounce
    input  wire        hold_facing,            // BTNC ค้าง = strafe (ไม่เปลี่ยนทิศ)
    input  wire [1:0]  form,                   // 0..3 = ร่าง 1..4
    input  wire [3:0]  grid,                   // ห้องปัจจุบัน (0..12)
    input  wire        doors_open,             // ประตู D เปิดไหม (P3: มาจาก cleared[room])
    input  wire        open_L,                 // ประตูบอสเปิดไหม (has_item[floor])
    input  wire        load,                   // วางผู้เล่นที่ (load_x, load_y)
    input  wire [9:0]  load_x, load_y,
    output reg  [9:0]  px = 0,                 // มุมซ้ายบนของ sprite
    output reg  [9:0]  py = 0,
    output reg  [1:0]  facing = 0,             // 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา
    output reg  [1:0]  pose = 0,               // 0 idle 1 ก้าว A 2 ก้าว B
    output reg         door_evt = 0,           // pulse 1 clock
    output reg  [1:0]  door_dir = 0            // 0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา (ขอบจอที่ประตูอยู่)
);
    localparam S_WAIT = 3'd0, S_XA = 3'd1, S_XB = 3'd2, S_YA = 3'd3,
               S_YB = 3'd4, S_DA = 3'd5, S_DB = 3'd6;
    localparam D_DOWN = 2'd0, D_UP = 2'd1, D_LEFT = 2'd2, D_RIGHT = 2'd3;

    reg [2:0] state = S_WAIT;
    reg       frozen = 0;            // เข้าประตูแล้ว รอ top สั่ง load ห้องใหม่
    reg [1:0] dxs = 0, dys = 0;      // {active, negative}
    reg [9:0] nx, ny;                // ตำแหน่งที่จะไป
    reg [11:0] addr_a = 0, addr_b = 0;
    wire [3:0] t_a, t_b;
    reg [3:0] anim_cnt = 0;
    reg [1:0] step = 0;

    tilemap_rom rom_a (.addr(addr_a), .data(t_a));
    tilemap_rom rom_b (.addr(addr_b), .data(t_b));

    wire [1:0] spd = (form >= 2) ? 2'd3 : 2'd2;

    // address ของ tile ที่พิกเซล (x, y)
    function [11:0] taddr(input [3:0] g, input [9:0] x, input [9:0] y);
        taddr = g * 12'd300 + y[8:5] * 12'd20 + x[9:5];
    endfunction

    // passable ตามสูตรใน Core Mechanics Bible
    function pass(input [3:0] t);
        case (t)
            4'h1, 4'h7, 4'h8, 4'h9, 4'hA, 4'hB,
            4'hC, 4'hD, 4'hE, 4'hF: pass = 1'b1;
            4'h2: pass = doors_open;        // D
            4'h3: pass = open_L;            // L
            4'h4: pass = (form == 2'd3);    // E: ร่าง 4
            4'h5: pass = (form >= 2'd2);    // H: ร่าง 3+
            default: pass = 1'b0;           // # , F
        endcase
    endfunction

    function is_door(input [3:0] t);
        is_door = (t == 4'h2) || (t == 4'h3) || (t == 4'h4);
    endfunction

    wire moving = dxs[1] | dys[1];
    wire [9:0] cx = px + 10'd16, cy = py + 10'd16;   // จุดกลาง hitbox

    always @(posedge clk) begin
        door_evt <= 1'b0;
        if (rst) begin
            state <= S_WAIT;
            px <= load_x; py <= load_y;
            facing <= D_DOWN; pose <= 0; step <= 0; anim_cnt <= 0; frozen <= 0;
        end else if (load) begin
            px <= load_x; py <= load_y;
            state <= S_WAIT;
            frozen <= 1'b0;
        end else begin
            case (state)
            S_WAIT: if (frame_tick && !frozen) begin
                dxs <= {left ^ right, left & ~right};
                dys <= {up ^ down,   up & ~down};
                state <= S_XA;
            end
            // ---------- แกน x ----------
            S_XA: begin
                if (!dxs[1]) state <= S_YA;
                else begin
                    nx = dxs[0] ? px - spd : px + spd;
                    addr_a <= taddr(grid, dxs[0] ? nx + 10'd4 : nx + 10'd27, py + 10'd4);
                    addr_b <= taddr(grid, dxs[0] ? nx + 10'd4 : nx + 10'd27, py + 10'd27);
                    state <= S_XB;
                end
            end
            S_XB: begin
                if (pass(t_a) && pass(t_b))
                    px <= nx;
                else if (!pass(t_a) && pass(t_b) && ((py + 10'd4) & 10'd31) >= 10'd24)
                    py <= py + 10'd1;                       // ชนมุมบน -> ไถลลง
                else if (pass(t_a) && !pass(t_b) && ((py + 10'd27) & 10'd31) <= 10'd7)
                    py <= py - 10'd1;                       // ชนมุมล่าง -> ไถลขึ้น
                state <= S_YA;
            end
            // ---------- แกน y ----------
            S_YA: begin
                if (!dys[1]) state <= S_DA;
                else begin
                    ny = dys[0] ? py - spd : py + spd;
                    addr_a <= taddr(grid, px + 10'd4,  dys[0] ? ny + 10'd4 : ny + 10'd27);
                    addr_b <= taddr(grid, px + 10'd27, dys[0] ? ny + 10'd4 : ny + 10'd27);
                    state <= S_YB;
                end
            end
            S_YB: begin
                if (pass(t_a) && pass(t_b))
                    py <= ny;
                else if (!pass(t_a) && pass(t_b) && ((px + 10'd4) & 10'd31) >= 10'd24)
                    px <= px + 10'd1;                       // ชนมุมซ้าย -> ไถลขวา
                else if (pass(t_a) && !pass(t_b) && ((px + 10'd27) & 10'd31) <= 10'd7)
                    px <= px - 10'd1;                       // ชนมุมขวา -> ไถลซ้าย
                state <= S_DA;
            end
            // ---------- ประตู + animation ----------
            S_DA: begin
                addr_a <= taddr(grid, cx, cy);
                state  <= S_DB;
            end
            S_DB: begin
                if (is_door(t_a) && pass(t_a)) begin
                    door_evt <= 1'b1;
                    frozen   <= 1'b1;
                    if      (cx[9:5] == 5'd0)  door_dir <= D_LEFT;
                    else if (cx[9:5] == 5'd19) door_dir <= D_RIGHT;
                    else if (cy[8:5] == 4'd0)  door_dir <= D_UP;
                    else                       door_dir <= D_DOWN;
                end
                if (!hold_facing) begin
                    if (dxs[1])      facing <= dxs[0] ? D_LEFT : D_RIGHT;
                    else if (dys[1]) facing <= dys[0] ? D_UP : D_DOWN;
                end
                if (moving) begin
                    anim_cnt <= anim_cnt + 1'b1;
                    if (anim_cnt == 4'd7) begin
                        anim_cnt <= 0;
                        step <= step + 1'b1;
                    end
                end else begin
                    anim_cnt <= 0; step <= 0;
                end
                pose  <= (step == 2'd1) ? 2'd1 : (step == 2'd3) ? 2'd2 : 2'd0;
                state <= S_WAIT;
            end
            default: state <= S_WAIT;
            endcase
        end
    end
endmodule
