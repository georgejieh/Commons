class_name ReversedRanks
extends RefCounted
## Shared by the effects that turn rank order upside down.


## step is the map's gap between printed ranks: 1, or Standing.STEP for standings, which
## turn over about Standing.TURN, the same middle, so they stay a seat's order on the
## shared scale with a moved rank in the mirrored gap, never off the scale.
static func reverse(rank_map: PackedByteArray, step: int = 1) -> void:
	var top: int = Ranks.COUNT - 1 if step == 1 else Standing.TURN
	for rank: int in Ranks.COUNT:
		rank_map[rank] = top - rank_map[rank]
