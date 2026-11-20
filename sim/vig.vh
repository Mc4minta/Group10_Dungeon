// reference model of the renderer's vignette (rtl/renderer.v): the tiles get darker towards the screen edges, `fade` adds levels
function [11:0] vig_shade(input [11:0] c, input integer x, input integer y, input integer fade);
    integer vdx, vdy, vx, vy, vm, lvl, r, g, b;
    begin
        vdx = (x >= 320) ? x - 320 : 320 - x;
        vdy = (y >= 240) ? y - 240 : 240 - y;
        vx = vdx / 8; vy = (vdy + vdy / 4) / 8;
        vm = vx * vx + vy * vy;
        lvl = (vm >= 2500) ? 3 : (vm >= 1900) ? 2 : (vm >= 1400) ? 1 : 0;
        lvl = lvl + fade; if (lvl > 3) lvl = 3;
        r = c[11:8]; g = c[7:4]; b = c[3:0];
        r = (r > lvl) ? r - lvl : 0; g = (g > lvl) ? g - lvl : 0; b = (b > lvl) ? b - lvl : 0;
        vig_shade = {r[3:0], g[3:0], b[3:0]};
    end
endfunction
