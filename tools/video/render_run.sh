#!/usr/bin/env bash
# Replay recorded inputs headless on the seeded build and render a clean 60 fps 1920x1080 MP4 with sound.
#   tools/video/render_run.sh RUN.txt OUT.mp4
#   tools/video/render_run.sh run_floor1.txt run_floor2.txt run_boss.txt OUT.mp4     several recordings -> one MP4 (in order)
#   tools/video/render_run.sh RUN.txt                                                -> tools/video/out/<RUN>.mp4
# (The last argument is the output when it ends in .mp4.)
#
# Needs (Linux / WSL): ffmpeg + ffprobe (with the drawtext filter), python3, mkfifo, and the SEEDED build:
#   cd sim/verilator && make SEED=0x1234        -> sim/verilator/obj_dir_seeded/Vtop
# Env:  FIT=nearest (default: x2.25 nearest neighbour to 1440x1080, black bars left/right, pixels stay hard-edged)
#       FIT=smooth3 (x3 nearest to 1920x1440, then 'area' down to 1440x1080: even pixel sizes, slightly soft edges)
#       AUDIO=0      no sound            KEEP=1  keep the temp dir (frames pipe is never stored: it goes straight into ffmpeg)
#       VTOP=...     other binary        LOG=60  print the game state every 60 frames into <OUT>.log
#       LABEL='...'  overlay text (bottom left)        FRAMES=<n>  simulate only the first n frames of each run
#
# How it works, per recording:
#   1. Vtop --headless --script-file RUN --raw-out <fifo> --wav w.wav : every simulated VGA frame (640x480 RGB24) is piped to ffmpeg
#      (no disk space needed: 1 minute = 3600 frames = 3 GB raw)
#   2. ffmpeg: 640x480 @ 60 fps -> nearest-neighbour scale -> pad to 1920x1080 -> drawtext -> H.264 CRF 20 veryfast yuv420p (video only)
#   3. audio: the PWM output sampled by Vtop (mono 48.8 kHz, game time). One frame of the board lasts 16.8 ms (59.5 Hz) but the video plays at
#      60 Hz, so the audio is sped up by atempo = audio_seconds / video_seconds (about 1.008, pitch kept) and padded/trimmed to exactly
#      frames/60 seconds at 48 kHz. Every recording gets its own exact-length wav, so nothing drifts when several are joined.
#   4. all pieces: video joined with the concat demuxer (stream copy), wavs joined sample-exact, then muxed once, audio AAC 192k.
# A recording that contains '# render-range: A B' (made by trim_run.py) is simulated from frame 0 to B and only frames A..B go in the video.
# Not rendered: the board. The label says so: this is a PC simulation of the FPGA design.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
[ $# -ge 1 ] || { sed -n 2,6p "$0"; exit 2; }

ARGS=("$@"); LAST=${ARGS[$((${#ARGS[@]}-1))]}
case "$LAST" in
  *.mp4) OUT=$LAST; unset 'ARGS[$((${#ARGS[@]}-1))]' ;;
  *)     OUT=$HERE/out/$(basename "${ARGS[0]%.*}").mp4 ;;
esac
RUNS=("${ARGS[@]}")
[ ${#RUNS[@]} -ge 1 ] || { echo "no recording given"; exit 2; }
for r in "${RUNS[@]}"; do [ -f "$r" ] || { echo "no such recording: $r"; exit 2; }; done

VTOP=${VTOP:-$ROOT/sim/verilator/obj_dir_seeded/Vtop}
FIT=${FIT:-nearest}; AUDIO=${AUDIO:-1}
LABEL=${LABEL:-PC simulation of the FPGA design}
for t in ffmpeg ffprobe mkfifo; do command -v $t >/dev/null 2>&1 || { echo "missing tool: $t"; exit 2; }; done
[ -x "$VTOP" ] || { echo "missing $VTOP - build it:  cd sim/verilator && make SEED=0x1234"; exit 2; }
ffmpeg -hide_banner -filters 2>/dev/null | grep -q drawtext || { echo "this ffmpeg has no drawtext filter (needs libfreetype)"; exit 2; }
if [ -n "$(find "$ROOT/rtl" "$ROOT/sim/verilator/main.cpp" -newer "$VTOP" 2>/dev/null | head -1)" ]; then
  echo "WARNING: rtl/ or main.cpp is newer than $VTOP - rebuild it (make SEED=0x1234) so the replay matches the recording"
fi
case "$FIT" in
  nearest) VF="scale=1440:1080:flags=neighbor,pad=1920:1080:240:0:black" ;;
  smooth3) VF="scale=1920:1440:flags=neighbor,scale=1440:1080:flags=area,pad=1920:1080:240:0:black" ;;
  *) echo "FIT must be nearest or smooth3"; exit 2 ;;
esac
FONT=$(fc-match -f '%{file}' "DejaVu Sans" 2>/dev/null || true)
[ -f "${FONT:-}" ] || FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
[ -f "$FONT" ] || { echo "no font found for the label (install fonts-dejavu-core)"; exit 2; }
DRAW="drawtext=fontfile=$FONT:text='$LABEL':fontcolor=white:fontsize=22:box=1:boxcolor=black@0.55:boxborderw=6:x=18:y=h-th-18"

T=$(mktemp -d "${TMPDIR:-/tmp}/g10render.XXXXXX")
[ "${KEEP:-0}" = 1 ] && echo "[render] temp dir kept: $T" || trap 'rm -rf "$T"' EXIT
mkdir -p "$(dirname "$OUT")"
FPS=60
USER_FRAMES=${FRAMES:-}                                          # FRAMES=n from the environment limits every run
i=0; : > "$T/vlist.txt"; : > "$T/alist.txt"; TOTAL_FRAMES=0

for RUN in "${RUNS[@]}"; do
  i=$((i+1)); RUNABS=$(cd "$(dirname "$RUN")" && pwd)/$(basename "$RUN")
  eval "$($PY "$HERE/runinfo.py" "$RUNABS")"                     # sets FRAMES VID_A VID_B SEED SKIP
  if [ -n "$USER_FRAMES" ]; then FRAMES=$USER_FRAMES; [ "$VID_B" -gt "$FRAMES" ] && VID_B=$FRAMES; fi
  RECARG=()
  if [ "$VID_A" -gt 1 ] || [ "$VID_B" -lt "$FRAMES" ]; then RECARG=(--rec "$VID_A:$VID_B"); fi
  NV=$((VID_B - VID_A + 1))                                      # frames in this video part
  VD=$($PY -c "print($NV/$FPS)")
  echo "[render] ($i/${#RUNS[@]}) $RUN: simulate $FRAMES frames, video frames $VID_A..$VID_B = $NV = ${VD}s"
  mkfifo "$T/raw$i"
  ffmpeg -v error -y -f rawvideo -pix_fmt rgb24 -s 640x480 -framerate $FPS -i "$T/raw$i" \
    -vf "$VF,$DRAW,format=yuv420p" -r $FPS -c:v libx264 -preset veryfast -crf 20 -an "$T/v$i.mp4" &
  FFPID=$!
  WAVARG=(); [ "$AUDIO" = 1 ] && WAVARG=(--wav "$T/w$i.wav")
  T0=$(date +%s)
  if ! ( cd "$ROOT/mem" && LOG=${LOG:-0} "$VTOP" --headless --frames "$FRAMES" --script-file "$RUNABS" --raw-out "$T/raw$i" "${RECARG[@]}" "${WAVARG[@]}" > "$T/sim$i.log" 2>&1 ); then
    echo "simulation failed:"; tail -5 "$T/sim$i.log"; kill $FFPID 2>/dev/null; exit 1
  fi
  wait $FFPID || { echo "ffmpeg failed on part $i"; exit 1; }
  echo "[render]   simulated+encoded in $(( $(date +%s) - T0 )) s; $(tail -1 "$T/sim$i.log" | cut -c1-120)"
  [ "${LOG:-0}" != 0 ] && cat "$T/sim$i.log" >> "${OUT%.mp4}.log"
  VFR=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$T/v$i.mp4")
  [ "$VFR" = "$NV" ] || echo "WARNING: part $i has $VFR video frames, expected $NV (the simulation ended early?)"
  echo "file '$T/v$i.mp4'" >> "$T/vlist.txt"
  TOTAL_FRAMES=$((TOTAL_FRAMES + VFR))

  if [ "$AUDIO" = 1 ]; then
    AD=$($PY - "$T/w$i.wav" <<'PY'
import sys, wave
w = wave.open(sys.argv[1]); print(w.getnframes() / w.getframerate())
PY
)
    VDREAL=$($PY -c "print($VFR/$FPS)")
    FACT=$($PY -c "print($AD/$VDREAL)")
    # sped up by FACT, resampled to 48 kHz, padded with silence / cut to exactly the video length
    ffmpeg -v error -y -i "$T/w$i.wav" -af "atempo=$FACT,aresample=48000,apad=whole_dur=$VDREAL,atrim=end=$VDREAL" -ar 48000 -ac 2 -c:a pcm_s16le "$T/a$i.wav" || exit 1
    echo "[render]   audio ${AD}s of game time vs video ${VDREAL}s: atempo=$FACT ($($PY -c "print(round(($FACT-1)*100,2))") % speed-up)"
    echo "file '$T/a$i.wav'" >> "$T/alist.txt"
  fi
done

# ---- join + mux ----
ffmpeg -v error -y -f concat -safe 0 -i "$T/vlist.txt" -c copy "$T/video_all.mp4" || exit 1
if [ "$AUDIO" = 1 ]; then
  ffmpeg -v error -y -f concat -safe 0 -i "$T/alist.txt" -c copy "$T/audio_all.wav" || exit 1
  ffmpeg -v error -y -i "$T/video_all.mp4" -i "$T/audio_all.wav" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -movflags +faststart "$OUT" || exit 1
else
  ffmpeg -v error -y -i "$T/video_all.mp4" -c copy -movflags +faststart "$OUT" || exit 1
fi

# ---- report ----
echo "[render] done: $OUT ($(du -h "$OUT" | cut -f1)), $TOTAL_FRAMES frames"
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate,nb_frames,duration -of default=nw=1 "$OUT"
VDUR=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of csv=p=0 "$OUT")
echo "[render] video duration ${VDUR}s (expected $($PY -c "print($TOTAL_FRAMES/$FPS)")s)"
if [ "$AUDIO" = 1 ]; then
  ADUR=$(ffprobe -v error -select_streams a:0 -show_entries stream=duration -of csv=p=0 "$OUT")
  echo "[render] audio duration ${ADUR}s; drift (audio - video) = $($PY -c "print(round(($ADUR-$VDUR)*1000,1))") ms"
fi
