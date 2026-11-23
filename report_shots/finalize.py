#!/usr/bin/env python3
"""Copy the chosen frames (Vtop --shot-at BMPs of the exploration runs in /tmp/g10dense) to /tmp/g10shots/<name>.bmp.
Usage: finalize.py name=job:frame ...    (only the given figures)"""
import shutil, sys, os
os.makedirs("/tmp/g10shots", exist_ok=True)
for a in sys.argv[1:]:
    name, jf = a.split("="); job, fr = jf.split(":")
    src = f"/tmp/g10dense/{job}_f{int(fr):05d}.bmp"
    shutil.copyfile(src, f"/tmp/g10shots/{name}.bmp"); print(src, "->", name)
