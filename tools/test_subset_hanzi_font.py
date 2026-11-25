"""The character list for the Chinese face comes from the data, each character once."""

from subset_hanzi_font import collect_characters


def test_the_characters_are_the_seals_and_the_families() -> None:
    characters = collect_characters()
    for each in "斗地主王赵":
        assert each in characters
    assert len(set(characters)) == len(characters)
    assert characters == "".join(sorted(characters))
