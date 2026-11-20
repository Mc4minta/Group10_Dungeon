# Game Story + In-Game Text — THE CHOSEN ONE

Nov 20, 2026 · @min · อนุมัติเรื่องและบทพูดทุกบรรทัดแล้ว

> **ไฟล์นี้คือ source of truth ของเรื่องและข้อความบนจอทั้งหมด** — แก้ข้อความ (คอลัมน์ บรรทัด 1 / บรรทัด 2 / ผู้พูด / Trigger) ในตารางด้านล่าง แล้วรัน
> `python scripts/build_story.py` (หรือ `scripts/update_sprites.sh` / `scripts/check_all.sh`) ระบบจะสร้าง `mem/text.mem`, `mem/dlg.mem`, `rtl/text_layout.vh`,
> `rtl/text_select.vh`, `rtl/dlg_cfg.vh` ใหม่ทั้งหมดจากไฟล์นี้ ห้ามแก้ไฟล์ที่ generate ด้วยมือ. สคริปต์ตรวจให้: อักขระที่ใช้ได้ ความยาวบรรทัด ID ซ้ำ trigger ที่ไม่รู้จัก.
> เสร็จแล้ว build โปรเจกต์ Vivado ใหม่ (`docs/BOARD_TEST_STEPS.md`).

## กติกาการแก้ข้อความ

* อักขระที่ใช้ได้: `A-Z 0-9` เว้นวรรค และ `- : ! .` เท่านั้น (ฟอนต์ 8x8 ไม่มีตัวพิมพ์เล็ก ไม่มี `,` `?` `'` ภาษาไทย)
* ไม่เกิน **20 ตัวอักษรต่อบรรทัด**, ไม่เกิน 2 บรรทัดต่อข้อความ (บรรทัด 2 เว้นว่างได้)
* ID ต้องไม่ซ้ำ. เพิ่มแถวใหม่ได้ (ใส่ Trigger ให้ครบ) · ลบแถว = ข้อความนั้นไม่แสดง
* จำนวนข้อความ dialogue สูงสุด 128 ข้อความ, ตัวอักษรรวมสูงสุด 3,500 ตัว (สคริปต์เตือนถ้าเกิน)
* ชื่อผู้พูด: `Player` (ขาว) · `Voice` (เหลือง) · `System` (ฟ้า) — กำหนดสีตัวอักษรของกล่อง dialogue

### รหัส Trigger (คอลัมน์ Trigger)

| รูปแบบ | ความหมาย |
| --- | --- |
| `screen:<ชื่อ>` | หน้าจอเต็ม (ไม่ใช่กล่อง dialogue): `title`, `prologue1`-`prologue4`, `evolve2`, `evolve3`, `evolve4`, `floorclear`, `maze`, `win`, `timeout`, `gameover` |
| `<event>` | แสดงเป็นกล่อง dialogue ที่ด้านล่างจอ ~2.5 วิ แล้วหายเอง (เกมเดินต่อ) · แสดงครั้งเดียวต่อเกมใหม่ |
| `<event>!` | เหมือนกัน แต่ **หยุดเกม** จนกด BTNC (ใช้กับบทสนทนา) |
| `after:<ID>` / `after:<ID>!` | แสดงต่อจากข้อความ `<ID>` ที่แสดงจบแล้ว |
| `none` | ยังไม่ผูกกับเหตุการณ์ (ไม่แสดง) |

เหตุการณ์ (event) ที่มีในเกม:
`start` เริ่มเกม · `first_attack` กดโจมตีครั้งแรก · `lock_f1c1` `lock_f1c2` `lock_f2c1` `lock_f2c2` `lock_f3c1` `lock_f3c2` เข้าห้องต่อสู้ (ประตูล็อก, มอนยังอยู่) ·
`clear_f1c1` `clear_f1c2` `clear_f2c2` `clear_f3c2` ห้องต่อสู้เคลียร์ · `enter_f2c1` เข้าห้องต่อสู้ 1 ชั้น 2 ทุกครั้งแรก ·
`enter_f1puz` `enter_f2puz` `enter_f3puz` เข้าห้อง puzzle · `item_f1` `item_f2` `item_f3` puzzle แก้ได้ ไอเทมปรากฏ · `got_f1` เก็บไอเทมชั้น 1 ·
`evolved_f1` `evolved_f2` `evolved_f3` แปลงร่างเสร็จ (กลับมาเล่น) · `enter_f1boss` `enter_f2boss` `enter_f3boss` เข้าห้องบอส ·
`vuln_f2` บอส 2 เข้าช่วงตีได้ · `charge_f3` บอส 3 เริ่มชาร์จโจมตีใหญ่ (ครั้งแรก) · `interrupt_f3` ชาร์จบอส 3 ถูกขัด ·
`bossdead_f1` `bossdead_f2` บอส 1 / 2 ตาย · `key_drop` บอส 3 ตาย กุญแจตก · `enter_f2start` `enter_f3start` เข้าห้อง START ชั้น 2 / 3 ·
`enter_f3start_key` กลับถึง START ชั้น 3 พร้อมกุญแจ · `maze_banner_end` ป้ายเริ่มเขาวงกตจบ

## เรื่องย่อเกม

ผู้เล่นคือนักศึกษาที่เผลอหลับตอนปั่นงานก่อน deadline แล้วตื่นขึ้นมาในดันเจี้ยนปริศนา เสียงลึกลับบอกว่าจะส่งกลับบ้านได้ ถ้าผ่านครบ 3 ชั้น แต่ละชั้นมีห้องต่อสู้ 2 ห้อง ห้อง puzzle และบอส เมื่อแก้ puzzle ได้ ดันเจี้ยนจะมอบพลังให้แปลงร่างใหม่ และแต่ละร่างคือกุญแจในการสยบบอส: บอส 1 วิ่งเร็ว ต้องปรบมือให้ติด stun, บอส 2 เรียกลูกน้องมาเป็นระลอก ตีบอสได้ตลอด (W17) แต่ลูกน้องคอยขวาง จึงควรกำจัดด้วยกระสุน AOE, บอส 3 สวมเกราะ ต้องยิงชาร์จเท่านั้น บอสสุดท้ายดรอปกุญแจ ผู้เล่นต้องเดินไปเก็บกุญแจ กลับไปไขประตูที่จุดเริ่มต้น และผ่านเขาวงกตที่ควบคุมด้วยการเอียงบอร์ดให้ทันเวลา ผ่านก็ได้กลับบ้าน หมดเวลาก็ติดอยู่ที่นี่ตลอดไป

## โครงเกมและกลไก

ทุกชั้นเล่นเรียงกัน: ห้องต่อสู้ 2 ห้อง → ห้อง puzzle → ไอเทมแปลงร่าง และเปิดประตูบอส → ห้องบอส ผู้เล่นเริ่มที่ Form 1 (Human, ตีใกล้) ตายเมื่อไรก็ GAME OVER

| ชั้น | Puzzle | ร่างที่ได้ | บอส | กลไกบอส / วิธีชนะ |
| --- | --- | --- | --- | --- |
| 1 | Light Bulb | Form 2: Orc (ยิงธรรมดา) | Boss 1 (HP 10) | วิ่งเร็วมาก รับดาเมจตลอด ปรบมือ (ไมค์ หรือ SW11 สำรอง) ให้ stun 3 วิ (cooldown 4 วิ) แล้วตามตี |
| 2 | Sokoban (pressure plate) | Form 3: Angel (ยิง AOE กระสุนแตก 4 ทิศเมื่อโดนมอน) | Boss 2 (HP 16) | เรียกลูกน้อง 3 ตัวต่อรอบ **บอสตีได้ตลอด (W17)**; ลูกน้องตายหมดแล้วรอ 2 วิ ก็ summon รอบใหม่ |
| 3 | Simon Says | Form 4: ชาร์จยิงกระสุนใหญ่ (หยุดเมื่อโดน) | Boss 3 (HP 3 charged hit) | เกราะ รับดาเมจเฉพาะ charged shot ชาร์จโจมตีใหญ่ 2 วิ ถ้าชาร์จครบ lethal ทั้งห้อง ต้องยิงชาร์จขัดก่อน |
| จบเกม | Ball in a Maze |  |  | บอส 3 ดรอปกุญแจ (เห็นบนพื้น เดินไปเก็บ) → ไขประตู START ชั้น 3 → เอียงบอร์ดกลิ้งลูกบอลใน 60 วิ → WIN (หมดเวลา = GAME OVER) |

ตัวเลขอิง `docs/DESIGN_PLAN.md` (หัวข้อ 6 และ W10–W12) ปรับได้ที่ `rtl/params.vh`

## ข้อความในเกม

### Title (หน้าแรก)

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| TITLE-01 | A | screen:title | หน้า TITLE (บรรทัด 2 กะพริบ) | System | THE CHOSEN ONE | BTNC PLAY  BTNR HELP |

### Prologue

จอดำ ตัวอักษรขาวกลางจอ แสดงทีละจอ (กด BTNC ข้าม หรือรอ 6 วิ) จบแล้วเข้า Safe Room (ชั้น 1)

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| PRO-01 | A | screen:prologue1 | จอดำ จอแรก | System | ROME WASNT BUILT | IN A DAY. |
| PRO-02 | A | screen:prologue2 | จอถัดไป | System | BUT WE HAVE ONLY | 4 HOURS LEFT. |
| PRO-03 | A | screen:prologue3 | จอถัดไป | System | I NEED COFFEE... | DONT FALL ASLEEP! |
| PRO-04 | A | screen:prologue4 | จอถัดไป → เข้า PLAY | System | I CANT STAY AWAKE... | ALL WENT QUIET. |

### ชั้น 1

บทสนทนา Safe Room (F1-01 ถึง F1-12) หยุดเกมและกด BTNC เพื่ออ่านต่อ

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| F1-01 | B | start! | Safe Room: ตื่น | Player | GASP! WHERE AM I! | WHAT IS THIS PLACE! |
| F1-02 | B | after:F1-01! | Safe Room: ต่อจากตื่น (20/11: เดิมรอโจมตีครั้งแรก) | Player | I DONT GET IT YET. | BUT THIS IS COOL! |
| F1-03 | B | after:F1-02! | Safe Room | Voice | BRAVE HERO! | HEED MY CALL! |
| F1-04 | B | after:F1-03! | Safe Room | Player | YOU MEAN... ME! |  |
| F1-05 | B | after:F1-04! | Safe Room | Voice | I CAN SEND YOU HOME. | LISTEN CLOSELY. |
| F1-06 | B | after:F1-05! | Safe Room | Player | I AM ALL EARS! |  |
| F1-07 | B | after:F1-06! | Safe Room | Voice | EACH FLOOR HAS | 2 FIGHTS 1 PUZZLE |
| F1-08 | B | after:F1-07! | Safe Room | Voice | THEN A BOSS WAITS. | BEAT IT TO MOVE UP. |
| F1-09 | B | after:F1-08! | Safe Room | Voice | BEAT THE LAST BOSS | TO WIN A KEY. |
| F1-10 | B | after:F1-09! | Safe Room | Voice | RETURN TO THE START. | THE GATE HOME WAITS. |
| F1-11 | B | after:F1-10! | Safe Room | Voice | FAIL AND YOU STAY | HERE FOREVER. |
| F1-12 | B | after:F1-11! | Safe Room | Player | FIGHT. SOLVE. WIN. | SIMPLE ENOUGH! |
| F1-13 | B | lock_f1c1 | Combat 1: เข้าห้อง (ประตูล็อก) | System | SPIKES ROSE! | DEFEAT ALL ENEMIES! |
| F1-14 | B | clear_f1c1 | Combat 1: เคลียร์ | Player | WHEW. THAT WAS HARD. | SPIKES ARE DOWN! |
| F1-15 | B | lock_f1c2 | Combat 2: เข้าห้อง | System | DEFEAT ALL ENEMIES! |  |
| F1-16 | B | clear_f1c2 | Combat 2: เคลียร์ | Player | CLEARED! ONWARD! |  |
| F1-17 | B | enter_f1puz | Puzzle: เข้าห้อง | Player | A PUZZLE ROOM. | LIGHT ALL THE BULBS. |
| F1-18 | B | item_f1 | Puzzle: ไอเทมปรากฏ | Player | WHAT IS THAT THING. | LET ME TAKE A LOOK. |
| F1-19 | B | got_f1 | เก็บไอเทม | Player | WHOA! WHAT HAPPENED! |  |
| F1-20 | A | screen:evolve2 | แปลงร่าง → Form 2 (state EVOLVE) | System | NEW FORM: ORC! | RANGED SHOT! |
| F1-21 | B | evolved_f1 | หลังแปลงร่าง | Voice | THE DUNGEON REWARDS | THE WORTHY. |
| F1-22 | B | after:F1-21 | หลังแปลงร่าง | Player | ONLY THE BOSS LEFT! |  |
| F1-23 | B | enter_f1boss | Boss 1: ก่อนสู้ | Voice | THIS BOSS IS FAST. | CLAP TO STUN IT! |
| F1-24 | B | bossdead_f1 | Boss 1: ตาย | Player | I GOT THE HANG OF IT | SAME ON NEXT FLOOR! |
| F1-25 | A | screen:floorclear | FLOOR CLEAR (2 วิ) — เลขชั้นในข้อความถูกแทนด้วยเลขชั้นจริง | System | FLOOR 1 CLEAR! |  |

### ชั้น 2

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| F2-01 | B | enter_f2start | เข้าชั้น 2 | Voice | FLOOR 2. HARDER NOW. | WATCH FOR TRAPS! |
| F2-02 | B | lock_f2c1 | Combat 1: เข้าห้อง | System | DEFEAT ALL ENEMIES! |  |
| F2-03 | B | lock_f2c2 | Combat 2: เข้าห้อง | System | SPIKES ROSE! | DEFEAT ALL ENEMIES! |
| F2-04 | B | clear_f2c2 | Combat 2: เคลียร์ | Player | CLEARED! ONWARD! |  |
| F2-05 | B | after:F2-02 | Breakable box (ห้อง Combat 1 ชั้น 2) | Player | THIS BOX CAN BREAK. | MAYBE LOOT INSIDE. |
| F2-06 | B | enter_f2puz | Puzzle: เข้าห้อง | Player | PUSH THE BOXES | ONTO THE PLATES. |
| F2-07 | B | item_f2 | Puzzle: ไอเทมปรากฏ | Player | ANOTHER RELIC! |  |
| F2-08 | A | screen:evolve3 | แปลงร่าง → Form 3 (state EVOLVE) | System | NEW FORM: ANGEL! | SHOTS SPLIT ON HIT! |
| F2-09 | B | evolved_f2 | หลังแปลงร่าง | Player | I FEEL STRONGER. |  |
| F2-10 | B | enter_f2boss | Boss 2: ก่อนสู้ (1) | Voice | THIS BOSS SUMMONS. | KILL ALL MINIONS! |
| F2-11 | B | after:F2-10 | Boss 2: ก่อนสู้ (2) | Voice | IT IS IMMUNE NOW. | MINIONS DIE FIRST! |
| F2-12 | B | vuln_f2 | Boss 2: ลูกน้องตายหมด (รอบใหม่กำลังมา) | System | MINIONS ALL DEAD! | HIT THE BOSS NOW! |
| F2-13 | B | bossdead_f2 | Boss 2: ตาย | Player | ONE FLOOR LEFT! |  |
| F2-14 | A | screen:floorclear | FLOOR CLEAR (2 วิ) (ใช้แบบเดียวกับ F1-25) | System | FLOOR 2 CLEAR! |  |

### ชั้น 3

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| F3-01 | B | enter_f3start | เข้าชั้น 3 | Voice | FLOOR 3. LAST FLOOR. | THE GATE IS CLOSE. |
| F3-02 | B | lock_f3c1 | Combat 1: เข้าห้อง | System | DEFEAT ALL ENEMIES! |  |
| F3-03 | B | lock_f3c2 | Combat 2: เข้าห้อง | System | SPIKES ROSE! | DEFEAT ALL ENEMIES! |
| F3-04 | B | clear_f3c2 | Combat 2: เคลียร์ | Player | CLEARED! ONWARD! |  |
| F3-05 | B | enter_f3puz | Puzzle: เข้าห้อง | Player | WATCH THE PATTERN. | THEN REPEAT IT! |
| F3-06 | B | item_f3 | Puzzle: ไอเทมปรากฏ | Player | THE LAST RELIC! |  |
| F3-07 | A | screen:evolve4 | แปลงร่าง → Form 4 (state EVOLVE) | System | NEW FORM: FORM 4! | HOLD ATTACK: CHARGE! |
| F3-08 | B | evolved_f3 | หลังแปลงร่าง | Voice | CHARGE SHOTS BREAK | BOSS ARMOR. |
| F3-09 | B | enter_f3boss | Boss 3: ก่อนสู้ | Voice | ARMOR BLOCKS ALL. | ONLY CHARGE HURTS! |
| F3-10 | B | charge_f3 | Boss 3: เข้า CHARGING (ครั้งแรก) | System | IT IS CHARGING! | INTERRUPT IT OR DIE! |
| F3-11 | B | interrupt_f3 | Boss 3: ถูกขัด | System | INTERRUPTED! |  |

### Endgame

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| END-01 | B | key_drop | Boss 3 ตาย กุญแจตกบนพื้น | Player | A KEY DROPPED! |  |
| END-02 | B | after:END-01 | บอกทางไปต่อ | Voice | GO BACK TO THE START | THE GATE WAITS. |
| END-03 | B | enter_f3start_key | ถึง START ชั้น 3 พร้อมกุญแจ | System | THE GATE IS LOCKED | BY A MAZE. |
| END-04 | B | screen:maze | เริ่ม Ball in a Maze (ป้ายตอนเริ่ม) | Voice | TILT THE BOARD TO | ROLL THE BALL OUT! |
| END-05 | B | maze_banner_end | เริ่มจับเวลา | System | YOU HAVE 60 SECONDS! |  |
| END-06 | A | screen:win | ผ่าน Maze → WIN | System | YOU ESCAPED! | YOU WIN! |
| END-07 | A | screen:timeout | หมดเวลา → GAME OVER | System | TIME IS UP! | BTNC RETRY FLOOR {F} |
| END-08 | A | screen:gameover | ผู้เล่นตาย → GAME OVER (บรรทัด 2 กะพริบ: BTNC = ลองชั้นเดิมใหม่, BTNL = กลับ TITLE) | System | GAME OVER | BTNC RETRY FLOOR {F} |

## หมายเหตุสำหรับ implement

**ตัวเรียกข้อความ (trigger)** — ดูตารางรหัส Trigger ด้านบน. Tier A = หน้าจอเต็มของ state ที่มีอยู่ (TITLE, PROLOGUE, EVOLVE, FLOOR CLEAR, ป้ายเขาวงกต, WIN, GAME OVER). Tier B = กล่อง dialogue ด้านล่างจอ (`rtl/dialog.v`) — W16.

* F3-10: โจมตีใหญ่ของบอส 3 ตาม plan W12 คือ lethal ทั้งห้อง จึงใช้ `INTERRUPT IT OR DIE!`
* F2-12 แสดงเมื่อลูกน้องบอส 2 ตายหมด (event `vuln_f2`; หลัง W17 ไม่ได้หมายถึง "ตีได้แล้ว" อีกต่อไป เป็นแค่สัญญาณก่อนระลอกใหม่)
* WIN screen ไม่มีเลขเวลาแล้ว (เวลาเล่นยังอยู่ที่ 7-seg)

**ตัวเลขอิง plan** — Boss 1 stun 3 วิ / cooldown 4 วิ, Boss 3 ชาร์จ 2 วิ HP 3 charged hit, Maze 60 วิ หมดเวลา = GAME OVER, กระสุนชาร์จทำลายกระสุนศัตรูที่ขวางทาง (ตัดสินใจแล้ว), `ATTACK` = BTNC.

**ชื่อเกม:** THE CHOSEN ONE (แก้ที่ TITLE-01).

## W28 / W29 / W31 / W32 / W33 (20/11): หน้า CONTROLS / CREDITS บน TITLE, กล่องเริ่มเกมซ้ำ, ข้อความ hint strip

หน้า TITLE กด BTNR (หรือลูกศรขวา / D) = หน้าถัดไป, BTNL = หน้าก่อน; ลำดับ TITLE -> CONTROLS 1-5 -> CREDITS 1-3 -> TITLE; BTNC / Space / Enter = เริ่มเกมจากทุกหน้า.
**CREDITS: ชื่อทีมเป็น placeholder ให้เจ้าของแก้** (และตรวจ credit ของ asset pack ก่อนส่ง).

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| CTL-01 | A | screen:controls1 | หน้า CONTROLS 1 | System | MOVE | ARROWS WASD OR BTNS |
| CTL-02 | A | screen:controls2 | หน้า CONTROLS 2 | System | ATTACK | SPACE J ENTER BTNC |
| CTL-03 | A | screen:controls3 | หน้า CONTROLS 3 | System | SPRINT AND PAUSE | SHIFT SW14  P SW15 |
| CTL-04 | A | screen:controls4 | หน้า CONTROLS 4 | System | AUTO AIM | L OR SW9  FACE SW12 |
| CTL-05 | A | screen:controls5 | หน้า CONTROLS 5 | System | OTHER KEYS | R BOXES  C CLAP SW11 |
| CRD-01 | A | screen:credits1 | หน้า CREDITS 1 | System | THE CHOSEN ONE | GROUP 10 |
| CRD-02 | A | screen:credits2 | หน้า CREDITS 2 | System | DESIGN AND CODE | NAMES HERE |
| CRD-03 | A | screen:credits3 | หน้า CREDITS 3 | System | ART AND SOUND | SEE ASSET PACKS |
| F1-00 | B | start_again! | เริ่มเกมครั้งที่ 2+ (ข้าม intro เต็ม) | Player | FIGHT. SOLVE. WIN. | ONCE MORE! |

Hint strip (กล่องเล็กกลางบนของจอ ไม่หยุดเกม; ไม่เกิน 17 ตัวอักษรต่อบรรทัด): objective ของห้อง + บทสอนที่รอให้ผู้เล่นทำ.

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| H-01 | B | hint:obj_combat | ห้องต่อสู้ล็อก | System | DEFEAT ALL ENEMIES | ENEMIES LEFT: {F} |
| H-02 | B | hint:obj_open | ห้องเคลียร์ | System | DOORS OPEN | GO ON |
| H-03 | B | hint:obj_bulb | ห้อง puzzle ชั้น 1 | System | LIGHT ALL BULBS | PULL THE LEVERS |
| H-04 | B | hint:obj_soko | ห้อง puzzle ชั้น 2 | System | BOXES ONTO PLATES | STUCK: R OR SW13 |
| H-05 | B | hint:obj_simon | ห้อง puzzle ชั้น 3 | System | WATCH THE PATTERN | THEN REPEAT IT |
| H-06 | B | hint:obj_boss1 | บอส 1 | System | DEFEAT THE BOSS | CLAP TO STUN IT |
| H-07 | B | hint:obj_boss2 | บอส 2 | System | KILL MINIONS FIRST | THEN HIT THE BOSS |
| H-08 | B | hint:obj_boss3 | บอส 3 | System | DEFEAT THE BOSS | CHARGE SHOTS ONLY |
| H-09 | B | hint:obj_bossdead | บอสตาย | System | BOSS DOWN | TAKE THE DOOR |
| H-10 | B | hint:obj_key | ได้กุญแจ | System | GO BACK TO START | THE GATE WAITS |
| H-11 | B | hint:tut_move | บทสอน: เดิน | System | MOVE: ARROWS WASD | OR BUTTONS |
| H-12 | B | hint:tut_attack | บทสอน: โจมตี | System | ATTACK: SPACE J | ENTER OR BTNC |
| H-13 | B | hint:tut_sprint | บทสอน: วิ่งเร็ว | System | SPRINT: SHIFT | OR SW14 |
| H-14 | B | hint:tut_pause | บทสอน: หยุดเกม | System | PAUSE: P ESC | OR SW15 |
| H-15 | B | hint:tut_aim | บทสอน: auto aim | System | AUTO AIM IS ON | L OR SW9: OFF |
| H-16 | B | hint:tut_start | ก่อนเริ่มบทสอน | System | FREE TO MOVE | TRY THE CONTROLS |

## W36 (20/11): หน้า SETTINGS บน TITLE - ระดับเสียงตบมือ (BTNU / ลูกศรขึ้น = สูงขึ้น, BTND / ลูกศรลง = ต่ำลง)

| ID | Tier | Trigger | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- | --- |
| SET-01 | A | screen:settings1 | CLAP LEVEL 1 | System | CLAP LEVEL | VERY LOW - EASY |
| SET-02 | A | screen:settings2 | CLAP LEVEL 2 | System | CLAP LEVEL | LOW |
| SET-03 | A | screen:settings3 | CLAP LEVEL 3 (default) | System | CLAP LEVEL | MID |
| SET-04 | A | screen:settings4 | CLAP LEVEL 4 | System | CLAP LEVEL | HIGH |
| SET-05 | A | screen:settings5 | CLAP LEVEL 5 | System | CLAP LEVEL | VERY HIGH - HARD |
| H-17 | B | hint:obj_stuck | Sokoban ติด / นานเกิน 90 วิ | System | BOX STUCK! | PRESS R OR SW13 |
