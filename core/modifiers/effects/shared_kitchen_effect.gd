class_name SharedKitchenEffect
extends ModifierEffect
## The holder may make only so many private-plot swaps each round (ADR 0023).

## Parameter key: the most plot swaps the round allows.
const SWAPS: String = "swaps"


## Needs the swap cap.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([SWAPS])


## Caps the round's plot swaps.
func round_start(context: RoundContext) -> void:
	context.cap_swaps(parameters[SWAPS])
