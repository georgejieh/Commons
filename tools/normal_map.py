"""Makes a tangent-space normal map from an image's brightness (P3C.6).

Brightness is read as height: paper grain, folds and ink ridges become a gentle
surface for 2D lights. Height is blurred once, then Sobel gradients give the normal,
packed as RGB. Deterministic, so the same image always gives the same file.

    python tools/normal_map.py IN.png OUT.png [--strength 2.0] [--size 512]
"""

import argparse
import math

from PIL import Image, ImageFilter

BLUR_RADIUS = 1.5


def height_field(image, size):
    gray = image.convert("L")
    if size:
        scale = size / max(gray.size)
        if scale < 1.0:
            target = (max(1, round(gray.size[0] * scale)), max(1, round(gray.size[1] * scale)))
            gray = gray.resize(target, Image.Resampling.LANCZOS)
    return gray.filter(ImageFilter.GaussianBlur(BLUR_RADIUS))


def normal_map(height, strength):
    width, rows = height.size
    values = height.load()
    out = Image.new("RGB", (width, rows))
    pixels = out.load()

    def at(x, y):
        return values[min(max(x, 0), width - 1), min(max(y, 0), rows - 1)] / 255.0

    for y in range(rows):
        for x in range(width):
            dx = (at(x + 1, y - 1) + 2 * at(x + 1, y) + at(x + 1, y + 1)) - (
                at(x - 1, y - 1) + 2 * at(x - 1, y) + at(x - 1, y + 1)
            )
            dy = (at(x - 1, y + 1) + 2 * at(x, y + 1) + at(x + 1, y + 1)) - (
                at(x - 1, y - 1) + 2 * at(x, y - 1) + at(x + 1, y - 1)
            )
            # Green points up the image (OpenGL convention, as Godot's canvas lighting
            # expects); image y runs down, so a height rising downward tilts it up.
            nx, ny, nz = -dx * strength, dy * strength, 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            pixels[x, y] = tuple(round((component / length * 0.5 + 0.5) * 255) for component in (nx, ny, nz))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--strength", type=float, default=2.0)
    parser.add_argument("--size", type=int, default=0, help="longest side, 0 keeps the size")
    args = parser.parse_args()
    with Image.open(args.source) as image:
        result = normal_map(height_field(image, args.size), args.strength)
    result.save(args.target, format="PNG", optimize=False, compress_level=9)
    print(f"{args.target}: {result.size[0]}x{result.size[1]}")


if __name__ == "__main__":
    main()
