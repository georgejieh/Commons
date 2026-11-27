class_name GleanersEffect
extends ModifierEffect
## When the peasants win a round, its Commons grows by percent for each card left in the
## landlord's hand, before it is split (ADR 0032). It stacks with any other multiplier.

const PERCENT: String = "percent"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([PERCENT])


func round_end(context: RoundContext) -> void:
	var peasants_won: bool = context.winner != Seats.NONE and context.winner != context.landlord
	if not peasants_won or context.landlord_cards <= 0:
		return
	var grown: int = parameters[PERCENT] * context.landlord_cards
	context.commons_scale *= (100 + grown) / 100.0
	memo.fire(grown)
