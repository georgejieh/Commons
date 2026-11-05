"""Packs a folder of sprites into one atlas and writes a Godot AtlasTexture per sprite (P3C.4).

Sprites are placed on shelves in name order, so the same input always gives the same
atlas and regions. The atlas is named `atlas_<category>.png`, and each AtlasTexture is
named after its sprite, following the `category_name_variant` convention in
art/STYLE.md. Atlases are at most 4096 x 4096.

    python tools/pack_atlas.py art/icons art/atlases/atlas_icons.png data/ui/atlas
"""

import argparse
import os

from PIL import Image

MAX_SIDE = 4096
PADDING = 2


def pack(sprites):
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


def _try(sprites, side):
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


def atlas_tres(atlas_res, region):
    x, y, w, h = region
    return (
        '[gd_resource type="AtlasTexture" format=3]\n\n'
        f'[ext_resource type="Texture2D" path="{atlas_res}" id="1"]\n\n'
        "[resource]\n"
        'atlas = ExtResource("1")\n'
        f"region = Rect2({x}, {y}, {w}, {h})\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("atlas")
    parser.add_argument("resources")
    args = parser.parse_args()
    names = sorted(n for n in os.listdir(args.source) if n.lower().endswith(".png"))
    images = {n: Image.open(os.path.join(args.source, n)).convert("RGBA") for n in names}
    width, height, placed = pack([(n, images[n].size) for n in names])
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for name, (x, y, _, _) in placed.items():
        sheet.paste(images[name], (x, y))
    os.makedirs(os.path.dirname(args.atlas), exist_ok=True)
    sheet.save(args.atlas, format="PNG", optimize=False, compress_level=9)
    atlas_res = "res://" + args.atlas.replace(os.sep, "/")
    os.makedirs(args.resources, exist_ok=True)
    for name, region in placed.items():
        path = os.path.join(args.resources, os.path.splitext(name)[0] + ".tres")
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(atlas_tres(atlas_res, region))
    print(f"{args.atlas}: {width}x{height}, {len(placed)} sprites")


if __name__ == "__main__":
    main()
