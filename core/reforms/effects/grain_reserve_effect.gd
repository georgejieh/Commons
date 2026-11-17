class_name GrainReserveEffect
extends ReformEffect
## Grain Reserve: a missed Quota adds less Famine.

const FAMINE: String = "famine"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([FAMINE])


func famine_relief() -> int:
	return parameters[FAMINE]
