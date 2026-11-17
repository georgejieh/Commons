class_name HiddenReservesEffect
extends ModifierEffect
## The holder's kickers score their Grain, which kickers normally never do. A kicker
## scores as its own card prints, whatever rank a wild card stands in for (ADR 0029).


func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat:
		return
	for rank: int in context.kicker_cards:
		context.add_grain += context.card_grain[rank]
