"""Writes the village's family Resources (P4.5) from one table, so the roster's data
stays consistent. Run from the repository root: python tools/make_families.py

Writes data/villagers/families/*.tres, data/villagers/youth/*.tres and
data/villagers/village.tres. A portrait is linked only when its PNG exists.
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FACES_PATH = os.path.join(ROOT, "data", "villagers", "portrait_faces.json")
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
YOUTH = [
    ("youth_a", "", "E", "LHHLL", "start", 0, True, False, (224.0, 1.14, 5.9, 0.04)),
    ("youth_b", "", "E", "MLMML", "start", 0, True, False, (142.0, 1.03, 5.7, 0.07)),
]
YOUTH_SURNAMES = [
    ("hu", "Hu"), ("lin", "Lin"), ("zhu", "Zhu"), ("he", "He"), ("guo", "Guo"),
    ("luo", "Luo"), ("song", "Song"), ("xie", "Xie"), ("han", "Han"), ("yang", "Yang"),
    ("cao", "Cao"), ("peng", "Peng"),
]
SURNAMES = {
    "wang": "Wang", "li": "Li", "zhao": "Zhao", "sun": "Sun", "chen": "Chen", "liu": "Liu",
    "qin": "Qin", "gao": "Gao", "xu": "Xu", "zhou": "Zhou", "ma": "Ma", "feng": "Feng",
    "tang": "Tang", "deng": "Deng",
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


def tres_string(text):
    return json.dumps(text, ensure_ascii=False)


def family_tres(row, folder, faces):
    fid, hanzi, tier, levels, unlock, runs, rising, mirrors, voice = row
    exts = [
        ('Script', "res://data/villagers/family_def.gd"),
        ('Script', "res://data/bots/personality.gd"),
        ('Script', "res://data/ui/speech_book.gd"),
        ('Script', "res://data/ui/speech_line.gd"),
    ]
    if isinstance(voice, str):
        exts.append(("Resource", voice))
    else:
        exts.append(("Script", "res://data/ui/voice_profile.gd"))
    portrait = "art/portraits/portrait_%s_face.png" % fid
    has_portrait = os.path.exists(os.path.join(ROOT, portrait))
    if has_portrait:
        exts.append(("Texture2D", "res://" + portrait))
    lines = SPEECH.get(fid, [])
    out = ['[gd_resource type="Resource" script_class="FamilyDef" format=3]', ""]
    for index, (kind, path) in enumerate(exts):
        out.append('[ext_resource type="%s" path="%s" id="%d"]' % (kind, path, index + 1))
    out.append("")
    bombs, coop, honesty, ambition, grudge = (LEVEL[c] for c in levels)
    out += [
        '[sub_resource type="Resource" id="personality"]',
        'script = ExtResource("2")',
        "tier = %d" % TIER[tier],
        "bomb_aggression = %d" % bombs,
        "cooperation = %d" % coop,
        "honesty = %d" % honesty,
        "ambition = %d" % ambition,
        "grudge = %d" % grudge,
        "",
    ]
    if not isinstance(voice, str):
        pitch, tone, pace, rough = voice
        out += [
            '[sub_resource type="Resource" id="voice"]',
            'script = ExtResource("5")',
            "pitch = %.1f" % pitch,
            "tone = %.2f" % tone,
            "pace = %.1f" % pace,
            "roughness = %.2f" % rough,
            "",
        ]
    counts = {}
    line_ids = []
    for event, mood, _text in lines:
        counts[event] = counts.get(event, 0) + 1
        key = "speech.%s.%s.%d" % (fid, event, counts[event])
        line_id = "line_%d" % len(line_ids)
        line_ids.append(line_id)
        out += [
            '[sub_resource type="Resource" id="%s"]' % line_id,
            'script = ExtResource("4")',
            'event = "%s"' % event,
            'text_key = "%s"' % key,
            'mood = "%s"' % mood,
            "",
        ]
    out += [
        '[sub_resource type="Resource" id="speech"]',
        'script = ExtResource("3")',
        "lines = Array[ExtResource(\"4\")]([%s])"
        % ", ".join('SubResource("%s")' % i for i in line_ids),
        "",
    ]
    face = faces.get(fid, DEFAULT_FACE)
    voice_ref = 'ExtResource("5")' if isinstance(voice, str) else 'SubResource("voice")'
    out += [
        "[resource]",
        'script = ExtResource("1")',
        'id = "%s"' % fid,
        'name_key = "villager.%s"' % fid,
        "hanzi = %s" % tres_string(hanzi),
        'personality = SubResource("personality")',
        "voice = %s" % voice_ref,
    ]
    if has_portrait:
        out.append('portrait = ExtResource("6")')
    out += [
        "portrait_face = Rect2(%s, %s, %s, %s)" % tuple(face),
        'speech = SubResource("speech")',
        "unlock = %d" % UNLOCK[unlock],
        "unlock_runs = %d" % runs,
        "rising = %s" % ("true" if rising else "false"),
        "mirrors_player = %s" % ("true" if mirrors else "false"),
        "",
    ]
    path = os.path.join(ROOT, "data", "villagers", folder, fid + ".tres")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(out))
    return "res://data/villagers/%s/%s.tres" % (folder, fid)


def village_tres(family_paths, youth_paths):
    exts = ['[ext_resource type="Script" path="res://data/villagers/village_book.gd" id="1"]']
    for index, path in enumerate(family_paths + youth_paths):
        exts.append('[ext_resource type="Resource" path="%s" id="%d"]' % (path, index + 2))
    family_refs = ", ".join('ExtResource("%d")' % (i + 2) for i in range(len(family_paths)))
    youth_refs = ", ".join(
        'ExtResource("%d")' % (i + 2 + len(family_paths)) for i in range(len(youth_paths))
    )
    surnames = ", ".join('"villager.youth.%s"' % key for key, _name in YOUTH_SURNAMES)
    out = ['[gd_resource type="Resource" script_class="VillageBook" format=3]', ""]
    out += exts
    out += [
        "",
        "[resource]",
        'script = ExtResource("1")',
        "families = Array[Resource]([%s])" % family_refs,
        "youth_templates = Array[Resource]([%s])" % youth_refs,
        "youth_surnames = Array[String]([%s])" % surnames,
        "reeducation_sets = 2",
        "rise_sets = 2",
        "opponents = 2",
        "",
    ]
    path = os.path.join(ROOT, "data", "villagers", "village.tres")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(out))


def string_rows():
    rows = []
    for fid, name in SURNAMES.items():
        rows.append(("villager.%s" % fid, name))
    for key, name in YOUTH_SURNAMES:
        rows.append(("villager.youth.%s" % key, name))
    for fid, lines in SPEECH.items():
        counts = {}
        for event, _mood, text in lines:
            counts[event] = counts.get(event, 0) + 1
            rows.append(("speech.%s.%s.%d" % (fid, event, counts[event]), text))
    return rows


def csv_field(text):
    if any(c in text for c in ',"'):
        return '"%s"' % text.replace('"', '""')
    return text


def update_strings():
    path = os.path.join(ROOT, "data", "strings", "strings.csv")
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    rows = string_rows()
    generated = {key for key, _text in rows}
    lines = [line for line in lines if line.split(",", 1)[0] not in generated]
    for key, text in rows:
        lines.append("%s,%s" % (key, csv_field(text)))
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def main():
    faces = {}
    if os.path.exists(FACES_PATH):
        with open(FACES_PATH, encoding="utf-8") as handle:
            faces = json.load(handle)
    for folder in ("families", "youth"):
        os.makedirs(os.path.join(ROOT, "data", "villagers", folder), exist_ok=True)
    family_paths = [family_tres(row, "families", faces) for row in FAMILIES]
    youth_paths = [family_tres(row, "youth", faces) for row in YOUTH]
    village_tres(family_paths, youth_paths)
    update_strings()
    print("wrote %d families and %d youth templates" % (len(family_paths), len(youth_paths)))


if __name__ == "__main__":
    main()
