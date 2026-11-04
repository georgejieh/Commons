class_name HiddenReservesEffect
extends ModifierEffect
## The holder's kickers score their Grain, which kickers normally never do.


func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat:
		return
	for rank: int in context.pattern.kicker_ranks:
		context.add_grain += context.card_grain[rank]
