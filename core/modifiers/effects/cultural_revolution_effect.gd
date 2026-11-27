class_name CulturalRevolutionEffect
extends ModifierEffect
## After any bomb, rank order inverts until the trick ends, for the holder's seat alone
## (SeatScope, ADR 0039).


## Reverses the holder's rank order while the trick has a bomb in it.
func build_rank_map(context: RankMapContext) -> void:
	if context.trick_bombed:
		ReversedRanks.reverse(context.rank_map, context.step)
