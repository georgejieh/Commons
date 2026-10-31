class_name DealContext
extends RefCounted
## Passed to the on deal hook.

var landlord: int
var deal: DealResult


func _init(
	landlord_value: int,
	deal_value: DealResult,
) -> void:
	landlord = landlord_value
	deal = deal_value
