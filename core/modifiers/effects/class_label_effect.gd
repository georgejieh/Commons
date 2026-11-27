class_name ClassLabelEffect
extends ModifierEffect
## While the holder is landlord, the ranks the holder holds only stamped cards of rank
## above 2s and below the jokers, keeping their printed order among themselves. A rank
## map is per rank, not per card, so a rank counts only while every card of it in the
## holder's hand carries the holder's stamp: an unstamped card never gains by it.


## Lifts each rank the holder holds only stamped cards of above the 2s and below the jokers, while
## the holder is landlord.
func build_rank_map(context: RankMapContext) -> void:
	if context.landlord != holder_seat or context.stamped == 0:
		return
	for rank: int in Ranks.TWO:
		if context.stamped & (1 << rank) == 0:
			continue
		var top: int = _top_below_jokers(context.rank_map, rank)
		if context.rank_map[rank] < context.rank_map[top]:
			RankShift.move_above(context.rank_map, rank, top, context.step)


## The rank other than rank that stands highest without being a joker.
static func _top_below_jokers(rank_map: PackedByteArray, rank: int) -> int:
	var top: int = Ranks.TWO
	for other: int in Ranks.TWO + 1:
		if other != rank and rank_map[other] > rank_map[top]:
			top = other
	return top
