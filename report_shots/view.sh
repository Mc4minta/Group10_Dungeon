#!/usr/bin/env bash
# view.sh <glob-prefix> : make 640x480 PNG previews of dense shots in scratchpad
mkdir -p /mnt/c/Users/admin/AppData/Local/Temp/claude/283bf1d06b7219df/fe5dee6f-164f-47fc-9b59-b4f289d8baa3/scratchpad/v
python3 - "$@" <<'PY'
import sys,glob,os
from PIL import Image
out='/mnt/c/Users/admin/AppData/Local/Temp/claude/283bf1d06b7219df/fe5dee6f-164f-47fc-9b59-b4f289d8baa3/scratchpad/v'
fs=[]
for p in sys.argv[1:]: fs+=sorted(glob.glob('/tmp/g10dense/'+p+'*.bmp'))
# contact sheet 3 cols at half size
ims=[(os.path.basename(f),Image.open(f).convert('RGB').crop((0,0,640,480)).resize((320,240))) for f in fs]
from PIL import ImageDraw
cols=3; rows=(len(ims)+cols-1)//cols
sheet=Image.new('RGB',(320*cols,240*rows))
for i,(n,im) in enumerate(ims):
    d=ImageDraw.Draw(im); d.text((3,3),n[:-4],fill=(255,255,0))
    sheet.paste(im,((i%cols)*320,(i//cols)*240))
sheet.save(out+'/sheet.png'); print(len(ims))
PY
