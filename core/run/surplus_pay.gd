class_name SurplusPay
extends RefCounted
## Pays the household for the Surplus cards the player scores (ADR 0041): each pays the
## data's coupons, up to the data's most in a round, and a villager who scores one is paid
## nothing. Each payment is a step after the play's score, so the table acts it out on
## the card that paid. The count starts again with every deal; a save replays the round's
## plays, so it is never saved.

var _paid: int = 0


func start_round() -> void:
	_paid = 0


## Pays for the play's scored Surplus cards and returns a step for each card that paid,
## in play order.
func pay(state: RunState, surplus_cards: Array[int], params: ScoreParams) -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = []
	for card_id: int in surplus_cards:
		var coupons: int = mini(params.surplus_coupons, params.surplus_round_most - _paid)
		if coupons <= 0:
			break
		_paid += coupons
		state.coupons += coupons
		var step: ScoreStep = ScoreStep.new(
			ScoreStep.Figure.COUPONS, ScoreStep.Source.MARK, ScoreStep.Op.ADD, coupons, 0.0, coupons
		)
		step.card_id = card_id
		step.source_id = CardInstance.SURPLUS
		steps.append(step)
	return steps
