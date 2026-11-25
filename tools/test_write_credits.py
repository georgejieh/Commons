import write_credits


def _sound(source, author, licence, where):
    return {"source": source, "author": author, "license": licence, "pack_or_url": where}


def test_the_committed_credits_are_current():
    assert write_credits.main(["--check"]) == 0


def test_sounds_are_credited_by_source_author_and_licence():
    rows = [
        _sound("Synthesis", "project", "Original", "tools/make_sfx.py"),
        _sound("Kenney", "Kenney Vleugels", "CC0", "Casino Audio 1.1 (https://kenney.nl/a) b.ogg"),
        _sound("Kenney", "Kenney Vleugels", "CC0", "Casino Audio 1.1 (https://kenney.nl/a) c.ogg"),
        _sound("Kenney + synthesis", "Kenney Vleugels; project", "CC0", "Impact 1.0 (https://k/i) d"),
        _sound("Freesound", "radwoc", "CC0", "https://freesound.org/x/1/ piecz_07.wav"),
        _sound("Freesound", "ani", "CC0", "https://freesound.org/x/2/ Pencil writing (cut)"),
    ]
    made = write_credits.sounds(rows)
    assert made["made"] == 1
    assert made["credited"] == [
        {"source": "Kenney", "by": "Kenney Vleugels", "licence": "CC0",
         "works": ["Casino Audio 1.1", "Impact 1.0"]},
        {"source": "Freesound", "by": "radwoc", "licence": "CC0", "works": ["piecz_07.wav"]},
        {"source": "Freesound", "by": "ani", "licence": "CC0", "works": ["Pencil writing"]},
    ]


def test_pictures_cut_from_others_count_with_their_model():
    rows = [
        {"model": "tools/normal_map.py from GPT Image source"},
        {"model": "GPT Image via Codex image_gen"},
        {"model": "GPT Image via Codex image_gen (cropped)"},
    ]
    assert write_credits.pictures(rows) == [{"model": "GPT Image via Codex image_gen", "count": 3}]


def test_only_what_ships_is_credited():
    table = "\n".join(
        [
            "| Name | Version | License | Why | Replaced |",
            "| --- | --- | --- | --- | --- |",
            "| [Tool](https://x) | 1 | MIT | Lint; development only, not shipped | Nothing |",
            "| [Oswald](https://f) (`art/fonts/O.ttf`) | v | SIL OFL 1.1 (`art/fonts/O-OFL.txt`) "
            "| Face; ships | Nothing |",
            "| Godot Engine | 4.7.2-stable | MIT | The engine; ships in every build | Nothing |",
        ]
    )
    fonts, components = write_credits.shipped(table)
    assert fonts == [{"name": "Oswald", "licence": "SIL OFL 1.1", "file": "art/fonts/O-OFL.txt"}]
    assert components == [{"name": "Godot Engine", "version": "4.7.2-stable", "licence": "MIT"}]
