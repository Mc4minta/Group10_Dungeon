// Game FSM (P2): TITLE / PROLOGUE / PLAY / EVOLVE / FLOOR_CLEAR / ESCAPE (maze) / WIN / GAME_OVER  (pause is not a state: see top.v)
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
//   sprint      level: ความเร็ว + SPRINT_BONUS (SW14 / Shift key)
// เอาต์พุต
//   state       ดู S_* ด้านล่าง
//   restart     pulse ตอน TITLE -> PLAY (world กลับชั้น 1 START)
//   next_floor  pulse ตอนจบ FLOOR_CLEAR
//   form 0..3 (= ร่าง 1..4), hp, hp_max, speed (px/เฟรม รวม sprint), damage (ไว้ใช้ P3)
//   rgb         {R,G,B} สี LED16 (ขาวตอน EVOLVE)
//   freeze      player ไม่เดิน/ไม่ animate  ·  hide_player  จังหวะกะพริบตอน EVOLVE
//   m_t m_o s_t s_o  เวลาเล่น mm.ss เป็น BCD
module game_fsm #(
    parameter PROLOGUE = 1                   // 1 = TITLE -> PROLOGUE (4 หน้า) -> PLAY; 0 = TITLE -> PLAY ตรง (testbench เก่า)
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_tick,
    input  wire       btnc_rise,
    input  wire       btnl_rise,             // W43: on the GAME OVER screen BTNL = back to the title (BTNC = retry the current floor)
    input  wire [1:0] floor_in,              // W43: the floor the hero died on (for the retry)
    input  wire       got_item,
    input  wire       take_hit,
    input  wire       floor_done,
    input  wire       exit_evt,
    input  wire       escape_start,          // pulse: บอส 3 ตาย -> ESCAPE
    input  wire       exit_direct,           // 1 = exit_evt ตอน PLAY ไป WIN ตรง ๆ (DEBUG, สคริปต์เก่า)
    input  wire       sprint,
    input  wire       key_get,               // pulse: บอส 3 ตาย -> ได้กุญแจ (W7)
    input  wire       goal,                  // pulse: ลูกบอลถึงเส้นชัยในเขาวงกต (ESCAPE state = maze) -> WIN
    input  wire       kill,                  // pulse: โจมตีใหญ่ของบอส 3 -> HP 0 -> GAME_OVER (PLAY / ESCAPE)
    output reg  [2:0] state = 3'd0,
    output reg        timeout = 1'b0,        // W16: GAME_OVER มาจากหมดเวลาเขาวงกต (หน้าจอข้อความต่างจากตายธรรมดา)
    output reg        has_key = 1'b0,        // W7: มีกุญแจแล้ว -> ประตู E (START ชั้น 3) เปิด; เดินเข้า = เริ่มเขาวงกต
    output reg  [1:0] page = 2'd0,           // หน้า prologue 0..3 (ใช้ตอน state = S_PROLOGUE)
    output reg        restart = 1'b0,
    output reg        retry = 1'b0,          // W43: pulse together with restart: keep the current floor (world.v)
    output reg        next_floor = 1'b0,
    output reg  [1:0] form = 2'd0,
    output reg  [2:0] hp = 3'd3,
    output wire [2:0] hp_max,
    output wire [2:0] speed,
    output wire [1:0] damage,
    output wire [2:0] rgb,
    output wire       freeze,
    output wire       hide_player,
    output reg  [3:0] m_t = 0, m_o = 0, s_t = 0, s_o = 0,
    // ESCAPE: นับถอยหลัง ss.ff (วินาที . เฟรมในวินาที) เป็น BCD, banner = ช่วงแสดง ESCAPE!
    output reg  [3:0] e_s_t = 0, e_s_o = 0, e_f_t = 0, e_f_o = 0,
    output wire       esc_banner
);
    `include "params.vh"                      // ตารางค่าต่อร่าง + เวลา EVOLVE/FLOOR_CLEAR (tentative)
    localparam [2:0] BLINK_BIT = 3'd2;        // กะพริบ: เห็น 4 เฟรม / ซ่อน 4 เฟรม (บิต 2 ของตัวนับ)

    localparam [2:0] S_TITLE = 3'd0, S_PLAY = 3'd1, S_EVOLVE = 3'd2, S_FLOOR_CLEAR = 3'd3,
                     S_ESCAPE = 3'd4, S_WIN = 3'd5, S_GAME_OVER = 3'd6, S_PROLOGUE = 3'd7;

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
    assign freeze = (state == S_TITLE) || (state == S_PROLOGUE) || (state == S_ESCAPE) || (state == S_EVOLVE) || (state == S_FLOOR_CLEAR) ||
                    (state == S_WIN)   || (state == S_GAME_OVER);

    reg [8:0] pcnt = 9'd0;                   // นับเฟรมในหน้า prologue
    reg [7:0] cnt = 8'd0;                    // นับเฟรมใน EVOLVE / FLOOR_CLEAR
    assign hide_player = (state == S_EVOLVE) && cnt[BLINK_BIT];

    // ---------- timer ----------
    reg [5:0] tick60 = 6'd0;
    wire timer_run = (state == S_PLAY) || (state == S_EVOLVE) || (state == S_FLOOR_CLEAR) || (state == S_ESCAPE);
    reg [7:0] esc_el = 0;                    // เฟรมที่ผ่านไปใน ESCAPE (ไว้แสดง banner)
    assign esc_banner = (state == S_ESCAPE) && (esc_el < ESCAPE_BANNER);
    localparam [3:0] ESC_T = ESCAPE_SECONDS / 10, ESC_O = ESCAPE_SECONDS % 10;
    reg timer_clr;                           // pulse ภายใน always (blocking, ใช้ใน block เดียว)

    always @(posedge clk) begin
        restart    <= 1'b0;
        retry      <= 1'b0;
        next_floor <= 1'b0;
        timer_clr = 1'b0;

        if (rst) begin
            state <= S_TITLE; form <= 2'd0; hp <= HP1; cnt <= 0; has_key <= 1'b0; timeout <= 1'b0;
            timer_clr = 1'b1;
        end else begin
            if (key_get) has_key <= 1'b1;
            case (state)
            S_TITLE: if (btnc_rise) begin
                form <= 2'd0; hp <= HP1; cnt <= 0; page <= 2'd0; pcnt <= 0; has_key <= 1'b0; timeout <= 1'b0;
                timer_clr = 1'b1;
                if (PROLOGUE != 0) state <= S_PROLOGUE;
                else begin state <= S_PLAY; restart <= 1'b1; end
            end

            S_PROLOGUE: begin                           // W9a: จอดำ + ข้อความทีละหน้า; BTNC หรือครบเวลา = หน้าถัดไป
                if (btnc_rise || (frame_tick && pcnt == PROLOGUE_FRAMES - 1)) begin
                    pcnt <= 0;
                    if (page == PROLOGUE_PAGES - 1) begin state <= S_PLAY; restart <= 1'b1; page <= 2'd0; timer_clr = 1'b1; end
                    else page <= page + 1'b1;
                end else if (frame_tick) pcnt <= pcnt + 1'b1;
            end

            S_PLAY: begin
                if (take_hit && hp != 3'd0) hp <= hp - 1'b1;
                if (kill || (take_hit && hp <= 3'd1)) begin       // HP หมด / โดนโจมตีใหญ่
                    hp <= 3'd0; state <= S_GAME_OVER;
                end else if (got_item && form != 2'd3) begin
                    state <= S_EVOLVE; cnt <= 0;
                end else if (escape_start) begin         // บอส 3 ตาย
                    state <= S_ESCAPE; esc_el <= 0;
                    e_s_t <= ESC_T; e_s_o <= ESC_O; e_f_t <= 0; e_f_o <= 0;
                end else if (floor_done) begin
                    state <= S_FLOOR_CLEAR; cnt <= 0;
                end else if (exit_evt && exit_direct) begin
                    state <= S_WIN;                     // DEBUG: ทางลัดแบบเก่า
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

            S_ESCAPE: begin                             // W7: Ball in a Maze 60 วิ (ถึงเส้นชัย = WIN, หมดเวลา = GAME OVER)
                if (take_hit && hp != 3'd0) hp <= hp - 1'b1;
                if (kill || (take_hit && hp <= 3'd1)) begin
                    hp <= 3'd0; state <= S_GAME_OVER;
                end else if (goal) begin
                    state <= S_WIN;                     // W7: ลูกบอลถึงเส้นชัย
                end else if (frame_tick) begin
                    if (esc_el != 8'hFF) esc_el <= esc_el + 1'b1;
                    // นับถอยหลัง ss.ff (ff = 59..0)
                    if (e_s_t == 0 && e_s_o == 0 && e_f_t == 0 && e_f_o == 1) begin
                        e_f_o <= 0; state <= S_GAME_OVER; timeout <= 1'b1;       // หมดเวลา
                    end else if (e_f_t == 0 && e_f_o == 0) begin
                        e_f_t <= 4'd5; e_f_o <= 4'd9;
                        if (e_s_o == 0) begin e_s_o <= 4'd9; e_s_t <= e_s_t - 1'b1; end
                        else e_s_o <= e_s_o - 1'b1;
                    end else if (e_f_o == 0) begin
                        e_f_o <= 4'd9; e_f_t <= e_f_t - 1'b1;
                    end else e_f_o <= e_f_o - 1'b1;
                end
            end

            S_WIN: if (btnc_rise) state <= S_TITLE;
            S_GAME_OVER: begin                              // W43: BTNC = retry the CURRENT floor with full hearts, BTNL = title
                if (btnc_rise) begin
                    state <= S_PLAY; restart <= 1'b1; retry <= 1'b1;
                    form <= (floor_in == 2'd3) ? 2'd2 : floor_in; hp <= f_hp((floor_in == 2'd3) ? 2'd2 : floor_in);
                    cnt <= 0; has_key <= 1'b0; timeout <= 1'b0;
                end else if (btnl_rise) state <= S_TITLE;
            end

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
