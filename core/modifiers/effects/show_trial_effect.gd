class_name ShowTrialEffect
extends ModifierEffect
## The holder's Bombs and Rockets multiply their Zeal, given in hundredths, and each one
## the player plays adds Resentment.

const TIMES_PERCENT_ZEAL: String = "times_percent_zeal"
const RESENTMENT: String = "resentment"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([TIMES_PERCENT_ZEAL, RESENTMENT])


func play_scored(context: PlayContext) -> void:
	if context.is_bomb():
		context.mul_zeal *= parameters[TIMES_PERCENT_ZEAL] / 100.0


func turn_taken(context: TurnContext) -> void:
	if context.seat == holder_seat and context.seat == context.player and context.is_bomb():
		context.resentment += parameters[RESENTMENT]
