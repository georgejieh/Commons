"""make_families writes the committed family files, village book and strings byte for byte."""

from pathlib import Path

import make_families

CRLF = b"\r\n"
LF = b"\n"


def test_every_file_it_writes_is_the_committed_file(tmp_path: Path) -> None:
    families, youth = make_families.write_all(tmp_path)
    written = sorted(path for path in tmp_path.rglob("*") if path.is_file())
    assert len(written) == families + youth + 2
    for path in written:
        committed = make_families.DATA / path.relative_to(tmp_path)
        # A Windows checkout may turn the committed file's line ends to CRLF.
        assert committed.read_bytes().replace(CRLF, LF) == path.read_bytes(), committed
