class_name GrainReserveEffect
extends ReformEffect
## Grain Reserve: a missed Quota adds less Famine.

## Parameter key: how much less Famine a missed Quota adds.
const FAMINE: String = "famine"


## Needs the Famine it takes off.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([FAMINE])


## The Famine a missed Quota adds less of, from the parameter.
func famine_relief() -> int:
	return parameters[FAMINE]
