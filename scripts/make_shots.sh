#!/usr/bin/env bash
# Render preview screenshots of the real renderer (no game logic) into preview/shots/*.png. Needs iverilog + python3 + Pillow.
#   scripts/make_shots.sh            all scenarios      scripts/make_shots.sh start_f1 title     only these
cd "$(dirname "$0")/../mem" || exit 2
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
mkdir -p ../preview/shots
iverilog -g2012 -I../rtl -I../sim -o ../sim/tb_shot.vvp ../sim/tb_shot.v ../rtl/renderer.v ../rtl/hud.v ../rtl/objline.v ../rtl/roms.v || exit 1
declare -A S
S[title]="+scr=1 +px=232 +py=240 +pf=9 +bact=1 +bx=352 +by=192 +bf=4"
S[start_f1]="+grid=0 +floor=0 +px=288 +py=224 +hp=4 +hpmax=4"
S[combat_f1]="+grid=4 +floor=0 +px=200 +py=200 +hp=4 +hpmax=4 +m0x=100 +m0y=60 +m0t=0 +m1x=500 +m1y=330 +m1t=0 +m2x=300 +m2y=380 +m2t=1 +doors=0"
S[combat_f2]="+grid=7 +floor=1 +px=300 +py=250 +pf=12 +hp=4 +hpmax=4 +m0x=250 +m0y=190 +m0t=0 +m1x=380 +m1y=190 +m1t=0"
S[combat_f3]="+grid=10 +floor=2 +px=300 +py=330 +pf=24 +hp=3 +hpmax=4 +m0x=130 +m0y=100 +m0t=0 +m1x=470 +m1y=100 +m1t=0 +m2x=96 +m2y=340 +m2t=1"
S[boss1]="+grid=2 +floor=0 +px=100 +py=240 +hp=4 +hpmax=4 +bact=1 +bx=304 +by=208 +bf=0"
S[boss2]="+grid=3 +floor=1 +px=100 +py=240 +pf=12 +hp=4 +hpmax=4 +bact=1 +bx=272 +by=208 +bf=2"
S[boss3]="+grid=2 +floor=2 +px=100 +py=240 +pf=36 +hp=4 +hpmax=4 +bact=1 +bx=304 +by=208 +bf=4"
S[puzzle_f1]="+grid=6 +floor=0 +px=300 +py=300 +hp=4 +hpmax=4"
S[sokoban_f2]="+grid=9 +floor=1 +px=300 +py=300 +hp=4 +hpmax=4"
S[simon_f3]="+grid=12 +floor=2 +px=300 +py=380 +pf=36 +hp=4 +hpmax=4"
S[maze]="+scr=5 +floor=2 +grid=1 +pz0f=10 +pz0x=32 +pz0y=32"
S[start_f3]="+grid=1 +floor=2 +px=300 +py=300 +pf=36 +hp=4 +hpmax=4"
names=("$@"); [ ${#names[@]} -eq 0 ] && names=(title start_f1 combat_f1 combat_f2 combat_f3 boss1 boss2 boss3 puzzle_f1 sokoban_f2 simon_f3 maze start_f3)
for n in "${names[@]}"; do
  vvp ../sim/tb_shot.vvp ${S[$n]} +out=../preview/shots/$n.ppm > /dev/null
  $PY -c "from PIL import Image; Image.open('../preview/shots/$n.ppm').resize((640,480)).save('../preview/shots/$n.png')"
  rm -f ../preview/shots/$n.ppm
  echo "preview/shots/$n.png"
done
