# THE CHOSEN ONE - controls guide (board and keyboard)

Everything works with the **Nexys A7 board** (buttons and switches), with a **USB keyboard** plugged into the USB-HID port, or with both at the same time.
Plug the keyboard in before or after power-on (the board needs about 1 s to detect it). Use a plain wired USB keyboard.

## 1. Walking and fighting

| Action | Board | Keyboard |
|---|---|---|
| Walk (two together = diagonal) | **BTNU / BTND / BTNL / BTNR** (up / down / left / right) | **Arrow keys** or **W A S D** |
| Attack / start the game / close a story box | **BTNC** (centre button) | **Space**, **J** or **Enter** |
| Sprint (+1 pixel per frame) | **SW14** up (hold it while walking) | **Shift** (left or right) |
| Pause / resume | **SW15** up = paused, down = running | **P** or **Esc** (press again to go on); with SW15 up, P resumes |
| Auto aim (**ON by default**): turn it off / on again | **SW9** up = OFF (down = ON) | **L** (press to toggle) |
| Lock the facing direction (step back while swinging) | **SW12** up | (a tap of the attack key also keeps the facing for 0.4 s) |
| Show the hit boxes (green hero, red monsters, orange boss, yellow bullets) | **SW8** up | **H** (press to toggle) |
| Reset the Sokoban boxes (floor 2 puzzle room) | **SW13** up (flick) | **R** |
| Clap fallback (stun boss 1 without clapping) | **SW11** up (flick) | **C** |

* Walking up and down (or left and right) at the same time cancels: the hero stands still.
* A keyboard key that stays "stuck" after you unplug the keyboard clears itself after 2 seconds.

## 2. What the attack button does (it depends on your form)

| Form | Attack |
|---|---|
| 1 Human | melee swing in front of you (also pulls levers). Hit it again after a short cool-down |
| 2 Orc | fires a shot in the direction you face; hold the button to keep firing |
| 3 Angel | fires 3 shots in a spread; a shot that hits an enemy splits into 4 more |
| 4 Gold hero | tap = fast shot; **hold about 0.75 s** and release = a big ball (a growing ball appears in front of you while you hold; it is full size when you can let go). The big ball stops at the first enemy it hits and is the only thing that hurts boss 3 |

* **Auto aim (on by default; SW9 up or L turns it off):** the shot flies at the nearest enemy within about 240 pixels at a free angle (form 3's spread stays in 8 directions), and a blinking **yellow / red corner marker** shows which enemy you are aiming at. The marker stays on the same enemy until it dies or is far away.
* You evolve to the next form each time you solve the puzzle room of a floor.

## 3. Story boxes and hints

* A **story box** (black band at the bottom) **freezes the whole game**. Press **BTNC / Space / Enter** to close it (a blinking arrow on the right of the box reminds you). A timed box also closes by itself after 2.5 seconds. **Hold the button for 1.5 seconds** to fast-forward through boxes. After a box closes, release the attack button once before you can attack again.
* The first game after power-on tells the whole intro; later games only show one short box.
* The **hint strip** (small box at the top centre) never stops the game. It tells you the goal of the room: *defeat all enemies*, *doors open*, the puzzle goal, *defeat the boss*, *take the door*, *go back to the start*. In the first room it also teaches the controls one by one: move, attack, sprint, pause, auto aim.

## 3b. After GAME OVER

**BTNC / Space / Enter = retry the floor you died on** (full hearts, the form of that floor), **BTNL / left arrow = back to the title**. Winning the game returns to the title with BTNC.

## 4. Title screen

| Action | Board | Keyboard |
|---|---|---|
| Next page (SETTINGS, CONTROLS 1-5, CREDITS 1-8, back to the title) | **BTNR** | **Right arrow** or **D** |
| Previous page | **BTNL** | **Left arrow** or **A** |
| Clap level (SETTINGS page): louder clap needed | **BTNU** | **Up arrow** or **W** |
| Clap level: quieter clap is enough | **BTND** | **Down arrow** or **S** |
| Start the game (from any page) | **BTNC** | **Space** or **Enter** |

## 5. The clap boss (floor 1) and the clap meter

* Boss 1 is stunned for 3 seconds by a **clap** near the board (then 4 seconds before it can be stunned again). If the microphone does not work, flick **SW11** or press **C**.
* A **meter** under the boss health bar shows the microphone: a **black bar** with a **green level** (the current sound) and a **red vertical line** (the trigger level). When the green reaches the red line the clap is registered and the green flashes white.
* You can set the red line **higher or lower** in the SETTINGS page of the title screen (five steps from VERY LOW to VERY HIGH) and test it there with live claps. For tuning on the board **SW5 to SW7** also set it (0 = use the setting; otherwise 128 x the number the three switches show).

## 6. Boss fights in short

| Boss | What to do |
|---|---|
| 1 (floor 1, fast chaser with a fan / ring of bullets) | clap to stun it, then hit it. It blinks before each volley |
| 2 (floor 2, priest in a fence, summons minions) | hit it at any time; split shots (form 3) clear minions. Hide behind the pillars from its cross and X bullets |
| 3 (floor 3, armoured, 9 HP: 9 hits) | only charged shots (form 4) hurt it (1 HP each). While it charges (bar under its health bar, blink gets faster and changes colour) hit it with a charged shot to interrupt. At 100 % it fires a storm of heavy bullets (2 hearts each): move between the gaps, then it rests for 2 seconds (any hit hurts it) |

## 7. Rooms and puzzles in short

* **Combat room:** the doors close (spikes up) until every monster is dead. Crates can be shot or cut open. Pits can only be crossed on the bridges (or by form 3).
* **Spikes:** floor 2 spikes (timed) go flat, then half up (warning), then up (2 hearts); floor 3 spikes are always up (1 heart). Form 3 flies over them.
* **Floor 1 puzzle (light bulbs):** pull the levers (hit them) until all four bulbs are lit.
* **Floor 2 puzzle (Sokoban):** push both boxes onto the two plates; **SW13 / R** resets the boxes.
* **Floor 3 puzzle (Simon):** watch the colour pattern, then walk onto the same plates in order.
* **Floor 3 boss drops a key:** go back to the start room of floor 3 and walk into the maze door.
* **Ball in a Maze:** tilt the board to roll the ball to the goal in 60 seconds (or hold **SW10** to use the four buttons / arrow keys instead of the tilt).

## 8. Board indicators

| Item | Meaning |
|---|---|
| 7-segment display | floor - hearts - time (mm.ss) |
| LED 0-3 | direction buttons (in the puzzle rooms: bulbs / rounds), LED 4-7 monsters left, LED 8-11 hearts, LED 12 doors locked, LED 13 floor item taken, LED 14 sprint, LED 15 win |
| RGB LED 16 | colour of your form |
| RGB LED 17 | red = just hit; blue flickers when the keyboard clock moves, green flickers when a key code was decoded (keyboard check) |
| SW0 to SW4 | debug switches (open doors, skip floor, clear room, evolve, lose a heart): only when `DEBUG = 1` in `rtl/top.v`. **The file's default is 1**; the hand-in build must be built with `DEBUG = 0` |
| CPU RESET | restarts everything (also resets the clap level and the intro) |

## 9. Quick card

```
WALK     BTNU/D/L/R      ARROWS or WASD
ATTACK   BTNC            SPACE / J / ENTER   (also: start, close a box)
SPRINT   SW14            SHIFT
PAUSE    SW15            P or ESC
AUTO AIM on by default; SW9 up = OFF   L = toggle
BOXES    SW13            R        (Sokoban reset)
CLAP     clap or SW11    C
MAZE     tilt or SW10    arrows
TITLE    BTNR / BTNL = pages     BTNU / BTND = clap level (SETTINGS page)
```
