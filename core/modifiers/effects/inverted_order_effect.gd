class_name InvertedOrderEffect
extends ModifierEffect
## Rank order is reversed for the holder's plays only.


func build_rank_map(context: RankMapContext) -> void:
	if context.seat == holder_seat:
		ReversedRanks.reverse(context.rank_map)
