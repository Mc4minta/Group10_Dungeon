# Sprite status - what is final, what is a placeholder, what you still need to find or edit

**Updated every time a sprite, ROM or map changes.** Last update: levers = your `picture/new_switch.png` (frame 1 = lever up, frame 4 = lever down).
Legend: **FINAL** = real art you are happy with. **PLACEHOLDER** = real art but a stand-in (wrong meaning, recoloured, borrowed). **OLD ART** = the original programmer placeholder from the first version (`*_v1.mem`), nothing new yet.

How to change any sprite: see `sprites/README.md`. One command for everything: `scripts/update_sprites.sh` (Windows: `scripts\update_sprites.bat`).

---

## 1. Needs YOUR art (find or draw these) - priority order

| # | Sprite | Now | What to provide | Where it goes |
|---|---|---|---|---|
| 1 | **Form 4 hero** (the final form) | PLACEHOLDER: Human sheets recoloured gold | 4x4 walk sheet (128x128, rows: front-Right, front-Left, back-Right, back-Left), optional 16-column idle sheet. Same layout as `Human/Walk.png` | put the PNGs in `picture/`, list them under `forms."4".sheets` in `sprites/sprites.json`, delete the `"tint"` line |
| 2 | **Player bullets and enemy bullets** | OLD ART (8x8 squares) | 8x8 px sprites in a 16x16 cell, frames: 0 form-2 shot, 1 enemy shot, 2 form-3 spread, 3 form-4 fast shot, 4 form-4 big charged shot (full 16x16) | needs a new pipeline (pack arrows are 16x32, too big): tell me and I add it |
| 3 | **Melee slash** (form 1 attack effect) | OLD ART (white arc) | 4 arcs, one per direction, 32x32 | same: I add the pipeline |
| 4 | **Levers** (lightbulb puzzle) | FINAL art from `picture/new_switch.png`, but the two states differ by only 12 pixels (the inner yellow dash moves 2 px) so it is hard to see on screen | optional: redraw with a bigger knob travel / a colour change between left and right | `picture/new_switch.png` (cells [0,0] and [1,0]) + `sprites/puzzle.json` frames 2, 3 |
| 5 | **Title screen / GAME OVER / WIN screens** | OLD ART: plain colour fills + text | optional: a logo/background (needs a ROM + renderer change, Verilog) | later |
| 6 | **Angel size** | FINAL art but small (1x, wings 22 px wide) | optional: redraw with a narrower wingspan so it can use 2x like Human and Orc | `sprites/sprites.json` `forms."3".scale` |
| 7 | **Orc / Angel idle sheets** | none (idle = walk frame 0) | optional: idle sheets like `Human/Idle.png` | `forms."2"/"3".sheets.idle` |

## 2. Player (mem/player.mem, 48 frames, `scripts/build_player_mem.py`)

| Form | Source | Scale | Status | Notes |
|---|---|---|---|---|
| 1 Human | `picture/Character/Human/Walk.png`, `Idle.png` | 2x | FINAL | idle pose = Idle.png col 0, steps = Walk col 1 / col 3 |
| 2 Orc | `picture/Character/ORc/form2_Walk.png` | 2x | FINAL (walk only) | no idle sheet |
| 3 Angel | `picture/Character/Angel/Angel_walk.png.png` | 1x | FINAL but small | wings would be cut off at 2x; odd file name handled (clean copy in `picture/_clean/`) |
| 4 | Human sheets + gold tint | 2x | **PLACEHOLDER** | see "Needs your art" #1 |

Art available but NOT used by the game yet (needs Verilog, see NEXT_STEPS B): Human `Attack.png`, `Dmg.png`, `Jump.png`, `ChargedAttack.png`, `SoulDie.png`, `SpinDie.png`, the 16-frame idle loop.
Row 4 of every walk sheet (back facing Left) is unused: the game has only 4 directions.

## 3. Map tiles (mem/tileset.mem, `scripts/build_tileset_mem.py`, `sprites/tileset.json`)

| Tile | Art | Status |
|---|---|---|
| wall, floor, doors (closed/open), boss door, exit (closed/open), hole, fence | asset pack `Dungeon_Tileset.png` (2x) | FINAL |
| pressure plate | pack cell r6 c9, a flat brown square | PLACEHOLDER (no detailed plate in the pack) |
| plate with box | crate over the plate | FINAL |
| floor decoration (crack, bones, skull, rubble) on floors 1-2 | pack cells | FINAL |
| Simon plates (floor 3) | red potion, blue potion, coin, key | FINAL |
| floor colours | floor 1 purple, 2 teal, 3 olive (recolor + gain 1.7) | FINAL (adjust in `tileset.json`) |
| wall variety (corners, tops, torches) | none: one wall id only | NOT POSSIBLE without Verilog (NEXT_STEPS C1) |

## 4. Enemies and bosses

| Sprite | Source | Status |
|---|---|---|
| Monster A (chaser) 2 frames | skeleton1 movement cols 1, 4 (`sprites/monsters.json`) | FINAL (2 frames only, no facing) |
| Monster B (turret) 2 frames | vampire idle cols 0, 3 | FINAL |
| Boss 1 (floors 1) | skeleton2 idle, 2x | FINAL but smaller than the old 64x64 blob |
| Boss 2 (floor 2) normal / stunned | skeleton1 idle / skeleton1 damage frame, 2x | FINAL, the stunned picture is subtle |
| Boss 3 (floor 3) | vampire attack frames 4, 7, 2x | FINAL |

Unused enemy art in `picture/enemies/`: attack, death and damage strips for all three enemies (needs Verilog).

## 5. Puzzle-room objects (mem/puzzle.mem, `scripts/build_puzzle_mem.py`, `sprites/puzzle.json`)

| Frame | Art | Status |
|---|---|---|
| bulb on / bulb off | **your** `picture/props/torch.mem` (frame 0 lit, frame 7 smouldering) | FINAL |
| lever up / down | **your** `picture/new_switch.png`: frame 1 (cell r0 c0, fully left) = up, frame 4 (cell r1 c0, fully right) = down; frames 2,3,5,6 are in-between animation (the game has no lever animation, so unused); frame 7 = fully left again | FINAL art, but the left/right difference is tiny (see #4) |
| box | iron crate | FINAL |
| gate closed / open | spikes up / retracted (background cut out) | FINAL |
| item floor 1 / 2 / 3 | gold key / silver key / red shield | FINAL |

## 6. Still the original placeholders (OLD ART, never replaced)

`mem/bullet.mem`, `mem/effect.mem`, `mem/font.mem` + `mem/text.mem` (text), title/GAME OVER/WIN backgrounds (colour fills), the HUD strip. Everything else in the game is new art.

---

## Next to implement (details in `docs/NEXT_STEPS.md`)

1. You: playtest on the board and tell me what feels too hard (A4), re-create the Vivado project and send BRAM/WNS (A6).
2. You: provide form 4 art, lever art, bullet and slash art if you want them (section 1).
3. Me (no Verilog): bullet / slash pipelines once you have art, difficulty tuning, final report.
4. Me (needs Verilog, after the 22:00 freeze, separate branch): Human idle / attack / hurt / death animations (B1-B4), wall autotile and wall decoration (C1-C2).

## Files to look at

| File | What it is |
|---|---|
| `docs/SPRITE_STATUS.md` (this file) | what is final / placeholder / missing |
| `docs/NEXT_STEPS.md` | backlog with checkboxes |
| `docs/CHANGE_REVIEW.md` | everything changed on this branch, verification, rollback, board steps |
| `sprites/README.md` | how to change each sprite (plain words) |
| `sprites/*.json` | the settings: `sprites.json` (player), `tileset.json`, `monsters.json`, `bosses.json`, `puzzle.json` |
| `preview/` | pictures: `all_forms.png`, `tileset_rooms.png`, `monster_contact.png`, `boss_contact.png`, `puzzle_contact.png`, `game/*.png` (screenshots) |
| `maps/*.txt`, `maps_v1/` | room layouts (decoration characters `, ; : \``) and the untouched originals |
