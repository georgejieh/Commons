"""Writes the village's family Resources from one table, so the roster's data stays consistent.

    python tools/make_families.py [--out DIR]

Writes data/villagers/families/*.tres, data/villagers/youth/*.tres,
data/villagers/village.tres and the surnames and speech lines it owns in
data/strings/strings.csv. A portrait is linked only when its PNG exists. DIR stands for
the data folder (the default is the project's own); tools/test_make_families.py runs it
into a temporary one and requires every file to equal the committed one, so the table here
and the files never part.
"""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
FACES_PATH = DATA / "villagers" / "portrait_faces.json"
STRINGS = Path("strings") / "strings.csv"
LF = "\n"
LEVEL = {"L": 0, "M": 1, "H": 2}
TIER = {"E": 0, "M": 1, "H": 2, "X": 3}
UNLOCK = {"start": 0, "runs": 1, "landlord": 2}

# id, hanzi, tier, bombs coop honesty ambition grudge, unlock, runs, rising, mirrors,
# voice (pitch, tone, pace, roughness) or a path to an existing voice.
FAMILIES = [
    ("wang", "王", "M", "LHHLL", "start", 0, False, False, "res://data/ui/voices/wang.tres"),
    ("li", "李", "M", "LMLMM", "start", 0, False, False, (196.0, 1.08, 4.4, 0.18)),
    ("zhao", "赵", "H", "HMHHH", "start", 0, False, False, "res://data/ui/voices/zhao.tres"),
    ("sun", "孙", "M", "LHHLL", "start", 0, False, False, "res://data/ui/voices/sun.tres"),
    ("chen", "陈", "E", "HLLHL", "start", 0, False, False, (132.0, 1.0, 6.4, 0.2)),
    ("liu", "刘", "E", "LLLLL", "start", 0, False, False, (118.0, 0.92, 3.8, 0.22)),
    ("qin", "秦", "M", "MMMMH", "start", 0, False, False, (188.0, 1.05, 4.8, 0.15)),
    ("gao", "高", "E", "MLMML", "start", 0, True, False, (138.0, 1.02, 5.6, 0.08)),
    ("xu", "徐", "E", "LHHLL", "runs", 1, True, False, (228.0, 1.15, 5.8, 0.03)),
    ("zhou", "周", "H", "MMHMH", "runs", 2, False, False, (126.0, 0.98, 5.0, 0.1)),
    ("ma", "马", "X", "MMHML", "runs", 3, False, False, (108.0, 0.93, 4.0, 0.28)),
    ("feng", "冯", "H", "LHHLM", "runs", 4, False, False, (182.0, 1.0, 4.6, 0.2)),
    ("tang", "唐", "X", "MLHHH", "runs", 5, False, False, (104.0, 0.9, 3.9, 0.3)),
    ("deng", "邓", "H", "MLMMH", "landlord", 0, False, True, (200.0, 1.06, 5.2, 0.1)),
]
# Traits that change with a run meter (ADR 0043): (meter, band, trait, level, dossier key).
# Bands are MeterBands.Band (3 is HIGH); levels are LEVEL's.
SHIFTS = {
    "qin": [("famine", 3, "honesty", "L", "dossier.shift.famine")],
}
YOUTH = [
    ("youth_a", "", "E", "LHHLL", "start", 0, True, False, (224.0, 1.14, 5.9, 0.04)),
    ("youth_b", "", "E", "MLMML", "start", 0, True, False, (142.0, 1.03, 5.7, 0.07)),
]
YOUTH_SURNAMES = [
    ("hu", "Hu"),
    ("lin", "Lin"),
    ("zhu", "Zhu"),
    ("he", "He"),
    ("guo", "Guo"),
    ("luo", "Luo"),
    ("song", "Song"),
    ("xie", "Xie"),
    ("han", "Han"),
    ("yang", "Yang"),
    ("cao", "Cao"),
    ("peng", "Peng"),
]
SURNAMES = {
    "wang": "Wang",
    "li": "Li",
    "zhao": "Zhao",
    "sun": "Sun",
    "chen": "Chen",
    "liu": "Liu",
    "qin": "Qin",
    "gao": "Gao",
    "xu": "Xu",
    "zhou": "Zhou",
    "ma": "Ma",
    "feng": "Feng",
    "tang": "Tang",
    "deng": "Deng",
}
# Family lines: (event, mood, text). Keys become speech.<id>.<event>.<n>.
SPEECH = {
    "wang": [
        ("pass", "calm", "Go ahead, it's yours."),
        ("bomb", "tired", "I was saving that. Oh, well."),
        ("won", "calm", "Not bad for old hands."),
    ],
    "li": [
        ("pass", "calm", "Pass. You go on."),
        ("no_call", "calm", "No. I'll sit this one out."),
        ("lost", "sour", "I still had two twos."),
    ],
    "zhao": [
        ("call", "eager", "I'll call. Watch closely."),
        ("bomb", "eager", "There. That's how it's done."),
        ("cards_left", "eager", "{count}. Keep up."),
    ],
    "sun": [
        ("pass", "eager", "Pass, pass."),
        ("cards_left", "eager", "{count}! Nearly out."),
        ("won", "eager", "Out first. Shuffle up."),
    ],
    "chen": [
        ("call", "sly", "I'll call. These look lucky."),
        ("bomb", "sly", "Ha! Didn't see that coming."),
        ("lost", "sly", "Next hand's mine."),
    ],
    "liu": [
        ("pass", "tired", "Go on, you've got this one."),
        ("pass", "tired", "Mm. Pass."),
        ("won", "calm", "We did all right, didn't we?"),
    ],
    "qin": [
        ("no_call", "calm", "No. Pass it on."),
        ("pass", "calm", "I'll wait."),
        ("lost", "tired", "Better luck tomorrow."),
    ],
    "gao": [
        ("call", "sour", "Sure. Why not."),
        ("pass", "sour", "Is this how it always goes?"),
        ("lost", "sour", "Same as last time, then."),
    ],
    "xu": [
        ("pass", "eager", "You take it, you're doing better."),
        ("won", "eager", "Oh, that's us! Well played."),
        ("cards_left", "eager", "Only {count}! Help me out."),
    ],
    "zhou": [
        ("pass", "sly", "Go on, I'm listening."),
        ("cards_left", "sly", "{count} left? Mm."),
        ("won", "calm", "Good game. Same again?"),
    ],
    "ma": [
        ("pass", "calm", "Not yet."),
        ("won", "calm", "That'll do."),
        ("bomb", "calm", "Had that one ready a while."),
    ],
    "feng": [
        ("pass", "calm", "Go on, finish it."),
        ("call", "calm", "Give it here. I'll manage."),
        ("won", "calm", "Good. Tea after this one."),
    ],
    "tang": [
        ("call", "calm", "I'll take it, if no one minds."),
        ("pass", "calm", "Take your time."),
        ("lost", "calm", "It happens."),
    ],
    "deng": [
        ("call", "eager", "Mine. Let's see you take it back."),
        ("bomb", "sly", "Your trick, my bomb."),
        ("won", "eager", "Again. Same seats."),
    ],
    "youth_a": [
        ("pass", "eager", "Should I play that? No. Pass."),
        ("won", "eager", "Is that a win? It is!"),
        ("cards_left", "eager", "{count} left, I think."),
    ],
    "youth_b": [
        ("pass", "sour", "Pass. Obviously."),
        ("lost", "sour", "Great. Wonderful."),
        ("call", "sour", "Sure, I'll call."),
    ],
}
DEFAULT_FACE = [0.2, 0.12, 0.6, 0.55]


# The village book's own numbers, written after its roster, in this order.
VILLAGE_SETTINGS = {
    "reeducation_sets": "1",
    "rise_sets": "2",
    "opponents": "2",
    "starvations_per_year": "1",
    "drift_chance": "0.15",
    "pitch_step": "0.04",
    "pitch_limit": "0.12",
}


def tres_string(text: str) -> str:
    """The text as a quoted resource string, Chinese characters left as they are."""
    return json.dumps(text, ensure_ascii=False)


def _flag(value: bool) -> str:
    return "true" if value else "false"


def family_tres(row: tuple, faces: dict[str, list[float]]) -> str:
    """The text of one family's or youth template's resource file."""
    fid, hanzi, tier, levels, unlock, runs, rising, mirrors, voice = row
    exts = _externals(fid, voice)
    shift_ext = len(exts)
    out = ['[gd_resource type="Resource" script_class="FamilyDef" format=3]', ""]
    for index, (kind, path) in enumerate(exts):
        out.append(f'[ext_resource type="{kind}" path="{path}" id="{index + 1}"]')
    out.append("")
    out += _personality(tier, levels)
    if not isinstance(voice, str):
        out += _voice(voice)
    line_ids = _speech_lines(fid, out)
    shift_ids = _shift_resources(fid, shift_ext, out)
    line_refs = ", ".join(f'SubResource("{i}")' for i in line_ids)
    out += [
        '[sub_resource type="Resource" id="speech"]',
        'script = ExtResource("3")',
        f'lines = Array[ExtResource("4")]([{line_refs}])',
        "",
    ]
    face = faces.get(fid, DEFAULT_FACE)
    voice_ref = 'ExtResource("5")' if isinstance(voice, str) else 'SubResource("voice")'
    out += [
        "[resource]",
        'script = ExtResource("1")',
        f'id = "{fid}"',
        f'name_key = "villager.{fid}"',
        f"hanzi = {tres_string(hanzi)}",
        'personality = SubResource("personality")',
        f"voice = {voice_ref}",
    ]
    if _has_portrait(fid):
        out.append('portrait = ExtResource("6")')
    out += [
        f"portrait_face = Rect2({face[0]}, {face[1]}, {face[2]}, {face[3]})",
        'speech = SubResource("speech")',
        f"unlock = {UNLOCK[unlock]}",
        f"unlock_runs = {runs}",
        f"rising = {_flag(rising)}",
        f"mirrors_player = {_flag(mirrors)}",
    ]
    if shift_ids:
        shift_refs = ", ".join(f'SubResource("{i}")' for i in shift_ids)
        out.append(f'shifts = Array[ExtResource("{shift_ext}")]([{shift_refs}])')
    out.append("")
    return LF.join(out)


def _portrait(fid: str) -> str:
    return f"art/portraits/portrait_{fid}_face.png"


def _has_portrait(fid: str) -> bool:
    return (ROOT / _portrait(fid)).exists()


def _externals(fid: str, voice: str | tuple) -> list[tuple[str, str]]:
    """The file's external resources as (type, path), in the order their ids are given."""
    exts = [
        ("Script", "res://data/villagers/family_def.gd"),
        ("Script", "res://data/bots/personality.gd"),
        ("Script", "res://data/ui/speech_book.gd"),
        ("Script", "res://data/ui/speech_line.gd"),
    ]
    if isinstance(voice, str):
        exts.append(("Resource", voice))
    else:
        exts.append(("Script", "res://data/ui/voice_profile.gd"))
    if _has_portrait(fid):
        exts.append(("Texture2D", "res://" + _portrait(fid)))
    if SHIFTS.get(fid, []):
        exts.append(("Script", "res://data/villagers/trait_shift.gd"))
    return exts


def _personality(tier: str, levels: str) -> list[str]:
    bombs, coop, honesty, ambition, grudge = (LEVEL[c] for c in levels)
    return [
        '[sub_resource type="Resource" id="personality"]',
        'script = ExtResource("2")',
        f"tier = {TIER[tier]}",
        f"bomb_aggression = {bombs}",
        f"cooperation = {coop}",
        f"honesty = {honesty}",
        f"ambition = {ambition}",
        f"grudge = {grudge}",
        "",
    ]


def _voice(voice: tuple) -> list[str]:
    pitch, tone, pace, rough = voice
    return [
        '[sub_resource type="Resource" id="voice"]',
        'script = ExtResource("5")',
        f"pitch = {pitch:.1f}",
        f"tone = {tone:.2f}",
        f"pace = {pace:.1f}",
        f"roughness = {rough:.2f}",
        "",
    ]


def _speech_lines(fid: str, out: list[str]) -> list[str]:
    """Appends a sub-resource for each of the family's speech lines; returns their ids."""
    counts: dict[str, int] = {}
    line_ids = []
    for event, mood, _text in SPEECH.get(fid, []):
        counts[event] = counts.get(event, 0) + 1
        line_id = f"line_{len(line_ids)}"
        line_ids.append(line_id)
        out += [
            f'[sub_resource type="Resource" id="{line_id}"]',
            'script = ExtResource("4")',
            f'event = "{event}"',
            f'text_key = "speech.{fid}.{event}.{counts[event]}"',
            f'mood = "{mood}"',
            "",
        ]
    return line_ids


def _shift_resources(fid: str, script_id: int, out: list[str]) -> list[str]:
    """Appends a sub-resource for each of the family's trait shifts; returns their ids."""
    shift_ids = []
    for meter, band, trait, level, seen_key in SHIFTS.get(fid, []):
        shift_id = f"shift_{meter}"
        shift_ids.append(shift_id)
        out += [
            f'[sub_resource type="Resource" id="{shift_id}"]',
            f'script = ExtResource("{script_id}")',
            f'meter = "{meter}"',
            f"band = {band}",
            f'trait_name = "{trait}"',
            f"level = {LEVEL[level]}",
            f'seen_key = "{seen_key}"',
            "",
        ]
    return shift_ids


def village_tres(family_paths: list[str], youth_paths: list[str]) -> str:
    """The text of the village book, which lists every family and youth template."""
    exts = ['[ext_resource type="Script" path="res://data/villagers/village_book.gd" id="1"]']
    for index, path in enumerate(family_paths + youth_paths):
        exts.append(f'[ext_resource type="Resource" path="{path}" id="{index + 2}"]')
    family_refs = ", ".join(f'ExtResource("{i + 2}")' for i in range(len(family_paths)))
    youth_refs = ", ".join(
        f'ExtResource("{i + 2 + len(family_paths)}")' for i in range(len(youth_paths))
    )
    surnames = ", ".join(f'"villager.youth.{key}"' for key, _name in YOUTH_SURNAMES)
    out = ['[gd_resource type="Resource" script_class="VillageBook" format=3]', ""]
    out += exts
    out += [
        "",
        "[resource]",
        'script = ExtResource("1")',
        f"families = Array[Resource]([{family_refs}])",
        f"youth_templates = Array[Resource]([{youth_refs}])",
        f"youth_surnames = Array[String]([{surnames}])",
        *(f"{name} = {value}" for name, value in VILLAGE_SETTINGS.items()),
        "",
    ]
    return LF.join(out)


def string_rows() -> list[tuple[str, str]]:
    """The strings.csv rows this table owns, as (key, text), in order."""
    rows = [(f"villager.{fid}", name) for fid, name in SURNAMES.items()]
    rows += [(f"villager.youth.{key}", name) for key, name in YOUTH_SURNAMES]
    for fid, lines in SPEECH.items():
        counts: dict[str, int] = {}
        for event, _mood, text in lines:
            counts[event] = counts.get(event, 0) + 1
            rows.append((f"speech.{fid}.{event}.{counts[event]}", text))
    return rows


def csv_field(text: str) -> str:
    """The text as one CSV field, quoted when it holds a comma or a quote."""
    if any(c in text for c in ',"'):
        return '"' + text.replace('"', '""') + '"'
    return text


def strings_text() -> str:
    """The project's strings.csv with this table's rows updated in place or appended."""
    lines = (DATA / STRINGS).read_text(encoding="utf-8").splitlines()
    owned = dict(string_rows())
    written = set()
    for index, line in enumerate(lines):
        key = line.split(",", 1)[0]
        if key in owned:
            lines[index] = f"{key},{csv_field(owned[key])}"
            written.add(key)
    lines += [f"{key},{csv_field(text)}" for key, text in owned.items() if key not in written]
    return LF.join(lines) + LF


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline=LF)


def write_all(out: Path) -> tuple[int, int]:
    """Writes every file under out, which stands for the data folder; returns the counts."""
    faces = {}
    if FACES_PATH.exists():
        faces = json.loads(FACES_PATH.read_text(encoding="utf-8"))
    family_paths = []
    for folder, rows in (("families", FAMILIES), ("youth", YOUTH)):
        paths = []
        for row in rows:
            _write(out / "villagers" / folder / f"{row[0]}.tres", family_tres(row, faces))
            paths.append(f"res://data/villagers/{folder}/{row[0]}.tres")
        family_paths.append(paths)
    _write(out / "villagers" / "village.tres", village_tres(*family_paths))
    _write(out / STRINGS, strings_text())
    return len(FAMILIES), len(YOUTH)


def main() -> None:
    """Writes the family files, the village book and the strings."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DATA, help="the data folder to write into")
    args = parser.parse_args()
    families, youth = write_all(args.out)
    print(f"wrote {families} families and {youth} youth templates")


if __name__ == "__main__":
    main()
