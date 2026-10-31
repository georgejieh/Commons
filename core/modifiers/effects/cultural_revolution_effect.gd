class_name CulturalRevolutionEffect
extends ModifierEffect
## After any bomb, rank order inverts until the trick ends.


func build_rank_map(context: RankMapContext) -> void:
	if context.trick_bombed:
		ReversedRanks.reverse(context.rank_map)
