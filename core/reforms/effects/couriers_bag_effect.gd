class_name CouriersBagEffect
extends ReformEffect
## Courier's Bag: the player can hold more Campaigns.

## Parameter key: how many more Campaigns the player can hold.
const CAMPAIGNS: String = "campaigns"


## Needs the number of extra Campaigns.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([CAMPAIGNS])


## The extra Campaigns, from the parameter.
func extra_campaigns() -> int:
	return parameters[CAMPAIGNS]
