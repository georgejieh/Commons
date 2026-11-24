"""Renders the synthesized sound effects from their patches, the same bytes every time.

    python tools/make_sfx.py            # writes every file in SOUNDS to audio/sfx/
    python tools/make_sfx.py --check    # renders to memory and fails if a file differs

Each patch in audio/patches/ is rendered by the commons-sfx skill's vendored sfx.py with a
fixed seed per take, so the output never changes unless a patch does. A sound with takes
is rendered as name_01, name_02 and so on, each a varied take of the same patch. Every
file is logged in audio/sources/manifest.csv as Original synthesis (P5.2a).
"""

import argparse
import io
import os
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL = os.path.join(ROOT, ".claude", "skills", "commons-sfx", "scripts")
PATCHES = os.path.join(ROOT, "audio", "patches")
OUT = os.path.join(ROOT, "audio", "sfx")

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


def _sfx():
    sys.path.insert(0, SKILL)
    import sfx  # noqa: E402  (vendored, unmodified; see the skill's NOTICE.md)

    return sfx


def renders(names=None):
    """Every file as (file name, WAV bytes), in a fixed order."""
    sfx = _sfx()
    made = []
    for name, takes in SOUNDS.items():
        if names and name not in names:
            continue
        patch = sfx.load_patch(os.path.join(PATCHES, name + ".json"))
        jobs = [(f"{name}_{i + 1:02d}", SEED + i, True, i) for i in range(takes)]
        for stem, seed, variant, index in jobs or [(name, SEED, False, 0)]:
            samples = sfx.render(patch, seed, variant, index)
            made.append((stem + ".wav", _wav_bytes(sfx, samples)))
    return made


def _wav_bytes(sfx, samples):
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(sfx.SR)
        frames = bytearray()
        for value in samples:
            clipped = max(-1.0, min(1.0, value))
            frames += int(round(clipped * 32767)).to_bytes(2, "little", signed=True)
        out.writeframes(bytes(frames))
    return buffer.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="fail if a rendered file differs from the one on disk")
    parser.add_argument("names", nargs="*", help="patches to render; all when none are named")
    args = parser.parse_args()
    differs = []
    total = 0
    for file_name, data in renders(args.names):
        path = os.path.join(OUT, file_name)
        total += len(data)
        if args.check:
            with open(path, "rb") as existing:
                if existing.read() != data:
                    differs.append(file_name)
            continue
        with open(path, "wb") as out:
            out.write(data)
        print(f"{file_name}: {len(data)} bytes")
    print(f"{total} bytes in all")
    if differs:
        sys.exit("differs from its patch: " + ", ".join(differs))


if __name__ == "__main__":
    main()
