"""Villager voice prototype (P3B.13), to judge by ear before anything enters the game.

Renders about ten table lines in three voices as WAV files, by formant synthesis:
a buzzing glottal source shaped by three vowel resonators, with short consonant
onsets. No TTS and no recordings. Standard library only.

    python tools/voice_proto/voice_proto.py --out reports/voice_proto

What to listen for:
- Each voice is recognizable, and the three are told apart.
- Questions rise, statements fall, exclamations come faster and louder, and lines
  ending in "..." trail off.
- The syllables sound invented. They must not read as imitation Mandarin: every
  syllable holds one flat pitch with no per-syllable tone shapes, and the line's
  contour comes only from its punctuation and mood.

The same line always gives the same syllables, because the choice comes from the
line's letters and a seed derived from the line.
"""

import argparse
import math
import os
import random
import struct
import wave
import zlib

RATE = 22050
# The invented palette: soft onsets and five plain vowels, with no retroflex, tonal or
# aspirated sets that would suggest Mandarin.
ONSETS = ["b", "d", "m", "n", "l", "w", "p", "t", "v", ""]
VOWELS = {
    # F1, F2, F3 in Hz for a mid-size voice.
    "a": (750, 1250, 2550),
    "e": (500, 1800, 2550),
    "i": (320, 2200, 2950),
    "o": (520, 950, 2450),
    "u": (360, 850, 2350),
}
VOWEL_KEYS = sorted(VOWELS)

# Voice profiles: base pitch in Hz, formant scale, syllables per second, roughness 0-1.
VOICES = {
    "wang": {"pitch": 112.0, "tone": 0.94, "pace": 4.2, "roughness": 0.35},
    "zhao": {"pitch": 148.0, "tone": 1.04, "pace": 6.2, "roughness": 0.12},
    "sun": {"pitch": 205.0, "tone": 1.12, "pace": 5.4, "roughness": 0.05},
}

# Mood: pitch range scale, pace scale, loudness scale, overall pitch shift.
MOODS = {
    "": (1.0, 1.0, 1.0, 1.0),
    "calm": (0.8, 0.95, 0.9, 1.0),
    "eager": (1.3, 1.15, 1.1, 1.05),
    "sour": (0.7, 0.95, 0.95, 0.93),
    "sly": (1.1, 0.9, 0.85, 1.0),
    "tired": (0.6, 0.8, 0.8, 0.95),
}

LINES = [
    ("I'll call.", "calm"),
    ("Pass.", "calm"),
    ("You going to play that, or hold it till the thaw?", ""),
    ("Give me the seat!", "eager"),
    ("Down to 2.", "eager"),
    ("Sorry. I had to.", "sly"),
    ("Try topping that!", "eager"),
    ("Bad cards from the start...", "tired"),
    ("Who dealt this?", "sour"),
    ("Only 1 now. Careful.", "sly"),
]


def line_seed(text):
    return zlib.crc32(text.encode("utf-8"))


def syllables_for(text):
    """Invented syllables from the line's letters: one or two per word."""
    rng = random.Random(line_seed(text))
    result = []
    for word in text.split():
        letters = [c for c in word.lower() if c.isalpha() or c.isdigit()]
        if not letters:
            continue
        count = 1 if len(letters) <= 4 else 2
        for index in range(count):
            code = sum(ord(c) for c in letters[index::count]) + rng.randrange(7)
            onset = ONSETS[code % len(ONSETS)]
            vowel = VOWEL_KEYS[(code // len(ONSETS)) % len(VOWEL_KEYS)]
            result.append(onset + vowel)
    return result


def contour(text):
    """Pitch multipliers at the line's start and end, and a loudness and pace scale."""
    stripped = text.rstrip()
    if stripped.endswith("..."):
        return (1.0, 0.55, 0.8, 0.75)
    if stripped.endswith("?"):
        return (0.95, 1.3, 1.0, 1.0)
    if stripped.endswith("!"):
        return (1.15, 1.0, 1.25, 1.2)
    return (1.05, 0.85, 1.0, 1.0)


class Resonator:
    """A two-pole band-pass filter at one formant."""

    def __init__(self, freq, bandwidth):
        r = math.exp(-math.pi * bandwidth / RATE)
        self.b1 = 2.0 * r * math.cos(2.0 * math.pi * freq / RATE)
        self.b2 = -r * r
        self.gain = 1.0 - r
        self.y1 = 0.0
        self.y2 = 0.0

    def step(self, x):
        y = self.gain * x + self.b1 * self.y1 + self.b2 * self.y2
        self.y2, self.y1 = self.y1, y
        return y


def render_syllable(syllable, f0, voice, loud, rng, out):
    """Appends one syllable: a short onset, then a flat-pitched vowel."""
    onset, vowel = syllable[:-1], syllable[-1]
    seconds = 1.0 / voice["pace_now"]
    tone = voice["tone"]
    formants = [Resonator(f * tone, 80 + 40 * i) for i, f in enumerate(VOWELS[vowel])]
    rough = voice["roughness"]
    onset_len = int(RATE * 0.035) if onset else 0
    total = int(RATE * seconds)
    phase = 0.0
    for n in range(total):
        envelope = min(1.0, n / (RATE * 0.012)) * min(1.0, (total - n) / (RATE * 0.03))
        if n < onset_len:
            # Plosives are a puff of noise; nasals and glides a low hum.
            if onset in "bdpt":
                source = rng.uniform(-1, 1) * 0.5
            else:
                source = math.sin(2 * math.pi * f0 * n / RATE) * 0.6
            sample = source
        else:
            jitter = 1.0 + rough * 0.03 * rng.uniform(-1, 1)
            phase += f0 * jitter / RATE
            phase -= math.floor(phase)
            pulse = 1.0 - 2.0 * phase  # sawtooth glottal source
            pulse += rough * 0.25 * rng.uniform(-1, 1)
            sample = sum(r.step(pulse) for r in formants)
        out.append(sample * envelope * loud)


def render_line(text, mood, voice_name):
    voice = dict(VOICES[voice_name])
    span, pace, loud_mood, shift = MOODS[mood]
    start, end, loud_line, pace_line = contour(text)
    syllables = syllables_for(text)
    rng = random.Random(line_seed(text) ^ line_seed(voice_name))
    out = []
    count = max(1, len(syllables) - 1)
    pitches = []
    for index, syllable in enumerate(syllables):
        position = index / count
        bend = start + (end - start) * position
        f0 = voice["pitch"] * shift * (1.0 + (bend - 1.0) * span)
        voice["pace_now"] = voice["pace"] * pace * pace_line
        render_syllable(syllable, f0, voice, loud_mood * loud_line, rng, out)
        pitches.append(f0)
        out.extend([0.0] * int(RATE * 0.02))
    return out, syllables, pitches


def write_wav(path, samples, peak):
    """Writes with one shared peak, so louder and softer lines stay that way."""
    scale = 0.8 * 32767 / peak
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(struct.pack("<h", int(s * scale)) for s in samples))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default="reports/voice_proto")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rendered = []
    for voice_name in VOICES:
        for number, (text, mood) in enumerate(LINES, 1):
            rendered.append((voice_name, number, text) + render_line(text, mood, voice_name))
    peak = max(1e-6, max(max(abs(s) for s in item[3]) for item in rendered))
    for voice_name, number, text, samples, syllables, pitches in rendered:
        path = os.path.join(args.out, f"{voice_name}_{number:02d}.wav")
        write_wav(path, samples, peak)
        rise = pitches[-1] / pitches[0] if pitches else 1.0
        print(f"{path}: {' '.join(syllables)} | end/start pitch {rise:.2f} | {text}")


if __name__ == "__main__":
    main()
