class_name CouriersBagEffect
extends ReformEffect
## Courier's Bag: the player can hold more Campaigns.

const CAMPAIGNS: String = "campaigns"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([CAMPAIGNS])


func extra_campaigns() -> int:
	return parameters[CAMPAIGNS]
