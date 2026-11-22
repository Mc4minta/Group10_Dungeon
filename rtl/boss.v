// P5: บอส 3 ตัว (module เดียว + ROM พารามิเตอร์ boss_rom) — ใช้ slot บอสที่สำรองไว้ใน objects.v
//
//   W20: all bosses shoot patterns (fire_pat: 0 cross, 1 ring, 2 X, 3 aimed fan) every BOSS*_FIRE frames, blink (warn) BOSS_WARN frames before; boss 1 / 3 chase slowly
//   บอส 1 (ชั้น 1): HP 10, ไล่ (W20: ช้าลง 1 px ทุก 2 เฟรม), ยิงกระสุนเป็นแพทเทิร์น, รับดาเมจตลอด, ตบมือ (หรือ SW11) = มึน 180 เฟรม แล้ว cooldown 240 (W10)
//   บอส 2 (ชั้น 2): HP 16, อยู่กับที่, เรียกลูกน้อง 3 ตัวต่อรอบ; ตีได้ตลอด (W17; เดิม W11 ตีได้เฉพาะตอนลูกน้องตายหมด) ลูกน้องตายหมด -> รอ 120 เฟรม -> summon รอบใหม่
//   บอส 3 (ชั้น 3): HP 3, เกราะ: รับเฉพาะกระสุนชาร์จ (ทีละ 1); ไล่ 180 เฟรม -> ชาร์จโจมตีใหญ่ 120 เฟรม (หยุดนิ่ง กะพริบ) -> ผู้เล่นตาย (kill) / ถูกชาร์จขัดแล้ววนใหม่ (W12)
//   (ค่าทั้งหมดอยู่ใน params.vh)
//
// sprite 64x64 มุมซ้ายบน (bx, by), hitbox 48x48 = พิกเซล 8..55
// ชน tile เหมือนมอน (กำแพง ประตู หลุม = ผ่านไม่ได้) + บอส 2 ผ่านรั้ว F ไม่ได้ (บอส 1, 3 ผ่านได้)
// เช็ค 3 จุดบนขอบที่เดินไป (8, 31, 55) เพราะ hitbox 48 px กว้างกว่า tile 32 px
//
// เข้าห้องบอส (room_load, room = BOSS) และบอสชั้นนี้ยังไม่ตาย -> spawn ที่ B; ตายแล้ว = dead[floor] ค้างจน restart
// ทำงานต่อเฟรมหลัง frame_tick BOSS_DELAY clock (หลัง objects.v) ~ 10 clock
module boss_rom (
    input  wire [1:0] kind,           // 0..2 = บอส 1..3
    output wire [4:0] hp,
    output wire [1:0] speed,
    output wire [1:0] every,          // ก้าวทุกกี่เฟรม
    output wire       bounce,         // 1 = เด้งทแยง, 0 = ไล่ผู้เล่น
    output wire [6:0] fire,           // 0 = ไม่ยิง
    output wire       stunnable,
    output wire       fence           // 1 = ผ่านรั้ว F ไม่ได้
);
    `include "params.vh"
    // ใช้ assign (iverilog ไม่คิด always @* ที่ input ไม่เคยเปลี่ยน -> X)
    assign hp        = (kind == 2'd0) ? BOSS1_HP    : (kind == 2'd1) ? BOSS2_HP    : BOSS3_HP;
    assign speed     = (kind == 2'd0) ? BOSS1_SPEED : (kind == 2'd1) ? BOSS2_SPEED : BOSS3_SPEED;
    assign every     = (kind == 2'd0) ? BOSS1_EVERY : (kind == 2'd2) ? BOSS3_EVERY : 2'd1;
    assign bounce    = 1'b0;                      // ไม่มีบอสเด้งแล้ว (W11)
    assign fire      = (kind == 2'd0) ? BOSS1_FIRE : (kind == 2'd1) ? BOSS2_FIRE : BOSS3_FIRE;
    assign stunnable = (kind == 2'd0);            // W10: ตบมือ = บอส 1 มึน
    assign fence     = (kind == 2'd1);
endmodule

module boss (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,
    input  wire        run,              // PLAY หรือ ESCAPE
    input  wire        restart,          // เกมใหม่: บอสกลับมามีชีวิตทุกตัว
    input  wire        room_load,        // world.load
    input  wire [1:0]  floor,
    input  wire [2:0]  room,
    input  wire [3:0]  grid,
    input  wire [9:0]  px, py,           // ผู้เล่น (มุมซ้ายบน sprite)
    input  wire        dmg,              // pulse จาก objects.v: โดนกระสุน / ฟัน
    input  wire [2:0]  dmg_amt,
    input  wire        clap,             // pulse จาก pdm_mic.v (หรือ SW11)
    input  wire        dmg_big,          // pulse มาพร้อม dmg: กระสุนชาร์จ (ร่าง 4) -- บอส 3 รับดาเมจเฉพาะอันนี้
    input  wire [7:0]  brk,              // W5: บล็อกพังได้ที่พังแล้ว
    input  wire [2:0]  minions,          // มอนที่เหลือในห้อง (objects.alive): บอส 2 ตีได้เมื่อ 0
    output reg         act = 1'b0,
    output reg  [9:0]  bx = 0, by = 0,   // มุมซ้ายบน sprite 64x64
    output reg  [1:0]  kind = 0,
    output wire        flash,            // วาดขาว
    output wire        stunned,
    output reg         fire = 1'b0,      // pulse: fire a bullet pattern from the centre (objects.v puts it in enemy bullet slots)
    output reg  [1:0]  fire_pat = 2'd0,  // W20: pattern of this pulse: 0 cross (4 straight), 1 ring (8), 2 X (4 diagonals), 3 aimed fan (3 bullets at the player)
    output reg         fire_heavy = 1'b0,// W24: this volley is the boss-3 storm: its bullets hurt 2 HP
    output wire [1:0]  tele_lvl,         // W21: charge progress in quarters 0..3 (blink gets faster)
    output wire [6:0]  chg_w,            // W21: charge bar fill in px (0..120), 0 when not charging
    output wire        warn,             // W20: the boss is about to fire (last BOSS_WARN frames): drawn blinking
    output reg         died = 1'b0,      // pulse: บอสตาย (kind บอกว่าตัวไหน)
    output reg         summon = 1'b0,    // pulse: บอส 2 เรียกลูกน้อง (objects.v spawn)
    output reg         kill = 1'b0,      // pulse: โจมตีใหญ่ของบอส 3 ถูกผู้เล่น (HP -> 0)
    output wire        vuln,             // W16: บอส 2 อยู่ในช่วงตีได้ (VULNERABLE)
    output reg         intr = 1'b0,      // W16: pulse: ชาร์จบอส 3 ถูกขัด
    output wire        shield,           // บอส 2 ยังตีไม่ได้ (วาดกะพริบ)
    output wire        tele,             // บอส 3 กำลังชาร์จโจมตีใหญ่ (วาดกะพริบ)
    output reg  [2:0]  dead = 3'b000,    // [floor] บอสชั้นนั้นตายแล้ว
    output reg  [4:0]  hp = 0,
    output reg  [7:0]  hp_bar = 0,       // LED0-7 สัดส่วน HP
    output wire        anim,
    output wire        busy
);
    `include "params.vh"
    `include "puzzle_layout.vh"
    localparam R_BOSS = 3'd4;

    wire rage_hp;                                    // W43: second phase flag (see below)
    wire [4:0] p_hp; wire [1:0] p_speed, p_every; wire p_bounce, p_stun, p_fence; wire [6:0] p_fire;
    boss_rom prm (.kind(kind), .hp(p_hp), .speed(p_speed), .every(p_every), .bounce(p_bounce),
                  .fire(p_fire), .stunnable(p_stun), .fence(p_fence));

    // ---------- tile ROM ----------
    reg  [11:0] ta = 0, tb = 0;
    wire [3:0]  tda, tdb;
    tilemap_rom rom_a (.addr(ta), .brk(brk), .data(tda), .ov());
    tilemap_rom rom_b (.addr(tb), .brk(brk), .data(tdb), .ov());
    `include "tilebase.vh"
    function [11:0] taddr(input [3:0] g, input [9:0] x, input [9:0] y);
        taddr = rbase(g) + rowx20(y[8:5]) + x[9:5];
    endfunction
    function bpass(input [3:0] t);           // พื้น / แผ่น / แผ่น Simon; รั้วผ่านได้ถ้าไม่ใช่บอส 2
        bpass = (t == 4'h1) || (t == 4'h7) || (t >= 4'hB) || (t == 4'h6 && !p_fence);
    endfunction

    // ---------- state ----------
    reg [3:0]  fl = 0;                       // เฟรมกะพริบ
    reg [8:0]  stn = 0;                      // STUN + COOLDOWN นับถอยหลัง (> COOLDOWN = กำลังมึน)
    reg [6:0]  ftmr = 0;
    // W43 second phase: boss 1 / 2 below half HP, boss 3 below a third; the boss flashes once when it starts
    wire [7:0] hp2 = {hp, 1'b0}, hp3 = {1'b0, hp, 1'b0} + {3'b000, hp};
    wire rage = act && ((kind == 2'd2) ? (hp3 <= {3'b000, p_hp}) : (hp2 <= {3'b000, p_hp}));
    assign rage_hp = rage;
    reg  rage_d = 1'b0;
    wire [6:0] fire_per = rage ? ((kind == 2'd0) ? BOSS1_FIRE_RAGE : (kind == 2'd1) ? BOSS2_FIRE_RAGE : BOSS3_FIRE_RAGE) : p_fire;
    reg [1:0]  ecnt = 0;
    reg        sx = 1'b0, sy = 1'b0;         // ทิศเด้ง: 1 = ลบ
    reg        clap_req = 1'b0, spawn_req = 1'b0;
    reg [9:0]  nx = 0, ny = 0;
    reg        okab = 1'b0;
    reg [7:0]  fcnt = 0;
    assign flash   = (fl != 0) && fl[1];
    assign stunned = (stn > STUN_COOLDOWN);
    assign anim = fcnt[4];
    // บอส 2: 0 รอ summon แรก, 1 ลูกน้องยังอยู่ (ตีไม่ได้), 2 VULNERABLE (ตีได้) · บอส 3: b3 0 ไล่ (เกราะ), 1 ชาร์จโจมตีใหญ่
    reg [1:0]  bs2 = 0;
    reg        b3 = 1'b0;
    reg [8:0]  phase_t = 0;
    assign shield = act && kind == 2'd1 && bs2 != 2'd2;     // W42: boss 2 is immune (white blink) until every minion is dead
    assign vuln   = act && kind == 2'd1 && bs2 == 2'd2;
    assign tele   = act && kind == 2'd2 && b3;
    reg [1:0]  s3 = 2'd0;                                   // W24: boss 3 after the charge: 0 none, 1 storm, 2 rest (vulnerable)
    reg [5:0]  stf = 0;                                     // storm volley timer
    reg [2:0]  sn = 0;                                      // storm volley number
    wire [8:0] chg_el = BOSS3_CHARGE - phase_t;             // frames charged so far
    assign tele_lvl = (chg_el < BOSS3_CHARGE / 4) ? 2'd0 : (chg_el < BOSS3_CHARGE / 2) ? 2'd1 : (chg_el < BOSS3_CHARGE * 3 / 4) ? 2'd2 : 2'd3;
    assign chg_w    = (act && kind == 2'd2 && b3) ? chg_el[7:1] : 7'd0;
    reg [1:0]  pcnt = 2'd0;                                 // W20: pattern counter, steps with every volley
    assign warn   = act && p_fire != 0 && !stunned && !b3 && s3 == 2'd0 && ftmr < BOSS_WARN;
    // W20 pattern lists (4 volleys, then again): boss 1 fan fan ring fan; boss 2 cross X cross X (spiral look); boss 3 cross X ring fan
    function [1:0] pat_of(input [1:0] k, input [1:0] c);
        case (k)
            2'd0:    pat_of = (c == 2'd2) ? 2'd1 : 2'd3;
            2'd1:    pat_of = c[0] ? 2'd2 : 2'd0;
            default: pat_of = (c == 2'd0) ? 2'd0 : (c == 2'd1) ? 2'd2 : (c == 2'd2) ? 2'd1 : 2'd3;
        endcase
    endfunction
    wire       acc = (kind == 2'd0) || (kind == 2'd1 && bs2 == 2'd2) || (kind == 2'd2 && (dmg_big || s3 == 2'd2));   // W24: boss 3 is open to any hit during its rest; W42: boss 2 only while all its minions are dead
    wire [2:0] amt = (kind == 2'd2) ? 3'd1 : dmg_amt;

    localparam [3:0] B_IDLE = 4'd0, B_DLY = 4'd1, B_X0 = 4'd2, B_X1 = 4'd3, B_X2 = 4'd4,
                     B_Y0 = 4'd5, B_Y1 = 4'd6, B_Y2 = 4'd7, B_END = 4'd8;
    reg [3:0] st = B_IDLE;
    reg [8:0] dly = 0;
    assign busy = (st != B_IDLE);

    // ก้าวที่จะเดินแต่ละแกน (ไล่: ไปหาจุดกลางผู้เล่น ไม่เกิน speed; เด้ง: speed ตามทิศ)
    wire [10:0] bcx = {1'b0, bx} + 11'd32, bcy = {1'b0, by} + 11'd32;
    wire [10:0] pcx = {1'b0, px} + 11'd16, pcy = {1'b0, py} + 11'd16;
    wire [10:0] adx = (pcx > bcx) ? pcx - bcx : bcx - pcx;
    wire [10:0] ady = (pcy > bcy) ? pcy - bcy : bcy - pcy;
    wire [1:0]  stx = p_bounce ? p_speed : (adx >= p_speed) ? p_speed : adx[1:0];
    wire [1:0]  sty = p_bounce ? p_speed : (ady >= p_speed) ? p_speed : ady[1:0];
    wire        negx = p_bounce ? sx : (pcx < bcx);
    wire        negy = p_bounce ? sy : (pcy < bcy);
    wire [3:0]  bgrid = (floor == 2'd1) ? 4'd3 : 4'd2;

    always @(posedge clk) begin
        fire <= 1'b0;
        died <= 1'b0;
        summon <= 1'b0;
        kill <= 1'b0;
        intr <= 1'b0;
        if (room_load) spawn_req <= 1'b1;
        if (clap) clap_req <= 1'b1;

        if (rst || restart) begin
            act <= 1'b0; dead <= 3'b000; st <= B_IDLE; stn <= 0; fl <= 0;
        end else begin
            case (st)
            B_IDLE:
                if (spawn_req) begin
                    spawn_req <= 1'b0;
                    act <= 1'b0;
                    if (room == R_BOSS && grid == bgrid && !dead[floor]) begin
                        act  <= 1'b1;
                        kind <= floor;
                        bx   <= (floor == 2'd1) ? {BOSSB_TX, 5'd0} - 10'd16 : {BOSSA_TX, 5'd0} - 10'd16;
                        by   <= (floor == 2'd1) ? {1'b0, BOSSB_TY, 5'd0} - 10'd16 : {1'b0, BOSSA_TY, 5'd0} - 10'd16;
                        stn <= 0; fl <= 0; ecnt <= 0; sx <= 1'b0; sy <= 1'b1;
                        bs2 <= 2'd0; b3 <= 1'b0; s3 <= 2'd0;
                        phase_t <= (floor == 2'd1) ? BOSS2_FIRST : BOSS3_CHASE;
                        ftmr <= (floor == 2'd0) ? BOSS1_FIRE - 1 : (floor == 2'd1) ? BOSS2_FIRE - 1 : BOSS3_FIRE - 1;   // W20: first volley a full period after entering
                        pcnt <= 2'd0;
                        hp <= (floor == 2'd0) ? BOSS1_HP : (floor == 2'd1) ? BOSS2_HP : BOSS3_HP;
                        hp_bar <= 8'hFF;
                    end
                end else if (frame_tick && run && act) begin
                    dly <= BOSS_DELAY; st <= B_DLY;
                end
            B_DLY: begin
                dly <= dly - 1'b1;
                if (dly <= 1) begin
                    fcnt <= fcnt + 1'b1;
                    rage_d <= rage;
                    if (rage && !rage_d) fl <= 4'd15;                          // W43: the boss flashes once when its second phase starts
                    else if (fl != 0) fl <= fl - 1'b1;
                    // ตบมือ: เฉพาะบอส 1 และไม่อยู่ใน cooldown
                    if (clap_req && p_stun && stn == 0) stn <= STUN_FRAMES + STUN_COOLDOWN;
                    else if (stn != 0) stn <= stn - 1'b1;
                    clap_req <= 1'b0;
                    // บอส 2: summon / รอลูกน้องตาย / VULNERABLE
                    if (kind == 2'd1) begin
                        if (bs2 == 2'd1) begin
                            if (phase_t < 9'd3) phase_t <= phase_t + 1'b1;            // รอให้ objects spawn ลูกน้องเสร็จก่อนเช็ค minions
                            else if (minions == 0) begin bs2 <= 2'd2; phase_t <= rage ? BOSS2_VULN_RAGE : BOSS2_VULN_FRAMES; end
                        end else if (phase_t == 0) begin
                            if (bs2 == 2'd2) begin bs2 <= 2'd0; phase_t <= rage ? BOSS2_REST_RAGE : BOSS2_REST; end    // W42: vulnerable window over -> a breather before the next wave
                            else begin summon <= 1'b1; bs2 <= 2'd1; end
                        end else phase_t <= phase_t - 1'b1;                                   // bs2 0 (first wait / breather) / bs2 2 (vulnerable window)
                    end
                    // บอส 3: ไล่ -> ชาร์จ -> โจมตีใหญ่ (kill) -> ไล่
                    if (kind == 2'd2) begin
                        if (phase_t == 0) begin
                            if (b3) begin b3 <= 1'b0; s3 <= 2'd1; phase_t <= BOSS3_STORM; stf <= 0; sn <= 0; end     // W24: charge done -> storm (no instant kill)
                            else if (s3 == 2'd1) begin s3 <= 2'd2; phase_t <= rage ? BOSS3_REST_RAGE : BOSS3_REST; end                       // storm done -> rest
                            else if (s3 == 2'd2) begin s3 <= 2'd0; phase_t <= rage ? BOSS3_CHASE_RAGE : BOSS3_CHASE; end                      // rest done -> chase again
                            else begin b3 <= 1'b1; phase_t <= BOSS3_CHARGE; end
                        end else phase_t <= phase_t - 1'b1;
                        // W24 storm volleys: cross, X, ring, X, cross ... every BOSS3_STORM_PERIOD frames, heavy bullets
                        if (s3 == 2'd1) begin
                            if (stf == 0) begin
                                fire <= 1'b1; fire_heavy <= 1'b1; fire_pat <= (sn == 3'd2) ? 2'd1 : sn[0] ? 2'd2 : 2'd0;
                                sn <= sn + 1'b1; stf <= (rage ? BOSS3_STORM_PERIOD_RAGE : BOSS3_STORM_PERIOD) - 1;
                            end else stf <= stf - 1'b1;
                        end
                    end
                    if (stunned || (kind == 2'd2 && (b3 || s3 != 2'd0))) st <= B_END;
                    else begin
                        // ยิง
                        if (p_fire != 0) begin
                            if (ftmr == 0) begin fire <= 1'b1; fire_heavy <= 1'b0; fire_pat <= pat_of(kind, pcnt); pcnt <= pcnt + 1'b1; ftmr <= fire_per - 1; end
                            else ftmr <= ftmr - 1'b1;
                        end
                        // เดินทุก every เฟรม
                        if (ecnt >= ((rage && kind == 2'd0) ? 0 : p_every - 1)) begin ecnt <= 0; st <= B_X0; end                       // W43: boss 1 walks twice as fast in its second phase
                        else begin ecnt <= ecnt + 1'b1; st <= B_END; end
                    end
                end
            end
            // ---------- แกน x: 3 จุดบนขอบ ----------
            B_X0: if (stx == 0) st <= B_Y0;
                  else begin
                      nx <= negx ? bx - stx : bx + stx;
                      ta <= taddr(grid, negx ? bx - stx + 10'd8 : bx + stx + 10'd55, by + 10'd8);
                      tb <= taddr(grid, negx ? bx - stx + 10'd8 : bx + stx + 10'd55, by + 10'd55);
                      st <= B_X1;
                  end
            B_X1: begin
                okab <= bpass(tda) && bpass(tdb);
                ta <= taddr(grid, negx ? nx + 10'd8 : nx + 10'd55, by + 10'd31);
                st <= B_X2;
            end
            B_X2: begin
                if (okab && bpass(tda)) bx <= nx;
                else if (p_bounce) sx <= ~sx;                       // เด้งกลับ
                st <= B_Y0;
            end
            // ---------- แกน y ----------
            B_Y0: if (sty == 0) st <= B_END;
                  else begin
                      ny <= negy ? by - sty : by + sty;
                      ta <= taddr(grid, bx + 10'd8,  negy ? by - sty + 10'd8 : by + sty + 10'd55);
                      tb <= taddr(grid, bx + 10'd55, negy ? by - sty + 10'd8 : by + sty + 10'd55);
                      st <= B_Y1;
                  end
            B_Y1: begin
                okab <= bpass(tda) && bpass(tdb);
                ta <= taddr(grid, bx + 10'd31, negy ? ny + 10'd8 : ny + 10'd55);
                st <= B_Y2;
            end
            B_Y2: begin
                if (okab && bpass(tda)) by <= ny;
                else if (p_bounce) sy <= ~sy;
                st <= B_END;
            end
            B_END: begin
                // HP bar 8 ดวง: ดวง k ติดถ้า hp*8 > k*maxHP
                hp_bar[0] <= (hp * 8 > 0 * p_hp);
                hp_bar[1] <= (hp * 8 > 1 * p_hp);
                hp_bar[2] <= (hp * 8 > 2 * p_hp);
                hp_bar[3] <= (hp * 8 > 3 * p_hp);
                hp_bar[4] <= (hp * 8 > 4 * p_hp);
                hp_bar[5] <= (hp * 8 > 5 * p_hp);
                hp_bar[6] <= (hp * 8 > 6 * p_hp);
                hp_bar[7] <= (hp * 8 > 7 * p_hp);
                st <= B_IDLE;
            end
            default: st <= B_IDLE;
            endcase

            // ---------- โดนตี (มาได้ทุก clock จาก objects.v) ----------
            if (dmg && act && acc) begin
                fl <= BOSS_FLASH;
                if (kind == 2'd2 && b3) begin b3 <= 1'b0; phase_t <= BOSS3_CHASE; intr <= 1'b1; end   // ชาร์จขัด: เริ่มรอบใหม่
                if (hp <= amt) begin
                    hp <= 0; act <= 1'b0; dead[kind] <= 1'b1; died <= 1'b1; hp_bar <= 0;
                end else hp <= hp - amt;
            end
        end
    end
endmodule
