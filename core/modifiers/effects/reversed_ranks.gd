class_name ReversedRanks
extends RefCounted
## Shared by the effects that turn rank order upside down.


static func reverse(rank_map: PackedByteArray) -> void:
	for rank: int in Ranks.COUNT:
		rank_map[rank] = Ranks.COUNT - 1 - rank_map[rank]
