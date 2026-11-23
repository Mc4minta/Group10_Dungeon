#!/usr/bin/env bash
# Render gameplay video from the Verilator simulation, no window.
#   tools/video/render.sh scripts/a_floor1.txt [out.mp4]
# Needs on PATH: verilator 5.x, g++, make, sdl2-config (SDL2 dev files), python3, ffmpeg (with drawtext).
# Env: FIT=pad (default, 1440x1080 inside 1920x1080) | native (1920x1440)   AUDIO=0 (no audio)
#      SEED=4660 (puzzle seed, same as 'make seeded')   REBUILD=1 (force rebuild)   KEEP=1 (keep temp files)
# The design (rtl/) is not modified. Only sim/verilator/main.cpp has the extra --raw-out option.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
SEG=${1:?usage: render.sh <segment-script> [out.mp4]}
OUT=${2:-$HERE/out/$(basename "${SEG%.*}").mp4}
FIT=${FIT:-pad}; AUDIO=${AUDIO:-1}; SEED=${SEED:-4660}
MDIR=$HERE/build/obj_seed$SEED
TMP=$(mktemp -d "${TMPDIR:-/tmp}/g10vid.XXXXXX")
[ "${KEEP:-0}" = 1 ] || trap 'rm -rf "$TMP"' EXIT
mkdir -p "$(dirname "$OUT")"
now() { date +%s.%N; }

# ---- 1. build (only when main.cpp / rtl changed) ----
if [ "${REBUILD:-0}" = 1 ] || [ ! -x "$MDIR/Vtop" ] || [ -n "$(find "$ROOT/rtl" "$ROOT/sim/verilator/main.cpp" -newer "$MDIR/Vtop" 2>/dev/null | head -1)" ]; then
  echo "[render] building Verilator model -> $MDIR"
  rm -rf "$MDIR"; mkdir -p "$MDIR"
  SDL_CF=$(sdl2-config --cflags); SDL_LD=$(sdl2-config --libs)
  # same parameters as sim/verilator/Makefile; '--default-language 1364-2005' because Verilator 5.x
  # rejects the identifier 'inside' in rtl/renderer.v (rtl/ is left untouched); -GPROLOGUE=0 because the Makefile passes it empty
  verilator --cc --exe -O3 -j 0 --top-module top -I"$ROOT/rtl" -Wno-fatal -Wno-lint -Wno-style \
    --default-language 1364-2005 -GDEBOUNCE=2000 -GCE_DIV=1 -GDEBUG=${DEBUG:-1} -GSEED=$SEED -GPROLOGUE=0 \
    --Mdir "$MDIR" --x-assign fast --x-initial fast \
    -CFLAGS "-DNDEBUG -DCE_DIV=1 -DFAST_CLOCK=1 $SDL_CF" -LDFLAGS "$SDL_LD" \
    "$ROOT"/rtl/*.v "$ROOT/sim/verilator/main.cpp" > "$TMP/verilator.log" 2>&1 || { cat "$TMP/verilator.log"; exit 1; }
  OPT="-O3 -march=native -fno-stack-protector"
  env -u CXXFLAGS -u CPPFLAGS -u CFLAGS -u DEBUG_CXXFLAGS -u DEBUG_CPPFLAGS \
    make -C "$MDIR" -f Vtop.mk -j"$(nproc)" OPT_FAST="$OPT" OPT_SLOW="$OPT" OPT_GLOBAL="$OPT" > "$TMP/make.log" 2>&1 || { tail -30 "$TMP/make.log"; exit 1; }
fi

# ---- 2. segment script -> frame script ----
python3 "$HERE/seg2script.py" "$SEG" > "$TMP/frames.txt" 2> "$TMP/total.txt"
NSIM=$(python3 "$HERE/seg2script.py" --total "$SEG")      # frames to simulate (up to the last recorded frame)
N=$(python3 "$HERE/seg2script.py" --count "$SEG")         # frames in the video
RECARG=(); while read -r r; do RECARG+=(--rec "$r"); done < <(python3 "$HERE/seg2script.py" --rec "$SEG")
echo "[render] $SEG: simulate $NSIM frames, record $N = $(python3 -c "print(round($N/60,1))") s of video"

# ---- 3. simulate headless, raw RGB24 frames through a pipe into ffmpeg ----
case "$FIT" in
  native) VF="scale=1920:1440:flags=neighbor" ;;
  pad)    VF="scale=1920:1440:flags=neighbor,scale=1440:1080:flags=area,pad=1920:1080:240:0:black" ;;
  *) echo "FIT must be pad or native"; exit 1 ;;
esac
FONT=$(fc-match -f '%{file}' "DejaVu Sans" 2>/dev/null || true)
[ -f "$FONT" ] || FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
LABEL="drawtext=fontfile=$FONT:text='PC simulation of the FPGA design':fontcolor=white:fontsize=26:box=1:boxcolor=black@0.6:boxborderw=8:x=w-tw-24:y=h-th-24"
mkfifo "$TMP/raw"
T0=$(now)
ffmpeg -v error -y -f rawvideo -pix_fmt rgb24 -s 640x480 -framerate 60 -i "$TMP/raw" \
  -vf "$VF,$LABEL,format=yuv420p" -r 60 -c:v libx264 -preset medium -crf 18 -movflags +faststart "$TMP/video.mp4" &
FFPID=$!
WAVARG=(); [ "$AUDIO" = 1 ] && WAVARG=(--wav "$TMP/audio.wav")
( cd "$ROOT/mem" && LOG=${LOG:-60} "$MDIR/Vtop" --headless --frames "$NSIM" --script-file "$TMP/frames.txt" --raw-out "$TMP/raw" "${RECARG[@]}" "${WAVARG[@]}" > "$TMP/sim.log" )
wait $FFPID
T1=$(now)
cp "$TMP/sim.log" "${OUT%.mp4}.log"      # state log (f= frame, st, floor, room, hp, form, boss ... every LOG frames)
tail -2 "$TMP/sim.log" | cut -c1-200

# ---- 4. audio: the PWM output sampled in the sim (not synthesised); stretched 0.8 % so N frames at 60 Hz = N frames at the board's 59.5 Hz ----
if [ "$AUDIO" = 1 ] && [ -s "$TMP/audio.wav" ]; then
  VD=$(python3 -c "print($N/60)")
  AD=$(python3 - "$TMP/audio.wav" <<'PY'
import sys,wave
w=wave.open(sys.argv[1]); print(w.getnframes()/w.getframerate())
PY
)
  FACT=$(python3 -c "print($AD/$VD)")
  ffmpeg -v error -y -i "$TMP/video.mp4" -i "$TMP/audio.wav" -filter_complex "[1:a]atempo=$FACT,aresample=48000[a]" \
    -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 160k -t "$VD" "$OUT"
  echo "[render] audio: wav ${AD}s vs video ${VD}s, atempo=$FACT"
else
  cp "$TMP/video.mp4" "$OUT"
fi
echo "[render] done: $OUT ($(du -h "$OUT" | cut -f1)); simulate+encode $(python3 -c "print(round($T1-$T0,1))") s"
