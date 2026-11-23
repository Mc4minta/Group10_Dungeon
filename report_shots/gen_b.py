from tl import TL
# ---- B: floor 1 Light Bulb (fig 25, 26): real walk; SW2 (DEBUG) only clears the combat rooms
t = TL().intro()
t.hold('R', 156); t.at(475); t.spam('2', 14, 30)          # C1: wait out the lock dialog, clear all waves
t.hold('R', 132); t.hold('U', 125)                         # C1 -> top door -> C2
t.at(1310); t.spam('2', 16, 30)                            # C2: lock dialog, clear all waves, clear dialog
t.wait(10); t.hold('R', 104); t.wait(6); t.hold('U', 83); t.wait(6); t.hold('R', 40)   # C2 -> right door -> Light Bulb room
t.wait(160)                                                # room dialog
t.hold('R', 108); t.hold('D', 50); t.wait(8); t.pulse('C')           # lever b (row 11, hit from above, facing down)
t.wait(30); t.hold('R', 128); t.hold('D', 6); t.wait(8); t.pulse('C')   # lever d -> solved
t.save('B.txt', 'job B: floor 1 Light Bulb puzzle (gen_b.py)')
# ---- K: floor clear screen (SW1 DEBUG) and GAME OVER (SW4 DEBUG x4 = HP 0)
k = TL().intro()
k.at(160); k.pulse2('1')
k.at(520); k.spam('4', 6, 30)
k.save('K.txt', 'job K: FLOOR CLEAR via SW1, GAME OVER via SW4 (gen_b.py)')
# ---- H2: floor 1 boss 1 (fig 31) + room cleared (fig 24). SW0 (DEBUG) holds the boss door open, SW2 clears the waves
h = TL().intro()
h.lines.append("0:150:9000")
h.hold('R', 156); h.at(475); h.spam('2', 14, 30)
h.hold('U', 8); h.hold('R', 280)
h.wait(165); h.pulse('K')
for _ in range(10): h.hold('C', 3); h.wait(15)
h.wait(40); h.pulse('K')
for _ in range(40): h.hold('C', 3); h.wait(15)
h.save('H2.txt', 'job H2: floor 1 boss 1 (gen_b.py)')
