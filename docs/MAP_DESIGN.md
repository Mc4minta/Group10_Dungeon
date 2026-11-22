# Map design (W23) - every object has a purpose

Rule from the owner (20/11): nothing is placed only to fill space. Redrawn 20/11-21/11: combat rooms 4, 5, 7, 8, 10, 11, start room 1, boss rooms 2 and 3, and the light-bulb puzzle room 6 (levers and bulbs moved to the bottom rows 11 / 13). Deliberately NOT redrawn: start room 0 (the `tb_objects` tests use its exact tiles:
pillars, fences, row 7), and the puzzle rooms 6 (light bulbs), 9 (Sokoban, solved by `solve_sokoban.py`, the walls are the puzzle) and 12 (Simon): every wall there already serves the puzzle and the tests pin the geometry.
Source: `maps/*.txt` (generated for this pass by a one-off script, now edited by hand), `maps_v1/` stays as the first version.

Legend: `#` wall, `F` fence (bullets pass, feet do not), `H` pit (only form 3 flies over), `Z` breakable crate, `Y` pillar (blocks everything),
`X` static spike (1 HP, floor 3), `W` / `V` timed spikes (2 HP, floor 2, opposite phases), `S` chaser, `T` turret, `, ; :` decoration (cracks, bones, skull).

| Room | Theme | Object -> purpose |
|---|---|---|
| 4 (floor 1, combat 1) | crypt ambush | wall corner top left = a pocket where a chaser waits behind the wall (you see it late); **crate plug `Z` (13,12) + walls = a sealed turret nest**: the doors stay locked until the nest turret is dead, so the crate must be broken; pillar cluster `Y` (10-11, 8-9) = cover from the nest lane; crack `,` beside the plug = the hint; skull / bones = dead-end markers |
| 5 (floor 1, combat 2) | firing gallery | fence wall row 5 = turrets (3, 2) (9, 2) (15, 2) can shoot through it and so can you, nobody can walk through; **one pillar in each turret lane** (3, 8) (9, 9) (15, 6) = the cover you hide behind; the right end of the fence is open = the flank route to melee the last turret; 3 chasers force you to keep moving between the covers |
| 7 (floor 2, combat 1) | spike garden | **timed spike gate** `W` / `V` columns 11-12 = the fast way from the left door to the right door, learn the rhythm (one column is up while the other is down); the long way round the top (past (1,4) and cols 14+) is safe but covered by the 2 top turrets; wall ledge with 2 fence windows = the top-left turret fires down through them and you can shoot up through them; lower wall = splits the bottom area, bottom turrets cover its lanes; bones / skull at the gate = the warning |
| 8 (floor 2, combat 2) | courtyard + gauntlet | fenced courtyard with a turret inside = shoot it through the fence (it cannot be reached on foot); **corridor of timed spikes in front of the right door = the only way out** (the door is the reward for timing it, the chasers behind you are the pressure); crack beside the corridor entry = the hint |
| 10 (floor 3, combat 1) | pit bridge | pit band across the room = splits it, only a 2-wide bridge crosses (cols 9-10); static spikes on the bridge in a checkerboard = the safe line is the diagonal; turrets in the far corners cover the bridge |
| 11 (floor 3, combat 2) | pit column | pit column with a bridge on rows 7-8 right in front of the right door = the last obstacle before the exit; L-shaped pillar cover on the left = hide from the far turrets; spikes on the bridge = checkerboard again |

| 1 (floor 3, start) | maze-door nook | the two short wall pieces frame the maze door E in a torch-lit nook (the door the whole game leads to); everything else is open ground so the hero can walk straight from the start tile to either door |
| 2 (boss, floors 1 + 3) | cover arena | boss spawn and the lane rows 6-8 to the left stay clear (the boss approaches along it); wall clusters of 1 / 2 / 3 tiles (top left L, top right single, bottom right L, bottom left single) = the hero's cover from the W20 bullet patterns and the boss-3 storm; they also block the boss so it has to go round |
| 3 (boss, floor 2) | priest in a fence box | a 6 x 5 fence box in the middle of the room around the stationary priest (bullets pass, feet and minions do not); the minions appear on the 3 summon tiles OUTSIDE the box and chase the hero across the open room; the boss is immune until all of them are dead (W42); cover pillars around the room are where the hero hides from his cross / X bullets |
| 6 (floor 1, light bulbs) | bottom puzzle | the 4 levers (row 11) and the 4 bulbs (row 13) are at the BOTTOM so the hint strip and the story box (drawn at the top in this room) never hide them; the hero stands on row 12 between them and hits a lever facing up |

**Waves (W43):** map chars `m n` = second wave, `o p` = third wave (chaser / turret), stored in `mem/monsters.mem` (4 blocks of 16 rooms x 8); rooms 4, 5, 8 have 2 waves, rooms 10 and 11 have 3, room 7 stays one wave (`tb_objects` pins it). The doors stay shut between waves and the next wave appears 1 s after the last monster dies.

Checks (`tests/test_maps.py` `test_redesigned_rooms`): door tiles unchanged, the spawn pockets next to the doors are free of walls / traps / crates,
at most 6 monsters, every monster can be reached or shot (fences let bullets through) once the crates are broken, every door can be reached,
a crate always plugs something (2 opposite blocked sides or a niche, never loose), room 7 keeps the monster order `T T S S T T` and the turret at (17, 13) that
`tb_objects` uses, room 8 keeps 4 monsters.
