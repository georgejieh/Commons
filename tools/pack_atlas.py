"""Packs a folder of sprites into one atlas and writes a Godot AtlasTexture per sprite.

Sprites are placed on shelves in name order, so the same input always gives the same
atlas and regions. The atlas is named `atlas_<category>.png`, and each AtlasTexture is
named after its sprite, following the `category_name_variant` convention in
art/STYLE.md. Atlases are at most 4096 x 4096.

    python tools/pack_atlas.py art/icons art/atlases/atlas_icons.png data/ui/atlas
"""

import argparse
from pathlib import Path

from PIL import Image

MAX_SIDE = 4096
PADDING = 2
# Godot's own files end lines with a line feed, whatever the platform.
LF = "\n"


def pack(
    sprites: list[tuple[str, tuple[int, int]]],
) -> tuple[int, int, dict[str, tuple[int, int, int, int]]]:
    """Shelf packing; returns (width, height, {name: (x, y, w, h)})."""
    # The narrowest shelf width that fits, in steps of 64, keeps the atlas near square.
    for side in range(64, MAX_SIDE + 1, 64):
        placed = _try(sprites, side)
        if placed is None:
            continue
        width = max(x + w for x, y, w, h in placed.values()) + PADDING
        height = max(y + h for x, y, w, h in placed.values()) + PADDING
        if height <= side:
            return width, height, placed
    raise ValueError("sprites do not fit in a 4096 x 4096 atlas")


def _try(
    sprites: list[tuple[str, tuple[int, int]]], side: int
) -> dict[str, tuple[int, int, int, int]] | None:
    if any(width + 2 * PADDING > side for _, (width, _) in sprites):
        return None
    placed = {}
    x = y = shelf = PADDING
    for name, (width, height) in sprites:
        if x + width + PADDING > side:
            x, y, shelf = PADDING, y + shelf + PADDING, PADDING
        if y + height + PADDING > side:
            return None
        placed[name] = (x, y, width, height)
        x += width + PADDING
        shelf = max(shelf, height)
    return placed


def res_path(path: str | Path) -> str:
    """The Godot res:// path for a file, relative to the project root when it is inside."""
    root = Path(__file__).resolve().parent.parent
    full = Path(path).resolve()
    relative = full.relative_to(root) if full.is_relative_to(root) else Path(path)
    return "res://" + relative.as_posix()


def atlas_tres(atlas_res: str, region: tuple[int, int, int, int]) -> str:
    """The text of one AtlasTexture resource cut from the atlas at region."""
    x, y, w, h = region
    return (
        '[gd_resource type="AtlasTexture" format=3]\n\n'
        f'[ext_resource type="Texture2D" path="{atlas_res}" id="1"]\n\n'
        "[resource]\n"
        'atlas = ExtResource("1")\n'
        f"region = Rect2({x}, {y}, {w}, {h})\n"
    )


def main() -> None:
    """Packs a folder of PNGs into an atlas and writes one AtlasTexture each."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("atlas")
    parser.add_argument("resources")
    args = parser.parse_args()
    images = {}
    for file in sorted(Path(args.source).iterdir()):
        if file.suffix.lower() == ".png":
            with Image.open(file) as image:
                images[file.name] = image.convert("RGBA")
    width, height, placed = pack([(name, image.size) for name, image in images.items()])
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for name, (x, y, _, _) in placed.items():
        sheet.paste(images[name], (x, y))
    atlas = Path(args.atlas)
    atlas.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(atlas, format="PNG", optimize=False, compress_level=9)
    atlas_res = res_path(atlas)
    resources = Path(args.resources)
    resources.mkdir(parents=True, exist_ok=True)
    for name, region in placed.items():
        path = resources / (Path(name).stem + ".tres")
        path.write_text(atlas_tres(atlas_res, region), encoding="utf-8", newline=LF)
    print(f"{args.atlas}: {width}x{height}, {len(placed)} sprites")


if __name__ == "__main__":
    main()
