class_name NightSchoolEffect
extends ModifierEffect
## Singles and Pairs gain flat Zeal, given in hundredths (ADR 0032), for the holder and
## the holder's teammate (SeatScope, ADR 0039).

const ZEAL_PERCENT: String = "zeal_percent"
const SMALL_PLAYS: Array[Pattern.Type] = [Pattern.Type.SINGLE, Pattern.Type.PAIR]


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


func play_scored(context: PlayContext) -> void:
	if SMALL_PLAYS.has(context.pattern.type):
		context.add_zeal += parameters[ZEAL_PERCENT] / 100.0
