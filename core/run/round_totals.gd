class_name RoundTotals
extends RefCounted
## Scores plays as they happen, and applies the round-end multipliers to each seat's total.


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


static func play_score(
	event: RoundEvent, levels: HandLevels, landlord: int, stack: ModifierStack
) -> float:
	var breakdown: ScoreBreakdown = Scorer.score_play(
		event.cards,
		event.pattern,
		levels.level_of(event.pattern.type),
		event.seat,
		event.seat == landlord,
		stack
	)
	return breakdown.total
