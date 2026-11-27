class_name ReadingCodec
extends RefCounted
## Saves a play's reading (ADR 0029) for the commands and written decisions whose cards
## read more than one way, and checks the round's saved wild ranks. A reading is its type,
## main rank, chain length, card count and kicker ranks; the cards it spends are the
## command's own.

## The key a play's reading is saved under in a command.
const KEY: String = "reading"
## The fields a saved reading holds; every one is required.
const FIELDS: Array[String] = ["type", "main", "chain", "cards", "kickers"]
## At most two ranks are wild at once, each from 3 to 2.
const MAX_WILD_RANKS: int = 2
## More cards than any play can hold, plot copies included.
const MAX_CARDS: int = 64


## A reading as a map of the fields in FIELDS, for a command or a written decision.
static func encode(reading: Pattern) -> Dictionary:
	return {
		"type": reading.type,
		"main": reading.main_rank,
		"chain": reading.chain_length,
		"cards": reading.card_count,
		"kickers": Array(reading.kicker_ranks),
	}


## Returns null for no value. Call is_valid first on anything read from a file.
static func decode(value: Variant) -> Pattern:
	if not is_valid(value):
		return null
	var data: Dictionary = value
	var kickers: PackedByteArray = PackedByteArray()
	for rank: Variant in data["kickers"]:
		kickers.append(int(rank))
	var main: int = int(data["main"])
	var type: Pattern.Type = int(data["type"]) as Pattern.Type
	return Pattern.new(type, main, int(data["chain"]), int(data["cards"]), kickers, main)


## True when value is a saved reading whose fields are all present and make a play Pattern can
## hold.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if data.size() != FIELDS.size():
		return false
	for field: String in FIELDS:
		if not data.has(field):
			return false
	var type: Variant = data["type"]
	if not RunState.is_whole(type) or type <= Pattern.Type.PASS or type >= Pattern.Type.size():
		return false
	if not _is_rank(data["main"]) or not data["kickers"] is Array:
		return false
	for whole: Variant in [data["chain"], data["cards"]]:
		if not RunState.is_whole(whole) or whole < 1 or whole > MAX_CARDS:
			return false
	for rank: Variant in data["kickers"]:
		if not _is_rank(rank):
			return false
	# A chain that runs off the ranks, or kickers for every card, is no play, and
	# Pattern.counts() must never be asked to lay one out.
	var kickers: Array = data["kickers"]
	if int(data["main"]) + int(data["chain"]) > Ranks.COUNT:
		return false
	return kickers.size() < int(data["cards"])


## The round's wild ranks: at most two different ranks from 3 to 2.
static func wild_ranks_valid(value: Variant) -> bool:
	if not value is Array:
		return false
	var ranks: Array = value
	if ranks.size() > MAX_WILD_RANKS:
		return false
	var seen: Dictionary[int, bool] = {}
	for rank: Variant in ranks:
		if not _is_rank(rank) or rank > Ranks.TWO or seen.has(int(rank)):
			return false
		seen[int(rank)] = true
	return true


static func _is_rank(value: Variant) -> bool:
	return RunState.is_whole(value) and Ranks.is_valid(int(value))
