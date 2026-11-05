class_name IronRiceBowlEffect
extends ModifierEffect
## The holder's plays gain flat Grain, and their Zeal can't rise above a cap.

const GRAIN: String = "grain"
const ZEAL_CAP: String = "zeal_cap"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN, ZEAL_CAP])


func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat:
		return
	context.add_grain += parameters[GRAIN]
	context.zeal_cap = minf(context.zeal_cap, parameters[ZEAL_CAP])
