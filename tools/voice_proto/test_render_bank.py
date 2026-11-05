"""Tests for the syllable bank renderer (P3B.13). Run with: python -m pytest tools"""

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


def test_the_bank_covers_every_syllable_and_is_byte_identical(tmp_path):
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
        assert len(files) == len(render_bank.bank_syllables())
        match, mismatch, errors = filecmp.cmpfiles(first / voice, second / voice, files, False)
        assert not mismatch and not errors


def test_a_profile_saved_with_default_values_still_reads(tmp_path):
    defaults = render_bank.profile_defaults()
    assert set(defaults) == set(render_bank.FIELDS)
    path = tmp_path / "plain.tres"
    path.write_text('[resource]\nscript = ExtResource("1")\npitch = 1.2e2\n', encoding="utf-8")
    profile = render_bank.read_profile(str(path))
    assert profile["pitch"] == 120.0
    assert profile["tone"] == defaults["tone"]
