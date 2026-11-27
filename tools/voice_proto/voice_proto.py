"""Villager voice prototype (P3B.13), to judge by ear before anything enters the game.

Renders about ten table lines in three voices as WAV files. Each letter of the line
plays one short sound as it would type out, in the way of Animalese-style babble: a
consonant onset and a vowel taken from how the letter sounds in English, by formant
synthesis (a buzzing glottal source shaped by three vowel resonators). No TTS and no
recordings. Standard library only.

    python tools/voice_proto/voice_proto.py --out reports/voice_proto

What to listen for:
- Each voice is recognizable, and the three are told apart.
- The babble follows the words: long words take longer, spaces and punctuation pause.
- Each word steps its own pitch and the sentence drifts down. Only the last word
  carries the ending: questions rise, statements fall, exclamations come faster and
  louder, and lines ending in "..." trail off.
- It must not read as imitation Mandarin: every letter holds one flat pitch with no
  per-letter tone shapes, and the sounds come from English letters.

The same line always gives the same sounds: letters map to fixed sounds, and the small
pitch wobble comes from a seed derived from the line.
"""

import argparse
import math
import os
import random
import struct
import wave
import zlib

RATE = 22050
VOWELS = {
    # F1, F2, F3 in Hz for a mid-size voice.
    "a": (750, 1250, 2550),
    "e": (500, 1800, 2550),
    "i": (320, 2200, 2950),
    "o": (520, 950, 2450),
    "u": (360, 850, 2350),
}
# Each letter's sound: its onset consonant ("" for none) and its vowel, close to how
# the letter is said in English words.
LETTERS = {
    "a": ("", "a"), "b": ("b", "i"), "c": ("k", "a"), "d": ("d", "e"), "e": ("", "e"),
    "f": ("f", "e"), "g": ("g", "o"), "h": ("h", "a"), "i": ("", "i"), "j": ("j", "a"),
    "k": ("k", "e"), "l": ("l", "a"), "m": ("m", "a"), "n": ("n", "e"), "o": ("", "o"),
    "p": ("p", "i"), "q": ("k", "u"), "r": ("r", "o"), "s": ("s", "e"), "t": ("t", "i"),
    "u": ("", "u"), "v": ("v", "i"), "w": ("w", "u"), "x": ("k", "e"), "y": ("w", "i"),
    "z": ("z", "i"),
}
# Onset kinds: a short noise puff, a longer hiss, or a voiced hum.
PLOSIVES = "bdgkpt"
FRICATIVES = "fhjsvz"
DIGITS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
# Profiles give pace in syllables per second; a syllable is about this many letters.
LETTERS_PER_SYLLABLE = 2.6
# Pauses, in letter lengths.
PAUSES = {" ": 0.5, ",": 2.5, ".": 4.0, "!": 4.0, "?": 4.0, ";": 3.0, ":": 3.0}
TRAIL_PAUSE = 6.0

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


def spoken_text(text):
    """The line with digits spelled out, so "Down to 2." babbles "two"."""
    return "".join(DIGITS[int(c)] if c.isdigit() else c for c in text)


def sentences(text):
    """Splits the line into (sentence, ending) pairs; the ending sets its contour."""
    result = []
    current = ""
    index = 0
    while index < len(text):
        char = text[index]
        if text.startswith("...", index):
            result.append((current, "..."))
            current = ""
            index += 3
            continue
        current += char
        if char in ".?!":
            result.append((current, char))
            current = ""
        index += 1
    if current.strip():
        result.append((current, "."))
    return result


def contour(ending):
    """The last word's pitch at its start and end, and the sentence's loudness and pace.

    Only the last word carries the ending, as in speech: a long question stays level
    until its last word rises.
    """
    if ending == "...":
        return (0.95, 0.6, 0.8, 0.75)
    if ending == "?":
        return (1.0, 1.35, 1.0, 1.0)
    if ending == "!":
        return (1.18, 1.0, 1.25, 1.2)
    return (1.0, 0.85, 1.0, 1.0)


# The whole sentence drifts down by this much from its first word to its last.
DECLINATION = 0.1
# Per-word pitch steps: longer words tend to carry the stress and step up.
LONG_WORD = 4
LONG_ACCENT = (0.04, 0.14)
SHORT_ACCENT = (-0.07, 0.04)


def word_accent(word):
    """A fixed pitch step for a word, so the same word always sounds the same."""
    rng = random.Random(line_seed(word))
    low, high = LONG_ACCENT if len(word) >= LONG_WORD else SHORT_ACCENT
    return rng.uniform(low, high)


def _words(sentence):
    """Each word as its spoken letters, with the pause characters that follow it."""
    words = []
    letters = ""
    for char in sentence.lower():
        if char in LETTERS:
            letters += char
        elif char in PAUSES:
            if letters:
                words.append((letters, []))
                letters = ""
            if words:
                words[-1][1].append(PAUSES[char])
    if letters:
        words.append((letters, []))
    return words


def events_for(text):
    """The line as ("letter", letter, bend, ending) and ("pause", lengths, 1.0, ending).

    Bend is the letter's pitch multiplier before the mood's range is applied: a slow
    drift down across the sentence, a step per word, and the ending on the last word.
    """
    events = []
    for sentence, ending in sentences(spoken_text(text)):
        words = _words(sentence)
        last_start, last_end = contour(ending)[:2]
        for index, (word, pauses) in enumerate(words):
            drift = 1.0 + DECLINATION / 2 - DECLINATION * index / max(1, len(words) - 1)
            final = index == len(words) - 1
            for position, char in enumerate(word):
                if final:
                    along = position / max(1, len(word) - 1)
                    bend = drift * (last_start + (last_end - last_start) * along)
                else:
                    bend = drift * (1.0 + word_accent(word))
                events.append(("letter", char, bend, ending))
            for length in pauses:
                events.append(("pause", length, 1.0, ending))
        if ending == "...":
            events.append(("pause", TRAIL_PAUSE, 1.0, ending))
    return events


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


def letter_seconds(voice):
    return 1.0 / (voice["pace_now"] * LETTERS_PER_SYLLABLE)


def _onset_length(onset):
    if not onset:
        return 0
    if onset in FRICATIVES:
        return int(RATE * 0.03)
    return int(RATE * 0.018)


def render_letter(letter, f0, voice, loud, rng, out):
    """Appends one letter's sound: a short onset, then a flat-pitched vowel."""
    onset, vowel = LETTERS[letter]
    tone = voice["tone"]
    formants = [Resonator(f * tone, 80 + 40 * i) for i, f in enumerate(VOWELS[vowel])]
    rough = voice["roughness"]
    onset_len = _onset_length(onset)
    total = max(onset_len + int(RATE * 0.03), int(RATE * letter_seconds(voice)))
    phase = 0.0
    for n in range(total):
        envelope = min(1.0, n / (RATE * 0.006)) * min(1.0, (total - n) / (RATE * 0.015))
        if n < onset_len:
            if onset in PLOSIVES:
                sample = rng.uniform(-1, 1) * 0.5
            elif onset in FRICATIVES:
                sample = rng.uniform(-1, 1) * 0.3
            else:
                sample = math.sin(2 * math.pi * f0 * n / RATE) * 0.6
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
    rng = random.Random(line_seed(text) ^ line_seed(voice_name))
    out = []
    letters = []
    pitches = []
    for kind, value, bend, ending in events_for(text):
        loud_line, pace_line = contour(ending)[2:]
        voice["pace_now"] = voice["pace"] * pace * pace_line
        if kind == "pause":
            out.extend([0.0] * int(RATE * letter_seconds(voice) * value))
            continue
        wobble = 1.0 + 0.04 * rng.uniform(-1, 1)
        f0 = voice["pitch"] * shift * (1.0 + (bend - 1.0) * span) * wobble
        render_letter(value, f0, voice, loud_mood * loud_line, rng, out)
        letters.append(value)
        pitches.append(f0)
    return out, letters, pitches


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
    for voice_name, number, text, samples, letters, _pitches in rendered:
        path = os.path.join(args.out, f"{voice_name}_{number:02d}.wav")
        write_wav(path, samples, peak)
        seconds = len(samples) / RATE
        print(f"{path}: {len(letters)} letters, {seconds:.2f} s | {text}")


if __name__ == "__main__":
    main()
