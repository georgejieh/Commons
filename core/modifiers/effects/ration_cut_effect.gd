class_name RationCutEffect
extends ModifierEffect
## The holder's plays lose flat Zeal.

const ZEAL: String = "zeal"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL])


func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat:
		context.add_zeal -= parameters[ZEAL]
