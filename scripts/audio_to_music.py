#!/usr/bin/env python3
"""Turn the MELODY of an audio file (mp3 / wav ...) into a track for the game's music engine (square-wave notes).

    python scripts/audio_to_music.py my_audio/connect_madoka.mp3 --start 0 --duration 45 --out sprites/music/connect.txt
    python scripts/audio_to_music.py song.wav --preview preview/sound/song.wav   # also write a WAV of how the game will sound

What it does (honest limits): it finds ONE pitch every 1/60 s (YIN pitch tracker, vocal range), turns that into notes, merges/simplifies until it fits the
music ROM (at most 127 entries per track, each 1..255 frames) and writes them as text "C5:12 D5:8 R:4 ..." (R = rest, number = frames of 1/60 s).
It works on a clear single melody (a lead voice or instrument). On a full mix with chords and drums the result is only the dominant line - listen to the
--preview WAV and use --transpose / --fmin / --fmax / --min-frames to improve it, or edit the text by hand.
The game plays two square-wave voices at most, so this is a chiptune version, never the recording.
Needs ffmpeg (WSL: apt has it) for anything that is not already a WAV; numpy for the maths.

Exit code: 0 ok | 2 bad input (file missing, ffmpeg missing and not a wav, no melody found).
"""
import argparse
import math
import os
import shutil
import subprocess
import sys
import tempfile
import wave

try:
    import numpy as np
except ImportError:  # pragma: no cover
    print("ERROR: numpy is required (pip install numpy)")
    sys.exit(2)

FPS = 60                      # game frames per second
SR = 16000                    # analysis sample rate
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
MIN_MIDI, MAX_MIDI = 55, 96   # G3 (196 Hz, lowest the 18-bit half-period allows) .. C7
MAX_ENTRIES = 127             # entries per track in mem/music.mem (128, the last one must be the end marker)
MAX_DUR = 255


class InputError(Exception):
    pass


def midi_name(m):
    return f"{NAMES[m % 12]}{m // 12 - 1}"


def read_wav(path):
    with wave.open(path) as w:
        n = w.getnframes()
        ch = w.getnchannels()
        sw = w.getsampwidth()
        sr = w.getframerate()
        raw = w.readframes(n)
    if sw != 2:
        raise InputError("WAV must be 16 bit")
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return x, sr


def load_audio(path, start, duration):
    """-> float32 mono samples at SR (via ffmpeg when needed)"""
    if not os.path.isfile(path):
        raise InputError(f"file not found: {path}")
    tmp = None
    try:
        ff = shutil.which("ffmpeg")
        if ff is None and path.lower().endswith(".wav"):
            x, sr = read_wav(path)
            if sr != SR:
                x = np.interp(np.arange(0, len(x), sr / SR), np.arange(len(x)), x).astype(np.float32)
            a, b = int(start * SR), int((start + duration) * SR) if duration else len(x)
            return x[a:b]
        if ff is None:
            raise InputError("ffmpeg not found (needed for mp3 etc.): install ffmpeg or convert the file to a 16-bit WAV first")
        fd, tmp = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        cmd = [ff, "-v", "error", "-y", "-ss", str(start)] + (["-t", str(duration)] if duration else []) + \
              ["-i", path, "-ac", "1", "-ar", str(SR), tmp]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            raise InputError("ffmpeg failed: " + r.stderr.strip()[:200])
        x, sr = read_wav(tmp)
        return x
    finally:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)


def yin_frame(x, c, fmin, fmax, thr):
    """YIN on the window around sample c. -> (f0 or 0, confidence 0..1)"""
    w = 1024
    tmax = int(SR / fmin)
    tmin = max(2, int(SR / fmax))
    a = c - w // 2
    seg = x[max(0, a):a + w + tmax]
    if len(seg) < w + tmax:
        return 0.0, 0.0
    s = seg[:w]
    if float(np.sqrt((s * s).mean())) < 0.01:                  # silence
        return 0.0, 0.0
    # difference function via FFT autocorrelation
    n = 1
    while n < len(seg) + w:
        n *= 2
    fs = np.fft.rfft(seg, n)
    fw = np.fft.rfft(s, n)
    acf = np.fft.irfft(fs * np.conj(fw), n)[:tmax + 1]
    cs = np.concatenate(([0.0], np.cumsum(seg * seg)))
    e_w = cs[w] - cs[0]
    e_shift = cs[w + np.arange(tmax + 1)] - cs[np.arange(tmax + 1)]
    d = e_w + e_shift - 2.0 * acf
    d[0] = 0.0
    cm = np.ones_like(d)
    run = np.cumsum(d[1:])
    cm[1:] = d[1:] * np.arange(1, tmax + 1) / np.maximum(run, 1e-9)
    t = None
    for tau in range(tmin, tmax):
        if cm[tau] < thr:
            while tau + 1 < tmax and cm[tau + 1] < cm[tau]:
                tau += 1
            t = tau
            break
    if t is None:
        return 0.0, 0.0
    if 1 < t < tmax:                                           # parabolic refinement
        y0, y1, y2 = cm[t - 1], cm[t], cm[t + 1]
        den = y0 - 2 * y1 + y2
        off = 0.5 * (y0 - y2) / den if abs(den) > 1e-9 else 0.0
        t = t + max(-1.0, min(1.0, off))
    return SR / t, float(1.0 - cm[int(round(t))])


def track_pitch(x, fmin, fmax, thr):
    nfr = int(len(x) / SR * FPS)
    hop = SR / FPS
    midi = np.zeros(nfr, dtype=np.int32)
    conf = np.zeros(nfr, dtype=np.float32)
    for i in range(nfr):
        f, cf = yin_frame(x, int(i * hop) + 512, fmin, fmax, thr)
        if f > 0:
            midi[i] = int(round(69 + 12 * math.log2(f / 440.0)))
            conf[i] = cf
    return midi, conf


def fold_octave(m):
    while m > MAX_MIDI:
        m -= 12
    while 0 < m < MIN_MIDI:
        m += 12
    return m


def clean(midi, transpose):
    """median smooth, octave-jump repair, transpose, fold into the hardware range"""
    m = midi.copy()
    n = len(m)
    sm = m.copy()
    for i in range(n):
        win = [v for v in m[max(0, i - 2):i + 3] if v > 0]
        sm[i] = int(np.median(win)) if len(win) >= 3 else 0
    prev = 0
    for i in range(n):
        v = sm[i]
        if v == 0:
            continue
        if prev:
            while v - prev > 7:                                # octave errors: stay near the previous note
                v -= 12
            while prev - v > 7:
                v += 12
        sm[i] = v
        prev = v
    out = np.where(sm > 0, sm + transpose, 0)
    return np.array([fold_octave(int(v)) if v > 0 else 0 for v in out], dtype=np.int32)


def to_notes(m, min_frames, rest_frames):
    """frame-wise midi -> [(midi|0, frames)]"""
    runs = []
    for v in m:
        if runs and runs[-1][0] == v:
            runs[-1][1] += 1
        else:
            runs.append([int(v), 1])
    # drop very short notes: absorb into the previous run
    changed = True
    while changed:
        changed = False
        out = []
        for v, n in runs:
            if n < (rest_frames if v == 0 else min_frames) and out:
                out[-1][1] += n
                changed = True
            else:
                out.append([v, n])
        merged = []
        for v, n in out:
            if merged and merged[-1][0] == v:
                merged[-1][1] += n
                changed = changed or False
            else:
                merged.append([v, n])
        runs = merged
    # split anything longer than 255 frames
    res = []
    for v, n in runs:
        while n > MAX_DUR:
            res.append((v, MAX_DUR))
            n -= MAX_DUR
        if n:
            res.append((v, n))
    return res


def fit(m, max_entries, min_frames, rest_frames):
    """raise min_frames until the notes fit the ROM"""
    mf = min_frames
    while True:
        notes = to_notes(m, mf, rest_frames)
        while notes and notes[0][0] == 0:
            notes = notes[1:]
        if len(notes) <= max_entries or mf > 60:
            return notes[:max_entries], mf
        mf += 1


def estimate_grid(notes):
    """beat length in frames: median of the shorter half of the notes"""
    d = sorted(n for v, n in notes if v and n >= 6)
    if not d:
        return 0.0
    short = d[:max(1, len(d) // 2)]
    return float(short[len(short) // 2])


def snap(notes, grid):
    """snap every duration to a multiple of the beat length (keeps the rhythm steady); rests too"""
    out = []
    for v, n in notes:
        units = max(1, int(round(n / grid)))
        out.append((v, min(MAX_DUR, int(round(units * grid)))))
    return out


def render_wav(notes, path, sr=22050):
    """square-wave rendition (what the game does: one square wave, +/- amplitude)"""
    out = []
    ph = 0.0
    for v, n in notes:
        ns = int(n / FPS * sr)
        if v == 0:
            out.append(np.zeros(ns, dtype=np.float32))
            continue
        f = 440.0 * 2 ** ((v - 69) / 12.0)
        t = (np.arange(ns) / sr) * f + ph
        ph = float(t[-1] % 1.0) if ns else ph
        out.append((np.where((t % 1.0) < 0.5, 0.25, -0.25)).astype(np.float32))
    y = np.concatenate(out) if out else np.zeros(1, dtype=np.float32)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((y * 32767).astype(np.int16).tobytes())


def chroma_similarity(x, notes):
    """cosine similarity of the pitch-class energy of the original and of the notes (1.0 = same key / same notes)"""
    seg = x[:SR * 60]
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    freqs = np.fft.rfftfreq(len(seg), 1 / SR)
    sel = (freqs > 190) & (freqs < 2000)
    pcs = np.round(69 + 12 * np.log2(freqs[sel] / 440.0)).astype(int) % 12
    a = np.bincount(pcs, weights=spec[sel] ** 2, minlength=12)
    b = np.zeros(12)
    for v, n in notes:
        if v:
            b[v % 12] += n
    if a.sum() == 0 or b.sum() == 0:
        return 0.0
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    return float(a @ b)


def notes_to_text(notes):
    return " ".join(("R" if v == 0 else midi_name(v)) + ":" + str(n) for v, n in notes)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Melody of an audio file -> game music track text.")
    ap.add_argument("input")
    ap.add_argument("--out", default=None, help="write the track text here (default: print)")
    ap.add_argument("--start", type=float, default=0.0, help="start second in the file")
    ap.add_argument("--duration", type=float, default=0.0, help="seconds to convert (0 = to the end, but the ROM holds about 127 notes)")
    ap.add_argument("--fmin", type=float, default=196.0)
    ap.add_argument("--fmax", type=float, default=1000.0)
    ap.add_argument("--threshold", type=float, default=0.15, help="YIN threshold: lower = stricter pitch detection")
    ap.add_argument("--min-frames", type=int, default=4, help="shortest note in 1/60 s frames (raised automatically until the track fits)")
    ap.add_argument("--rest-frames", type=int, default=4, help="shortest rest kept (shorter silence is joined to the previous note)")
    ap.add_argument("--transpose", type=int, default=0, help="semitones (octave shifts are applied automatically to fit the speaker range)")
    ap.add_argument("--grid", default="0", help="snap note lengths to a beat of this many frames (a number), or 'auto' to estimate it; 0 = off")
    ap.add_argument("--max-notes", type=int, default=MAX_ENTRIES)
    ap.add_argument("--preview", default=None, help="write a WAV of the square-wave version")
    a = ap.parse_args(argv)
    try:
        x = load_audio(a.input, a.start, a.duration)
        if len(x) < SR:
            raise InputError("audio shorter than 1 second")
        midi, conf = track_pitch(x, a.fmin, a.fmax, a.threshold)
        voiced = float((midi > 0).mean())
        if voiced < 0.15:
            raise InputError(f"no clear melody found (only {voiced:.0%} of the frames have a stable pitch): "
                             f"try --fmin/--fmax, a lower --threshold, or a section with a clearer lead line")
        m = clean(midi, a.transpose)
        notes, mf = fit(m, a.max_notes, a.min_frames, a.rest_frames)
    except InputError as e:
        print(f"ERROR: {e}")
        return 2
    g = estimate_grid(notes) if a.grid == "auto" else float(a.grid)
    if g > 0:
        notes = snap(notes, g)
        print(f"rhythm: note lengths snapped to a beat of {g:g} frames ({60.0 * FPS / (2 * g):.0f} bpm if the beat is an eighth note)")
    else:
        eg = estimate_grid(notes)
        if eg:
            print(f"hint: the beat looks like about {eg:g} frames; use --grid {eg:g} to snap the rhythm")
    total = sum(n for _, n in notes)
    pitched = [v for v, _ in notes if v]
    print(f"input {a.input}: {len(x) / SR:.1f} s analysed, pitch found in {voiced:.0%} of the frames")
    print(f"track: {len(notes)} entries, {total / FPS:.1f} s, notes {midi_name(min(pitched))}..{midi_name(max(pitched))}, shortest note kept = {mf} frames")
    print(f"key agreement with the original (pitch-class cosine, 1.0 = perfect): {chroma_similarity(x, notes):.2f}")
    text = "# generated by scripts/audio_to_music.py from " + os.path.basename(a.input) + f" (start {a.start}s, {total / FPS:.1f} s)\n# unit=1 (numbers are frames of 1/60 s)\n" + notes_to_text(notes) + "\n"
    if a.out:
        os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
        with open(a.out, "w", encoding="utf-8", newline="") as f:
            f.write(text)
        print(f"wrote {a.out}")
    else:
        print(text)
    if a.preview:
        os.makedirs(os.path.dirname(os.path.abspath(a.preview)), exist_ok=True)
        render_wav(notes, a.preview)
        print(f"wrote preview {a.preview}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
