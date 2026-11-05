"""Batch cleanup for generated art (P3C.3).

Each image goes through the same fixed steps, in order:

1. Trim fully transparent edges.
2. Threshold alpha: pixels below the cut become fully transparent, the rest opaque.
3. Resize to the target size with a fixed Lanczos filter (only if a size is given).
4. Quantize to the style palette in art/palette.json, with optional Floyd-Steinberg
   dithering.
5. Normalize outlines: dark pixels that touch transparency become the palette's ink.

The output is deterministic (the same input always gives byte-identical files) and
idempotent (cleaning a cleaned image changes nothing).

    python tools/art_cleanup.py IN_DIR OUT_DIR [--size 512x512] [--dither]
"""

import argparse
import json
import os

from PIL import Image

PALETTE_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art", "palette.json")
ALPHA_CUT = 128
# Pixels at or below this luminance next to transparency count as outline.
OUTLINE_LUMA = 80
INK_NAME = "ink"
IMAGE_TYPES = (".png", ".webp", ".jpg", ".jpeg")


def load_palette(path=PALETTE_PATH):
    """The palette as a list of (r, g, b), and the ink color."""
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    colors = [_rgb(entry["hex"]) for entry in data["colors"]]
    ink = next(_rgb(entry["hex"]) for entry in data["colors"] if entry["name"] == INK_NAME)
    return colors, ink


def _rgb(hex_text):
    value = hex_text.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def trim(image):
    box = image.getchannel("A").getbbox()
    return image.crop(box) if box else image


def threshold_alpha(image):
    alpha = image.getchannel("A").point(lambda value: 255 if value >= ALPHA_CUT else 0)
    result = image.copy()
    result.putalpha(alpha)
    return result


def resize(image, size):
    if size is None or image.size == size:
        return image
    return image.resize(size, Image.Resampling.LANCZOS)


def quantize(image, colors, dither):
    """Maps every opaque pixel to its palette color; transparent pixels stay clear."""
    flat = [channel for color in colors for channel in color]
    holder = Image.new("P", (1, 1))
    holder.putpalette(flat + flat[:3] * (256 - len(colors)))
    mode = Image.Dither.FLOYDSTEINBERG if dither else Image.Dither.NONE
    mapped = image.convert("RGB").quantize(palette=holder, dither=mode).convert("RGB")
    result = mapped.convert("RGBA")
    result.putalpha(image.getchannel("A"))
    return result


def normalize_outlines(image, ink):
    """Dark pixels that touch transparency, or the image edge, become pure ink."""
    pixels = image.load()
    width, height = image.size
    changes = []
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0 or (red, green, blue) == ink:
                continue
            if 0.299 * red + 0.587 * green + 0.114 * blue > OUTLINE_LUMA:
                continue
            if _touches_clear(pixels, x, y, width, height):
                changes.append((x, y))
    for x, y in changes:
        pixels[x, y] = ink + (255,)
    return image


def _touches_clear(pixels, x, y, width, height):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if nx < 0 or ny < 0 or nx >= width or ny >= height or pixels[nx, ny][3] == 0:
            return True
    return False


def clean(image, colors, ink, size=None, dither=False):
    image = trim(image.convert("RGBA"))
    image = threshold_alpha(image)
    image = resize(image, size)
    image = threshold_alpha(image)
    image = quantize(image, colors, dither)
    return normalize_outlines(image, ink)


def save(image, path):
    # Fixed PNG settings and no metadata, so output bytes depend only on the pixels.
    image.save(path, format="PNG", optimize=False, compress_level=9)


def parse_size(text):
    if not text:
        return None
    width, height = text.lower().split("x")
    return int(width), int(height)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--size", help="target size as WIDTHxHEIGHT")
    parser.add_argument("--dither", action="store_true")
    parser.add_argument("--palette", default=PALETTE_PATH)
    args = parser.parse_args()
    colors, ink = load_palette(args.palette)
    os.makedirs(args.target, exist_ok=True)
    for name in sorted(os.listdir(args.source)):
        if not name.lower().endswith(IMAGE_TYPES):
            continue
        with Image.open(os.path.join(args.source, name)) as image:
            result = clean(image, colors, ink, parse_size(args.size), args.dither)
        out_name = os.path.splitext(name)[0] + ".png"
        save(result, os.path.join(args.target, out_name))
        print(f"{name} -> {out_name} {result.size[0]}x{result.size[1]}")


if __name__ == "__main__":
    main()
