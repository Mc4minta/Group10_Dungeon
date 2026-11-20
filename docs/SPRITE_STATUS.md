# Sprite status - what is final, what is a placeholder, what you still need to find or edit

**Updated every time a sprite, ROM or map changes.** Last update: on-screen health display added (section 5b: hearts for the player, health bar for the boss). Human animations are built but OFF, see section 2b.
Legend: **FINAL** = real art you are happy with. **PLACEHOLDER** = real art but a stand-in (wrong meaning, recoloured, borrowed). **OLD ART** = the original programmer placeholder from the first version (`*_v1.mem`), nothing new yet.

How to change any sprite: see `sprites/README.md`. One command for everything: `scripts/update_sprites.sh` (Windows: `scripts\update_sprites.bat`).

---

## 1. Needs YOUR art (find or draw these) - priority order

| # | Sprite | Now | What to provide | Where it goes |
|---|---|---|---|---|
| 1 | **Form 4 hero** (the final form) | PLACEHOLDER: Human sheets recoloured gold | 4x4 walk sheet (128x128, rows: front-Right, front-Left, back-Right, back-Left), optional 16-column idle sheet. Same layout as `Human/Walk.png` | put the PNGs in `my_asset/`, list them under `forms."4".sheets` in `sprites/sprites.json`, delete the `"tint"` line |
| 2 | **Player bullets and enemy bullets** | OLD ART (8x8 squares) | 8x8 px sprites in a 16x16 cell, frames: 0 form-2 shot, 1 enemy shot, 2 form-3 spread, 3 form-4 fast shot, 4 form-4 big charged shot (full 16x16) | needs a new pipeline (pack arrows are 16x32, too big): tell me and I add it |
| 3 | **Melee slash** (form 1 attack effect) | OLD ART (white arc) | 4 arcs, one per direction, 32x32 | same: I add the pipeline |
| 4 | **Levers** (lightbulb puzzle) | FINAL art from `my_asset/new_switch.png`, but the two states differ by only 12 pixels (the inner yellow dash moves 2 px) so it is hard to see on screen | optional: redraw with a bigger knob travel / a colour change between left and right | `my_asset/new_switch.png` (cells [0,0] and [1,0]) + `sprites/puzzle.json` frames 2, 3 |
| 5 | **Title screen / GAME OVER / WIN screens** | OLD ART: plain colour fills + text | optional: a logo/background (needs a ROM + renderer change, Verilog) | later |
| 6 | **Angel size** | FINAL art, now 2x (body matches Human / Orc); wing tips are cut flat at the frame edge | optional: redraw with a narrower wingspan so the wings fit whole | `sprites/sprites.json` `forms."3".scale` |
| 7 | **Orc / Angel idle sheets** | none (idle = walk frame 0) | optional: idle sheets like `Human/Idle.png` | `forms."2"/"3".sheets.idle` |

## 2. Player (mem/player.mem, 48 frames, `scripts/build_player_mem.py`)

| Form | Source | Scale | Status | Notes |
|---|---|---|---|---|
| 1 Human | `my_asset/Character/Human/Walk.png`, `Idle.png` | 2x | FINAL | idle pose = Idle.png col 0, steps = Walk col 1 / col 3 |
| 2 Orc | `my_asset/Character/ORc/form2_Walk.png` | 2x | FINAL (walk only) | no idle sheet |
| 3 Angel | `my_asset/Character/Angel/Angel_walk.png.png` | 2x | FINAL, wing tips cut at the frame edge | body now same size as the others; odd file name handled (clean copy in `my_asset/_clean/`) |
| 4 | Human sheets + gold tint | 2x | **PLACEHOLDER** | see "Needs your art" #1 |

Art available but NOT used by the game yet (needs Verilog, see NEXT_STEPS B): Human `Attack.png`, `Dmg.png`, `Jump.png`, `ChargedAttack.png`, `SoulDie.png`, `SpinDie.png`, the 16-frame idle loop.
Row 4 of every walk sheet (back facing Left) is unused: the game has only 4 directions.

## 2b. Player animations (Human built but OFF; Orc / Angel attack + red hurt flash ON since 20/11, W14 option C)

The Human (form 1) has extra pictures that the game does not show yet unless you switch them on (`sprites/sprites.json` -> `animations`, then rebuild and synthesise; each costs Block RAM):

| Animation | Source sheet | Flag | Block RAM (estimate) | State |
|---|---|---|---|---|
| idle loop (16 pictures x 4 directions) | `Human/Idle.png` | `idle_anim` | about 22 RAMB36 | built, tested, OFF |
| melee attack (4 x 4) | `Human/Attack.png` | `attack_anim` | about 6 | built, tested, OFF |
| hurt (4 x 4) | `Human/Dmg.png` | `hurt_anim` | about 6 | built, tested, OFF |
| death (12 pictures, last held; the last one is empty on purpose) | `Human/SoulDie.png` or `SpinDie.png` (`death_sheet`) | `death_anim` | about 6 | built, tested, OFF |

**W14 (option C):** the **attack ROM now holds 3 forms** (Human, Orc, Angel: 48 pictures, about 16 RAMB36 in total). Orc (`ORc/form2_Attack.png`) and Angel (`Angel/Angel_Attack.png`) show their 4 attack pictures (3 frames each) whenever they fire a shot or swing melee (flags `attack_anim_form2` / `attack_anim_form3`, ON). The **hurt** reaction of every form is a **red flash** of the sprite for 12 frames (`hurt_flash`, ON, no ROM). The Orc / Angel damage sheets (`form2_Dmg.png`, `Angel_Dmg.png`) are in `my_asset` and built into the config but unused (a hurt ROM for them would be option A). Angel wing tips are cut at the 32 px frame edge. If the Vivado build runs out of Block RAM: set `attack_anim_form2` / `attack_anim_form3` to false and rebuild (no attack ROM = about -16 RAMB36). Form 4 has no attack pictures yet.

Forms 2-4 otherwise keep the walking pictures. Nothing here is a placeholder: it is finished art waiting for a Block RAM check (`docs/NEXT_STEPS.md` P3.1).
Not used by the game at all: `Jump.png`, `ChargedAttack.png`.

## 3. Map tiles (mem/tileset.mem, `scripts/build_tileset_mem.py`, `sprites/tileset.json`)

| Tile | Art | Status |
|---|---|---|
| wall, floor, hole, fence | asset pack `Dungeon_Tileset.png` (2x) | FINAL |
| doors D / L (closed = spikes up, open = spikes down) | `my_asset/props/peaks_1.png` / `peaks_3.png` over the floor (`cut` colour, W1) | FINAL (static; a spike animation is optional polish) |
| exit E (closed = solid wall picture, open = plain floor: the maze door vanishes) | tile 0 / tile 1 cells (W1) | FINAL |
| pressure plate | pack cell r6 c9, a flat brown square | PLACEHOLDER (no detailed plate in the pack) |
| plate with box | crate over the plate | FINAL |
| floor decoration (crack, bones, skull, rubble) on floors 1-2 | pack cells | FINAL |
| Simon plates (floor 3) | red potion, blue potion, coin, key | FINAL |
| maze ball | `my_asset/props/coin_1.png`, 2x (puzzle frame 10; `sprites/puzzle.json`) | PLACEHOLDER-ish (a coin; swap the PNG) |
| overlay: breakable block `Z` / spike trap `X` (red plate + spikes) / solid decoration `Y` | `my_asset/props/box_1_1.png`, `peaks_1.png`, `candlestick_1_1.png`, 2x (`sprites/overlay.json` -> `mem/ovtile.mem`, +2 RAMB36) | FINAL art slots; swap the PNG in `overlay.json` to change |
| floor colours | floor 1 purple, 2 teal, 3 olive (recolor + gain 1.7) | FINAL (adjust in `tileset.json`) |
| wall variety (corners, tops, torches) | none: one wall id only | NOT POSSIBLE without Verilog (NEXT_STEPS C1) |

## 4. Enemies and bosses

| Sprite | Source | Status |
|---|---|---|
| Monster A (chaser) 2 frames | skeleton1 movement cols 1, 4 (`sprites/monsters.json`) | FINAL (2 frames only, no facing) |
| Monster B (turret) 2 frames | vampire idle cols 0, 3 | FINAL |
| Boss 1 (floor 1) normal / stunned | skeleton2 idle col 0 / skeleton2 damage col 2, 2x (W10: frame 1 = stunned picture) | FINAL, the stunned picture is subtle |
| Boss 2 (floor 2) 2 idle frames | skeleton1 idle cols 0, 3, 2x (blinks white while shielded = no art needed) | FINAL |
| Boss 3 (floor 3) | vampire attack frames 4, 7, 2x | FINAL |

Unused enemy art in `my_asset/enemies/`: attack, death and damage strips for all three enemies (needs Verilog).

## 5. Puzzle-room objects (mem/puzzle.mem, `scripts/build_puzzle_mem.py`, `sprites/puzzle.json`)

| Frame | Art | Status |
|---|---|---|
| bulb on / bulb off | **your** `my_asset/props/torch.mem` (frame 0 lit, frame 7 smouldering) | FINAL |
| lever up / down | **your** `my_asset/new_switch.png`: frame 1 (cell r0 c0, fully left) = up, frame 4 (cell r1 c0, fully right) = down; frames 2,3,5,6 are in-between animation (the game has no lever animation, so unused); frame 7 = fully left again | FINAL art, but the left/right difference is tiny (see #4) |
| box | iron crate | FINAL |
| gate closed / open | spikes up / retracted (background cut out) | FINAL |
| item floor 1 / 2 / 3 | gold key / silver key / red shield | FINAL |

## 5a. Pressure plates (`my_asset/props/plate.png`, tiles 7 / 11 / 12-15 in `sprites/tileset.json`)

| Use | Art | Status |
|---|---|---|
| Sokoban plates (floor 2): no box on it / box on it | **your** plate picture: row 0 raised / row 1 pressed (1:1, 32x32) | FINAL |
| Simon plates (floor 3): 4 big plates (each = 2x2 tiles, drawn as one 64x64 plate) | the same picture at half-size sampling, tinted red / blue / green / yellow (`"tint"`) | FINAL; lit = brightened raised plate (no pressed art for lit) |

The Simon map has its plates on even rows now (`maps/12_f3_puzzle_simon.txt`); tests: `tests/test_maps.py`, `scripts/run_sim.sh simonplate`.

## 5b. Health display (mem/hud.mem, `scripts/build_hud_mem.py`, `sprites/hud.json`)

| Part | Art | Status |
|---|---|---|
| player hearts (top left, one per max HP; full = HP left, dark = lost) | **your** `my_asset/ui/Hearts/PNG/basic/` (background + heart + border layers), drawn 2x = 34 px | FINAL |
| boss health bar (top right, boss room only, fill = hp / max hp) | **your** `my_asset/ui/Hearts/PNG/health_bar/` (frame + fill, fill 14 px right of the frame start), drawn 2x | FINAL |
| `my_asset/ui/MediavelFree.png` (UI sheet: wood panel, buttons, candle, sword, health bar) | copied in, not used yet (candidate for title / story panels) | UNUSED |

Positions and spacing: `HUD_*` in `rtl/params.vh`. Costs about 3 Block RAM tiles. Preview: `preview/hud_sheet.png`.

## 6. Still the original placeholders (OLD ART, never replaced)

`mem/bullet.mem`, `mem/effect.mem`, `mem/font.mem` + `mem/text.mem` (text), title/GAME OVER/WIN backgrounds (colour fills). Everything else in the game is new art.

---

## Next to implement (details in `docs/NEXT_STEPS.md`)

1. You: board test (Block RAM + WNS + how it feels), then send the art in section 1 that you want.
2. Me (no Verilog): bullet / slash pipelines once you have art, difficulty tuning from your playtest.
3. Me (needs Verilog, own branch): switch the Human animations on after the Block RAM check, wall variants (`wip/wall-variants`), sample playback.

## Files to look at

| File | What it is |
|---|---|
| `docs/SPRITE_STATUS.md` (this file) | what is final / placeholder / missing |
| `docs/NEXT_STEPS.md` | backlog with checkboxes |
| `docs/CHANGE_REVIEW.md` | everything changed on this branch, verification, rollback |
| `docs/README.md` | the project index (folders, workflow, branches) |
| `docs/SOUND_PLAN.md` | every sound and the music |
| `sprites/README.md` | how to change each sprite (plain words) |
| `sprites/*.json` | the settings: `sprites.json` (player), `tileset.json`, `monsters.json`, `bosses.json`, `puzzle.json` |
| `preview/` | pictures: `all_forms.png`, `tileset_rooms.png`, `monster_contact.png`, `boss_contact.png`, `puzzle_contact.png`, `game/*.png` (screenshots) |
| `maps/*.txt`, `maps_v1/` | room layouts (decoration characters `, ; : \``) and the untouched originals |
