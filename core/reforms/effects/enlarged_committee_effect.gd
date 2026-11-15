class_name EnlargedCommitteeEffect
extends ReformEffect
## Enlarged Committee: the player can hold more Cadres.

const CADRES: String = "cadres"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([CADRES])


func extra_cadres() -> int:
	return parameters[CADRES]
