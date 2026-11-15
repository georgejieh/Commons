class_name LastSheafEffect
extends ModifierEffect
## The holder's play that empties their hand multiplies its Zeal, given in hundredths.

const TIMES_PERCENT_ZEAL: String = "times_percent_zeal"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([TIMES_PERCENT_ZEAL])


func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat and context.cards_left == 0:
		context.mul_zeal *= parameters[TIMES_PERCENT_ZEAL] / 100.0
