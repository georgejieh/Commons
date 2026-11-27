class_name ReadingText
extends RefCounted
## Puts wild ranks and readings into words (ADR 0029): "Sevens are wild", "Bomb of Nines",
## "Straight, 5 to 9". Rank names come from the string table: the printed glyphs the
## Rules sheet uses for a run's ends and a Single, and plural words for a set of one rank,
## so an Ace reads as "Aces". Readings that would read the same are told apart by their
## kickers.

## The string-table prefix of a rank's plural name.
const PLURAL_PREFIX: String = "rank.plural."
## The string-table prefix of a rank's printed glyph.
const LABEL_PREFIX: String = "rank."


## A hand type's key in the string table, its enum name in lower case: "trio_pair".
static func type_key(type: Pattern.Type) -> String:
	return String(Pattern.Type.keys()[type]).to_lower()


## Every hand type a play can be, all but a pass, in the enum's order.
static func hand_types() -> Array[Pattern.Type]:
	var types: Array[Pattern.Type] = []
	for type: int in Pattern.Type.values():
		if type != Pattern.Type.PASS:
			types.append(type as Pattern.Type)
	return types


## A rank's plural name, "Sevens".
static func plural(rank: int) -> String:
	var suffix: String = Ranks.label_key(rank).trim_prefix(LABEL_PREFIX)
	return TranslationServer.translate(PLURAL_PREFIX + suffix)


## A rank as the card prints it, "7" or "Q".
static func glyph(rank: int) -> String:
	return TranslationServer.translate(Ranks.label_key(rank))


## "Sevens are wild", or "Sevens and Queens are wild", in the order they were drawn; empty
## with none.
static func wild_line(ranks: Array[int]) -> String:
	if ranks.is_empty():
		return ""
	if ranks.size() == 1:
		return TranslationServer.translate("wild.one").format({"rank": plural(ranks[0])})
	var values: Dictionary = {"first": plural(ranks[0]), "second": plural(ranks[1])}
	return TranslationServer.translate("wild.two").format(values)


## One reading in words.
static func describe(reading: Pattern) -> String:
	var high: int = reading.main_rank + maxi(reading.chain_length, 1) - 1
	var values: Dictionary = {
		"rank": glyph(reading.main_rank) if reading.type != Pattern.Type.ROCKET else "",
		"ranks": plural(reading.main_rank) if reading.main_rank <= Ranks.TWO else "",
		"low": glyph(reading.main_rank) if reading.main_rank >= 0 else "",
		"high": glyph(high) if high >= 0 and high < Ranks.COUNT else "",
		"count": reading.card_count,
	}
	var key: String = "reading." + ReadingText.type_key(reading.type)
	if reading.type == Pattern.Type.BOMB and reading.card_count > Pattern.MIN_BOMB_WIDTH:
		key = "reading.bomb_big"
	return TranslationServer.translate(key).format(values)


## Every reading in words, in the order given; two that would read the same name their
## kickers too.
static func describe_all(readings: Array[Pattern]) -> PackedStringArray:
	var plain: PackedStringArray = []
	for reading: Pattern in readings:
		plain.append(describe(reading))
	var lines: PackedStringArray = []
	for index: int in plain.size():
		var shared: bool = plain.count(plain[index]) > 1
		lines.append(_with_kickers(readings[index]) if shared else plain[index])
	return lines


static func _with_kickers(reading: Pattern) -> String:
	var kickers: PackedStringArray = []
	for rank: int in reading.kicker_ranks:
		kickers.append(glyph(rank))
	var values: Dictionary = {"reading": describe(reading), "kickers": " ".join(kickers)}
	return TranslationServer.translate("reading.kickers").format(values)
