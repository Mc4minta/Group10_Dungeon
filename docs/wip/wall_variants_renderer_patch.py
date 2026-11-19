def edit(path, pairs):
    s = open(path, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert a in s, (path, a[:70])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)


edit('rtl/roms.v', [(
    'module tileset_rom (\n    input  wire        clk,\n    input  wire [15:0] addr,   // (floor*16 + tile)*1024 + y*32 + x\n    output reg  [11:0] data\n);\n    reg [11:0] mem [0:49151];',
    'module tileset_rom #(\n    parameter WORDS = 49152        // 48 tiles; 64 tiles (65536) when wall variants are on (rtl/tileset_cfg.vh)\n) (\n    input  wire        clk,\n    input  wire [15:0] addr,   // tile*1024 + y*32 + x ; tile = floor*16 + id, wall variants = 48 + floor*5 + k\n    output reg  [11:0] data\n);\n    reg [11:0] mem [0:WORDS-1];')])

edit('rtl/renderer.v', [
    ('    `include "sprite_cfg.vh"', '    `include "sprite_cfg.vh"\n    `include "tileset_cfg.vh"'),
    ("        r1_taddr <= {floor, tvis, vs_r[4:0], hs_r[4:0]};          // (floor*16 + tvis) = {floor, tvis}",
     "        // wall variants (visual only): a plain wall tile on the room border uses another picture, chosen by tile position\n"
     "        r1_taddr <= wv_on ? {wv_tile, vs_r[4:0], hs_r[4:0]} : {floor, tvis, vs_r[4:0], hs_r[4:0]};   // (floor*16 + tvis) = {floor, tvis}"),
    ("    reg [3:0] tvis;",
     "    // ---- wall variants: top / bottom / left / right edge + torches on the top row (same rule as scripts/build_tileset_mem.py wall_variant)\n"
     "    wire [4:0] w_tx = hs_r[9:5];\n"
     "    wire [3:0] w_ty = vs_r[8:5];\n"
     "    wire       wv_top = (w_ty == 4'd0), wv_bot = (w_ty == 4'd14), wv_l = (w_tx == 5'd0), wv_r = (w_tx == 5'd19);\n"
     "    wire       wv_torch = wv_top && (w_tx == TORCH_X0 || w_tx == TORCH_X1);\n"
     "    wire [2:0] wv_idx = wv_torch ? 3'd4 : wv_top ? 3'd0 : wv_bot ? 3'd1 : wv_l ? 3'd2 : 3'd3;      // top bottom left right torch\n"
     "    wire       wv_on = (WALL_VAR_EN != 0) && (tid == 4'h0) && (wv_top || wv_bot || wv_l || wv_r);\n"
     "    wire [5:0] wv_tile = 6'd48 + {2'b00, floor, 2'b00} + {4'b0000, floor} + {3'b000, wv_idx};      // 48 + floor*5 + idx (max 62)\n"
     "    reg [3:0] tvis;"),
    ("    tileset_rom tset (.clk(clk), .addr(r1_taddr), .data(tile_px));", "    tileset_rom #(.WORDS(TILESET_WORDS)) tset (.clk(clk), .addr(r1_taddr), .data(tile_px));"),
])
print('ok')
