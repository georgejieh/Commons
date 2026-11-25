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
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "credits", "credits.json")
SOUNDS = os.path.join(ROOT, "audio", "sources", "manifest.csv")
PICTURES = os.path.join(ROOT, "art", "sources", "manifest.csv")
DEPENDENCIES = os.path.join(ROOT, "docs", "DEPENDENCIES.md")
LICENCE = os.path.join(ROOT, "LICENSE")
# A sound or voice the project made itself, which is counted, not credited by name.
ORIGINAL = "Original"
URL = re.compile(r"https?://[^\s)]+")
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
CODE = re.compile(r"`([^`]+)`")


def _rows(path):
    with open(path, encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def sounds(rows):
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


def pictures(rows):
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


def _table(text):
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


def _plain(cell):
    """A Markdown cell's words, links reduced to their text and code marks dropped."""
    return CODE.sub(r"\1", LINK.sub(r"\1", cell))


def shipped(text):
    """The fonts and other components the table says ship, each with its licence."""
    fonts = []
    components = []
    for name, version, licence, why, _replaced in _table(text):
        if "ships" not in why.lower() or "not shipped" in why.lower():
            continue
        title = LINK.search(name).group(1) if LINK.search(name) else _plain(name).split(" (")[0]
        files = [path for path in CODE.findall(licence) if path.startswith("art/fonts/")]
        if files:
            fonts.append({"name": title, "licence": _plain(licence).split(" (")[0], "file": files[0]})
        else:
            components.append(
                {"name": title, "version": _plain(version).split(",")[0], "licence": _plain(licence)}
            )
    return fonts, components


def credits():
    with open(DEPENDENCIES, encoding="utf-8") as handle:
        fonts, components = shipped(handle.read())
    with open(LICENCE, encoding="utf-8") as handle:
        licence = handle.read().strip()
    return {
        "licence": licence,
        "fonts": fonts,
        "components": components,
        "sounds": sounds(_rows(SOUNDS)),
        "pictures": pictures(_rows(PICTURES)),
    }


def text():
    return json.dumps(credits(), indent="\t", ensure_ascii=False) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if the file is not current")
    args = parser.parse_args(argv)
    if args.check:
        with open(OUT, encoding="utf-8", newline="") as handle:
            current = handle.read() == text()
        if not current:
            print("data/credits/credits.json is out of date: run tools/write_credits.py")
        return 0 if current else 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text())
    return 0


if __name__ == "__main__":
    sys.exit(main())
