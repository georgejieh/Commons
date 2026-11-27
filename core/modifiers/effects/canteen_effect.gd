class_name CanteenEffect
extends ModifierEffect
## Every seat's Trio, Trio with a Single and Trio with a Pair gains flat Zeal, given in
## hundredths.

const ZEAL_PERCENT: String = "zeal_percent"
const TRIOS: Array[Pattern.Type] = [
	Pattern.Type.TRIO, Pattern.Type.TRIO_SINGLE, Pattern.Type.TRIO_PAIR
]


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


func play_scored(context: PlayContext) -> void:
	if TRIOS.has(context.pattern.type):
		context.add_zeal += parameters[ZEAL_PERCENT] / 100.0
