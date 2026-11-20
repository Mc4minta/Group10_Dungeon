# Game Story + In-Game Text — Group 10 Dungeon

Nov 19, 2026 · @min

เอกสารนี้สรุปเนื้อเรื่องและข้อความทั้งหมดที่แสดงบนจอเกม ตัวเลขทั้งหมดอิง DESIGN\_PLAN.md (บอส 2: ตีได้เมื่อลูกน้องตายหมดเท่านั้น)

## เรื่องย่อเกม

ผู้เล่นคือนักศึกษาที่เผลอหลับตอนปั่นงานก่อน deadline แล้วตื่นขึ้นมาในดันเจี้ยนปริศนา เสียงลึกลับบอกว่าจะส่งกลับบ้านได้ ถ้าผ่านครบ 3 ชั้น แต่ละชั้นมีห้องต่อสู้ 2 ห้อง ห้อง puzzle และบอส เมื่อแก้ puzzle ได้ ดันเจี้ยนจะมอบพลังให้แปลงร่างใหม่ และแต่ละร่างคือกุญแจในการสยบบอส: บอส 1 วิ่งเร็ว ต้องปรบมือให้ติด stun, บอส 2 เรียกลูกน้องมาป้องกันตัว ต้องกำจัดลูกน้องให้หมดก่อนจึงตีบอสได้, บอส 3 สวมเกราะ ต้องยิงชาร์จเท่านั้น บอสสุดท้ายดรอปกุญแจ ผู้เล่นต้องกลับไปไขประตูที่จุดเริ่มต้น และผ่านเขาวงกตที่ควบคุมด้วยการเอียงบอร์ดให้ทันเวลา ผ่านก็ได้กลับบ้าน หมดเวลาก็ติดอยู่ที่นี่ตลอดไป

## โครงเกมและกลไก

ทุกชั้นเล่นเรียงกัน: ห้องต่อสู้ 2 ห้อง → ห้อง puzzle → ไอเทมแปลงร่าง และเปิดประตูบอส → ห้องบอส ผู้เล่นเริ่มที่ Form 1 (Human, ตีใกล้) ตายเมื่อไรก็ GAME OVER

| ชั้น | Puzzle | ร่างที่ได้ | บอส | กลไกบอส / วิธีชนะ |
| --- | --- | --- | --- | --- |
| 1 | Light Bulb | Form 2: Orc (ยิงธรรมดา) | Boss 1 (HP 10) | วิ่งเร็วมาก รับดาเมจตลอด ปรบมือ (ไมค์ หรือ SW11 สำรอง) ให้ stun 3 วิ (cooldown 4 วิ) แล้วตามตี |
| 2 | Sokoban (pressure plate) | Form 3: Angel (ยิง AOE กระสุนแตก 4 ทิศเมื่อโดนมอน) | Boss 2 (HP 16) | เรียกลูกน้อง 3 ตัวต่อรอบ บอสไม่รับดาเมจตอนลูกน้องยังอยู่ ตีได้เมื่อลูกน้องตายหมด (ช่วง 2 วิ) แล้ว summon รอบใหม่ |
| 3 | Simon Says | Form 4: ชาร์จยิงกระสุนใหญ่ (หยุดเมื่อโดน) | Boss 3 (HP 3 charged hit) | เกราะ รับดาเมจเฉพาะ charged shot ชาร์จโจมตีใหญ่ 2 วิ ถ้าชาร์จครบ lethal ทั้งห้อง ต้องยิงชาร์จขัดก่อน |
| จบเกม | Ball in a Maze |  |  | บอส 3 ดรอปกุญแจ → ไขประตู START ชั้น 3 → เอียงบอร์ดกลิ้งลูกบอลใน 60 วิ → WIN (หมดเวลา = GAME OVER) |

ตัวเลขอิง `docs/DESIGN_PLAN.md` (หัวข้อ 6 และ W10–W12) ปรับได้ที่ `rtl/params.vh`

## ข้อความในเกม

ทุกข้อความใช้ A–Z, 0–9, เว้นวรรค และ `- : ! .` เท่านั้น ไม่เกิน 2 บรรทัดต่อจอ และ **ไม่เกิน 20 ตัวอักษรต่อบรรทัด** (ตาม DESIGN\_PLAN W9a) ตรวจด้วยสคริปต์แล้วทุกบรรทัด ชื่อผู้พูดอยู่คอลัมน์แยก ไม่นับในความยาว

**Tier A** = ใช้หน้าจอ/state ที่มีหรือ plan ไว้แล้ว (Prologue W9a, FLOOR CLEAR, แบนเนอร์ NEW FORM ใน state EVOLVE, WIN, GAME OVER) · **Tier B** = ต้องมี dialogue overlay ใหม่ ซึ่งยังไม่มีใน plan ถ้าไม่ทำ ให้เล่าในวิดีโอ/report แทน

### Prologue

จอดำ ตัวอักษรขาวกลางจอ แสดงทีละจอ จบแล้วเข้า Safe Room (ชั้น 1)

| ID | Tier | จังหวะ | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- |
| PRO-01 | A | จอดำ จอแรก | ROME WASNT BUILT | IN A DAY. |
| PRO-02 | A | จอถัดไป | BUT WE HAVE ONLY | 4 HOURS LEFT. |
| PRO-03 | A | จอถัดไป | I NEED COFFEE... | DONT FALL ASLEEP! |
| PRO-04 | A | จอถัดไป → เข้า PLAY | I CANT STAY AWAKE... | ALL WENT QUIET. |

### ชั้น 1

ข้อความสอนเล่น (เดิน/วิ่ง, โจมตี) ไม่มีใน plan จึงไม่ใส่ในตาราง ถ้าต้องการ ให้เป็น Tier B หรืออธิบายในวิดีโอ

| ID | Tier | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- |
| F1-01 | B | Safe Room: ตื่น | Player | GASP! WHERE AM I! | WHAT IS THIS PLACE! |
| F1-02 | B | หลังลองเดิน/โจมตี | Player | I DONT GET IT YET. | BUT THIS IS COOL! |
| F1-03 | B | Safe Room | Voice | BRAVE HERO! | HEED MY CALL! |
| F1-04 | B | Safe Room | Player | YOU MEAN... ME! |  |
| F1-05 | B | Safe Room | Voice | I CAN SEND YOU HOME. | LISTEN CLOSELY. |
| F1-06 | B | Safe Room | Player | I AM ALL EARS! |  |
| F1-07 | B | Safe Room | Voice | EACH FLOOR HAS | 2 FIGHTS 1 PUZZLE |
| F1-08 | B | Safe Room | Voice | THEN A BOSS WAITS. | BEAT IT TO MOVE UP. |
| F1-09 | B | Safe Room | Voice | BEAT THE LAST BOSS | TO WIN A KEY. |
| F1-10 | B | Safe Room | Voice | RETURN TO THE START. | THE GATE HOME WAITS. |
| F1-11 | B | Safe Room | Voice | FAIL AND YOU STAY | HERE FOREVER. |
| F1-12 | B | Safe Room | Player | FIGHT. SOLVE. WIN. | SIMPLE ENOUGH! |
| F1-13 | B | Combat 1: เข้าห้อง (ประตูล็อก) | System | SPIKES ROSE! | DEFEAT ALL ENEMIES! |
| F1-14 | B | Combat 1: เคลียร์ | Player | WHEW. THAT WAS HARD. | SPIKES ARE DOWN! |
| F1-15 | B | Combat 2: เข้าห้อง | System | DEFEAT ALL ENEMIES! |  |
| F1-16 | B | Combat 2: เคลียร์ | Player | CLEARED! ONWARD! |  |
| F1-17 | B | Puzzle: เข้าห้อง | Player | A PUZZLE ROOM. | LIGHT ALL THE BULBS. |
| F1-18 | B | Puzzle: ไอเทมปรากฏ | Player | WHAT IS THAT THING. | LET ME TAKE A LOOK. |
| F1-19 | B | เก็บไอเทม | Player | WHOA! WHAT HAPPENED! |  |
| F1-20 | A | แปลงร่าง → Form 2 (state EVOLVE) | System | NEW FORM: ORC! | RANGED SHOT! |
| F1-21 | B | หลังแปลงร่าง | Voice | THE DUNGEON REWARDS | THE WORTHY. |
| F1-22 | B | หลังแปลงร่าง | Player | ONLY THE BOSS LEFT! |  |
| F1-23 | B | Boss 1: ก่อนสู้ | Voice | THIS BOSS IS FAST. | CLAP TO STUN IT! |
| F1-24 | B | Boss 1: ตาย | Player | I GOT THE HANG OF IT | SAME ON NEXT FLOOR! |
| F1-25 | A | FLOOR CLEAR (2 วิ) | System | FLOOR 1 CLEAR! |  |

### ชั้น 2

| ID | Tier | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- |
| F2-01 | B | เข้าชั้น 2 | Voice | FLOOR 2. HARDER NOW. | WATCH FOR TRAPS! |
| F2-02 | B | Combat 1: เข้าห้อง | System | DEFEAT ALL ENEMIES! |  |
| F2-03 | B | Combat 2: เข้าห้อง | System | SPIKES ROSE! | DEFEAT ALL ENEMIES! |
| F2-04 | B | Combat 2: เคลียร์ | Player | CLEARED! ONWARD! |  |
| F2-05 | B | Breakable box ครั้งแรก (ออปชัน) | Player | THIS BOX CAN BREAK. | MAYBE LOOT INSIDE. |
| F2-06 | B | Puzzle: เข้าห้อง | Player | PUSH THE BOXES | ONTO THE PLATES. |
| F2-07 | B | Puzzle: ไอเทมปรากฏ | Player | ANOTHER RELIC! |  |
| F2-08 | A | แปลงร่าง → Form 3 (state EVOLVE) | System | NEW FORM: ANGEL! | SHOTS SPLIT ON HIT! |
| F2-09 | B | หลังแปลงร่าง | Player | I FEEL STRONGER. |  |
| F2-10 | B | Boss 2: ก่อนสู้ (1) | Voice | THIS BOSS SUMMONS. | SPLIT SHOTS HIT ALL! |
| F2-11 | B | Boss 2: ก่อนสู้ (2) | Voice | KILL ALL MINIONS | THEN HIT THE BOSS! |
| F2-12 | B | Boss 2: ลูกน้องตายหมด เข้า VULNERABLE (ออปชัน) | System | MINIONS ALL DEAD! | HIT THE BOSS NOW! |
| F2-13 | B | Boss 2: ตาย | Player | ONE FLOOR LEFT! |  |
| F2-14 | A | FLOOR CLEAR (2 วิ) | System | FLOOR 2 CLEAR! |  |

### ชั้น 3

| ID | Tier | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- |
| F3-01 | B | เข้าชั้น 3 | Voice | FLOOR 3. LAST FLOOR. | THE GATE IS CLOSE. |
| F3-02 | B | Combat 1: เข้าห้อง | System | DEFEAT ALL ENEMIES! |  |
| F3-03 | B | Combat 2: เข้าห้อง | System | SPIKES ROSE! | DEFEAT ALL ENEMIES! |
| F3-04 | B | Combat 2: เคลียร์ | Player | CLEARED! ONWARD! |  |
| F3-05 | B | Puzzle: เข้าห้อง | Player | WATCH THE PATTERN. | THEN REPEAT IT! |
| F3-06 | B | Puzzle: ไอเทมปรากฏ | Player | THE LAST RELIC! |  |
| F3-07 | A | แปลงร่าง → Form 4 (state EVOLVE) | System | NEW FORM: FORM 4! | HOLD ATTACK: CHARGE! |
| F3-08 | B | หลังแปลงร่าง | Voice | CHARGE SHOTS BREAK | BOSS ARMOR. |
| F3-09 | B | Boss 3: ก่อนสู้ | Voice | ARMOR BLOCKS ALL. | ONLY CHARGE HURTS! |
| F3-10 | B | Boss 3: เข้า CHARGING (ครั้งแรก) | System | IT IS CHARGING! | INTERRUPT IT OR DIE! |
| F3-11 | B | Boss 3: ถูกขัด | System | INTERRUPTED! |  |

### Endgame

| ID | Tier | จังหวะ | ผู้พูด | บรรทัด 1 | บรรทัด 2 |
| --- | --- | --- | --- | --- | --- |
| END-01 | B | Boss 3 ตาย กุญแจตก | Player | A KEY DROPPED! |  |
| END-02 | B | หลังเก็บกุญแจ | Voice | GO BACK TO THE START | THE GATE WAITS. |
| END-03 | B | ถึงประตู START (ประตู E) | System | THE GATE IS LOCKED | BY A MAZE. |
| END-04 | B | เริ่ม Ball in a Maze | Voice | TILT THE BOARD TO | ROLL THE BALL OUT! |
| END-05 | B | เริ่มจับเวลา | System | YOU HAVE 60 SECONDS! |  |
| END-06 | A | ผ่าน Maze → WIN | System | YOU ESCAPED! | YOU WIN! |
| END-07 | A | หมดเวลา → GAME OVER | System | TIME IS UP! | TRAPPED FOREVER. |
| END-08 | A | ผู้เล่นตายทุกจุด | System | GAME OVER |  |

## หมายเหตุสำหรับ implement

**ตัวเรียกข้อความ (trigger)**

- **Tier A** ผูกกับ state ที่มีอยู่/วางแผนไว้: Prologue → `S_PROLOGUE` (W9a), FLOOR n CLEAR → state FLOOR CLEAR (120 เฟรม), NEW FORM → state EVOLVE (60 เฟรม), WIN / GAME OVER → จอเดิม แก้แค่ข้อความ
- **Tier B** ทั้งหมด (บทพูด Voice, คำใบ้บอส, ข้อความห้อง) ต้องมี dialogue overlay ใหม่ ซึ่งไม่อยู่ใน plan ถ้าไม่ทำ ให้ใช้เอฟเฟกต์ภาพของ plan แทน (tint โล่บอส 2, telegraph บอส 3) และเล่าที่เหลือในวิดีโอ
- F3-10: โจมตีใหญ่ของบอส 3 ตาม plan W12 คือ lethal ทั้งห้อง ไม่ใช่โดนทีเดียว จึงใช้ `INTERRUPT IT OR DIE!`
- F2-12 แสดงเมื่อ state บอส 2 เปลี่ยนเป็น VULNERABLE

**State ของ Boss 2 (ปรับใหม่)**

```
IDLE ──► SUMMON ──► MINIONS_ALIVE (บอสไม่รับดาเมจ)
          ──(ลูกน้องตายหมด)──► VULNERABLE (บอสรับดาเมจ, แสดง F2-12) ──(หมดเวลา)──► SUMMON (รอบใหม่)
   HP = 0 ──► DEAD
```

**ข้อที่ยังต้องตัดสินใจ / ต้องเทียบของจริง**

- DESIGN\_PLAN และ FEATURES ยังเขียนกฎ Boss 2 ตรงข้าม (ตีได้ตอนลูกน้องยังอยู่) ต้องแก้ตาม prompt ที่ส่งให้ agent Design Notes แก้แล้วในไฟล์ `_fixed`
- ช่วง VULNERABLE ของ Boss 2: ตั้ง 2 วิ (ตีความจากข้อ 4 ของ plan "summon ใหม่หลัง 2 วิ") ต้องยืนยัน และจูนตอนเล่นจริง เพราะสั้นอาจฆ่าบอส HP 16 ไม่ทัน
- ตัวเลขอื่นอิง plan: Boss 1 stun 3 วิ / cooldown 4 วิ, Boss 3 ชาร์จ 2 วิ HP 3 charged hit, Maze 60 วิ หมดเวลา = GAME OVER
- `ATTACK` = BTNC ตาม FEATURES ข้อความ F3-07 จึงตรง
- "Stage N" ใน design = ห้องต่อสู้ 2 ห้อง (สมมติ) · ชื่อเกมและชื่อ Form 4 ยังไม่ตั้ง
