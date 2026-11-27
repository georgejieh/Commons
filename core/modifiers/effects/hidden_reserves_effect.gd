class_name HiddenReservesEffect
extends ModifierEffect
## The holder's kickers score their Grain, which kickers normally never do. A kicker
## scores as its own card prints, whatever rank a wild card stands in for (ADR 0029).


## Adds the Grain of each kicker the play carries.
func play_scored(context: PlayContext) -> void:
	for rank: int in context.kicker_cards:
		context.add_grain += context.card_grain[rank]
