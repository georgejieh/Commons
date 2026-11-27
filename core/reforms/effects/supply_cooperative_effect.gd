class_name SupplyCooperativeEffect
extends ReformEffect
## Supply Cooperative: every envelope holds more items to choose from.

## Parameter key: how many more items an envelope holds.
const CHOICES: String = "choices"


## Needs the number of extra choices.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([CHOICES])


## The extra items in every envelope, from the parameter.
func extra_envelope_choices() -> int:
	return parameters[CHOICES]
