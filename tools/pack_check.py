"""Lists what a Godot pack holds and fails if anything in it should never ship.

Reads a .pck, a Windows .exe with its pack embedded, or a macOS .zip holding one, in the
pack formats Godot 4 writes (versions 2 to 4) when the directory is not encrypted. Prints
every path, one a line, with --list, and exits 1 naming each path under FORBIDDEN. The
release and CI exports run it on every preset's build, so a filter that lets a tool, a
test, a development add-on or a working file into the game fails the build.

    python tools/pack_check.py PACK [PACK ...] [--list]
"""

import argparse
import struct
import sys
import zipfile
from pathlib import Path

MAGIC = 0x43504447  # "GDPC"
ENCRYPTED_DIRECTORY = 1
RELATIVE_FILE_BASE = 2
RESERVED_WORDS = 16

# Path prefixes, relative to res://, that never ship: development add-ons, tools, tests,
# documents, reports, the art and sound working files, and the agents' own folders.
FORBIDDEN = (
    ".claude/",
    ".github/",
    ".githooks/",
    ".mcp.json",
    "addons/gdUnit4/",
    "addons/godot_ai/",
    "art/palette.json",
    "art/sources/",
    "audio/patches/",
    "audio/preview/",
    "audio/sources/",
    "build/",
    "design/",
    "docs/",
    "reports/",
    "tests/",
    "tools/",
    "CLAUDE.md",
    "README.md",
    "requirements-dev.txt",
)


class PackError(Exception):
    """The file is not a pack this tool can read."""


def _start(data: bytes) -> int:
    """Where the pack starts: at 0 for a .pck, or before the trailer of an embedded one."""
    if len(data) >= 4 and struct.unpack_from("<I", data, 0)[0] == MAGIC:
        return 0
    if len(data) >= 12 and struct.unpack_from("<I", data, len(data) - 4)[0] == MAGIC:
        size = struct.unpack_from("<Q", data, len(data) - 12)[0]
        start = len(data) - 12 - size
        if start >= 0 and struct.unpack_from("<I", data, start)[0] == MAGIC:
            return start
    raise PackError("no Godot pack found")


def paths(data: bytes) -> list[str]:
    """The res:// paths a pack holds, without the res:// prefix, in the pack's order."""
    start = _start(data)
    version, _major, _minor, _patch, flags = struct.unpack_from("<5I", data, start + 4)
    if version not in (2, 3, 4):
        raise PackError(f"pack format {version} is not read")
    if flags & ENCRYPTED_DIRECTORY:
        raise PackError("the pack's directory is encrypted")
    at = start + 24 + 8  # magic, five words, the file base
    if version >= 3:
        at = start + struct.unpack_from("<Q", data, at)[0]
    else:
        at += RESERVED_WORDS * 4
    count = struct.unpack_from("<I", data, at)[0]
    at += 4
    found = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, at)[0]
        at += 4
        name = data[at : at + length].split(b"\0", 1)[0].decode("utf-8")
        at += length + 8 + 8 + 16 + 4  # offset, size, md5, flags
        found.append(name[len("res://") :] if name.startswith("res://") else name)
    return found


def read(pack: str | Path) -> bytes:
    """The bytes of the pack in a file: the file itself, or the .pck inside a .zip."""
    pack = Path(pack)
    if pack.suffix == ".zip":
        with zipfile.ZipFile(pack) as bundle:
            inside = [name for name in bundle.namelist() if name.endswith(".pck")]
            if len(inside) != 1:
                raise PackError(f"{pack} holds {len(inside)} packs")
            return bundle.read(inside[0])
    return pack.read_bytes()


def forbidden(names: list[str]) -> list[str]:
    """The names that are under a forbidden prefix."""
    return [name for name in names if name.startswith(FORBIDDEN)]


def main(argv: list[str] | None = None) -> int:
    """Checks each pack named on the command line; returns the process exit code."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("packs", nargs="+")
    parser.add_argument("--list", action="store_true", help="print every path in each pack")
    args = parser.parse_args(argv)
    failed = False
    for pack in args.packs:
        names = paths(read(pack))
        if args.list:
            print("\n".join(names))
        bad = forbidden(names)
        for name in bad:
            print(f"{pack}: {name} must not ship", file=sys.stderr)
        failed = failed or bool(bad)
        print(f"{pack}: {len(names)} files, {len(bad)} that must not ship")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
