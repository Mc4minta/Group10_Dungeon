# Sound plan - what every sound is now, where it lives, and how to change it

**Update this file every time a sound changes** (same rule as `docs/SPRITE_STATUS.md`). Last update: project cleanup (branch `sprite-zip`, tag `board-test-2`): custom music track 6 (Connect) on floors 1-3, sounds 11 (boss appears) and 12 (room change).

Legend: **FINAL** = you are happy with it. **PLACEHOLDER** = a programmer test tone (all sound effects are tones, none have been designed by you yet).

---

## 1. How sound works in this game (important for what is possible)

- The board has ONE mono output pin (`AUD_PWM`) with a PWM signal. There are **no sound samples**: everything is made of **square waves**
  (like an old 8-bit console).
- Two independent square-wave "voices":
  1. **Sound effects (SFX)**: one effect at a time, each with a priority (smaller number = more important). A more important effect cuts a less
     important one; the same or a less important one that arrives while another plays is dropped.
  2. **Background music (BGM)**: a note sequencer that reads `mem/music.mem`.
  The two are mixed (`SFX_AMP = 48`, `BGM_AMP = 18` in `rtl/params.vh`: music is quieter than effects).
- The Simon puzzle plays its own 4 notes on top of everything.
- No sound on the title screen (`bgm_en = !is_title`).
- Code: `rtl/audio.v`. Values: `rtl/params.vh` (section "SFX"). Music: `scripts/make_music.py`. Test: `./scripts/run_sim.sh audio` (57 checks).
- Preview recordings made by the simulator: `docs/audio/floor1.wav`, `docs/audio/escape.wav`.

## 2. Sound effects (12) - all PLACEHOLDER tones

| # | Name | When it plays | Pitch (start -> end) | Length | Defined by |
|---|---|---|---|---|---|
| 1 | HURT | the player is hit (also debug SW4) | 330 -> 110 Hz falling | 18 frames (0.3 s) | `SFX_HURT_*` |
| 2 | STUN | a boss becomes stunned | 1200 -> 600 Hz | 24 frames | `SFX_STUN_*` |
| 3 | DIE | a monster dies or a boss dies | 500 -> 120 Hz falling | 14 frames | `SFX_DIE_*` |
| 4 | ITEM | puzzle item picked up (also debug SW3 = evolve) | 800 -> 2000 Hz rising | 28 frames | `SFX_ITEM_*` |
| 5 | CLEAR | the room doors open (monsters cleared) or the Sokoban gate opens | 600 -> 1000 Hz rising | 20 frames | `SFX_CLEAR_*` |
| 6 | WRONG | wrong Simon plate / puzzle fail | 200 -> 170 Hz low buzz | 24 frames | `SFX_WRONG_*` |
| 7 | OK | correct Simon plate | 1500 Hz | 5 frames | `SFX_OK_*` |
| 8 | MHIT | a monster or boss is hit | 900 -> 700 Hz | 4 frames | `SFX_MHIT_*` |
| 9 | SHOOT | a shot is fired; 4 variants: form 2 single (1800->1200 Hz), form 3 spread (1400->1000), form 4 fast (2400->1600), form 4 big charged (600->250) | see left | 4-16 frames | `SFX_SHOOT0..3_*` |
| 10 | MELEE | the sword swing (form 1; forms 2-4 when an enemy is in the box) | 450 -> 250 Hz | 7 frames | `SFX_MELEE_*` |
| 11 | BOSS (new) | a boss appears | 250 -> 204 Hz low rumble | 30 frames (0.5 s) | `SFX_BOSS_*` |
| 12 | DOOR (new) | the player walks through a door into another room | 1000 Hz blip | 4 frames | `SFX_DOOR_*` |

Priority = the number: 1 beats everything, 12 is cut by every other effect. A boss sound (11) is allowed to cut the door blip (12), because the
boss appears right after the door.

How to change one: in `rtl/params.vh` each effect has `_HP` (half period of the square wave, smaller = higher pitch), `_SL` (slide per frame) and
`_LEN` (frames). Pitch in Hz = 100,000,000 / (2 x HP). Rebuild the bitstream after a change (it is RTL).

Not covered by any sound yet: evolving to a new form, floor cleared (jingle), picking up form changes, walking, bullets hitting walls, boss hit by
a bullet (uses MHIT), player death (uses the GAME OVER jingle), pressing buttons on the title screen.

## 3. Background music (6 tracks, from `scripts/make_music.py`)

| Track | Plays when | Mood / key | Length | Loops? |
|---|---|---|---|---|
| 0 | floor 1 | C major, bright, about 112 bpm | 17 s | yes |
| 1 | floor 2 | A minor, mysterious, slower | 19 s | yes |
| 2 | floor 3 | D minor, driving, faster | 13 s | yes |
| 3 | ESCAPE run | urgent alternating notes | 6 s | yes |
| 4 | WIN screen | short victory jingle | 3 s | no (plays once) |
| 5 | GAME OVER screen | falling 4-note jingle | 4 s | no |

| 6 (custom) | floors 1-3 (set in `sprites/music.json`) | the melody of **Connect**, extracted from `my_audio/connect_preview.wav` by `scripts/audio_to_music.py` (45 s, 89 notes, chiptune) | 45.6 s | yes |

Track 6 is the one custom slot. To use another song: `python scripts/audio_to_music.py my_audio/song.mp3 --start 10 --duration 40 --grid auto --out sprites/music/song.txt --preview preview/sound/song.wav`
(listen to the preview WAV), point `tracks` in `sprites/music.json` at it, run `python scripts/make_music.py`, rebuild. It loops. The tool finds ONE melody line; it is a chiptune version, not the recording.

All melodies were written for this project (not copied). They are plain text in `scripts/make_music.py`:
`C5:2` = note C5 for 2 units, `R:2` = rest. Edit the text, run `python3 scripts/make_music.py`, rebuild the bitstream (it is a ROM). Limit: 127 notes
per track, note length 1-255 frames. Status: **PLACEHOLDER** (programmer melodies).

## 4. Simon puzzle notes (4)

C5 523 Hz, E5 659 Hz, G5 784 Hz, C6 1047 Hz (`SIMON_HP0..3` in `params.vh`). Always on top of all other sound.

## 5. Needs your sound (what to find or compose) - suggestions

| # | Sound | Now | Idea |
|---|---|---|---|
| 1 | Title screen music | none (silent) | a calm 10-20 s loop |
| 2 | Evolve fanfare | none | rising 3-note flourish |
| 3 | Boss music (different from the floor track) | floor track continues | a heavier loop for boss rooms |
| 4 | Player attack variety | one tone per weapon | a noise-like "swish" for melee |
| 5 | Story / dialogue sounds | none | a short blip per text line, or a jingle between floors |
| 6 | Better versions of the 12 effects | tones | adjust pitch/length until they sound right on the board speaker |

---

## 6. Can I use an MP3? (short answer: not directly, but short clips can be converted)

**The game cannot play an MP3 file.** It has no sample player, no file system and no decoder. What is possible:

| Option | What you get | Cost / limit |
|---|---|---|
| **A. Convert a short clip to raw samples and store it in block RAM** (needs a small new Verilog sample-player, not written yet) | the real recording (voice line, roar, jingle) | Block RAM is limited: 8 kHz, 8-bit mono = 8 KB per second = about 2 of the 135 RAMB36 blocks per second. Realistic: a few clips of 1-3 s each (total about 5-10 s). Quality is "old phone": about 3-4 kHz bandwidth, 8 bit. |
| **B. Keep chiptune music, add a few sampled clips (voice, boss roar, win line)** (recommended) | best of both, small BRAM cost | needs A |
| **C. Full-length songs from MP3** | - | NOT possible in block RAM: 3 min at 8 kHz 8-bit = 1.4 MB = 11.5 Mbit, but the whole FPGA has 4.8 Mbit and the game already uses a lot. It would need the on-board DDR2 memory or the SD card, which is a big separate project. |
| **D. Re-write the song as chiptune notes** | your melody on the existing music engine, no extra BRAM | you (or I) transcribe the melody into `make_music.py` text; two square-wave voices only |

How the conversion would work (for A): `scripts/make_samples.py` runs `ffmpeg` (it exists in WSL here) to turn `sounds/*.mp3` into 8 kHz mono 8-bit,
writes `mem/sample_<name>.mem`, and a generated header lists the clips; `rtl/audio.v` gets a sample channel mixed with the existing output.
The build must prove it fits: I will report the block RAM used before and after, as for the animations.

To decide: tell me which sounds you want as real recordings, how long each is, and whether voice or music.

The full plan to turn any sound into the game (3 routes, budget, order, questions for you) is in `docs/SOUND_PIPELINE_PLAN.md`.

## 7. Files

| File | Purpose |
|---|---|
| `rtl/audio.v` | the sound engine (SFX channel with priority, BGM sequencer, Simon notes, PWM) |
| `rtl/params.vh` | SFX values, amplitudes, Simon notes, `AUD_SD_ON` |
| `scripts/make_music.py` -> `mem/music.mem` | the 6 music tracks |
| `sim/tb_audio.v` | the sound test (`./scripts/run_sim.sh audio`) |
| `docs/audio/*.wav` | recordings from the simulator |
