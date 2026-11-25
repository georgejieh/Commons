"""Renders the synthesized sound effects from their patches, the same bytes every time.

    python tools/make_sfx.py            # writes every file in SOUNDS to audio/sfx/
    python tools/make_sfx.py --check    # renders to memory and fails if a file differs

Each patch in audio/patches/ is rendered by the commons-sfx skill's vendored sfx.py with a
fixed seed per take, so the output never changes unless a patch does. A sound with takes
is rendered as name_01, name_02 and so on, each a varied take of the same patch. Every
file is logged in audio/sources/manifest.csv as Original synthesis.
"""

import argparse
import io
import sys
import wave
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parent.parent
SKILL = ROOT / ".claude" / "skills" / "commons-sfx" / "scripts"
PATCHES = ROOT / "audio" / "patches"
OUT = ROOT / "audio" / "sfx"

# Patch name, then how many takes: 0 for one file named as the patch.
SOUNDS = {
    "score_bead": 3,
    "score_stamp": 2,
    "score_land": 0,
    "score_land_heavy": 0,
    "score_bell": 0,
    "score_gong": 0,
    "paper_flick": 2,
    "brush_stroke": 0,
    "dice_bowl": 0,
    "soft_tap": 2,
}
# Each patch's takes start from this seed, so a take never changes when another is added.
SEED = 5200


def load_sfx() -> ModuleType:
    """The commons-sfx skill's vendored renderer."""
    if str(SKILL) not in sys.path:
        sys.path.insert(0, str(SKILL))
    import sfx  # vendored, unmodified; see the skill's NOTICE.md

    return sfx


def renders(names: list[str] | None = None) -> list[tuple[str, bytes]]:
    """Every file as (file name, WAV bytes), in a fixed order."""
    sfx = load_sfx()
    made = []
    for name, takes in SOUNDS.items():
        if names and name not in names:
            continue
        patch = sfx.load_patch(str(PATCHES / f"{name}.json"))
        jobs = [(f"{name}_{i + 1:02d}", SEED + i, True, i) for i in range(takes)]
        for stem, seed, variant, index in jobs or [(name, SEED, False, 0)]:
            samples = sfx.render(patch, seed, variant, index)
            made.append((stem + ".wav", wav_bytes(samples, sfx.SR)))
    return made


def wav_bytes(samples: list[float], rate: int) -> bytes:
    """Mono 16-bit PCM WAV of samples from -1 to 1, clipped there."""
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        frames = bytearray()
        for value in samples:
            clipped = max(-1.0, min(1.0, value))
            frames += int(round(clipped * 32767)).to_bytes(2, "little", signed=True)
        out.writeframes(bytes(frames))
    return buffer.getvalue()


def main() -> None:
    """Renders the sounds, or with --check compares them with the files on disk."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--check", action="store_true", help="fail if a rendered file differs from the one on disk"
    )
    parser.add_argument("names", nargs="*", help="patches to render; all when none are named")
    args = parser.parse_args()
    differs = []
    total = 0
    for file_name, data in renders(args.names):
        path = OUT / file_name
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
