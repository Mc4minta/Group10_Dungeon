`timescale 1ns/1ps
// player_frame: which animation picture is chosen for idle / walk / attack / hurt / death, per form.
// Compiled with sim/anim_on/sprite_cfg.vh first in the include path (all flags ON, IDLE_STEP 2, HURT_STEP 4, DEATH_STEP 3).
// Run: ./scripts/run_sim.sh playerframe
module tb_player_frame;
    reg clk = 0; always #5 clk = ~clk;
    reg rst = 1, tick = 0;
    reg [1:0] form = 0, facing = 0, mdir = 0;
    reg moving = 0, melee_on = 0, invuln = 0, dead = 0, active = 1, shoot = 0;
    wire [2:0] sel; wire [5:0] af; wire flash;
    player_frame dut(.clk(clk), .rst(rst), .frame_tick(tick), .form(form), .facing(facing), .melee_dir(mdir),
                     .moving(moving), .melee_on(melee_on), .invuln(invuln), .dead(dead), .active(active), .shoot(shoot),
                     .anim_sel(sel), .aframe(af), .hurt_flash(flash));
    integer errors = 0;
    task frames(input integer k); integer q; begin
        for (q = 0; q < k; q = q + 1) begin @(posedge clk) tick <= 1; @(posedge clk) tick <= 0; repeat (2) @(posedge clk); end
    end endtask
    task chk(input cond, input [8*40-1:0] msg); begin
        if (!cond) begin $display("FAIL %0s  (sel=%0d aframe=%0d)", msg, sel, af); errors = errors + 1; end
        else $display("PASS %0s", msg);
    end endtask
    initial begin
        repeat (4) @(posedge clk); rst <= 0; repeat (2) @(posedge clk);
        // ---- idle loop (human, standing): picture k advances every IDLE_STEP = 2 frames, per facing
        facing = 2'd2; #1;
        chk(sel == 3'd1 && af == {2'd2, 4'd0}, "idle: starts at picture 0, left");
        frames(2); chk(sel == 3'd1 && af == {2'd2, 4'd1}, "idle: picture 1 after 2 frames");
        frames(2); chk(sel == 3'd1 && af == {2'd2, 4'd2}, "idle: picture 2 after 4 frames");
        frames(28); chk(sel == 3'd1 && af == {2'd2, 4'd0}, "idle: loop wraps after 16 pictures");
        facing = 2'd3; #1; chk(af[5:4] == 2'd3, "idle: follows the facing direction");
        // ---- walking uses the normal pictures and restarts the idle loop
        moving = 1; frames(1); chk(sel == 3'd0, "moving: normal walking picture");
        moving = 0; frames(1); chk(sel == 3'd1 && af[3:0] == 4'd0, "stopped again: idle restarts at 0");
        // ---- attack: 4 pictures over 8 melee frames, in melee_dir
        mdir = 2'd1; melee_on = 1; frames(1);
        chk(sel == 3'd2 && af == {2'b00, 2'd1, 2'd0}, "attack: first picture, up");
        frames(2); chk(sel == 3'd2 && af[1:0] == 2'd1, "attack: picture 1");
        frames(2); chk(sel == 3'd2 && af[1:0] == 2'd2, "attack: picture 2");
        frames(2); chk(sel == 3'd2 && af[1:0] == 2'd3, "attack: picture 3");
        melee_on = 0; frames(1); chk(sel == 3'd1, "attack over: back to idle loop");
        // ---- hurt: 4 pictures x HURT_STEP 4 = 16 frames, then normal; wins over attack
        facing = 2'd0; invuln = 1; melee_on = 1; frames(1);
        chk(sel == 3'd3 && af == {2'd0, 2'd0}, "hurt: first picture, beats attack");
        frames(4); chk(sel == 3'd3 && af[1:0] == 2'd1, "hurt: picture 1 after 4 frames");
        frames(8); chk(sel == 3'd3 && af[1:0] == 2'd3, "hurt: picture 3");
        frames(6); chk(sel == 3'd2 || sel == 3'd0, "hurt shown only 16 frames, then attack/normal");
        melee_on = 0; frames(2); chk(sel == 3'd0, "blink phase: normal picture while invulnerable");
        invuln = 0; frames(1);
        // ---- death: DEATH_STEP 3 frames per picture, last (11) is held, beats everything
        dead = 1; invuln = 1; melee_on = 1; frames(1);
        chk(sel == 3'd4 && af == 6'd0, "death: first picture, beats hurt/attack");
        frames(3); chk(sel == 3'd4 && af == 6'd1, "death: picture 1 after 3 frames");
        frames(40); chk(sel == 3'd4 && af == 6'd11, "death: last picture held");
        frames(30); chk(sel == 3'd4 && af == 6'd11, "death: still held");
        dead = 0; invuln = 0; melee_on = 0; frames(2); chk(sel == 3'd1, "after death state: idle again");
        // ---- other forms and the title screen never use the human animations
        form = 2'd1; frames(1); chk(sel == 3'd0, "form 2: normal picture while standing");
        form = 2'd2; dead = 1; frames(1); chk(sel == 3'd0, "form 3: no death animation");
        dead = 0; form = 2'd3; melee_on = 1; frames(1); chk(sel == 3'd0, "form 4: no attack animation");
        melee_on = 0; frames(2);
        // ---- W14: forms 2 (Orc) and 3 (Angel): attack pictures when they shoot (SHOT_STEP = 2 frames per picture), address {form, dir, k}
        form = 2'd1; facing = 2'd3; frames(3);
        @(posedge clk) shoot <= 1; @(posedge clk) shoot <= 0; frames(1);
        chk(sel == 3'd2 && af == {2'd1, 2'd3, 2'd0}, "Orc shot: attack picture 0 (form 1, facing right)");
        facing = 2'd0; frames(2); chk(sel == 3'd2 && af == {2'd1, 2'd3, 2'd1}, "Orc shot: picture 1, direction kept from the shot");
        frames(2); chk(sel == 3'd2 && af[1:0] == 2'd2, "Orc shot: picture 2");
        frames(2); chk(sel == 3'd2 && af[1:0] == 2'd3, "Orc shot: picture 3");
        frames(2); chk(sel == 3'd0, "Orc shot over: normal picture again");
        form = 2'd2; facing = 2'd1; frames(2);
        @(posedge clk) shoot <= 1; @(posedge clk) shoot <= 0; frames(1);
        chk(sel == 3'd2 && af == {2'd2, 2'd1, 2'd0}, "Angel shot: attack picture 0 (form 2, facing up)");
        frames(8); chk(sel == 3'd0, "Angel shot over after 4 pictures x 2 frames");
        mdir = 2'd2; melee_on = 1; frames(1);
        chk(sel == 3'd2 && af == {2'd2, 2'd2, 2'd0}, "Angel melee swing: attack pictures too, in melee_dir");
        melee_on = 0; frames(10);
        form = 2'd3; @(posedge clk) shoot <= 1; @(posedge clk) shoot <= 0; frames(2); chk(sel == 3'd0, "form 4: a shot shows no attack animation");
        form = 2'd1; active = 0; @(posedge clk) shoot <= 1; @(posedge clk) shoot <= 0; frames(2); chk(sel == 3'd0, "title screen: no attack animation");
        active = 1; frames(10);
        // ---- W14: red hurt flash (all forms, FLASH_FRAMES = 5), no ROM
        form = 2'd0; invuln = 0; frames(1); chk(!flash, "no flash when not hit");
        form = 2'd3; invuln = 1; frames(1); chk(flash, "hit: red flash starts (form 4 too)");
        frames(3); chk(flash, "flash still on after 4 frames");
        frames(3); chk(!flash, "flash ends after FLASH_FRAMES while still invulnerable");
        invuln = 0; frames(1); chk(!flash, "flash off");
        form = 2'd0; melee_on = 0; active = 0; frames(1); chk(sel == 3'd0, "title screen: normal picture");
        $display("checks done  errors = %0d", errors);
        if (errors == 0) $display("ALL PASS");
        $finish;
    end
endmodule
