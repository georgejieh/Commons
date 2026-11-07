"""Tests for the letter bank renderer (P3B.13). Run with: python -m pytest tools"""

import filecmp
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import render_bank  # noqa: E402


def test_every_profile_reads_all_four_numbers():
    folder = os.path.join(ROOT, render_bank.PROFILE_DIR)
    names = [name for name in os.listdir(folder) if name.endswith(".tres")]
    assert names
    for name in names:
        profile = render_bank.read_profile(os.path.join(folder, name))
        assert set(profile) == set(render_bank.FIELDS)


def test_the_bank_covers_every_letter_and_is_byte_identical(tmp_path):
    outputs = []
    for run in ("a", "b"):
        out = tmp_path / run
        subprocess.run(
            [sys.executable, os.path.join(HERE, "render_bank.py"), "--out", str(out)],
            cwd=ROOT,
            check=True,
        )
        outputs.append(out)
    first, second = outputs
    voices = sorted(os.listdir(first))
    assert voices == sorted(os.listdir(second))
    for voice in voices:
        files = sorted(os.listdir(first / voice))
        assert len(files) == len(render_bank.bank_letters())
        match, mismatch, errors = filecmp.cmpfiles(first / voice, second / voice, files, False)
        assert not mismatch and not errors


def test_every_family_and_youth_has_a_voice():
    profiles = render_bank.family_profiles()
    assert len(profiles) == 16
    assert profiles["wang"] == render_bank.read_profile(
        os.path.join(ROOT, render_bank.PROFILE_DIR, "wang.tres")
    )
    for profile in profiles.values():
        assert set(profile) == set(render_bank.FIELDS)


def test_a_profile_saved_with_default_values_still_reads(tmp_path):
    defaults = render_bank.profile_defaults()
    assert set(defaults) == set(render_bank.FIELDS)
    path = tmp_path / "plain.tres"
    path.write_text('[resource]\nscript = ExtResource("1")\npitch = 1.2e2\n', encoding="utf-8")
    profile = render_bank.read_profile(str(path))
    assert profile["pitch"] == 120.0
    assert profile["tone"] == defaults["tone"]


def test_each_letter_plays_once_and_punctuation_pauses():
    import voice_proto

    events = voice_proto.events_for("Down to 2.")
    letters = "".join(value for kind, value, _p, _e in events if kind == "letter")
    assert letters == "downtotwo"
    pauses = [value for kind, value, _p, _e in events if kind == "pause"]
    assert pauses == [voice_proto.PAUSES[" "], voice_proto.PAUSES[" "], voice_proto.PAUSES["."]]


def test_each_sentence_takes_its_own_contour_and_a_line_is_repeatable():
    import voice_proto

    trail = [e for e in voice_proto.events_for("Bad cards...") if e[0] == "pause"]
    assert [e[1] for e in trail] == [voice_proto.PAUSES[" "], voice_proto.TRAIL_PAUSE]
    endings = [ending for _s, ending in voice_proto.sentences("Sorry. I had to?")]
    assert endings == [".", "?"]
    _out, _letters, pitches = voice_proto.render_line("Who dealt this?", "", "zhao")
    assert pitches[-1] > pitches[0] * 1.15
    _out, _letters, pitches = voice_proto.render_line("Bad cards from the start...", "", "zhao")
    assert pitches[-1] < pitches[0] * 0.75
    first = voice_proto.render_line("Pass.", "calm", "wang")[0]
    assert first == voice_proto.render_line("Pass.", "calm", "wang")[0]


def test_a_long_question_stays_level_until_its_last_word_rises():
    import voice_proto

    line = "You going to play that, or hold it till the thaw?"
    _out, letters, pitches = voice_proto.render_line(line, "", "zhao")
    last = len("thaw")
    body = pitches[:-last]
    base = voice_proto.VOICES["zhao"]["pitch"]
    assert max(body) < base * 1.2
    assert min(body) > base * 0.85
    assert len({round(p) for p in body}) > 5
    assert pitches[-1] > max(body)
