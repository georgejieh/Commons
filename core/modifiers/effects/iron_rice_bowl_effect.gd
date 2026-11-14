class_name IronRiceBowlEffect
extends ModifierEffect
## The holder's plays gain flat Grain, and their Rate can't rise above a cap.

const GRAIN: String = "grain"
const RATE_CAP: String = "rate_cap"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN, RATE_CAP])


func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat:
		return
	context.add_grain += parameters[GRAIN]
	context.rate_cap = minf(context.rate_cap, parameters[RATE_CAP])
