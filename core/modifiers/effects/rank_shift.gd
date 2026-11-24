class_name RankShift
extends RefCounted
## Moves one rank to just above another in an effective-rank map, so order holds whatever
## the map looked like before (ADR 0008). Shared by Promotion of the Masses, Rehabilitation
## and Class Label. In a seat's own order, 0 to 14 with no gaps, the ranks between shift to
## make room. In its standings (Standing, ADR 0039) the rank drops into the gap just above
## its target and no printed standing moves, so the ranks it passes stay level with every
## other seat's; only ranks already in that gap above the target shift, and never out of it.


## step is the map's gap between printed ranks: 1, or Standing.STEP for standings.
static func move_above(rank_map: PackedByteArray, rank: int, above: int, step: int = 1) -> void:
	var low: int = rank_map[rank]
	var high: int = rank_map[above]
	if low == high:
		return
	if step > 1:
		_drop_into_gap(rank_map, rank, high, step)
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


## Puts rank just above the value high in standings: after every other rank of high's gap
## (the values between one printed standing and the next) that stands at or below high,
## and before the rest, which shift up to make room. When the shift would reach the next
## printed standing, the gap packs from its floor instead; fifteen ranks always fit in it.
static func _drop_into_gap(rank_map: PackedByteArray, rank: int, high: int, step: int) -> void:
	var floor_value: int = high - high % step
	var dwellers: Array[int] = []
	for other: int in Ranks.COUNT:
		var value: int = rank_map[other]
		if other != rank and value > floor_value and value < floor_value + step:
			dwellers.append(other)
	dwellers.sort_custom(func(a: int, b: int) -> bool: return rank_map[a] < rank_map[b])
	var at: int = 0
	while at < dwellers.size() and rank_map[dwellers[at]] <= high:
		at += 1
	dwellers.insert(at, rank)
	var values: PackedInt32Array = PackedInt32Array()
	var last: int = high
	for index: int in dwellers.size():
		var value: int = rank_map[dwellers[index]]
		if index >= at:
			value = high + 1 if index == at else maxi(value, last + 1)
			last = value
		values.append(value)
	if last >= floor_value + step:
		for index: int in dwellers.size():
			values[index] = floor_value + 1 + index
	for index: int in dwellers.size():
		rank_map[dwellers[index]] = values[index]
