class_name GreatLeapEffect
extends ModifierEffect
## Boss (P4.7): every play the holder makes gains flat Zeal, given in hundredths. The run
## loop doubles the Quota from the definition's quota_percent.

const ZEAL_PERCENT: String = "zeal_percent"
const QUOTA_PERCENT: String = "quota_percent"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT, QUOTA_PERCENT])


func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat:
		context.add_zeal += parameters[ZEAL_PERCENT] / 100.0
