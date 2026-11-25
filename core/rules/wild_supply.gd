class_name WildSupply
extends RefCounted
## A hand's cards split into natural cards and wild cards (ADR 0029), and how a reading
## is spent from them. A wild card may stand in for any rank from 3 to 2, never a joker.
## A reading is spent natural cards first, then wild cards at their own rank, then
## stand-ins: from the wild rank the hand holds fewer of, then the lower, so a larger
## group of a wild rank stays whole and the higher card stays for its own rank.

const NOTHING: PackedByteArray = []

## Printed counts with every wild rank at zero.
var natural: PackedByteArray = PackedByteArray()
## Printed counts of the wild ranks only.
var wild: PackedByteArray = PackedByteArray()
## Wild cards in all.
var total: int = 0
## The wild ranks the hand holds, in the order stand-ins are taken from them.
var order: PackedByteArray = PackedByteArray()
## For MoveGenerator: true in lean generation, and the ranks a kicker of wild cards alone
## may read as in the kicker pool being built, in order.
var lean: bool = false
var offered: PackedByteArray = PackedByteArray()


## Returns null when the counts hold no wild card, so every caller keeps its plain path.
static func of(counts: PackedByteArray, rules: RuleSet) -> WildSupply:
	var ranks: Array[int] = rules.wild_ranks()
	if ranks.is_empty():
		return null
	var held: int = 0
	for rank: int in ranks:
		held += counts[rank]
	if held == 0:
		return null
	return WildSupply.new(counts, ranks)


func _init(counts: PackedByteArray, ranks: Array[int]) -> void:
	natural = counts.duplicate()
	wild.resize(Ranks.COUNT)
	for rank: int in ranks:
		wild[rank] = natural[rank]
		natural[rank] = 0
		total += wild[rank]
		if wild[rank] > 0:
			order.append(rank)
	var sorted: Array[int] = []
	sorted.assign(order)
	sorted.sort_custom(_taken_first)
	order = PackedByteArray(sorted)


## Cards that can read as each rank: its natural cards plus every wild card, for 3 to 2.
func available() -> PackedByteArray:
	var result: PackedByteArray = natural.duplicate()
	for rank: int in Ranks.TWO + 1:
		result[rank] += total
	return result


## The printed counts that spend the reading, or nothing when these cards can't: too few
## wild cards, a joker to stand in for, or a play of wild cards alone with none of them at
## its own rank (rule 2).
func fill(reading: PackedByteArray) -> PackedByteArray:
	var printed: PackedByteArray = PackedByteArray()
	printed.resize(Ranks.COUNT)
	var left: PackedByteArray = wild.duplicate()
	var placed: int = 0
	var standing: int = 0
	for rank: int in Ranks.COUNT:
		var wanted: int = reading[rank]
		if wanted == 0:
			continue
		var own: int = mini(wanted, natural[rank] + left[rank])
		printed[rank] += own
		placed += own
		left[rank] -= maxi(0, own - natural[rank])
		if wanted > own and rank > Ranks.TWO:
			return NOTHING
		standing += wanted - own
	if placed == 0:
		return NOTHING
	for rank: int in order:
		var taken: int = mini(standing, left[rank])
		printed[rank] += taken
		standing -= taken
	return NOTHING if standing > 0 else printed


## The ranks a kicker made of wild cards alone reads as, in the order they are offered:
## the wild ranks held, then ranks with no natural card from the lowest. Ranks set in
## excluded are left out. Only the first of them are offered, because any two such
## kickers spend the same cards and every rule compares a play by its body.
func wild_only(excluded: int) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	for rank: int in order:
		if excluded & (1 << rank) == 0:
			result.append(rank)
	for rank: int in Ranks.TWO + 1:
		if natural[rank] == 0 and wild[rank] == 0 and excluded & (1 << rank) == 0:
			result.append(rank)
	return result


## Offers the first slots ranks a kicker of wild cards alone may read as (wild_only).
func offer(excluded: int, slots: int) -> void:
	offered = wild_only(excluded).slice(0, slots)


## True for a rank with natural cards, or one of the first slots offered ranks.
func is_offered(rank: int, slots: int) -> bool:
	if natural[rank] > 0:
		return true
	var at: int = offered.find(rank)
	return at >= 0 and at < slots


## Outside lean generation always true. In it, true when the rank's own cards, natural or
## wild at their own rank, fill the width with no stand-in.
func fills_own(rank: int, width: int) -> bool:
	return not lean or natural[rank] + wild[rank] >= width


## Keeps the pool's ranks a kicker of this width may be: those with natural cards and the
## first slots offered outside the excluded ranks, and in lean generation only those
## their own cards fill.
func offered_pool(pool: PackedByteArray, excluded: int, slots: int, width: int) -> PackedByteArray:
	offer(excluded, slots)
	var kept: PackedByteArray = PackedByteArray()
	for rank: int in pool:
		if is_offered(rank, slots) and fills_own(rank, width):
			kept.append(rank)
	return kept


## False for a play a bot never needs (ADR 0029): one with a wild card standing in for a
## kicker, which a natural card or the wild card's own rank does as well, or a four with
## two whose four needs a stand-in, which is a soft bomb broken up.
static func is_lean(move: Pattern) -> bool:
	if move.spent.is_empty():
		return true
	var four_two: bool = (
		move.type == Pattern.Type.FOUR_TWO_SINGLES or move.type == Pattern.Type.FOUR_TWO_PAIRS
	)
	var reading: PackedByteArray = move.counts()
	for rank: int in Ranks.COUNT:
		if reading[rank] > move.spent[rank]:
			if four_two or not PlayPlacement.is_body(rank, move):
				return false
	return true


func _taken_first(first: int, second: int) -> bool:
	if wild[first] != wild[second]:
		return wild[first] < wild[second]
	return first < second
