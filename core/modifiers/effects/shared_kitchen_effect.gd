class_name SharedKitchenEffect
extends ModifierEffect
## The holder may make only so many private-plot swaps each round (ADR 0023).

const SWAPS: String = "swaps"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([SWAPS])


func round_start(context: RoundContext) -> void:
	context.cap_swaps(parameters[SWAPS])
