class_name PublicGranaryEffect
extends ModifierEffect
## Each round the peasants win with the holder among them, the player's Famine falls
## (ADR 0032), through the meters' one path down, so it stops at 0 and a fall back below
## a band re-arms its setback.

const FAMINE: String = "famine"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([FAMINE])


func round_end(context: RoundContext) -> void:
	if context.winner == Seats.NONE or holder_seat == context.landlord:
		return
	if context.side_lost(holder_seat):
		return
	context.famine_fall += parameters[FAMINE]
	memo.fire(parameters[FAMINE])
