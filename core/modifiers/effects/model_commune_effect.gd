class_name ModelCommuneEffect
extends ModifierEffect
## When the peasants win a round and the holder's teammate went out first, the round's
## Commons is multiplied, given in hundredths, before it is split.

const TIMES_PERCENT_COMMONS: String = "times_percent_commons"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([TIMES_PERCENT_COMMONS])


func round_end(context: RoundContext) -> void:
	var peasants_won: bool = context.winner != Seats.NONE and context.winner != context.landlord
	if holder_seat == context.landlord or not peasants_won or context.winner == holder_seat:
		return
	context.commons_scale *= parameters[TIMES_PERCENT_COMMONS] / 100.0
	memo.fire()
