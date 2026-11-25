"""art_cleanup gives the same bytes every time, stays on the palette and cleans only once."""

import filecmp
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image

import art_cleanup

TOOL = Path(__file__).resolve().parent / "art_cleanup.py"


def _sample(path: Path, seed: int) -> None:
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


def _run(source: Path, target: Path, *extra: str) -> None:
    subprocess.run(
        [sys.executable, str(TOOL), str(source), str(target), *extra],
        check=True,
    )


def test_two_runs_are_byte_identical(tmp_path: Path) -> None:
    source = tmp_path / "in"
    source.mkdir()
    for seed in range(3):
        _sample(source / f"sprite_{seed}.png", seed)
    for extra in ((), ("--dither", "--size", "40x30")):
        first, second = tmp_path / ("a" + "".join(extra)), tmp_path / ("b" + "".join(extra))
        _run(source, first, *extra)
        _run(source, second, *extra)
        names = sorted(path.name for path in first.iterdir())
        assert len(names) == 3
        _, mismatch, errors = filecmp.cmpfiles(first, second, names, shallow=False)
        assert not mismatch
        assert not errors


def test_cleaning_twice_changes_nothing(tmp_path: Path) -> None:
    source = tmp_path / "in"
    source.mkdir()
    _sample(source / "sprite.png", 7)
    once, twice = tmp_path / "once", tmp_path / "twice"
    _run(source, once)
    _run(once, twice)
    assert filecmp.cmp(once / "sprite.png", twice / "sprite.png", shallow=False)


def test_output_uses_only_palette_colors_and_hard_alpha() -> None:
    colors, ink = art_cleanup.load_palette()
    assert len(colors) <= 32
    assert ink in colors
    image = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    for x in range(2, 18):
        for y in range(4, 16):
            image.putpixel((x, y), (x * 12, y * 15, 200, 90 + x * 9))
    result = art_cleanup.clean(image, colors, ink, size=(10, 10))
    assert max(result.size) == 10
    assert min(result.size) < 10
    for red, green, blue, alpha in result.getdata():
        assert alpha in (0, 255)
        if alpha:
            assert (red, green, blue) in colors


def test_a_key_color_is_cut_out() -> None:
    colors, ink = art_cleanup.load_palette()
    image = Image.new("RGB", (30, 30), (252, 250, 248))
    for x in range(10, 20):
        for y in range(10, 20):
            image.putpixel((x, y), (180, 40, 25))
    result = art_cleanup.clean(image, colors, ink, key=(255, 255, 255))
    assert result.size == (10, 10)
    assert all(alpha == 255 for alpha in result.getchannel("A").getdata())


def _idempotent(image: Image.Image, tmp_path: Path, *extra: str) -> None:
    source = tmp_path / "in"
    source.mkdir(exist_ok=True)
    image.save(source / "sprite.png")
    once, twice = tmp_path / "once", tmp_path / "twice"
    _run(source, once, *extra)
    _run(once, twice, *extra)
    assert filecmp.cmp(once / "sprite.png", twice / "sprite.png", shallow=False)


def test_cleaning_twice_changes_nothing_after_a_resize_with_a_thin_spike(tmp_path: Path) -> None:
    image = Image.new("RGBA", (100, 100), (0, 0, 0, 0))
    for x in range(10, 90):
        for y in range(20, 90):
            image.putpixel((x, y), (180, 40, 25, 255))
    for y in range(20):
        image.putpixel((50, y), (180, 40, 25, 255))
    _idempotent(image, tmp_path, "--size", "40x40")


def test_cleaning_twice_changes_nothing_with_a_key_and_pale_paper(tmp_path: Path) -> None:
    image = Image.new("RGB", (30, 30), (255, 255, 255))
    for x in range(5, 25):
        for y in range(5, 25):
            image.putpixel((x, y), (240, 232, 212) if x < 15 else (180, 40, 25))
    _idempotent(image, tmp_path, "--key", "ffffff")


def test_cleaning_twice_changes_nothing_with_soft_margins(tmp_path: Path) -> None:
    image = Image.new("RGBA", (6, 6), (200, 60, 40, 64))
    for x in range(2, 4):
        for y in range(2, 4):
            image.putpixel((x, y), (200, 60, 40, 255))
    _idempotent(image, tmp_path)
