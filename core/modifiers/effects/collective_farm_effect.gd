class_name CollectiveFarmEffect
extends ModifierEffect
## Every peasant's Pair also scores the Grain of their teammate's last play this round,
## as added Grain. Nothing when the teammate has not played yet this round.


func play_scored(context: PlayContext) -> void:
	if context.pattern.type != Pattern.Type.PAIR:
		return
	var teammate: int = context.teammate()
	if teammate == Seats.NONE or context.seat_plays.size() <= teammate:
		return
	if context.seat_plays[teammate] > 0:
		context.add_grain += context.seat_grain[teammate]
