`timescale 1ns/1ps
// ทดสอบ audio.v: PWM, SFX ทุกแบบ (ความถี่ + ความยาว), priority, โน้ต Simon, BGM (โน้ต / ความยาว / วน / สลับแทร็ก / jingle), AUD_SD
// ใช้ TSHIFT = 6 และเฟรม = 26,250 clock (= 1,680,000 / 64) เพื่อให้เทสต์เร็ว: อัตราส่วนความถี่ต่อเฟรมเท่าบอร์ดจริง
// รัน: ./scripts/run_sim.sh audio
module tb_audio;
    `include "params.vh"
    localparam TS = 6;
    localparam FR = 1680000 / 64;                 // clock ต่อเฟรม
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1;
    reg [12:1] ev = 0; reg [1:0] shoot_k = 0;
    reg simon_on = 0; reg [1:0] simon_n = 0;
    reg bgm_en = 0; reg [2:0] track = 0; reg pause = 0;
    integer fc = 0; reg tick = 0;
    always @(posedge clk) begin fc <= (fc == FR - 1) ? 0 : fc + 1; tick <= (fc == FR - 1); end

    wire pwm, sd; wire [7:0] sample;
    audio #(.TSHIFT(TS)) dut (.clk(clk), .rst(rst), .frame_tick(tick), .ev(ev), .shoot_k(shoot_k),
        .simon_note_on(simon_on), .simon_note(simon_n), .pause(pause), .bgm_en(bgm_en), .bgm_track(track),
        .pwm(pwm), .sd(sd), .sample(sample));

    integer errors = 0, checks = 0;
    task check(input cond, input [8*80-1:0] msg); begin
        checks = checks + 1;
        if (cond) $display("PASS  %0s", msg);
        else begin $display("FAIL  %0s", msg); errors = errors + 1; end
    end endtask

    // 1 pulse เอฟเฟกต์ (clock เดียว)
    task fire(input integer id); begin @(posedge clk); ev[id] <= 1; @(posedge clk); ev[id] <= 0; end endtask

    // วัดครึ่งคาบแรกของ tone (clock) หลังเริ่มเสียง + ความยาว (เฟรม) จนจบ
    integer t_a, t_b, hp_meas, len_clk;
    task measure_sfx(output integer half, output integer frames_len); integer c, t0, t1, edges; reg q0; begin
        half = 0; edges = 0; t0 = 0; c = 0; q0 = dut.s_q;
        while (!dut.sfx_on && c < 100) begin @(posedge clk); c = c + 1; end
        c = 0;
        while (dut.sfx_on && c < 6000000) begin
            @(posedge clk); c = c + 1;
            if (dut.s_q !== q0) begin
                edges = edges + 1; q0 = dut.s_q;
                if (edges == 2) t0 = c;
                if (edges == 3) half = c - t0;
            end
        end
        frames_len = (c + FR / 2) / FR;
    end endtask

    // คาดหวัง: half-period เริ่มต้น (hp >> TS) ขยับต่อเฟรม -> ครึ่งคาบที่ 2..3 ของเสียงอยู่ในช่วง hp0 >> TS ถึง (hp0 + sl) >> TS ประมาณ
    task check_sfx(input integer id, input integer hp0, input integer sl, input integer len, input [8*40-1:0] name);
        integer h, l; integer lo, hi; begin
        fire(id); measure_sfx(h, l);
        lo = (hp0 >> TS) - 2; hi = ((hp0 + (sl > 0 ? sl : 0)) >> TS) + (sl < 0 ? 0 : 2) + 2;
        if (sl < 0) begin lo = ((hp0 + sl) >> TS) - 2; hi = (hp0 >> TS) + 2; end
        $display("      %0s: half-period %0d clk (start %0d), %0d frames (spec %0d)", name, h, hp0 >> TS, l, len);
        check(h >= lo && h <= hi, name);
        check(l == len, "   ...length in frames");
        repeat (FR * 2) @(posedge clk);
    end endtask

    // BGM: ช่วงโน้ตแรกของแทร็ก t (hp, ความยาวเฟรม จาก ROM)
    integer w0, w1, nfr, cc;
    reg [31:0] e0, e1, e2;

    integer n, hi_cnt, k, ok_all;
    initial begin
        repeat (5) @(posedge clk); rst <= 0; repeat (5) @(posedge clk);
        check(sd === (AUD_SD_ON != 0), "AUD_SD enables the amplifier (level AUD_SD_ON = 1)");
        // ---- PWM: duty ตาม sample (เงียบ = 128/256) ----
        hi_cnt = 0; for (n = 0; n < 256 * 4; n = n + 1) begin @(posedge clk); hi_cnt = hi_cnt + pwm; end
        check(sample == 8'd128 && hi_cnt >= 4 * 128 - 2 && hi_cnt <= 4 * 128 + 2, "silent: sample 128, PWM duty 50%");
        // ---- SFX ทั้ง 10 ----
        check_sfx(1, SFX_HURT_HP, SFX_HURT_SL, SFX_HURT_LEN, "sfx 1 hurt");
        check_sfx(2, SFX_STUN_HP, SFX_STUN_SL, SFX_STUN_LEN, "sfx 2 boss stunned");
        check_sfx(3, SFX_DIE_HP, SFX_DIE_SL, SFX_DIE_LEN, "sfx 3 monster/boss dies");
        check_sfx(4, SFX_ITEM_HP, SFX_ITEM_SL, SFX_ITEM_LEN, "sfx 4 item");
        check_sfx(5, SFX_CLEAR_HP, SFX_CLEAR_SL, SFX_CLEAR_LEN, "sfx 5 room clear / door");
        check_sfx(6, SFX_WRONG_HP, SFX_WRONG_SL, SFX_WRONG_LEN, "sfx 6 puzzle wrong");
        check_sfx(7, SFX_OK_HP, SFX_OK_SL, SFX_OK_LEN, "sfx 7 puzzle ok");
        check_sfx(8, SFX_MHIT_HP, SFX_MHIT_SL, SFX_MHIT_LEN, "sfx 8 enemy hit");
        shoot_k = 0; check_sfx(9, SFX_SHOOT0_HP, SFX_SHOOT0_SL, SFX_SHOOT0_LEN, "sfx 9 shoot form 2");
        shoot_k = 1; check_sfx(9, SFX_SHOOT1_HP, SFX_SHOOT1_SL, SFX_SHOOT1_LEN, "sfx 9 shoot form 3 (spread)");
        shoot_k = 2; check_sfx(9, SFX_SHOOT2_HP, SFX_SHOOT2_SL, SFX_SHOOT2_LEN, "sfx 9 shoot form 4 tap");
        shoot_k = 3; check_sfx(9, SFX_SHOOT3_HP, SFX_SHOOT3_SL, SFX_SHOOT3_LEN, "sfx 9 big shot (lower, longer)");
        check_sfx(10, SFX_MELEE_HP, SFX_MELEE_SL, SFX_MELEE_LEN, "sfx 10 melee");
        check_sfx(11, SFX_BOSS_HP, SFX_BOSS_SL, SFX_BOSS_LEN, "sfx 11 boss appears");
        check_sfx(12, SFX_DOOR_HP, SFX_DOOR_SL, SFX_DOOR_LEN, "sfx 12 door / room change");
        check(SFX_SHOOT3_LEN > SFX_SHOOT0_LEN && SFX_SHOOT3_HP > SFX_SHOOT0_HP, "big shot is lower and longer than the normal shot");
        // ---- priority ----
        fire(10); repeat (FR) @(posedge clk);
        check(dut.sfx_on && dut.sfx_id == 10, "melee playing");
        fire(1); @(posedge clk);
        check(dut.sfx_on && dut.sfx_id == 1, "higher priority (hurt) interrupts melee");
        fire(10); fire(7); @(posedge clk);
        check(dut.sfx_id == 1, "lower priority while hurt plays is dropped");
        fire(1); repeat (FR) @(posedge clk);
        check(dut.sfx_len >= SFX_HURT_LEN - 3, "same priority is dropped (hurt not restarted)");
        repeat (FR * (SFX_HURT_LEN + 2)) @(posedge clk);
        check(!dut.sfx_on, "sfx ends after its length");
        fire(12); repeat (FR) @(posedge clk);
        check(dut.sfx_on && dut.sfx_id == 12, "door sound playing");
        fire(11); @(posedge clk);
        check(dut.sfx_id == 11, "boss sound interrupts the door sound (boss enters right after the door)");
        fire(12); @(posedge clk);
        check(dut.sfx_id == 11, "door sound (lower priority) does not interrupt the boss sound");
        fire(10); @(posedge clk);
        check(dut.sfx_id == 10, "melee (higher priority) interrupts the boss sound");
        repeat (FR * (SFX_MELEE_LEN + 2)) @(posedge clk);
        // ---- โน้ต Simon: 4 เสียง, ทับ SFX ----
        fire(1);
        for (k = 0; k < 4; k = k + 1) begin
            simon_n = k; simon_on = 1; repeat (3) @(posedge clk);
            w0 = 0; cc = 0; ok_all = dut.s_q;
            while (cc < 4 * ((k == 0 ? SIMON_HP0 : k == 1 ? SIMON_HP1 : k == 2 ? SIMON_HP2 : SIMON_HP3) >> TS)) begin
                @(posedge clk); cc = cc + 1;
            end
            // วัดครึ่งคาบ
            t_a = 0; ok_all = dut.s_q; cc = 0;
            while (dut.s_q == ok_all && cc < 100000) begin @(posedge clk); cc = cc + 1; end
            t_a = 0; ok_all = dut.s_q;
            while (dut.s_q == ok_all && t_a < 100000) begin @(posedge clk); t_a = t_a + 1; end
            $display("      simon note %0d: half-period %0d clk (expect %0d)", k, t_a,
                     (k == 0 ? SIMON_HP0 : k == 1 ? SIMON_HP1 : k == 2 ? SIMON_HP2 : SIMON_HP3) >> TS);
            check(t_a >= ((k == 0 ? SIMON_HP0 : k == 1 ? SIMON_HP1 : k == 2 ? SIMON_HP2 : SIMON_HP3) >> TS) - 1 &&
                  t_a <= ((k == 0 ? SIMON_HP0 : k == 1 ? SIMON_HP1 : k == 2 ? SIMON_HP2 : SIMON_HP3) >> TS) + 1,
                  "Simon note tone");
            simon_on = 0; repeat (2) @(posedge clk);
        end
        repeat (FR * 40) @(posedge clk);
        // ---- BGM: โน้ตจาก ROM ตามความยาว, วน, สลับแทร็ก, jingle ----
        bgm_en = 1; track = 0; repeat (5) @(posedge clk);
        e0 = dut.mrom[0]; e1 = dut.mrom[1]; e2 = dut.mrom[2];
        @(posedge tick); @(posedge clk); @(posedge clk);
        check(dut.b_hp == e0[17:0] && dut.pos == 1, "BGM track 0 starts with its first note (C5)");
        nfr = 0; while (dut.b_hp == e0[17:0] && nfr < 100) begin @(posedge tick); @(posedge clk); @(posedge clk); nfr = nfr + 1; end
        $display("      first note lasted %0d frames (ROM says %0d)", nfr, e0[31:24]);
        check(nfr == e0[31:24] && dut.b_hp == e1[17:0], "first note lasts its ROM duration, then the second note plays");
        // เสียงของ BGM: ครึ่งคาบ
        t_a = 0; ok_all = dut.b_q; cc = 0;
        while (dut.b_q == ok_all && cc < 200000) begin @(posedge clk); cc = cc + 1; end
        ok_all = dut.b_q; t_a = 0;
        while (dut.b_q == ok_all && t_a < 200000) begin @(posedge clk); t_a = t_a + 1; end
        check(t_a >= ((e1[17:0] >> TS) - 1) && t_a <= ((e1[17:0] >> TS) + 1), "BGM square wave at the note's frequency");
        // วน: เด้งไปโน้ตสุดท้ายก่อนเครื่องหมายจบ
        for (n = 0; n < 128 && dut.mrom[n][31:24] != 0; n = n + 1) ;
        dut.pos = n - 1; dut.dur_cnt = 0;
        @(posedge tick); @(posedge clk); @(posedge clk);
        check(dut.pos == n, "BGM reaches the last note");
        k = 0; while (dut.pos != 1 && k < 60) begin @(posedge tick); @(posedge clk); @(posedge clk); k = k + 1; end
        check(dut.pos == 1 && dut.cur_track == 0, "BGM loops back to the first note");
        // สลับแทร็ก: ESCAPE (3)
        track = 3; repeat (4) @(posedge clk);
        check(dut.cur_track == 3 && dut.pos == 0, "track switches immediately (floor -> ESCAPE)");
        e0 = dut.mrom[3*128];
        @(posedge tick); @(posedge clk); @(posedge clk);
        check(dut.b_hp == e0[17:0], "ESCAPE track plays its own first note");
        check(e0[31:24] <= 14, "ESCAPE notes are short (urgent)");
        // ---- custom track (6, from sprites/music.json): plays its own notes and LOOPS like the floor tracks
        track = 6; repeat (4) @(posedge clk);
        check(dut.cur_track == 3'd6 && dut.pos == 0, "custom track 6 selected immediately");
        e0 = dut.mrom[6*128];
        if (e0[31:24] != 0) begin                                  // the slot is filled
            @(posedge tick); @(posedge clk); @(posedge clk);
            check(dut.b_hp == e0[17:0] && dut.pos == 1, "custom track plays its first note");
            for (n = 0; n < 127 && dut.mrom[6*128 + n][31:24] != 0; n = n + 1) ;
            dut.pos = n - 1; dut.dur_cnt = 0;
            @(posedge tick); @(posedge clk); @(posedge clk);
            check(dut.pos == n, "custom track reaches its last note");
            k = 0; while (dut.pos != 1 && k < 400) begin @(posedge tick); @(posedge clk); @(posedge clk); k = k + 1; end
            check(dut.pos == 1 && dut.cur_track == 3'd6 && !dut.b_done, "custom track loops back to the first note");
        end
        track = 7; repeat (4) @(posedge clk);
        // jingle WIN (4): เล่นครั้งเดียวแล้วหยุด
        track = 4; repeat (4) @(posedge clk);
        k = 0; while (!dut.b_done && k < 300) begin @(posedge tick); @(posedge clk); @(posedge clk); k = k + 1; end
        $display("      WIN jingle finished after %0d frames", k);
        check(dut.b_done && dut.b_hp == 0 && k > 100 && k < 250, "WIN jingle plays once and stops");
        // W15 pause: BGM ค้างที่โน้ตเดิม + เงียบ แล้วต่อจากเดิมเมื่อปล่อย
        track = 0; bgm_en = 0; repeat (4) @(posedge clk); bgm_en = 1; repeat (4) @(posedge clk);
        repeat (3) begin @(posedge tick); @(posedge clk); @(posedge clk); end
        begin : pause_t
            integer pos_a, dur_a; integer nz; integer q;
            pause = 1; repeat (4) @(posedge clk);
            pos_a = dut.pos; dur_a = dut.dur_cnt;
            nz = 0;
            for (q = 0; q < FR * 6; q = q + 1) begin @(posedge clk); if (sample != 8'd128) nz = nz + 1; end
            check(dut.pos == pos_a && dut.dur_cnt == dur_a, "pause: BGM position holds for 6 frames");
            check(nz == 0, "pause: audio output is silent (sample = 128)");
            pause = 0; repeat (2) begin @(posedge tick); @(posedge clk); @(posedge clk); end
            check(dut.pos != pos_a || dut.dur_cnt != dur_a, "pause released: BGM continues");
        end
        // BGM ดับเมื่อ bgm_en = 0 (TITLE)
        bgm_en = 0; repeat (4) @(posedge clk);
        check(dut.cur_track == 7 && dut.b_hp == 0, "BGM stops when disabled");
        // mix: SFX ดังกว่า BGM
        check(SFX_AMP > BGM_AMP, "SFX louder than BGM in the mix");
        $display("checks = %0d  errors = %0d", checks, errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
