"""pack_atlas packs the same atlas every time, keeps each sprite inside it and refuses too big."""

import filecmp
import subprocess
import sys
from pathlib import Path

import pytest
from PIL import Image

import pack_atlas

TOOL = Path(__file__).resolve().parent / "pack_atlas.py"


def test_the_atlas_packer_is_deterministic_and_regions_fit(tmp_path: Path) -> None:
    sizes = ((30, 20), (64, 64), (10, 50), (40, 40))
    source = tmp_path / "sprites"
    source.mkdir()
    for index, size in enumerate(sizes):
        Image.new("RGBA", size, (index * 40, 90, 120, 255)).save(source / f"icon_{index}.png")
    outputs = []
    for run in ("a", "b"):
        atlas = tmp_path / run / "atlas_icons.png"
        resources = tmp_path / run / "atlas"
        subprocess.run(
            [sys.executable, str(TOOL), str(source), str(atlas), str(resources)],
            check=True,
        )
        outputs.append(atlas)
    assert filecmp.cmp(outputs[0], outputs[1], shallow=False)
    with Image.open(outputs[0]) as sheet:
        width, height = sheet.size
    assert width <= pack_atlas.MAX_SIDE
    assert height <= pack_atlas.MAX_SIDE
    named = [(f"icon_{index}.png", size) for index, size in enumerate(sizes)]
    _, _, placed = pack_atlas.pack(named)
    boxes = list(placed.values())
    for x, y, w, h in boxes:
        assert x + w <= width
        assert y + h <= height
    for index, a in enumerate(boxes):
        for b in boxes[index + 1 :]:
            apart = (
                a[0] + a[2] <= b[0]
                or b[0] + b[2] <= a[0]
                or a[1] + a[3] <= b[1]
                or b[1] + b[3] <= a[1]
            )
            assert apart


def test_the_packer_rejects_a_sprite_wider_than_an_atlas() -> None:
    with pytest.raises(ValueError, match="do not fit"):
        pack_atlas.pack([("wide.png", (5000, 10))])
