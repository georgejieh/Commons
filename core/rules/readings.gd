class_name Readings
extends RefCounted
## Every legal reading of one set of cards (ADR 0029), strongest first: bombs and the
## rocket in the order they beat each other, then the other readings by hand type, the
## highest Pattern.Type first, then by effective main rank, then by kicker ranks, highest
## first. Cards with no wild card among them read through the classifier alone, as one
## reading or none. A kicker made of wild cards alone is read once (MoveGenerator).


## counts are the cards' printed ranks.
static func of(
	counts: PackedByteArray, rules: RuleSet, rank_map: PackedByteArray
) -> Array[Pattern]:
	var result: Array[Pattern] = []
	if WildSupply.of(counts, rules) == null:
		var classified: Classification = Classifier.classify(counts, rules, rank_map)
		if classified.is_valid():
			result.append(classified.pattern)
		return result
	result = MoveGenerator.exact(counts, rules, rank_map)
	result.sort_custom(func(a: Pattern, b: Pattern) -> bool: return stronger(a, b, rules))
	return result


## True when reading is a legal reading of exactly these printed cards, whatever any
## kicker of wild cards reads as. Returns the reading keyed in the rank map and with the
## cards it spends, or null.
static func checked(
	reading: Pattern, counts: PackedByteArray, rules: RuleSet, rank_map: PackedByteArray
) -> Pattern:
	if reading == null or reading.type == Pattern.Type.PASS:
		return null
	var ranks: PackedByteArray = reading.counts()
	var classified: Classification = Classifier.classify(ranks, rules, rank_map)
	if not classified.is_valid() or not classified.pattern.same_reading(reading):
		return null
	var total: int = 0
	for rank: int in Ranks.COUNT:
		total += counts[rank] - ranks[rank]
	var supply: WildSupply = WildSupply.of(counts, rules)
	if total != 0:
		return null
	if supply == null:
		return classified.pattern if ranks == counts else null
	var printed: PackedByteArray = supply.fill(ranks)
	if printed != counts:
		return null
	classified.pattern.spend(printed)
	return classified.pattern


## The documented order: true when a reads before b.
static func stronger(a: Pattern, b: Pattern, rules: RuleSet) -> bool:
	if PlayComparator.beats(a, b, rules) != PlayComparator.beats(b, a, rules):
		return PlayComparator.beats(a, b, rules)
	if a.type != b.type:
		return a.type > b.type
	if a.key != b.key:
		return a.key > b.key
	for index: int in mini(a.kicker_ranks.size(), b.kicker_ranks.size()):
		if a.kicker_ranks[index] != b.kicker_ranks[index]:
			return a.kicker_ranks[index] > b.kicker_ranks[index]
	return false
