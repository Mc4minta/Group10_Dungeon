# Gameplay and story review (20/11) - for the owner to read before the "implement all" step

Goal from the owner: (1) the player always knows what to do, (2) the story must not interrupt play: while a story box is on, the game stops listening to the player
(except pause), (3) play stays smooth, (4) edge cases reviewed. This file lists what I found in the code (`rtl/dialog.v`, `rtl/top.v`, `docs/STORY.md`) and what I propose.
**Status 20/11: the owner approved everything, W31 / W32 / W33 / W34 and the W28 / W29 designs are implemented on `dev` (see the DONE notes in `docs/DESIGN_PLAN.md`; deviations: the controls list is 5 two-line pages and the credits 3 pages, the enemy count is not shown in the objective). Not tested on the board.**

## 1. How the story works today
* 50 story boxes (`docs/STORY.md`, tier B): **12 are blocking** (the safe-room intro F1-01 .. F1-12: the game is frozen until BTNC), **38 are timed** (2.5 s, `DLG_FRAMES` = 150).
* A blocking box freezes everything (`ft` = frame tick is gated: hero, monsters, bullets, boss, timers) and the attack press only advances the box.
* A timed box **does not stop the game**: a black band (64 px) is drawn over the bottom of the screen for 2.5 s while hero, monsters and bullets keep moving.

## 2. Findings

| # | Finding | Why it matters | Proposal (PROPOSED = I implement it after your OK) |
|---|---|---|---|
| 1 | 38 of 50 boxes keep the game running under the black band | the band hides the bottom rows (hero, enemies, bullets); room-entry boxes (`lock_*`, `enter_*boss`), `IT IS CHARGING! INTERRUPT IT OR DIE!` and `MINIONS ALL DEAD! A NEW WAVE COMES!` appear in the middle of a fight; you can be hit while reading | **W31**: every story box freezes the game and ignores the player (move, attack, sprint, auto-aim, clap) except pause. Timed boxes close on a BTNC / Space / Enter press or after 2.5 s of frozen time, whichever comes first. Blocking boxes (the intro) wait for the press |
| 2 | The button that closes a box is still held on the next frame: `atk_hold` is not gated by the box | forms 2-4 shoot at once when the box closes, form 4 starts charging by accident, form 1 swings | **W31**: after a box closes the attack input stays ignored until the button has been released once |
| 3 | A clap (mic / SW11 / key C) during a box is remembered and stuns the boss the moment the box closes | feels like a random stun | **W31**: clap pulses are dropped while a box is open |
| 4 | Several boxes waiting at once are shown in list order (ID order), not in the order they happened | a late hint can show before the event that caused it (e.g. a clear message before the lock message) | **W31**: show in arrival order (small FIFO of 8, same ROM) |
| 5 | The intro is 12 blocking boxes at the start of every game, also after GAME OVER | tiring on the second try | **W33**: after the first game of a power-on the intro is replaced by one box (`FIGHT. SOLVE. WIN.`); holding BTNC for 1.5 s on any intro box skips the rest |
| 6 | A box gives no sign of how to close it | the player may think the game hangs | **W31**: a small blinking `BTNC` / `SPACE` hint at the right end of the box (second text line stays free) and the same rule on the PAUSED screen: `PAUSED  P OR SW15 TO GO ON` |
| 7 | The player is never told what to do next after a room is cleared or in a new room | "make sure the user knows what to do" | **W32 objective strip** (below) |
| 8 | Controls are not taught | keyboard and buttons both exist now | **W28** tutorial hints (below), **W29** controls page on the title |
| 9 | Keyboard: if the keyboard is unplugged while a key is down the key stays down | the hero walks by itself until RESET | **W34**: clear all keys when the PS/2 clock has been idle for 2 s AND a key is flagged down (a keyboard repeats a held key every 30-100 ms, so a long silence = released or unplugged) |
| 10 | Keyboard and button together: UP + DOWN (or LEFT + RIGHT) from two sources | `player.v` priority is undefined for me to confirm | **W34**: opposite directions cancel (stand still); to be checked in `player.v` first |
| 11 | P / Esc toggles pause but SW15 is a level: SW15 down + P pressed = still paused after releasing SW15 | confusing | **W34**: the pause is `SW15 xor key-toggle`; the PAUSED text explains how to go on |
| 12 | Messages are queued while EVOLVE / FLOOR CLEAR / GAME OVER run | fine: they wait for PLAY (already correct); a pending box when GAME OVER starts is dropped on restart (correct) | no change, checked |
| 13 | Boxes while paused | hidden and waiting (correct) | no change, checked |
| 14 | Maze (ESCAPE): the 60 s countdown stops while a box is open | fair; the maze banner box is short | no change, checked |
| 15 | Music and sound keep playing during a box | good | no change |
| 16 | The play timer on the 7-seg stops during boxes | fair | no change |

## 3. Never freeze the tutorial: two kinds of text
* **Story boxes** (narrative, `docs/STORY.md`): freeze the game (finding 1).
* **Hint strip** (new, W32): a small 2-line box in the top centre (between the hearts and the boss bar, about 17 characters wide at 2x) that **never freezes** the game and never covers the playfield. It carries (a) the **tutorial** prompts that wait for an action (W28: move, attack, sprint, pause, auto-aim, clap) and (b) the **objective**:
  * combat room locked: `DEFEAT ALL` / `ENEMIES n LEFT`
  * combat room cleared: `DOORS OPEN` / `GO ON`
  * puzzle room: `LIGHT ALL BULBS` / `SOLVE THE ROOM` (per floor: `PUSH THE BOXES` / `ON THE PLATES`, `REPEAT THE` / `PATTERN`)
  * boss room: `DEFEAT THE BOSS` (floor 1 adds `CLAP TO STUN`, floor 3 `CHARGE SHOT`)
  * boss dead: `TAKE THE DOOR` / `ONWARD`
  * key dropped: `GO BACK TO START` / `THE GATE WAITS`
  Rules: the objective is always visible while nothing else is on the strip; a tutorial prompt replaces it until its action is done, then the objective returns. The strip is off during dialogue boxes, the title, the prologue and GAME OVER.

## 4. Smoothness checks I will add as tests when implementing
* A box opens at room load: the hero does not move, no bullet advances, no timer runs; the box closes on one press and the same press does not attack.
* Holding the attack button through a box: no shot after it closes until the button was released once.
* A clap during a box is dropped.
* Two boxes pending: shown in arrival order; a blocking intro box is not skipped by a timed one.
* Pause during a box: the box hides, nothing runs; unpause: the box returns.
* GAME OVER with a box open: restart clears it.
* The hint strip never covers pixels of the playfield tiles (render test).

## 5. What I need from you
Reply with one of: **approved** (implement W31, W32, W33, W34 and the W28 / W29 designs as written), or edit the table (strike a row, change a number, change a text). Open choices, my defaults in bold:
1. Timed box auto-close: **2.5 s of frozen time** or press (alternative: 2 s).
2. Intro after GAME OVER: **one short box + skip by holding BTNC** (alternative: always the full 12 boxes).
3. Hint strip position: **top centre** (alternative: bottom centre over a thin 24 px band, which does cover a little of the room).
