class_name RoundTotals
extends RefCounted
## Applies the round-end multipliers to each seat's total. RoundScoring scores the plays.


static func totals(
	scores: PackedFloat64Array,
	landlord: int,
	winner: int,
	finish: RoundEvent.Finish,
	rules: RuleSet
) -> PackedFloat64Array:
	var landlord_won: bool = winner == landlord
	var result: PackedFloat64Array = PackedFloat64Array()
	for seat: int in scores.size():
		var side_won: bool = (seat == landlord) == landlord_won
		var multiplier: float = Scorer.round_multiplier(finish, seat == winner, side_won, rules)
		result.append(Scorer.round_total(scores[seat], multiplier))
	return result
