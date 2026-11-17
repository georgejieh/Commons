class_name RankShift
extends RefCounted
## Moves one rank to just above another in an effective-rank map, shifting the ranks
## between to make room, so order holds whatever the map looked like before (ADR 0008).
## Shared by Promotion of the Masses, Rehabilitation and Class Label.


static func move_above(rank_map: PackedByteArray, rank: int, above: int) -> void:
	var low: int = rank_map[rank]
	var high: int = rank_map[above]
	if low == high:
		return
	for other: int in Ranks.COUNT:
		var value: int = rank_map[other]
		if value > low and value <= high:
			rank_map[other] = value - 1
		elif value > high and value < low:
			rank_map[other] = value + 1
	rank_map[rank] = high if low < high else high + 1


## The rank just above rank in the map: the one with the least value higher than its
## own, or Ranks.INVALID when none is higher.
static func next_up(rank_map: PackedByteArray, rank: int) -> int:
	var found: int = Ranks.INVALID
	for other: int in Ranks.COUNT:
		if rank_map[other] <= rank_map[rank]:
			continue
		if found == Ranks.INVALID or rank_map[other] < rank_map[found]:
			found = other
	return found


static func is_joker(rank: int) -> bool:
	return rank == Ranks.SMALL_JOKER or rank == Ranks.BIG_JOKER
