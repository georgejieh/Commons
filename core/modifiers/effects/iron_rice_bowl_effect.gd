class_name IronRiceBowlEffect
extends ModifierEffect
## The holder's plays gain flat Grain, and their Rate can't rise above a cap.

## Parameter key: the flat Grain each of the holder's plays gains.
const GRAIN: String = "grain"
## Parameter key: the most Rate the holder's plays may score with.
const RATE_CAP: String = "rate_cap"


## Needs the Grain and the Rate cap.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN, RATE_CAP])


## Adds the Grain and lowers the play's Rate cap to the parameter.
func play_scored(context: PlayContext) -> void:
	context.add_grain += parameters[GRAIN]
	context.rate_cap = minf(context.rate_cap, parameters[RATE_CAP])
