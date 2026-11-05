"""Renders each villager's syllable bank from its voice profile (P3B.13).

Every onset and vowel pair of the invented palette becomes one WAV per voice, at the
voice's base pitch and pace. The in-game player sequences these and shifts their
pitch for the line's contour, so nothing is synthesized live. Uses the prototype's
synthesis, so a change approved by ear there changes the bank too. Standard library
only, and deterministic: the same profile always gives byte-identical files.

    python tools/voice_proto/render_bank.py --out reports/voice_bank

The bank stays in reports/ until the owner approves the voices by ear.
"""

import argparse
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voice_proto  # noqa: E402

PROFILE_DIR = os.path.join("data", "ui", "voices")
FIELDS = ("pitch", "tone", "pace", "roughness")
FIELD_LINE = re.compile(r"^(pitch|tone|pace|roughness)\s*=\s*([-0-9.]+)\s*$")


def read_profile(path):
    """Reads the four numbers from a VoiceProfile .tres file."""
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            match = FIELD_LINE.match(line.strip())
            if match:
                values[match.group(1)] = float(match.group(2))
    missing = [field for field in FIELDS if field not in values]
    if missing:
        raise ValueError(f"{path}: missing {', '.join(missing)}")
    return values


def bank_syllables():
    return [onset + vowel for onset in voice_proto.ONSETS for vowel in voice_proto.VOWEL_KEYS]


def render_bank(name, profile):
    """Every syllable for one voice, as {syllable: samples}."""
    voice = dict(profile)
    voice["pace_now"] = voice["pace"]
    bank = {}
    for syllable in bank_syllables():
        rng = random.Random(voice_proto.line_seed(name + ":" + syllable))
        samples = []
        voice_proto.render_syllable(syllable, voice["pitch"], voice, 1.0, rng, samples)
        bank[syllable] = samples
    return bank


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default="reports/voice_bank")
    parser.add_argument("--profiles", default=PROFILE_DIR)
    args = parser.parse_args()
    for file_name in sorted(os.listdir(args.profiles)):
        if not file_name.endswith(".tres"):
            continue
        name = file_name[: -len(".tres")]
        bank = render_bank(name, read_profile(os.path.join(args.profiles, file_name)))
        peak = max(1e-6, max(max(abs(s) for s in samples) for samples in bank.values()))
        folder = os.path.join(args.out, name)
        os.makedirs(folder, exist_ok=True)
        for syllable, samples in bank.items():
            label = syllable if syllable[0] not in voice_proto.VOWELS else "_" + syllable
            voice_proto.write_wav(os.path.join(folder, label + ".wav"), samples, peak)
        print(f"{folder}: {len(bank)} syllables")


if __name__ == "__main__":
    main()
