"""Renders the board's ambience loops from their patches, the same bytes every time.

    python tools/make_ambience.py            # writes every loop in BEDS to audio/sfx/
    python tools/make_ambience.py --check    # renders to memory and fails if a file differs

Each patch in audio/patches/ has a fixed duration, so the vendored sfx.py renders it as a
loop: tails wrap to the start, and the master high-pass and room run round the loop. A
steady layer is four copies a quarter-loop apart, each fading in and out over the whole
loop, so its level holds at the wrap; a tonal one is tuned to steps of 4 / duration Hz so
the copies stay in phase. The loop is then low-passed round the wrap and decimated to the
bed's rate, mono 16-bit. Every file is logged in audio/sources/manifest.csv.
"""

import argparse
import sys
from types import ModuleType

import make_sfx

# Bed patch, then the rate it ships at: 11025 Hz where nothing sounds above 4.5 kHz.
BEDS = {
    "ambience_room": 11025,
    "ambience_hollow": 11025,
    "ambience_chatter": 11025,
    "ambience_wind": 11025,
    "ambience_drone": 11025,
    "ambience_crowd": 11025,
    "ambience_rustle": 22050,
    "ambience_whispers": 22050,
    "ambience_clock": 22050,
}
SEED = 6800
# Three cascaded low-passes at this share of the new rate before decimating, so little
# folds back below it.
ANTIALIAS = 0.42
ANTIALIAS_PASSES = 3
# The ceiling the decimated loop is held under, as sfx.py holds a patch's peak.
PEAK_DB = -3.0


def renders(names: list[str] | None = None) -> list[tuple[str, int, list[float], bytes]]:
    """Every loop as (file name, rate, samples, WAV bytes), in a fixed order."""
    sfx = make_sfx.load_sfx()
    made = []
    for name, rate in BEDS.items():
        if names and name not in names:
            continue
        patch = sfx.load_patch(str(make_sfx.PATCHES / f"{name}.json"))
        samples = decimate(sfx, sfx.render(patch, SEED), sfx.SR // rate)
        made.append((name + ".wav", rate, samples, make_sfx.wav_bytes(samples, rate)))
    return made


def decimate(sfx: ModuleType, loop: list[float], factor: int) -> list[float]:
    """The loop at 1 / factor of its rate, low-passed round the wrap so the seam stays whole."""
    if factor == 1:
        return loop
    n = len(loop)
    cutoff = [ANTIALIAS * sfx.SR / factor] * (2 * n)
    for _ in range(ANTIALIAS_PASSES):
        # Filtering two copies and keeping the second starts the filter from the loop's end.
        loop = sfx.svf(loop + loop, "lowpass", cutoff, 0.707)[n:]
    out = loop[::factor]
    peak = max(abs(v) for v in out) or 1.0
    ceiling = 10 ** (PEAK_DB / 20)
    return [v * ceiling / peak for v in out] if peak > ceiling else out


def main() -> None:
    """Renders the ambience loops, or with --check compares them with the files on disk."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--check", action="store_true", help="fail if a rendered file differs from the one on disk"
    )
    parser.add_argument("names", nargs="*", help="beds to render; all when none are named")
    args = parser.parse_args()
    differs = []
    total = 0
    for file_name, _rate, _samples, data in renders(args.names):
        path = make_sfx.OUT / file_name
        total += len(data)
        if args.check:
            if path.read_bytes() != data:
                differs.append(file_name)
            continue
        path.write_bytes(data)
        print(f"{file_name}: {len(data)} bytes")
    print(f"{total} bytes in all")
    if differs:
        sys.exit("differs from its patch: " + ", ".join(differs))


if __name__ == "__main__":
    main()
