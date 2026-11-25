"""The ambience loops match their patches, wrap without a seam and sit in the effects' loudness."""

import math

import pytest

import make_ambience
import make_sfx

MANIFEST = make_sfx.ROOT / "audio" / "sources" / "manifest.csv"
# The wrap may be no sharper than all but this share of the loop's own sample moves.
SHARPEST = 0.999
# Hann windows this long are compared across the wrap and all through the loop.
WINDOW = 1024
# Bands, as shares of the Nyquist frequency, whose energy the seam must keep to.
BANDS = ((0.0, 0.05), (0.05, 0.2), (0.2, 0.5), (0.5, 1.0))
# The most the window across the wrap may hold above the loudest window inside the loop.
SEAM_MARGIN_DB = 1.0
# Seconds of level compared either side of the wrap, and the most it may change across
# it beyond the largest change the loop makes anywhere else over the same span.
LEVEL_SECONDS = 0.1
LEVEL_MARGIN_DB = 0.5


@pytest.fixture(scope="module")
def rendered() -> list[tuple[str, int, list[float], bytes]]:
    return make_ambience.renders()


def test_every_loop_matches_its_patch_and_is_mono_16_bit(rendered: list) -> None:
    assert [name for name, *_ in rendered] == [name + ".wav" for name in make_ambience.BEDS]
    for file_name, rate, _samples, data in rendered:
        assert (make_sfx.OUT / file_name).read_bytes() == data, file_name
        _, shipped_rate, channels = _shipped(file_name)
        assert (shipped_rate, channels) == (rate, 1), file_name


def test_rendering_is_deterministic(rendered: list) -> None:
    first = rendered[0][0][: -len(".wav")]
    assert make_ambience.renders([first]) == rendered[:1]


def test_no_loop_has_a_seam() -> None:
    for name in make_ambience.BEDS:
        samples, rate, _ = _shipped(name + ".wav")
        assert _seam_faults(samples, rate) == [], name


def test_the_seam_check_finds_a_cut_mid_cycle_and_a_jump_in_level() -> None:
    rate = 11025
    tone = [0.5 * math.sin(2 * math.pi * 49.0 * i / rate) for i in range(rate * 2)]
    assert _seam_faults(tone, rate) == []
    assert "step" in _seam_faults(tone[:-37], rate)
    # Fading by half over the loop jumps back up at the wrap and nowhere else.
    faded = [v * (1.0 - 0.5 * i / len(tone)) for i, v in enumerate(tone)]
    assert "level" in _seam_faults(faded, rate)


def test_every_loop_sits_within_the_loudness_of_the_other_effects() -> None:
    sfx = make_sfx.load_sfx()
    beds = {name + ".wav" for name in make_ambience.BEDS}
    others = []
    for path in sorted(make_sfx.OUT.glob("*.wav")):
        if path.name not in beds:
            samples, rate, _ = sfx.doctor.read_wav(str(path))
            others.append(sfx.doctor.loudness(samples, rate))
    for name in sorted(beds):
        samples, rate, _ = _shipped(name)
        lufs = sfx.doctor.loudness(samples, rate)
        assert min(others) <= lufs <= max(others), (name, lufs, min(others), max(others))
        # -1 dBFS, as every effect.
        assert max(abs(v) for v in samples) <= 0.892, name


def test_every_loop_is_logged() -> None:
    logged = MANIFEST.read_text(encoding="utf-8")
    for name in make_ambience.BEDS:
        assert "audio/sfx/" + name + ".wav" in logged, name


def _shipped(file_name: str) -> tuple[list[float], int, int]:
    return make_sfx.load_sfx().doctor.read_wav(str(make_sfx.OUT / file_name))


def _seam_faults(x: list[float], rate: int) -> list[str]:
    """What sets the wrap apart from the rest of the loop.

    A step in the samples, energy in a band no other moment has, or a change of level no
    other moment makes.
    """
    faults = []
    n = len(x)
    steps = sorted(abs(x[i + 1] - x[i]) for i in range(n - 1))
    bends = sorted(abs(x[i + 1] - 2 * x[i] + x[i - 1]) for i in range(1, n - 1))
    step_limit = steps[int(len(steps) * SHARPEST)]
    bend_limit = bends[int(len(bends) * SHARPEST)]
    if (
        abs(x[0] - x[-1]) > step_limit
        or max(abs(x[0] - 2 * x[-1] + x[-2]), abs(x[1] - 2 * x[0] + x[-1])) > bend_limit
    ):
        faults.append("step")
    seam = _band_energies(x, 0)
    # Every window that keeps clear of the wrap, so a tick or a gust anywhere is among them.
    inside = [_band_energies(x, centre) for centre in range(WINDOW, n - WINDOW + 1, WINDOW // 2)]
    for band in range(len(BANDS)):
        if _db(seam[band]) > max(_db(window[band]) for window in inside) + SEAM_MARGIN_DB:
            faults.append("spectrum")
            break
    span = int(LEVEL_SECONDS * rate)
    changes = [abs(_level_change(x, at, span)) for at in range(span, n - span + 1, span // 2)]
    if abs(_level_change(x, 0, span)) > max(changes) + LEVEL_MARGIN_DB:
        faults.append("level")
    return faults


def _band_energies(x: list[float], centre: int) -> list[float]:
    """Energy per band of a Hann window centred on a sample, reading round the loop."""
    fft = make_sfx.load_sfx().doctor.fft
    n = len(x)
    frame = [
        complex(
            x[(centre - WINDOW // 2 + k) % n] * (0.5 - 0.5 * math.cos(2 * math.pi * k / WINDOW))
        )
        for k in range(WINDOW)
    ]
    power = [abs(v) ** 2 for v in fft(frame)[: WINDOW // 2]]
    half = WINDOW // 2
    return [sum(power[int(lo * half) : int(hi * half)]) for lo, hi in BANDS]


def _level_change(x: list[float], at: int, span: int) -> float:
    """Decibels from the span before a sample to the span after it, reading round the loop."""
    n = len(x)
    before = sum(x[(at - k - 1) % n] ** 2 for k in range(span))
    after = sum(x[(at + k) % n] ** 2 for k in range(span))
    return _db(after) - _db(before)


def _db(energy: float) -> float:
    return 10 * math.log10(max(energy, 1e-20))
