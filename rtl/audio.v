// เสียง P6: mono PWM -> AUD_PWM, 2 ช่อง: SFX (ทีละเสียง มี priority) + BGM (เพลงวน/jingle)
//
//   SFX 10 แบบ: ev[1..10] เป็น pulse 1 clock; เลขน้อย = priority สูงกว่า
//     เสียงที่ priority สูงกว่าแทรกได้ทันที; เท่ากันหรือต่ำกว่าระหว่างที่ยังเล่นอยู่ = ทิ้ง (ไม่รอคิว)
//     ev[9] (ยิง) เลือกเสียงตาม shoot_k: 0 ร่าง 2, 1 กระจาย, 2 นัดเร็ว, 3 ลูกใหญ่ (ต่ำ ยาวกว่า)
//   โน้ต Simon: simon_note_on + simon_note ให้เสียงทับ SFX ทุกอย่าง (priority สูงสุด) ตลอดที่ on
//   SFX = คลื่นสี่เหลี่ยม: half-period + ขยับต่อเฟรม (slide) + ความยาวเป็นเฟรม (ตารางใน params.vh)
//   BGM = โน้ตจาก mem/music.mem (ดู scripts/make_music.py): track 0-2 ชั้น 1-3, 3 ESCAPE (วน), 4 WIN, 5 GAME OVER (เล่นครั้งเดียว)
//   mix: 128 + (+-SFX_AMP) + (+-BGM_AMP) -> PWM 8 bit, carrier = clk / 256
//
// TSHIFT: simulator ตั้ง CE_DIV = 1 ทำให้เฟรมเกมสั้นลง 4 เท่าเทียบกับ clock -> ย่อ half-period ลง 2^TSHIFT เท่า
//   (บอร์ด CE_DIV = 4 -> TSHIFT = 0) เสียงจึงสูง/ยาวตามสัดส่วนเดียวกับบอร์ดเมื่อวัดเป็นเวลาของเกม
module audio #(
    parameter TSHIFT = 0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,
    input  wire        pause,           // 1 = หยุดเกม (SW15): เงียบ + SFX / BGM ค้างที่เดิม แล้วต่อเมื่อปล่อย
    input  wire [12:1] ev,              // pulse เอฟเฟกต์ 1..12 (11 = บอสปรากฏ, 12 = ผ่านประตู; 12 ต่ำกว่า 11 เพื่อให้เสียงบอสแทรกเสียงประตูได้)
    input  wire [1:0]  shoot_k,
    input  wire        simon_note_on,
    input  wire [1:0]  simon_note,
    input  wire        bgm_en,          // 1 = เล่นเพลง (PLAY / EVOLVE / FLOOR_CLEAR / ESCAPE / WIN / GAME_OVER)
    input  wire [2:0]  bgm_track,
    output reg         pwm = 1'b0,
    output wire        sd,              // AUD_SD
    output wire [7:0]  sample           // ค่า 8 bit ก่อน PWM (debug / test)
);
    `include "params.vh"
    wire ft = frame_tick & ~pause;                 // เวลาของ SFX / BGM หยุดตอน pause

    assign sd = (AUD_SD_ON != 0);

    // ---------- SFX ----------
    reg        sfx_on = 1'b0;
    reg [3:0]  sfx_id = 4'd0;           // priority ปัจจุบัน (1..10)
    reg [17:0] sfx_hp = 0;
    reg signed [17:0] sfx_sl = 0;
    reg [7:0]  sfx_len = 0;

    reg [3:0]  new_id;
    reg [17:0] new_hp; reg signed [17:0] new_sl; reg [7:0] new_len;
    always @* begin
        new_id = 4'd0;
        if (ev[1]) new_id = 4'd1;
        else if (ev[2]) new_id = 4'd2;
        else if (ev[3]) new_id = 4'd3;
        else if (ev[4]) new_id = 4'd4;
        else if (ev[5]) new_id = 4'd5;
        else if (ev[6]) new_id = 4'd6;
        else if (ev[7]) new_id = 4'd7;
        else if (ev[8]) new_id = 4'd8;
        else if (ev[9]) new_id = 4'd9;
        else if (ev[10]) new_id = 4'd10;
        else if (ev[11]) new_id = 4'd11;
        else if (ev[12]) new_id = 4'd12;
        new_hp = 0; new_sl = 0; new_len = 0;
        case (new_id)
            4'd1:  begin new_hp = SFX_HURT_HP;  new_sl = SFX_HURT_SL;  new_len = SFX_HURT_LEN;  end
            4'd2:  begin new_hp = SFX_STUN_HP;  new_sl = SFX_STUN_SL;  new_len = SFX_STUN_LEN;  end
            4'd3:  begin new_hp = SFX_DIE_HP;   new_sl = SFX_DIE_SL;   new_len = SFX_DIE_LEN;   end
            4'd4:  begin new_hp = SFX_ITEM_HP;  new_sl = SFX_ITEM_SL;  new_len = SFX_ITEM_LEN;  end
            4'd5:  begin new_hp = SFX_CLEAR_HP; new_sl = SFX_CLEAR_SL; new_len = SFX_CLEAR_LEN; end
            4'd6:  begin new_hp = SFX_WRONG_HP; new_sl = SFX_WRONG_SL; new_len = SFX_WRONG_LEN; end
            4'd7:  begin new_hp = SFX_OK_HP;    new_sl = SFX_OK_SL;    new_len = SFX_OK_LEN;    end
            4'd8:  begin new_hp = SFX_MHIT_HP;  new_sl = SFX_MHIT_SL;  new_len = SFX_MHIT_LEN;  end
            4'd9:  case (shoot_k)
                       2'd0: begin new_hp = SFX_SHOOT0_HP; new_sl = SFX_SHOOT0_SL; new_len = SFX_SHOOT0_LEN; end
                       2'd1: begin new_hp = SFX_SHOOT1_HP; new_sl = SFX_SHOOT1_SL; new_len = SFX_SHOOT1_LEN; end
                       2'd2: begin new_hp = SFX_SHOOT2_HP; new_sl = SFX_SHOOT2_SL; new_len = SFX_SHOOT2_LEN; end
                       default: begin new_hp = SFX_SHOOT3_HP; new_sl = SFX_SHOOT3_SL; new_len = SFX_SHOOT3_LEN; end
                   endcase
            4'd10: begin new_hp = SFX_MELEE_HP; new_sl = SFX_MELEE_SL; new_len = SFX_MELEE_LEN; end
            4'd11: begin new_hp = SFX_BOSS_HP;  new_sl = SFX_BOSS_SL;  new_len = SFX_BOSS_LEN;  end
            4'd12: begin new_hp = SFX_DOOR_HP;  new_sl = SFX_DOOR_SL;  new_len = SFX_DOOR_LEN;  end
            default: ;
        endcase
    end

    always @(posedge clk) begin
        if (rst) sfx_on <= 1'b0;
        else begin
            if (new_id != 0 && (!sfx_on || new_id < sfx_id)) begin
                sfx_on <= 1'b1; sfx_id <= new_id; sfx_hp <= new_hp; sfx_sl <= new_sl; sfx_len <= new_len;
            end else if (ft && sfx_on) begin
                sfx_hp <= sfx_hp + sfx_sl;
                if (sfx_len <= 1) sfx_on <= 1'b0;
                sfx_len <= sfx_len - 1'b1;
            end
        end
    end

    // โน้ต Simon override
    wire [17:0] note_hp = (simon_note == 2'd0) ? SIMON_HP0 : (simon_note == 2'd1) ? SIMON_HP1 :
                          (simon_note == 2'd2) ? SIMON_HP2 : SIMON_HP3;
    wire        tone_on = simon_note_on || sfx_on;
    wire [17:0] tone_hp = simon_note_on ? note_hp : sfx_hp;
    wire [17:0] tone_rl = tone_hp >> TSHIFT;

    reg [17:0] s_cnt = 0;
    reg        s_q = 1'b0;
    always @(posedge clk) begin
        if (!tone_on || tone_rl == 0) begin s_cnt <= 0; s_q <= 1'b0; end
        else if (s_cnt <= 1) begin s_cnt <= tone_rl; s_q <= ~s_q; end
        else s_cnt <= s_cnt - 1'b1;
    end

    // ---------- BGM ----------
    reg [31:0] mrom [0:1023];                      // 8 tracks x 128 (6 = custom track from sprites/music.json, 7 = none)
    initial $readmemh("music.mem", mrom);
    reg [2:0]  cur_track = 3'd7;
    reg [6:0]  pos = 0;
    reg [7:0]  dur_cnt = 0;
    reg [17:0] b_hp = 0;
    reg        b_done = 1'b0;
    reg  [31:0] ent = 32'd0;                       // อ่าน ROM แบบ synchronous (1 register stage): ใช้ได้เพราะ frame_tick ห่างกันหลายล้าน clock
    always @(posedge clk) ent <= mrom[{cur_track, pos}];
    wire        loop = (cur_track < 3'd4) || (cur_track == 3'd6);   // floors / escape / custom track loop, jingles play once
    always @(posedge clk) begin
        if (rst || !bgm_en) begin
            cur_track <= 3'd7; pos <= 0; dur_cnt <= 0; b_hp <= 0; b_done <= 1'b0;
        end else if (bgm_track != cur_track) begin
            cur_track <= bgm_track; pos <= 0; dur_cnt <= 0; b_hp <= 0; b_done <= 1'b0;
        end else if (ft && !b_done) begin
            if (dur_cnt != 0) dur_cnt <= dur_cnt - 1'b1;
            else if (ent[31:24] == 8'd0) begin
                if (loop) pos <= 0; else begin b_done <= 1'b1; b_hp <= 0; end
            end else begin
                b_hp <= ent[17:0]; dur_cnt <= ent[31:24] - 1'b1; pos <= pos + 1'b1;
            end
        end
    end
    wire [17:0] b_rl = b_hp >> TSHIFT;
    wire        b_gate = (dur_cnt != 0) && (b_hp != 0);        // ช่วงสุดท้ายของโน้ตเงียบ 1 เฟรม = แยกโน้ต
    reg [17:0] b_cnt = 0;
    reg        b_q = 1'b0;
    always @(posedge clk) begin
        if (!b_gate || b_rl == 0) begin b_cnt <= 0; b_q <= 1'b0; end
        else if (b_cnt <= 1) begin b_cnt <= b_rl; b_q <= ~b_q; end
        else b_cnt <= b_cnt - 1'b1;
    end

    // ---------- mix + PWM ----------
    wire signed [9:0] sfx_v = (tone_on && !pause) ? (s_q ? SFX_AMP : -SFX_AMP) : 10'sd0;
    wire signed [9:0] bgm_v = (b_gate && !pause) ? (b_q ? BGM_AMP : -BGM_AMP) : 10'sd0;
    wire signed [9:0] mix   = 10'sd128 + sfx_v + bgm_v;
    assign sample = mix[7:0];
    reg [7:0] pc = 0;
    always @(posedge clk) begin
        pc  <= pc + 1'b1;
        pwm <= (pc < sample);
    end
endmodule
