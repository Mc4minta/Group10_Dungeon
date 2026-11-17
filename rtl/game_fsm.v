// Game FSM (P2): TITLE / PLAY / EVOLVE / FLOOR_CLEAR / ESCAPE / WIN / GAME_OVER
//  + ร่าง (form), HP, ตารางค่าต่อร่าง, timer mm.ss, sprint
//
// ค่าเกม (tentative) อยู่ใน rtl/params.vh ที่เดียว
//
// อินพุต (pulse 1 clock ทั้งหมด ยกเว้นที่ระบุ level)
//   frame_tick  1 pulse ต่อเฟรม (60 Hz)
//   btnc_rise   กด BTNC (หลัง debounce)
//   got_item    ได้ไอเทม -> EVOLVE (P4 จะมาจากปริศนา, ตอนนี้ debug SW3)
//   take_hit    โดนตี HP-1 (P3 จะมาจาก AABB, ตอนนี้ debug SW4)
//   floor_done  เคลียร์ชั้น -> FLOOR_CLEAR (P5 จะมาจากบอส, ตอนนี้ debug SW1)
//   exit_evt    เดินเข้าประตู E (จาก world.v) -> WIN (P5 จะแทรก ESCAPE ก่อน)
//   sprint      level: ความเร็ว + SPRINT_BONUS (SW15)
// เอาต์พุต
//   state       ดู S_* ด้านล่าง
//   restart     pulse ตอน TITLE -> PLAY (world กลับชั้น 1 START)
//   next_floor  pulse ตอนจบ FLOOR_CLEAR
//   form 0..3 (= ร่าง 1..4), hp, hp_max, speed (px/เฟรม รวม sprint), damage (ไว้ใช้ P3)
//   rgb         {R,G,B} สี LED16 (ขาวตอน EVOLVE)
//   freeze      player ไม่เดิน/ไม่ animate  ·  hide_player  จังหวะกะพริบตอน EVOLVE
//   m_t m_o s_t s_o  เวลาเล่น mm.ss เป็น BCD
module game_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_tick,
    input  wire       btnc_rise,
    input  wire       got_item,
    input  wire       take_hit,
    input  wire       floor_done,
    input  wire       exit_evt,
    input  wire       sprint,
    output reg  [2:0] state = 3'd0,
    output reg        restart = 1'b0,
    output reg        next_floor = 1'b0,
    output reg  [1:0] form = 2'd0,
    output reg  [2:0] hp = 3'd3,
    output wire [2:0] hp_max,
    output wire [2:0] speed,
    output wire [1:0] damage,
    output wire [2:0] rgb,
    output wire       freeze,
    output wire       hide_player,
    output reg  [3:0] m_t = 0, m_o = 0, s_t = 0, s_o = 0
);
    `include "params.vh"                      // ตารางค่าต่อร่าง + เวลา EVOLVE/FLOOR_CLEAR (tentative)
    localparam [2:0] BLINK_BIT = 3'd2;        // กะพริบ: เห็น 4 เฟรม / ซ่อน 4 เฟรม (บิต 2 ของตัวนับ)

    localparam [2:0] S_TITLE = 3'd0, S_PLAY = 3'd1, S_EVOLVE = 3'd2, S_FLOOR_CLEAR = 3'd3,
                     S_ESCAPE = 3'd4, S_WIN = 3'd5, S_GAME_OVER = 3'd6;

    function [2:0] f_spd(input [1:0] f);
        case (f) 2'd0: f_spd = SPD1; 2'd1: f_spd = SPD2; 2'd2: f_spd = SPD3; default: f_spd = SPD4; endcase
    endfunction
    function [2:0] f_hp(input [1:0] f);
        case (f) 2'd0: f_hp = HP1; 2'd1: f_hp = HP2; 2'd2: f_hp = HP3; default: f_hp = HP4; endcase
    endfunction
    function [1:0] f_dmg(input [1:0] f);
        case (f) 2'd0: f_dmg = DMG1; 2'd1: f_dmg = DMG2; 2'd2: f_dmg = DMG3; default: f_dmg = DMG4; endcase
    endfunction
    function [2:0] f_rgb(input [1:0] f);
        case (f) 2'd0: f_rgb = RGB1; 2'd1: f_rgb = RGB2; 2'd2: f_rgb = RGB3; default: f_rgb = RGB4; endcase
    endfunction

    assign hp_max = f_hp(form);
    assign speed  = f_spd(form) + (sprint ? SPRINT_BONUS : 3'd0);
    assign damage = f_dmg(form);
    assign rgb    = (state == S_EVOLVE) ? 3'b111 : f_rgb(form);
    assign freeze = (state == S_TITLE) || (state == S_EVOLVE) || (state == S_FLOOR_CLEAR) ||
                    (state == S_WIN)   || (state == S_GAME_OVER);

    reg [7:0] cnt = 8'd0;                    // นับเฟรมใน EVOLVE / FLOOR_CLEAR
    assign hide_player = (state == S_EVOLVE) && cnt[BLINK_BIT];

    // ---------- timer ----------
    reg [5:0] tick60 = 6'd0;
    wire timer_run = (state == S_PLAY) || (state == S_EVOLVE) || (state == S_FLOOR_CLEAR);
    reg timer_clr;                           // pulse ภายใน always (blocking, ใช้ใน block เดียว)

    always @(posedge clk) begin
        restart    <= 1'b0;
        next_floor <= 1'b0;
        timer_clr = 1'b0;

        if (rst) begin
            state <= S_TITLE; form <= 2'd0; hp <= HP1; cnt <= 0;
            timer_clr = 1'b1;
        end else begin
            case (state)
            S_TITLE: if (btnc_rise) begin
                state <= S_PLAY; restart <= 1'b1;
                form <= 2'd0; hp <= HP1; cnt <= 0;
                timer_clr = 1'b1;
            end

            S_PLAY: begin
                if (take_hit && hp != 3'd0) hp <= hp - 1'b1;
                if (take_hit && hp <= 3'd1) begin       // HP หมด
                    hp <= 3'd0; state <= S_GAME_OVER;
                end else if (got_item && form != 2'd3) begin
                    state <= S_EVOLVE; cnt <= 0;
                end else if (floor_done) begin
                    state <= S_FLOOR_CLEAR; cnt <= 0;
                end else if (exit_evt) begin
                    state <= S_WIN;                     // P5: เปลี่ยนเป็น ESCAPE ก่อน
                end
            end

            S_EVOLVE: if (frame_tick) begin
                if (cnt == EVOLVE_FRAMES - 1) begin
                    form  <= form + 1'b1;
                    hp    <= f_hp(form + 1'b1);         // เติม HP เต็มของร่างใหม่
                    state <= S_PLAY; cnt <= 0;
                end else cnt <= cnt + 1'b1;
            end

            S_FLOOR_CLEAR: if (frame_tick) begin
                if (cnt == CLEAR_FRAMES - 1) begin
                    next_floor <= 1'b1;
                    state <= S_PLAY; cnt <= 0;
                end else cnt <= cnt + 1'b1;
            end

            S_ESCAPE: state <= S_PLAY;                  // ยังไม่ใช้ (P5)

            S_WIN, S_GAME_OVER: if (btnc_rise) state <= S_TITLE;

            default: state <= S_TITLE;
            endcase
        end

        // timer: นับเฟรมใน PLAY / EVOLVE / FLOOR_CLEAR, 60 เฟรม = 1 วิ, อิ่มตัวที่ 99:59
        if (timer_clr) begin
            tick60 <= 0; m_t <= 0; m_o <= 0; s_t <= 0; s_o <= 0;
        end else if (timer_run && frame_tick) begin
            if (tick60 == 6'd59) begin
                tick60 <= 0;
                if (s_o != 4'd9) s_o <= s_o + 1'b1;
                else begin
                    s_o <= 0;
                    if (s_t != 4'd5) s_t <= s_t + 1'b1;
                    else begin
                        s_t <= 0;
                        if (m_o != 4'd9) m_o <= m_o + 1'b1;
                        else begin
                            m_o <= 0;
                            if (m_t != 4'd9) m_t <= m_t + 1'b1;
                            else begin m_t <= 4'd9; m_o <= 4'd9; s_t <= 4'd5; s_o <= 4'd9; end  // 99:59 ค้าง
                        end
                    end
                end
            end else tick60 <= tick60 + 1'b1;
        end
    end
endmodule
