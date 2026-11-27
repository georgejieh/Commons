class_name EnlargedCommitteeEffect
extends ReformEffect
## Enlarged Committee: the player can hold more Cadres.

## Parameter key: how many more Cadres the player can hold.
const CADRES: String = "cadres"


## Needs the number of extra Cadres.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([CADRES])


## The extra Cadres, from the parameter.
func extra_cadres() -> int:
	return parameters[CADRES]
