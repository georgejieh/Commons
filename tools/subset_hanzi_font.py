"""Cuts the decorative Chinese face down to the characters the game draws.

The game is English only; Chinese appears as decoration (ADR 0024). The full Noto Serif
SC is 25 MB, so the repository ships a heavy-weight subset holding only the characters
found in the data: each family's hanzi and the endings' seals. Run it again whenever
those change, with the variable font from the google/fonts repository (the pinned hash
is in docs/DEPENDENCIES.md):

    python tools/subset_hanzi_font.py PATH/TO/NotoSerifSC[wght].ttf

It writes art/fonts/NotoSerifSC-Black-subset.ttf.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ["data/villagers", "data/run/endings.tres"]
OUTPUT = ROOT / "art" / "fonts" / "NotoSerifSC-Black-subset.ttf"
WEIGHT = 900
CJK = re.compile(r"[一-鿿]")


def collect_characters(root: Path = ROOT) -> str:
    """Every Chinese character in the data that a seal may draw, sorted, each once."""
    found: set[str] = set()
    for source in SOURCES:
        path = root / source
        files = sorted(path.rglob("*.tres")) if path.is_dir() else [path]
        for file in files:
            found.update(CJK.findall(file.read_text(encoding="utf-8")))
    return "".join(sorted(found))


def write_subset(source: Path, output: Path, characters: str) -> None:
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    font = TTFont(source)
    missing = [each for each in characters if ord(each) not in font.getBestCmap()]
    if missing:
        raise SystemExit(f"The font lacks: {''.join(missing)}")
    heavy = instancer.instantiateVariableFont(font, {"wght": WEIGHT})
    options = subset.Options()
    options.layout_features = []
    options.hinting = False
    options.notdef_outline = True
    cutter = subset.Subsetter(options)
    cutter.populate(text=characters)
    cutter.subset(heavy)
    # Keep the source's timestamp, so the same input always gives the same bytes.
    heavy.recalcTimestamp = False
    heavy.save(output)


def main(arguments: list[str]) -> int:
    if len(arguments) != 1:
        print(__doc__)
        return 2
    characters = collect_characters()
    write_subset(Path(arguments[0]), OUTPUT, characters)
    # The characters themselves are left out: a Windows console may not hold them.
    print(f"{OUTPUT.relative_to(ROOT).as_posix()}: {len(characters)} characters")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
