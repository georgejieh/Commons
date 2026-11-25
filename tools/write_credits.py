"""Writes data/credits/credits.json, what the credits screen shows from the project's records.

The records it reads are working files that never ship (audio/sources/manifest.csv,
art/sources/manifest.csv, docs/DEPENDENCIES.md, LICENSE), so their credits are carried
into the game as this one file, written here and committed. tools/test_write_credits.py
fails while the committed file differs from what this writes, so a new sound, picture,
font or licence line cannot ship uncredited. The engine's own notices and the fonts'
licence texts are not copied: the game reads them as it shows the screen, from the engine
and from art/fonts/, which every export carries.

    python tools/write_credits.py [--check]
"""

import argparse
import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "credits" / "credits.json"
SOUNDS = ROOT / "audio" / "sources" / "manifest.csv"
PICTURES = ROOT / "art" / "sources" / "manifest.csv"
DEPENDENCIES = ROOT / "docs" / "DEPENDENCIES.md"
LICENCE = ROOT / "LICENSE"
LF = "\n"
CRLF = "\r\n"
# A sound or voice the project made itself, which is counted, not credited by name.
ORIGINAL = "Original"
URL = re.compile(r"https?://[^\s)]+")
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
CODE = re.compile(r"`([^`]+)`")


def _rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def sounds(rows: list[dict[str, str]]) -> dict:
    """Each outside source's works by author and licence, and how many the project made."""
    made = 0
    credited = {}
    for row in rows:
        if row["license"] == ORIGINAL:
            made += 1
            continue
        authors = [a.strip() for a in row["author"].split(";") if a.strip() != "project"]
        source = row["source"].split(" + ")[0]
        where = row["pack_or_url"]
        link = URL.search(where)
        # A pack is written "Pack 1.0 (url) file"; a single sound "url title (note)".
        if link and where.startswith(link.group(0)):
            work = where[len(link.group(0)) :].strip()
        else:
            work = where
        work = work.split(" (")[0]
        key = (source, "; ".join(authors), row["license"])
        entry = credited.setdefault(
            key,
            {"source": source, "by": key[1], "licence": row["license"], "works": []},
        )
        if work not in entry["works"]:
            entry["works"].append(work)
    return {"made": made, "credited": list(credited.values())}


def pictures(rows: list[dict[str, str]]) -> list[dict]:
    """How many pictures each image model made, the ones cut from them counted with them."""
    counts = {}
    derived = []
    for row in rows:
        # "GPT Image via Codex image_gen (cropped)", or "tools/x.py from GPT Image source".
        model = row["model"].split(" (")[0]
        if " from " in model:
            derived.append(model.split(" from ")[1].split(" source")[0])
        else:
            counts[model] = counts.get(model, 0) + 1
    for made_by in derived:
        model = next((m for m in counts if m.startswith(made_by)), made_by)
        counts[model] = counts.get(model, 0) + 1
    return [{"model": model, "count": count} for model, count in counts.items()]


def _table(text: str) -> list[list[str]]:
    """The rows of the first Markdown table in text, as lists of cells."""
    found = []
    for line in text.splitlines():
        if not line.startswith("|"):
            if found:
                break
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not set("".join(cells)) <= set("- "):
            found.append(cells)
    return found[1:]


def _plain(cell: str) -> str:
    """A Markdown cell's words, links reduced to their text and code marks dropped."""
    return CODE.sub(r"\1", LINK.sub(r"\1", cell))


def shipped(text: str) -> tuple[list[dict], list[dict]]:
    """The fonts and other components the table says ship, each with its licence."""
    fonts = []
    components = []
    for name, version, licence, why, _replaced in _table(text):
        if "ships" not in why.lower() or "not shipped" in why.lower():
            continue
        title = LINK.search(name).group(1) if LINK.search(name) else _plain(name).split(" (")[0]
        files = [path for path in CODE.findall(licence) if path.startswith("art/fonts/")]
        if files:
            fonts.append(
                {"name": title, "licence": _plain(licence).split(" (")[0], "file": files[0]}
            )
        else:
            components.append(
                {
                    "name": title,
                    "version": _plain(version).split(",")[0],
                    "licence": _plain(licence),
                }
            )
    return fonts, components


def credits() -> dict:
    """Everything the credits screen shows, as the JSON document's value."""
    fonts, components = shipped(DEPENDENCIES.read_text(encoding="utf-8"))
    licence = LICENCE.read_text(encoding="utf-8").strip()
    return {
        "licence": licence,
        "fonts": fonts,
        "components": components,
        "sounds": sounds(_rows(SOUNDS)),
        "pictures": pictures(_rows(PICTURES)),
    }


def text() -> str:
    """The credits file as it is committed."""
    return json.dumps(credits(), indent="\t", ensure_ascii=False) + "\n"


def main(argv: list[str] | None = None) -> int:
    """Writes the credits file, or with --check says whether it is current."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if the file is not current")
    args = parser.parse_args(argv)
    if args.check:
        # A Windows checkout may turn the file's line ends to CRLF.
        current = OUT.read_bytes().decode("utf-8").replace(CRLF, LF) == text()
        if not current:
            print("data/credits/credits.json is out of date: run tools/write_credits.py")
        return 0 if current else 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text(), encoding="utf-8", newline=LF)
    return 0


if __name__ == "__main__":
    sys.exit(main())
