class_name IntelText
extends RefCounted
## What the player's information Cadres reveal about one villager's hand, as a line for
## that villager's seat (P4.9). The Informant shows the hand types an opponent still
## holds; Peek shows the cards of the player closest to going out. With neither, or for
## a seat they don't cover, the line is empty.

## Hand types in the order they are listed, strongest first.
const ORDER: Array[int] = [
	Pattern.Type.ROCKET,
	Pattern.Type.BOMB,
	Pattern.Type.FOUR_TWO_PAIRS,
	Pattern.Type.FOUR_TWO_SINGLES,
	Pattern.Type.AIRPLANE_PAIRS,
	Pattern.Type.AIRPLANE_SINGLES,
	Pattern.Type.AIRPLANE,
	Pattern.Type.PAIR_CHAIN,
	Pattern.Type.STRAIGHT,
	Pattern.Type.TRIO_PAIR,
	Pattern.Type.TRIO_SINGLE,
	Pattern.Type.TRIO,
	Pattern.Type.PAIR,
	Pattern.Type.SINGLE,
]


static func for_seat(info: InfoView, seat: int) -> String:
	if info == null:
		return ""
	var lines: PackedStringArray = []
	if info.opponent_types.has(seat):
		var held: String = types_text(info.opponent_types[seat])
		if not held.is_empty():
			lines.append(TranslationServer.translate("intel.types").format({"list": held}))
	if info.closest_seat == seat and not info.closest_counts.is_empty():
		var cards: String = cards_text(info.closest_counts)
		lines.append(TranslationServer.translate("intel.cards").format({"list": cards}))
	return "\n".join(lines)


## Counts per hand type as "2 Pair, 1 Straight", leaving out types not held.
static func types_text(types: PackedInt32Array) -> String:
	var parts: PackedStringArray = []
	for type: int in ORDER:
		if type < types.size() and types[type] > 0:
			var key: String = "pattern." + String(Pattern.Type.keys()[type]).to_lower()
			parts.append("%d %s" % [types[type], TranslationServer.translate(key)])
	return ", ".join(parts)


## Cards by rank, lowest first, as their glyphs: "3 3 7 K 2".
static func cards_text(counts: PackedByteArray) -> String:
	var glyphs: PackedStringArray = []
	for rank: int in counts.size():
		for _copy: int in counts[rank]:
			glyphs.append(TranslationServer.translate(CardView.RANK_KEYS[rank]))
	return " ".join(glyphs)
