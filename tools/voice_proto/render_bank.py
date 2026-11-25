"""Renders each villager's letter bank from its voice profile.

Each of the 26 letters becomes one WAV per voice, at the voice's base pitch and pace. The
in-game player sequences these and shifts their pitch for the line's contour, so nothing
is synthesized live. Uses the synthesis in voice_synth.py, so a change there changes the
bank too. Standard library only, and deterministic: the same profile always gives
byte-identical files.

    python tools/voice_proto/render_bank.py

Every family and sent-down youth in data/villagers gets a bank named by its file, in
audio/voices/<id>/<letter>.wav, and is logged in audio/sources/manifest.csv.
"""

import argparse
import csv
import datetime
import random
import re
from pathlib import Path

import voice_synth

ROOT = Path(__file__).resolve().parent.parent.parent
PROFILE_DIR = Path("data") / "ui" / "voices"
MANIFEST = Path("audio") / "sources" / "manifest.csv"
VOICE_PREFIX = "audio/voices/"
FAMILY_DIRS = [Path("data") / "villagers" / "families", Path("data") / "villagers" / "youth"]
PROFILE_SCRIPT = ROOT / "data" / "ui" / "voice_profile.gd"
FIELDS = ("pitch", "tone", "pace", "roughness")
NUMBER = r"([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)"
FIELD_LINE = re.compile(r"^(pitch|tone|pace|roughness)\s*=\s*" + NUMBER + r"\s*$")
DEFAULT_LINE = re.compile(r"var (pitch|tone|pace|roughness)\s*:\s*float\s*=\s*" + NUMBER)
SECTION = re.compile(r"^\[(\w+)(.*)\]$")
ATTRIBUTE = re.compile(r'(\w+)="([^"]*)"')
VOICE_REF = re.compile(r'^voice\s*=\s*(Sub|Ext)Resource\("([^"]+)"\)')


def profile_defaults(script: Path = PROFILE_SCRIPT) -> dict[str, float]:
    """The script's default for each field; Godot leaves defaults out of .tres files."""
    defaults = {}
    for line in script.read_text(encoding="utf-8").splitlines():
        match = DEFAULT_LINE.search(line)
        if match:
            defaults[match.group(1)] = float(match.group(2))
    return defaults


def read_profile(path: Path) -> dict[str, float]:
    """Reads the four numbers from a VoiceProfile .tres file, defaulting missing ones."""
    values = dict(profile_defaults())
    for line in path.read_text(encoding="utf-8").splitlines():
        match = FIELD_LINE.match(line.strip())
        if match:
            values[match.group(1)] = float(match.group(2))
    missing = [field for field in FIELDS if field not in values]
    if missing:
        raise ValueError(f"{path}: missing {', '.join(missing)}")
    return values


def family_profile(path: Path) -> dict[str, float]:
    """The voice of a family file: its embedded voice, or the profile file it points at."""
    sections: dict[tuple[str, str], dict] = {}
    current = None
    reference = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
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
        return read_profile(ROOT / target.replace("res://", ""))
    values = dict(profile_defaults())
    for line in sections[("sub_resource", ident)]["lines"]:
        match = FIELD_LINE.match(line)
        if match:
            values[match.group(1)] = float(match.group(2))
    return values


def family_files() -> list[Path]:
    """Every family and youth template file, folder by folder, each in name order."""
    files = []
    for folder in FAMILY_DIRS:
        files += sorted((ROOT / folder).glob("*.tres"), key=lambda file: file.name)
    return files


def family_profiles() -> dict[str, dict[str, float]]:
    """Every family and youth template's voice, by file name."""
    return {file.stem: family_profile(file) for file in family_files()}


def bank_letters() -> list[str]:
    """The letters a bank holds, in order."""
    return sorted(voice_synth.LETTERS)


def render_bank(name: str, profile: dict[str, float]) -> dict[str, list[float]]:
    """Every letter for one voice, as {letter: samples}."""
    voice = dict(profile)
    voice["pace_now"] = voice["pace"]
    bank = {}
    for letter in bank_letters():
        rng = random.Random(voice_synth.line_seed(name + ":" + letter))
        samples: list[float] = []
        voice_synth.render_letter(letter, voice["pitch"], voice, 1.0, rng, samples)
        bank[letter] = samples
    return bank


def log_banks(names: list[str], manifest: Path, date: str) -> None:
    """Replaces the manifest's voice rows with one row per rendered letter."""
    with manifest.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    header, kept = rows[0], [row for row in rows[1:] if not row[0].startswith(VOICE_PREFIX)]
    for name in names:
        for letter in bank_letters():
            kept.append(
                [
                    f"{VOICE_PREFIX}{name}/{letter}.wav",
                    "voice",
                    "Synthesis",
                    "tools/voice_proto/render_bank.py",
                    "project",
                    "Original",
                    "",
                    "",
                    f"{name} VoiceProfile",
                    date,
                    "",
                    f"letter {letter}",
                ]
            )
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        csv.writer(handle, lineterminator=chr(10)).writerows([header, *kept])


def main() -> None:
    """Renders every bank, and logs them when they go to the project's own folder."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=ROOT / "audio" / "voices")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    args = parser.parse_args()
    profiles = family_profiles()
    for name, profile in profiles.items():
        bank = render_bank(name, profile)
        peak = max(1e-6, max(max(abs(s) for s in samples) for samples in bank.values()))
        folder = args.out / name
        folder.mkdir(parents=True, exist_ok=True)
        for letter, samples in bank.items():
            voice_synth.write_wav(folder / f"{letter}.wav", samples, peak)
        print(f"{folder}: {len(bank)} letters")
    if args.out.resolve() == (ROOT / "audio" / "voices").resolve():
        log_banks(list(profiles), ROOT / MANIFEST, args.date)
        print(f"logged {len(profiles) * len(bank_letters())} rows in {MANIFEST.as_posix()}")


if __name__ == "__main__":
    main()
