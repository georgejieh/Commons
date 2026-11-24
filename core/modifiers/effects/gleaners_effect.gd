class_name GleanersEffect
extends ModifierEffect
## When the holder is a peasant and the peasants win a round, its Commons grows by percent
## for each card left in the landlord's hand, before it is split (ADR 0032). It stacks
## with any other multiplier. Held by the landlord it pays nothing (ADR 0039).

const PERCENT: String = "percent"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([PERCENT])


func round_end(context: RoundContext) -> void:
	var peasants_won: bool = context.winner != Seats.NONE and context.winner != context.landlord
	if not SeatScope.is_peasant(holder_seat, context.landlord):
		return
	if not peasants_won or context.landlord_cards <= 0:
		return
	var grown: int = parameters[PERCENT] * context.landlord_cards
	context.commons_scale *= (100 + grown) / 100.0
	memo.fire(grown)
