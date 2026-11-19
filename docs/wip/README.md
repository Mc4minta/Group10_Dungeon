# WIP: wall variants (not finished, not in `sprite-zip`)

Goal: border walls of every room get their own pictures (top wall with torches, left / right strips, bottom wall face), chosen by tile position in the renderer.
Status of the pieces:

| Piece | State |
|---|---|
| Art mapping (`sprites/tileset.json` -> `wall_variants`, cells chosen: top r0c2, bottom r5c2, left r1c0, right r2c5, torch r9c0 on top) | done, looks right in `preview/tileset_rooms.png` (build with `--config sprites/tileset_on_test.json --check --preview`) |
| Builder (`scripts/build_tileset_mem.py`): 64-tile `tileset.mem` when enabled, generated `rtl/tileset_cfg.vh` (`WALL_VAR_EN`, `TILESET_WORDS`, `TORCH_X0/1`) | done, default OFF; Python tests for it NOT written yet |
| Renderer (`rtl/renderer.v`, `rtl/roms.v`): position rule + `tileset_rom #(WORDS)` | NOT applied: the exact edits are in `docs/wip/wall_variants_renderer_patch.py` (run it from the repo root, it edits `rtl/roms.v` and `rtl/renderer.v`) |
| Whole-system test (`scripts/test_wall_variants.sh`) | written, never run |
| Block RAM | +16 tiles = about +6 RAMB36 when enabled; measure in Vivado |

To finish: write `rtl/tileset_cfg.vh` (run the builder once), apply the renderer patch, add Python tests (variant tiles, torch over top, fallback to the plain wall, header), run `scripts/test_wall_variants.sh` and `scripts/run_sim.sh all`, look at the captured frames, then synthesise.
