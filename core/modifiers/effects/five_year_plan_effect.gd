class_name FiveYearPlanEffect
extends ModifierEffect
## Every seat's plays gain flat Zeal, given in hundredths, for each Year of the run so far,
## the Year in play counted (ADR 0032): one step in Year 1, eight in Year 8.

const ZEAL_PERCENT: String = "zeal_percent"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


func play_scored(context: PlayContext) -> void:
	context.add_zeal += parameters[ZEAL_PERCENT] * context.year / 100.0
