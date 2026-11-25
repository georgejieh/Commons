"""The letter bank renders identical files for every family, and the synthesis shapes a line."""

import filecmp
import subprocess
import sys
from pathlib import Path

import render_bank
import voice_synth

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def test_every_profile_reads_all_four_numbers() -> None:
    names = sorted((ROOT / render_bank.PROFILE_DIR).glob("*.tres"))
    assert names
    for name in names:
        profile = render_bank.read_profile(name)
        assert set(profile) == set(render_bank.FIELDS)


def test_the_bank_covers_every_letter_and_is_byte_identical(tmp_path: Path) -> None:
    outputs = []
    for run in ("a", "b"):
        out = tmp_path / run
        subprocess.run(
            [sys.executable, str(HERE / "render_bank.py"), "--out", str(out)],
            cwd=ROOT,
            check=True,
        )
        outputs.append(out)
    first, second = outputs
    voices = sorted(path.name for path in first.iterdir())
    assert voices == sorted(path.name for path in second.iterdir())
    for voice in voices:
        files = sorted(path.name for path in (first / voice).iterdir())
        assert len(files) == len(render_bank.bank_letters())
        _match, mismatch, errors = filecmp.cmpfiles(first / voice, second / voice, files, False)
        assert not mismatch
        assert not errors


def test_every_family_and_youth_has_a_voice() -> None:
    profiles = render_bank.family_profiles()
    templates = [
        file for folder in render_bank.FAMILY_DIRS for file in (ROOT / folder).glob("*.tres")
    ]
    assert len(profiles) == len(templates)
    assert profiles["wang"] == render_bank.read_profile(
        ROOT / render_bank.PROFILE_DIR / "wang.tres"
    )
    for profile in profiles.values():
        assert set(profile) == set(render_bank.FIELDS)


def test_a_profile_saved_with_default_values_still_reads(tmp_path: Path) -> None:
    defaults = render_bank.profile_defaults()
    assert set(defaults) == set(render_bank.FIELDS)
    path = tmp_path / "plain.tres"
    path.write_text('[resource]\nscript = ExtResource("1")\npitch = 1.2e2\n', encoding="utf-8")
    profile = render_bank.read_profile(path)
    assert profile["pitch"] == 120.0
    assert profile["tone"] == defaults["tone"]


def test_each_letter_plays_once_and_punctuation_pauses() -> None:
    events = voice_synth.events_for("Down to 2.")
    letters = "".join(value for kind, value, _p, _e in events if kind == "letter")
    assert letters == "downtotwo"
    pauses = [value for kind, value, _p, _e in events if kind == "pause"]
    assert pauses == [voice_synth.PAUSES[" "], voice_synth.PAUSES[" "], voice_synth.PAUSES["."]]


def test_each_sentence_takes_its_own_contour_and_a_line_is_repeatable() -> None:
    trail = [e for e in voice_synth.events_for("Bad cards...") if e[0] == "pause"]
    assert [e[1] for e in trail] == [voice_synth.PAUSES[" "], voice_synth.TRAIL_PAUSE]
    endings = [ending for _s, ending in voice_synth.sentences("Sorry. I had to?")]
    assert endings == [".", "?"]
    _out, _letters, pitches = voice_synth.render_line("Who dealt this?", "", "zhao")
    assert pitches[-1] > pitches[0] * 1.15
    _out, _letters, pitches = voice_synth.render_line("Bad cards from the start...", "", "zhao")
    assert pitches[-1] < pitches[0] * 0.75
    first = voice_synth.render_line("Pass.", "calm", "wang")[0]
    assert first == voice_synth.render_line("Pass.", "calm", "wang")[0]


def test_a_long_question_stays_level_until_its_last_word_rises() -> None:
    line = "You going to play that, or hold it till the thaw?"
    _out, _letters, pitches = voice_synth.render_line(line, "", "zhao")
    last = len("thaw")
    body = pitches[:-last]
    base = voice_synth.VOICES["zhao"]["pitch"]
    assert max(body) < base * 1.2
    assert min(body) > base * 0.85
    assert len({round(p) for p in body}) > 5
    assert pitches[-1] > max(body)


def test_logging_replaces_only_the_voice_rows(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.csv"
    manifest.write_text(
        "file,type,license\naudio/sfx/a.wav,sfx,CC0\naudio/voices/old/a.wav,voice,Original\n",
        encoding="utf-8",
    )
    render_bank.log_banks(["wang"], manifest, "2026-11-06")
    lines = manifest.read_text(encoding="utf-8").splitlines()
    assert lines[1] == "audio/sfx/a.wav,sfx,CC0"
    assert not any("voices/old" in line for line in lines)
    voice_rows = [line for line in lines if line.startswith("audio/voices/wang/")]
    assert len(voice_rows) == 26
