class_name WildLeaf
extends RefCounted
## Places a hand's spare wild cards (ADR 0029) for HandDecomposer's leaf, in closed form so
## the leaf stays cheap: each card in turn makes the lowest pair a trio while the loose
## singles and pairs outnumber the trios that could carry them, else the lowest single a
## pair, else the highest trio a bomb, else stays at its own rank. While no wild card has
## gone into a chain, all of them at their own rank is weighed too, so four of a wild rank
## can stay a pure-wild bomb. Plans are readings: a wild card counts as the rank it joins.

const SINGLE: int = 1
const PAIR: int = 2
const TRIO: int = 3

var _leaf: DecompositionLeaf
## Printed counts of the hand's wild cards.
var _own: PackedByteArray


func _init(leaf: DecompositionLeaf, own: PackedByteArray) -> void:
	_leaf = leaf
	_own = own


## Counts with spare wild cards placed. whole is true while every wild card is spare.
func placed(
	counts: PackedByteArray, planes: PackedInt32Array, spare: int, whole: bool
) -> PackedByteArray:
	var result: PackedByteArray = counts.duplicate()
	var own: PackedByteArray = _own.duplicate()
	for _card: int in spare:
		var rank: int = _target(result, planes.size())
		if rank == Ranks.INVALID:
			rank = _next_own(own)
		result[rank] += 1
	if not whole:
		return result
	var at_own: PackedByteArray = counts.duplicate()
	for rank: int in Ranks.COUNT:
		at_own[rank] += _own[rank]
	if _leaf.read(at_own, planes).score < _leaf.read(result, planes).score:
		return at_own
	return result


## The rank the next spare wild card joins, or INVALID to keep it at its own rank.
func _target(counts: PackedByteArray, planes: int) -> int:
	var lowest: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	var highest_trio: int = Ranks.INVALID
	var by_count: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for rank: int in Ranks.TWO + 1:
		var count: int = counts[rank]
		if count >= SINGLE and count <= TRIO:
			by_count[count] += 1
			if lowest[count] < 0:
				lowest[count] = rank
			if count == TRIO:
				highest_trio = rank
	var loose: int = by_count[SINGLE] + by_count[PAIR]
	if lowest[PAIR] >= 0 and loose > by_count[TRIO] + planes:
		return lowest[PAIR]
	if lowest[SINGLE] >= 0:
		return lowest[SINGLE]
	return highest_trio


## The printed rank of a spare wild card not yet placed: it stands at its own rank.
func _next_own(own: PackedByteArray) -> int:
	for rank: int in Ranks.TWO + 1:
		if own[rank] > 0:
			own[rank] -= 1
			return rank
	return Ranks.TWO
