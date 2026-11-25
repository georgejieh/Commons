"""pack_check reads every pack layout Godot writes and names only what must not ship."""

import struct
import zipfile
from pathlib import Path

import pytest

import pack_check


def _pack(names: list[str], version: int = 4) -> bytes:
    """A pack in Godot's layout holding names, with no file data."""
    entries = b""
    for name in names:
        path = ("res://" + name).encode("utf-8")
        path += b"\0" * (-len(path) % 4)
        entries += struct.pack("<I", len(path)) + path + struct.pack("<QQ", 0, 0)
        entries += b"\0" * 16 + struct.pack("<I", 0)
    header = struct.pack("<6I", pack_check.MAGIC, version, 4, 7, 2, pack_check.RELATIVE_FILE_BASE)
    header += struct.pack("<Q", 0)
    if version >= 3:
        start = len(header) + 8 + pack_check.RESERVED_WORDS * 4
        header += struct.pack("<Q", start)
    header += b"\0" * (pack_check.RESERVED_WORDS * 4)
    return header + struct.pack("<I", len(names)) + entries


NAMES = ["project.binary", "ui/main.tscn", "art/fonts/Oswald-OFL.txt"]


@pytest.mark.parametrize("version", [2, 3, 4])
def test_reads_every_path_in_each_format(version: int) -> None:
    assert pack_check.paths(_pack(NAMES, version)) == NAMES


def test_reads_a_pack_embedded_at_the_end_of_an_executable() -> None:
    pack = _pack(NAMES)
    exe = b"MZ" + b"\x90" * 1000 + pack + struct.pack("<QI", len(pack), pack_check.MAGIC)
    assert pack_check.paths(exe) == NAMES


def test_refuses_what_is_not_a_pack() -> None:
    with pytest.raises(pack_check.PackError):
        pack_check.paths(b"not a pack at all")


def test_names_only_what_must_not_ship() -> None:
    names = NAMES + [".mcp.json", "tools/balance.gd", "tests/unit/x.gd", "art/palette.json"]
    names += ["addons/gdUnit4/plugin.cfg", "docs/PLAN.md", "audio/sources/manifest.csv"]
    assert pack_check.forbidden(names) == names[len(NAMES) :]


def test_a_forbidden_path_fails_the_check(tmp_path: Path, capsys: pytest.CaptureFixture) -> None:
    clean = tmp_path / "clean.pck"
    clean.write_bytes(_pack(NAMES))
    dirty = tmp_path / "dirty.pck"
    dirty.write_bytes(_pack(NAMES + ["tools/tournament.gd"]))
    assert pack_check.main([str(clean)]) == 0
    assert pack_check.main([str(clean), str(dirty)]) == 1
    assert "tools/tournament.gd must not ship" in capsys.readouterr().err


def test_reads_the_pack_inside_a_macos_zip(tmp_path: Path) -> None:
    bundle = tmp_path / "Commons.zip"
    with zipfile.ZipFile(bundle, "w") as archive:
        archive.writestr("Commons.app/Contents/Resources/Commons.pck", _pack(NAMES))
    assert pack_check.paths(pack_check.read(bundle)) == NAMES
