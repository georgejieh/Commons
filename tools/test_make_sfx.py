"""The synthesized sounds render the same bytes every time and match the files shipped."""

import io
import wave

import make_sfx

MANIFEST = make_sfx.ROOT / "audio" / "sources" / "manifest.csv"


def test_rendering_is_deterministic_and_matches_the_shipped_files() -> None:
    first = make_sfx.renders()
    assert first == make_sfx.renders()
    for file_name, data in first:
        assert (make_sfx.OUT / file_name).read_bytes() == data, file_name


def test_every_file_is_short_mono_and_under_the_ceiling() -> None:
    for file_name, data in make_sfx.renders():
        with wave.open(io.BytesIO(data)) as sound:
            assert sound.getnchannels() == 1
            assert sound.getsampwidth() == 2
            assert sound.getframerate() == 44100
            frames = sound.readframes(sound.getnframes())
            seconds = sound.getnframes() / sound.getframerate()
        assert seconds < 0.7, file_name
        peak = max(
            abs(int.from_bytes(frames[i : i + 2], "little", signed=True))
            for i in range(0, len(frames), 2)
        )
        # -1 dBFS.
        assert peak <= 32767 * 0.892, file_name


def test_every_file_is_logged() -> None:
    logged = MANIFEST.read_text(encoding="utf-8")
    for file_name, _data in make_sfx.renders():
        assert "audio/sfx/" + file_name in logged, file_name
