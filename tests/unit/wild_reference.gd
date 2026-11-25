class_name WildReference
extends RefCounted
## Brute force for wild ranks (ADR 0029): every way to give a set's wild cards a rank from
## 3 to 2, read through the classifier, keeping rule 2's own rank for a play of wild cards
## alone. Slow on purpose, so it checks MoveGenerator and Readings, which never use it.


static func rules(wild: Array[int], big_bombs: bool, rocket_on_top: bool = true) -> RuleSet:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
	params.wild_ranks = wild.duplicate()
	params.five_plus_is_bomb = big_bombs
	params.rocket_above_wild_bomb = rocket_on_top
	return RuleSet.new(params)


## Every legal reading of exactly these printed cards, by identity, each spending them.
static func readings(
	printed: PackedByteArray, rules: RuleSet, map: PackedByteArray
) -> Dictionary[int, Pattern]:
	var reading: PackedByteArray = printed.duplicate()
	var wilds: int = 0
	for rank: int in rules.wild_ranks():
		wilds += reading[rank]
		reading[rank] = 0
	var found: Dictionary[int, Pattern] = {}
	_spread(0, wilds, reading, printed, rules, map, found)
	return found


## Every sub-multiset of a hand.
static func subsets(counts: PackedByteArray) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	var picked: PackedByteArray = PackedByteArray()
	picked.resize(Ranks.COUNT)
	while true:
		result.append(picked.duplicate())
		var rank: int = 0
		while rank < Ranks.COUNT and picked[rank] == counts[rank]:
			picked[rank] = 0
			rank += 1
		if rank == Ranks.COUNT:
			return result
		picked[rank] += 1
	return result


## What a comparison sees: type, main rank, length, cards and, for a bomb, its kind.
static func shape_of(pattern: Pattern) -> String:
	var kind: int = 0
	if pattern.type == Pattern.Type.BOMB:
		kind = PlayComparator.bomb_kind(pattern)
	return (
		"%d %d %d %d %d"
		% [pattern.type, pattern.main_rank, pattern.chain_length, pattern.card_count, kind]
	)


## True when a generated move matches a reading as the comparator sees it, or beats it as
## a bomb of the same rank and size.
static func covered(reading: Pattern, moves: Array[Pattern], rules: RuleSet) -> bool:
	for move: Pattern in moves:
		if shape_of(move) == shape_of(reading):
			return true
		var same_bomb: bool = (
			move.type == Pattern.Type.BOMB
			and reading.type == Pattern.Type.BOMB
			and move.main_rank == reading.main_rank
			and move.card_count == reading.card_count
		)
		if same_bomb and PlayComparator.beats(move, reading, rules):
			return true
	return false


static func wild_cards(counts: PackedByteArray, rules: RuleSet) -> int:
	var total: int = 0
	for rank: int in rules.wild_ranks():
		total += counts[rank]
	return total


static func _spread(
	rank: int,
	left: int,
	reading: PackedByteArray,
	printed: PackedByteArray,
	rules: RuleSet,
	map: PackedByteArray,
	found: Dictionary[int, Pattern]
) -> void:
	if rank > Ranks.TWO:
		if left == 0:
			_read(reading, printed, rules, map, found)
		return
	for extra: int in left + 1:
		reading[rank] += extra
		_spread(rank + 1, left - extra, reading, printed, rules, map, found)
		reading[rank] -= extra


static func _read(
	reading: PackedByteArray,
	printed: PackedByteArray,
	rules: RuleSet,
	map: PackedByteArray,
	found: Dictionary[int, Pattern]
) -> void:
	var classified: Classification = Classifier.classify(reading, rules, map)
	if not classified.is_valid():
		return
	var own: int = 0
	for rank: int in Ranks.COUNT:
		own += mini(reading[rank], printed[rank])
	if own == 0:
		return
	classified.pattern.spend(printed)
	found[classified.pattern.identity()] = classified.pattern
