# Synth patch reference

From game-sfx by GhazaGG (MIT). See ../NOTICE.md.

## Patch format

```json
{
  "name": "coin",
  "duration": null,
  "layers": [
    {
      "wave": "square",
      "duty": 0.5,
      "freq": [[0, 988], [0.06, 988], [0.06, 1319]],
      "detune_cents": 0,
      "env": {"attack": 0.001, "hold": 0.06, "release": 0.22, "curve": 2.5},
      "filters": [{"type": "lowpass", "cutoff": 9000, "q": 0.707}],
      "drive": 0,
      "gain_db": 0,
      "at": [0],
      "jitter": {"time": 0, "pitch": 0, "gain_db": 0}
    }
  ],
  "master": {"lufs": -16, "peak_db": -1, "highpass": 150},
  "vary": {"pitch": 1, "gain_db": 1},
  "expect": {"duration": [0.2, 0.4], "centroid": [1500, 6000]}
}
```

| Field | Meaning |
|---|---|
| `wave` | `sine` (pure, thin alone), `triangle` (soft), `square` (+`duty`, chiptune), `saw` (buzzy), `noise` (white; shape it with filters), `sample` (a recording, see `file`) |
| `file`, `start`, `length` | Sample layers only. `file` is a path relative to the patch, or a **list** of paths: variant *i* uses entry *i* (round-robin). `start` and `length` crop it, in seconds. The pitch of a sample is its playback rate (linear interpolation), so higher also means shorter. Without `env`, the whole sample plays with 1 ms / 10 ms fades. |
| `freq`, `cutoff` | A number, or `[[t, value], ...]` breakpoints in seconds from the layer start. Sweeps are exponential. Two points with the same `t` make an instant step (arpeggios). |
| `env` | `attack` (min 0.5 ms), `hold` at full level, `release` to exactly zero. `curve` 1 = linear fade, 2-3 = percussive. Layer length = attack + hold + release. |
| `filters` | Applied in order. `lowpass` / `highpass` / `bandpass`; `q` 0.7 = gentle, 4-8 = resonant ring. Bandpass is unity gain at the center. |
| `detune_cents` | Two slightly detuned copies. 5-15 makes it thick instead of thin. |
| `drive` | tanh saturation. 0.5-2 adds warmth and loudness to low thumps. |
| `fm` | `{"ratio": 3, "index": [[0, 2.5], [0.4, 0.3]]}` (sine only). Integer ratio = glassy/bell; 1.4 or 3.5 = metallic/gong. A falling index gives a "bling" that mellows. |
| `partials` | `[[ratio, gain_db, release_scale], ...]` stacks copies of the layer at frequency ratios. Wood/xylophone `[[1,0,1],[2.76,-8,0.5],[5.4,-16,0.3]]`. Bell `[[1,0,1],[2.4,-4,0.8],[5.95,-10,0.5]]`. Rich tone `[[1,0,1],[2,-10,0.6],[3,-18,0.4]]`. |
| `vibrato` | `{"rate": 16, "depth": semitones or breakpoints}`. 5-7 Hz = singing. 12-20 Hz with a decaying depth = spring "boing". |
| `gain_db` | Layer balance. The master is normalized afterwards, so only the differences between layers matter. |
| `at` | Start times. A list fires the layer repeatedly (footsteps, gallops, rolls). |
| `jitter` | Per-hit humanizing: ±seconds, ±semitones, ±dB. Layers firing at the same `at` time share the same draw, so stacked layers move together. |
| `duration` | Fixed length in seconds, for loops. Leave it null for one-shots: the tail is trimmed at -60 dB. |
| `master` | Final high-pass (Hz), loudness target (`lufs`), and peak ceiling (`peak_db`); the quieter of the two wins. `reverb`: `{"mix": 0.1, "decay": 0.4}` adds a small room. Loops wrap their reverb tail seamlessly. |
| `vary` | Variant spread: ±semitones for the whole sound, and up to -dB. Only used with `--variants`. |
| `expect` | Ranges the doctor enforces as FAIL: `duration`, `centroid`, `lufs`, `lead_ms`, `tail_ms`. |

## Rules that make SFX sound good

- **Layer it.** One oscillator sounds like a test tone. Build **transient** (0-30 ms, noise or click, high-passed above 1-2 kHz) + **body** (30-200 ms, tonal, 100-1000 Hz) + **tail** (filtered noise or a decaying tone) + an optional **sweetener** (sparkle, debris). Give each layer its own frequency lane.
- **Pitch should move.** Down for hits, lasers, hurt and death. Up for jumps, power-ups and confirms. Steps for coins and jingles. Static pitch only for UI ticks.
- **Short.** UI 15-80 ms. Pickups 150-400 ms. Impacts 100-300 ms. Only explosions, magic and jingles go past 0.5 s.
- **No mud.** High-pass UI and pickups at 150-300 Hz. Keep the sub (40-80 Hz) for impacts and explosions only.
- **Tame the top.** Low-pass bright square/saw/noise layers at 8-12 kHz. Too much 2-5 kHz energy is fatiguing when heard 500 times.
- **Loudness ladder** (`master.lufs`): hero impacts and explosions -12 to -14, pickups and jumps -16, footsteps and loops -18 to -20, UI -20 to -24. Peak is never above -1.

## Reading the doctor

- **peak / LUFS**: the level. LUFS is perceived loudness; compare it against the loudness ladder above.
- **crest**: peak-to-RMS ratio. Below 6 dB the sound is flat or droning (no transient). Above 20 dB it is mostly a spike with weak body.
- **centroid**: the brightness centre of gravity. UI 1-4 kHz, pickups 1.5-5 kHz, impacts 150-1500 Hz, explosions below 800 Hz, gallops and footsteps 200-1500 Hz.
- **energy bands**: below 80 Hz is weight or rumble. 2-5 kHz above 50% is harsh. Above 16 kHz above 5% means aliasing or hiss.
- **PNG**: the top strip is the amplitude envelope, with white ticks every 100 ms. Below it is the spectrogram: log frequency from 50 Hz at the bottom to 22 kHz at the top, dotted lines at 100 Hz, 1 kHz and 10 kHz, brighter = louder. Things to look for:
  - Sweeps show up as diagonal lines.
  - Noise shows up as vertical smears.
  - A tonal sound shows its harmonics as stacked horizontal lines.
