class_name SupplyCooperativeEffect
extends ReformEffect
## Supply Cooperative: every envelope holds more items to choose from.

const CHOICES: String = "choices"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([CHOICES])


func extra_envelope_choices() -> int:
	return parameters[CHOICES]
