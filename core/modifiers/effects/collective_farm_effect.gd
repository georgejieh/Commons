class_name CollectiveFarmEffect
extends ModifierEffect
## A peasant's Pair also scores the Grain of their teammate's last play this round, as
## added Grain. Nothing when the teammate has not played yet this round. It scores for the
## holder and the holder's teammate only (SeatScope, ADR 0039), so a landlord holding it
## gets nothing and the opponents never do.


## Adds the teammate's last Grain to a peasant's Pair, when the teammate has played this round.
func play_scored(context: PlayContext) -> void:
	if context.pattern.type != Pattern.Type.PAIR:
		return
	var teammate: int = context.teammate()
	if teammate == Seats.NONE or context.seat_plays.size() <= teammate:
		return
	if context.seat_plays[teammate] > 0:
		context.add_grain += context.seat_grain[teammate]
