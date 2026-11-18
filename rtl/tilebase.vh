// ที่อยู่ tile ใน tilemap_rom โดยไม่ใช้ตัวคูณ: grid*300 + ty*20 + tx
//   grid*300 = ตาราง 13 ค่า (LUT) · ty*20 = (ty << 4) + (ty << 2)
// ใช้ `include ภายใน module (player, objects, boss, renderer)
function [11:0] rbase(input [3:0] g);
    case (g)
        4'd0: rbase = 12'd0;    4'd1: rbase = 12'd300;  4'd2: rbase = 12'd600;  4'd3: rbase = 12'd900;
        4'd4: rbase = 12'd1200; 4'd5: rbase = 12'd1500; 4'd6: rbase = 12'd1800; 4'd7: rbase = 12'd2100;
        4'd8: rbase = 12'd2400; 4'd9: rbase = 12'd2700; 4'd10: rbase = 12'd3000; 4'd11: rbase = 12'd3300;
        4'd12: rbase = 12'd3600; default: rbase = 12'd0;
    endcase
endfunction
function [11:0] rowx20(input [3:0] ty);
    rowx20 = {4'b0, ty, 4'b0} + {6'b0, ty, 2'b0};
endfunction
