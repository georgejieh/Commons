"""normal_map gives the same bytes every time, is flat on flat input and points up a slope."""

import filecmp
import subprocess
import sys
from pathlib import Path

from PIL import Image

import normal_map

TOOL = Path(__file__).resolve().parent / "normal_map.py"


def test_normal_maps_are_deterministic_and_flat_on_flat_input(tmp_path: Path) -> None:
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
        subprocess.run([sys.executable, str(TOOL), str(source), str(target)], check=True)
        outputs.append(target)
    assert filecmp.cmp(outputs[0], outputs[1], shallow=False)


def test_normal_maps_point_up_on_a_slope_rising_down_the_image() -> None:
    ramp = Image.new("L", (16, 16))
    for y in range(16):
        for x in range(16):
            ramp.putpixel((x, y), y * 16)
    result = normal_map.normal_map(ramp, 2.0)
    red, green, _blue = result.getpixel((8, 8))
    assert green > 128
    assert abs(red - 128) <= 1
