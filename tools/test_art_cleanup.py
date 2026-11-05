"""Tests for tools/art_cleanup.py (P3C.3). Run with: python -m pytest tools"""

import filecmp
import os
import random
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_cleanup  # noqa: E402


def _sample(path, seed):
    """A noisy sprite with soft edges and a transparent margin."""
    rng = random.Random(seed)
    image = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(6, 42):
        for x in range(8, 56):
            edge = x in (8, 55) or y in (6, 41)
            alpha = rng.randrange(40, 200) if edge else 255
            pixels[x, y] = (rng.randrange(256), rng.randrange(256), rng.randrange(256), alpha)
    image.save(path)


def _run(source, target, *extra):
    subprocess.run(
        [sys.executable, os.path.join(HERE, "art_cleanup.py"), str(source), str(target), *extra],
        check=True,
    )


def test_two_runs_are_byte_identical(tmp_path):
    source = tmp_path / "in"
    source.mkdir()
    for seed in range(3):
        _sample(source / f"sprite_{seed}.png", seed)
    for extra in ((), ("--dither", "--size", "40x30")):
        first, second = tmp_path / ("a" + "".join(extra)), tmp_path / ("b" + "".join(extra))
        _run(source, first, *extra)
        _run(source, second, *extra)
        names = sorted(os.listdir(first))
        assert len(names) == 3
        _, mismatch, errors = filecmp.cmpfiles(first, second, names, shallow=False)
        assert not mismatch and not errors


def test_cleaning_twice_changes_nothing(tmp_path):
    source = tmp_path / "in"
    source.mkdir()
    _sample(source / "sprite.png", 7)
    once, twice = tmp_path / "once", tmp_path / "twice"
    _run(source, once)
    _run(once, twice)
    assert filecmp.cmp(once / "sprite.png", twice / "sprite.png", shallow=False)


def test_output_uses_only_palette_colors_and_hard_alpha(tmp_path):
    colors, ink = art_cleanup.load_palette()
    assert len(colors) <= 32
    assert ink in colors
    image = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    for x in range(2, 18):
        for y in range(4, 16):
            image.putpixel((x, y), (x * 12, y * 15, 200, 90 + x * 9))
    result = art_cleanup.clean(image, colors, ink, size=(10, 6))
    assert result.size == (10, 6)
    for red, green, blue, alpha in result.getdata():
        assert alpha in (0, 255)
        if alpha:
            assert (red, green, blue) in colors
