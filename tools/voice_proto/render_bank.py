"""Renders each villager's letter bank from its voice profile (P3B.13).

Each of the 26 letters becomes one WAV per voice, at the voice's base pitch and pace. The in-game player sequences these and shifts their
pitch for the line's contour, so nothing is synthesized live. Uses the prototype's
synthesis, so a change approved by ear there changes the bank too. Standard library
only, and deterministic: the same profile always gives byte-identical files.

    python tools/voice_proto/render_bank.py

Every family and sent-down youth in data/villagers gets a bank named by its file, in
audio/voices/<id>/<letter>.wav, and is logged in audio/sources/manifest.csv. The
owner approved the voices by ear on 2026-11-06.
"""

import argparse
import csv
import datetime
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voice_proto  # noqa: E402

PROFILE_DIR = os.path.join("data", "ui", "voices")
MANIFEST = os.path.join("audio", "sources", "manifest.csv")
VOICE_PREFIX = "audio/voices/"
FAMILY_DIRS = [os.path.join("data", "villagers", "families"), os.path.join("data", "villagers", "youth")]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROFILE_SCRIPT = os.path.join(ROOT, "data", "ui", "voice_profile.gd")
FIELDS = ("pitch", "tone", "pace", "roughness")
NUMBER = r"([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)"
FIELD_LINE = re.compile(r"^(pitch|tone|pace|roughness)\s*=\s*" + NUMBER + r"\s*$")
DEFAULT_LINE = re.compile(r"var (pitch|tone|pace|roughness)\s*:\s*float\s*=\s*" + NUMBER)


def profile_defaults(script=PROFILE_SCRIPT):
    """The script's default for each field; Godot leaves defaults out of .tres files."""
    defaults = {}
    with open(script, encoding="utf-8") as handle:
        for line in handle:
            match = DEFAULT_LINE.search(line)
            if match:
                defaults[match.group(1)] = float(match.group(2))
    return defaults


def read_profile(path):
    """Reads the four numbers from a VoiceProfile .tres file, defaulting missing ones."""
    values = dict(profile_defaults())
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            match = FIELD_LINE.match(line.strip())
            if match:
                values[match.group(1)] = float(match.group(2))
    missing = [field for field in FIELDS if field not in values]
    if missing:
        raise ValueError(f"{path}: missing {', '.join(missing)}")
    return values


SECTION = re.compile(r"^\[(\w+)(.*)\]$")
ATTRIBUTE = re.compile(r'(\w+)="([^"]*)"')
VOICE_REF = re.compile(r'^voice\s*=\s*(Sub|Ext)Resource\("([^"]+)"\)')


def family_profile(path):
    """The voice of a family file: its embedded voice, or the profile file it points at."""
    sections = {}
    current = None
    reference = None
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            header = SECTION.match(line)
            if header:
                attributes = dict(ATTRIBUTE.findall(header.group(2)))
                current = (header.group(1), attributes.get("id", ""))
                sections[current] = {"attributes": attributes, "lines": []}
                continue
            if current is not None:
                sections[current]["lines"].append(line)
            found = VOICE_REF.match(line)
            if found:
                reference = found.groups()
    if reference is None:
        raise ValueError(f"{path}: no voice")
    kind, ident = reference
    if kind == "Ext":
        target = sections[("ext_resource", ident)]["attributes"]["path"]
        return read_profile(os.path.join(ROOT, target.replace("res://", "")))
    values = dict(profile_defaults())
    for line in sections[("sub_resource", ident)]["lines"]:
        match = FIELD_LINE.match(line)
        if match:
            values[match.group(1)] = float(match.group(2))
    return values


def family_profiles():
    """Every family and youth template's voice, by file name."""
    profiles = {}
    for folder in FAMILY_DIRS:
        for file_name in sorted(os.listdir(os.path.join(ROOT, folder))):
            if file_name.endswith(".tres"):
                name = file_name[: -len(".tres")]
                profiles[name] = family_profile(os.path.join(ROOT, folder, file_name))
    return profiles


def bank_letters():
    return sorted(voice_proto.LETTERS)


def render_bank(name, profile):
    """Every letter for one voice, as {letter: samples}."""
    voice = dict(profile)
    voice["pace_now"] = voice["pace"]
    bank = {}
    for letter in bank_letters():
        rng = random.Random(voice_proto.line_seed(name + ":" + letter))
        samples = []
        voice_proto.render_letter(letter, voice["pitch"], voice, 1.0, rng, samples)
        bank[letter] = samples
    return bank


def log_banks(names, manifest, date):
    """Replaces the manifest's voice rows with one row per rendered letter."""
    with open(manifest, encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    header, kept = rows[0], [row for row in rows[1:] if not row[0].startswith(VOICE_PREFIX)]
    for name in names:
        for letter in bank_letters():
            kept.append([
                f"{VOICE_PREFIX}{name}/{letter}.wav", "voice", "Synthesis",
                "tools/voice_proto/render_bank.py", "project", "Original", "", "",
                f"{name} VoiceProfile", date, "", f"letter {letter}",
            ])
    with open(manifest, "w", encoding="utf-8", newline="") as handle:
        csv.writer(handle, lineterminator=chr(10)).writerows([header] + kept)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=os.path.join(ROOT, "audio", "voices"))
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    args = parser.parse_args()
    profiles = family_profiles()
    for name, profile in profiles.items():
        bank = render_bank(name, profile)
        peak = max(1e-6, max(max(abs(s) for s in samples) for samples in bank.values()))
        folder = os.path.join(args.out, name)
        os.makedirs(folder, exist_ok=True)
        for letter, samples in bank.items():
            voice_proto.write_wav(os.path.join(folder, letter + ".wav"), samples, peak)
        print(f"{folder}: {len(bank)} letters")
    if os.path.abspath(args.out) == os.path.join(ROOT, "audio", "voices"):
        log_banks(profiles, os.path.join(ROOT, MANIFEST), args.date)
        print(f"logged {len(profiles) * len(bank_letters())} rows in {MANIFEST}")


if __name__ == "__main__":
    main()
