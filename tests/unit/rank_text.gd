class_name RankText
extends RefCounted
## Writes count vectors as text for tests: "3334" or "TJQKA", with s and b for jokers.

const SYMBOLS: String = "3456789TJQKA2sb"


static func counts(text: String) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	for symbol: String in text:
		result[SYMBOLS.find(symbol)] += 1
	return result


static func rank(symbol: String) -> int:
	return SYMBOLS.find(symbol)


static func describe(pattern: Pattern) -> String:
	var kickers: String = ""
	for kicker: int in pattern.kicker_ranks:
		kickers += SYMBOLS[kicker]
	var name: String = Pattern.Type.keys()[pattern.type]
	return "%s %s x%d %s" % [name, SYMBOLS[pattern.main_rank], pattern.chain_length, kickers]
