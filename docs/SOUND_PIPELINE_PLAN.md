# Plan: how to turn ANY sound into the game (for you to edit and approve)

**Status 23/11/2026: PLANNED ONLY - none of the tools in this plan exist (no `scripts/audio_to_sfx.py`, no MIDI converter, no sample player in `rtl/`).** Only `scripts/audio_to_music.py` and `scripts/make_music.py` are built.

Edit this file, tick `[x]` on what you approve, answer the questions at the bottom, then tell me "approved".
Background: `docs/SOUND_PLAN.md` (what the game sounds like now and why MP3 cannot play directly).

Rules as for the sprites: Rule 1 (the game always builds; a missing or bad sound file falls back to the current sound with a warning), no game-logic
change, settings in one JSON file, generated `.mem`/`.vh` files, tests for every tool, nothing merged to `main` without your word.

---

## 0. The idea in one picture

    your sound (mp3 / wav / ogg / MIDI / a melody you hum)
            |
            v   ffmpeg (already installed in WSL)  -> clean mono WAV
            |
      +-----+------------------+---------------------------+
      |                        |                           |
   ROUTE 1: SFX fit        ROUTE 2: music              ROUTE 3: samples
   (short tone-like        (melody -> notes for        (the real recording,
    sound -> 3 numbers)     the music engine)           stored in block RAM)
      |                        |                           |
   params.vh               mem/music.mem               mem/sample_*.mem + sample player
      |                        |                           |
      +------------ the game (square waves + PWM output) --+

Pick the route by the kind of sound:

| Your sound is... | Use | Result |
|---|---|---|
| a short beep / laser / blip / coin sound | ROUTE 1 (SFX fit) | sounds like an 8-bit version, costs no extra memory |
| a melody you want as game music (single line, no singing) | ROUTE 2 (music) | chiptune version of your melody |
| a MIDI file | ROUTE 2 (best quality, exact notes) | exact notes, 2 voices at most |
| a voice line, a roar, an explosion, a real instrument, anything noisy | ROUTE 3 (samples) | the real recording, but short and "old phone" quality |
| a full song as an MP3 | not possible directly | use ROUTE 2 for the main melody, or ROUTE 3 for a 2-3 s hook only |

---

## 1. ROUTE 1 - sound effect fit (smallest job, do first)

Idea: our effects are square-wave sweeps with 3 numbers: start pitch (`HP`), slide (`SL`) and length (`LEN`). A tool listens to a short clip, finds the pitch
at the start and at the end and the length, and writes the three numbers.

- [ ] **R1.1** `scripts/audio_to_sfx.py clip.wav --name HIT` prints ready lines for `rtl/params.vh`:
  `localparam [17:0] SFX_HIT_HP = ...; localparam signed [17:0] SFX_HIT_SL = ...; localparam SFX_HIT_LEN = ...;` plus the pitch in Hz it found, so you can check it.
- [ ] **R1.2** `sprites/sound.json` section `"sfx"`: for each of the 12 effects either `"tone": {…}` (today's numbers) or `"from": "sounds/hit.wav"`. A build script writes
  the values into `rtl/sfx_cfg.vh` (generated) instead of hand-editing `params.vh`.
- [ ] **R1.3** A WAV preview of every effect as the game will play it (`preview/sound/sfx_*.wav`), so you can listen on the PC before building the board.
- Limits: one tone at a time, pitch 190 Hz .. 100 kHz range in the hardware, length up to 255 frames (4 s). Noise sounds (explosions) turn into a low buzz.
- Effort: about 1 hour. Needs Verilog? Only the generated header include.

## 2. ROUTE 2 - music from a melody or MIDI

- [ ] **R2.1** `scripts/midi_to_music.py song.mid --track 6` (best): reads the MIDI notes, keeps the highest note of the lead channel, writes the text lines used by `make_music.py`
  (`C5:2 E5:2 ...`), so you can edit it by hand afterwards.
- [ ] **R2.2** `scripts/audio_to_music.py melody.mp3 --track 6`: for a recording of a single melody (a whistled tune, a lead instrument). Finds the pitch every 1/60 s,
  merges equal notes, rounds to semitones, drops anything shorter than 2 frames. Does NOT work on full mixes, chords, drums or singing; it tells you when the result is poor.
- [ ] **R2.3** More tracks: the music ROM has 6 tracks x 128 notes (`mem/music.mem`, 768 words). New tracks (title screen, boss room, story) need the ROM and the track
  selection in `top.v` to grow: a small Verilog change (tracks 6-7 and a rule for when they play). Limits: 127 notes per track, 255 frames per note.
- [ ] **R2.4** Music preview WAV (`preview/sound/track_N.wav`) rendered by the same engine rules.
- Effort: R2.1 and R2.2 about 2 hours; R2.3 about 1 hour plus tests.

## 3. ROUTE 3 - real recordings (samples in block RAM)

How it works: the clip is converted to 8-bit mono at a low sample rate and stored in a ROM. A new `rtl/sample_player.v` reads one sample every
`100 MHz / rate` clocks and adds it to the output mix (the output is already an 8-bit number that goes to the PWM pin).

- [ ] **R3.1** `scripts/make_samples.py` runs ffmpeg for every file listed in `sprites/sound.json` -> `mem/sample.mem` (all clips in one ROM, with an index table) and the generated
  header `rtl/sample_cfg.vh` (number of clips, start address, length of each). Reports the block RAM it will use.
- [ ] **R3.2** `rtl/sample_player.v` + a mixer input in `rtl/audio.v`: one clip at a time, new clip cuts the old one (or is dropped, per priority), clips can be triggered by any existing
  game event (hurt, die, boss appears, item, win, evolve ...) or by a new event (story line start).
- [ ] **R3.3** `iverilog` tests (`tb_sample_player.v`): the right sample reaches the output at the right time, a clip ends, priority works; Python tests for the converter (length, rate, 8-bit range, missing file -> warning, never crash).
- [ ] **R3.4** The clip list in `sprites/sound.json`: `{ "file": "sounds/boss_roar.mp3", "trigger": "boss_appears", "rate": 8000, "max_seconds": 2 }`. A missing file means the old tone plays.

Memory budget (the whole chip has 135 RAMB36 = 4.8 Mbit; the game already uses part of it, the exact number comes from your Vivado utilization report):

| Rate / bits | Per second | RAMB36 per second | 2 s clip |
|---|---|---|---|
| 8 kHz, 8 bit (default) | 8 KB | about 1.8 | about 4 |
| 6 kHz, 8 bit | 6 KB | about 1.4 | about 3 |
| 11 kHz, 8 bit | 11 KB | about 2.5 | about 5 |
| 8 kHz, 4 bit (ADPCM, later) | 4 KB | about 0.9 | about 2 |

Realistic total: 5-10 seconds of clips (10-18 RAMB36) if the report shows that much free. If it does not fit, the build says so and I lower the rate or cut a clip, never the sprites.
Sound quality: about 3-4 kHz bandwidth, "old phone / old game console"; speech stays understandable.
- Effort: about 3-4 hours including tests. Needs Verilog (new module + mixer).

## 4. Long songs (MP3 background music): not planned

3 minutes at 8 kHz 8-bit = 11.5 Mbit, more than the whole chip. It would need the board's DDR2 memory or SD card (memory controller IP, a file reader): a separate multi-day project.
Use ROUTE 2 (melody as notes) for background music instead.

---

## 5. Order I suggest (before / after the demo)

| Step | Item | When |
|---|---|---|
| 1 | You send me 3-5 sounds you like and say which game event each is for | now |
| 2 | R1 (SFX fit) for the tone-like ones | tonight (low risk, no new memory) |
| 3 | R2.1 / R2.2 for one new melody (title or boss music) | tonight or tomorrow |
| 4 | R3 samples for 1-3 short clips (boss roar, win line, a story voice line) | after the demo, new branch; build and check BRAM first |

## 6. Questions for you

1. Which sounds do you want? (list them, what each is for, how long, tone / melody / voice / noise)
2. Do you have the files already? (format: mp3, wav, midi?) Put them in `sounds/` in the repo.
3. Voice lines for the story: English or Thai? How many seconds in total? (this decides ROUTE 3 size)
4. Should the title screen have music? (it is silent now)
5. OK to spend block RAM on samples if the Vivado report shows room? Your answer: ______

## 7. Files this plan will add (so nothing is a surprise)

`sounds/` (your source files) · `sprites/sound.json` (settings) · `scripts/audio_to_sfx.py`, `scripts/midi_to_music.py`, `scripts/audio_to_music.py`, `scripts/make_samples.py` ·
`rtl/sfx_cfg.vh`, `rtl/sample_cfg.vh` (generated) · `rtl/sample_player.v` · `mem/sample.mem` (generated) · `sim/tb_sample_player.v` · `tests/test_sound_pipeline.py` · `preview/sound/*.wav` ·
`docs/SOUND_PLAN.md` kept up to date with every sound (final / placeholder).
