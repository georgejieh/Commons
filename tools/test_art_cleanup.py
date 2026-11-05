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
    result = art_cleanup.clean(image, colors, ink, size=(10, 10))
    assert result.size == (10, 8)
    for red, green, blue, alpha in result.getdata():
        assert alpha in (0, 255)
        if alpha:
            assert (red, green, blue) in colors


def test_the_atlas_packer_is_deterministic_and_regions_fit(tmp_path):
    import pack_atlas

    source = tmp_path / "sprites"
    source.mkdir()
    for index, size in enumerate(((30, 20), (64, 64), (10, 50), (40, 40))):
        Image.new("RGBA", size, (index * 40, 90, 120, 255)).save(source / f"icon_{index}.png")
    outputs = []
    for run in ("a", "b"):
        atlas = tmp_path / run / "atlas_icons.png"
        resources = tmp_path / run / "atlas"
        subprocess.run(
            [sys.executable, os.path.join(HERE, "pack_atlas.py"), str(source), str(atlas), str(resources)],
            check=True,
        )
        outputs.append((atlas, resources))
    assert filecmp.cmp(outputs[0][0], outputs[1][0], shallow=False)
    width, height = Image.open(outputs[0][0]).size
    assert width <= pack_atlas.MAX_SIDE and height <= pack_atlas.MAX_SIDE
    sizes = [(f"icon_{i}.png", s) for i, s in enumerate(((30, 20), (64, 64), (10, 50), (40, 40)))]
    _, _, placed = pack_atlas.pack(sizes)
    boxes = list(placed.values())
    for x, y, w, h in boxes:
        assert x + w <= width and y + h <= height
    for i, a in enumerate(boxes):
        for b in boxes[i + 1 :]:
            assert a[0] + a[2] <= b[0] or b[0] + b[2] <= a[0] or a[1] + a[3] <= b[1] or b[1] + b[3] <= a[1]


def test_a_key_color_is_cut_out(tmp_path):
    colors, ink = art_cleanup.load_palette()
    image = Image.new("RGB", (30, 30), (252, 250, 248))
    for x in range(10, 20):
        for y in range(10, 20):
            image.putpixel((x, y), (180, 40, 25))
    result = art_cleanup.clean(image, colors, ink, key=(255, 255, 255))
    assert result.size == (10, 10)
    assert all(alpha == 255 for alpha in result.getchannel("A").getdata())


def test_normal_maps_are_deterministic_and_flat_on_flat_input(tmp_path):
    import normal_map

    flat = Image.new("RGB", (24, 16), (128, 128, 128))
    result = normal_map.normal_map(normal_map.height_field(flat, 0), 2.0)
    assert set(result.getdata()) == {(128, 128, 255)}
    source = tmp_path / "bumpy.png"
    bumpy = Image.new("RGB", (32, 32), (90, 90, 90))
    for x in range(10, 22):
        bumpy.putpixel((x, 16), (250, 250, 250))
    bumpy.save(source)
    outputs = []
    for run in ("a", "b"):
        target = tmp_path / f"{run}.png"
        subprocess.run([sys.executable, os.path.join(HERE, "normal_map.py"), str(source), str(target)], check=True)
        outputs.append(target)
    assert filecmp.cmp(outputs[0], outputs[1], shallow=False)
