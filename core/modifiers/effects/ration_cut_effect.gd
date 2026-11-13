class_name RationCutEffect
extends ModifierEffect
## The holder's plays lose flat Zeal, given in hundredths.

const ZEAL_PERCENT: String = "zeal_percent"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat:
		context.add_zeal -= parameters[ZEAL_PERCENT] / 100.0
