// ระบบห้อง: floor, room, grid (ลำดับไฟล์ maps/), ตารางประตู + จุดเกิดหน้าประตู
// ย้ายมาจาก top.v (พฤติกรรมเหมือนเดิมทุกอย่าง)
//
// อินพุต
//   restart     pulse: กลับ ชั้น 1 ห้อง START ที่จุดเกิด P
//   next_floor  pulse: ไปชั้นถัดไป (ชั้น 3 -> วนกลับชั้น 1 เหมือนเดิม) เกิดที่ START
//   door_evt    pulse จาก player.v ตอนเดินเข้าประตูเปิด, door_dir = ขอบจอที่ประตูอยู่ (0 ลง 1 ขึ้น 2 ซ้าย 3 ขวา)
// เอาต์พุต
//   floor 0..2, room 0..4 (START C1 C2 PUZ BOSS), grid 0..12
//   load + load_x/load_y: pulse สั่ง player วางที่จุดเกิดใหม่ (มุมซ้ายบนของ sprite)
//   exit_evt    pulse: เดินเข้าประตู E ในห้อง START (ชั้น 3) = ออกจากดันเจี้ยน
module world (
    input  wire       clk,
    input  wire       rst,
    input  wire       restart,
    input  wire       next_floor,
    input  wire       door_evt,
    input  wire [1:0] door_dir,
    output reg  [1:0] floor = 0,
    output reg  [2:0] room  = 3'd0,
    output wire [3:0] grid,
    output reg        load  = 1'b1,
    output reg  [9:0] load_x = 10'd288,
    output reg  [9:0] load_y = 10'd224,
    output reg        exit_evt = 1'b0
);
    localparam R_START = 3'd0, R_C1 = 3'd1, R_C2 = 3'd2, R_PUZ = 3'd3, R_BOSS = 3'd4;

    // จุดเกิดหน้าประตู (มุมซ้ายบนของ sprite)
    localparam [9:0] SP_LX = 10'd40,  SP_RX = 10'd568, SP_MX = 10'd304,
                     SP_MY = 10'd240, SP_TY = 10'd40,  SP_BY = 10'd408,
                     ST_X  = 10'd288, ST_Y  = 10'd224;   // จุด P ในห้อง START

    // ห้อง (floor, room) -> grid 0..12 (ลำดับไฟล์ใน maps/)
    assign grid = (room == R_START) ? ((floor == 2'd2) ? 4'd1 : 4'd0) :
                  (room == R_C1)    ? 4'd4 + floor * 4'd3 :
                  (room == R_C2)    ? 4'd5 + floor * 4'd3 :
                  (room == R_PUZ)   ? 4'd6 + floor * 4'd3 :
                                      ((floor == 2'd1) ? 4'd3 : 4'd2);   // BOSS

    always @(posedge clk) begin
        load     <= 1'b0;
        exit_evt <= 1'b0;
        if (rst || restart) begin
            floor <= 0; room <= R_START;
            load <= 1'b1; load_x <= ST_X; load_y <= ST_Y;
        end else if (next_floor) begin
            floor <= (floor == 2'd2) ? 2'd0 : floor + 1'b1;
            room  <= R_START;
            load <= 1'b1; load_x <= ST_X; load_y <= ST_Y;
        end else if (door_evt) begin
            load <= 1'b1;
            case (room)
                R_START: if (door_dir == 2'd3) begin room <= R_C1; load_x <= SP_LX; load_y <= SP_MY; end
                         else                  begin exit_evt <= 1'b1; load <= 1'b0; end   // ประตู E
                R_C1: case (door_dir)
                        2'd2:    begin room <= R_START; load_x <= SP_RX; load_y <= SP_MY; end
                        2'd1:    begin room <= R_C2;    load_x <= SP_MX; load_y <= SP_BY; end
                        default: begin room <= R_BOSS;  load_x <= SP_LX; load_y <= SP_MY; end
                      endcase
                R_C2:    if (door_dir == 2'd0) begin room <= R_C1;  load_x <= SP_MX; load_y <= SP_TY; end
                         else                  begin room <= R_PUZ; load_x <= SP_LX; load_y <= SP_MY; end
                R_PUZ:   begin room <= R_C2; load_x <= SP_RX; load_y <= SP_MY; end
                default: begin room <= R_C1; load_x <= SP_RX; load_y <= SP_MY; end   // BOSS -> C1
            endcase
        end
    end
endmodule
