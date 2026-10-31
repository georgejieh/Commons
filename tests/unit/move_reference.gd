class_name MoveReference
extends RefCounted
## Brute force for checking the move generator. It tries every sub-multiset of a hand, so
## it proves the generator agrees with the classifier and comparator, which have their own
## hand-written tables.


static func mask_of(counts: PackedByteArray) -> int:
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			mask |= 1 << rank
	return mask


static func expected_moves(
	counts: PackedByteArray, current: Pattern, rules: RuleSet, map: PackedByteArray
) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	var picked: PackedByteArray = PackedByteArray()
	picked.resize(Ranks.COUNT)
	while true:
		var result: Classification = Classifier.classify(picked, rules, map)
		if result.is_valid():
			if current == null or PlayComparator.beats(result.pattern, current, rules):
				found[result.pattern.identity()] = true
		var rank: int = 0
		while rank < Ranks.COUNT and picked[rank] == counts[rank]:
			picked[rank] = 0
			rank += 1
		if rank == Ranks.COUNT:
			return found
		picked[rank] += 1
	return found


static func generated(
	counts: PackedByteArray, current: Pattern, rules: RuleSet, map: PackedByteArray
) -> Array[Pattern]:
	return MoveGenerator.generate(counts, mask_of(counts), current, rules, map)


static func identities(moves: Array[Pattern]) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	for move: Pattern in moves:
		found[move.identity()] = true
	return found
