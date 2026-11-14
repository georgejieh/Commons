class_name DealContext
extends RefCounted
## Passed to the on deal hook.

var landlord: int
var deal: DealResult
## The deal stream, for effects that draw while dealing (P4.9).
var stream: RandomStream


func _init(
	landlord_value: int,
	deal_value: DealResult,
	stream_value: RandomStream = null,
) -> void:
	landlord = landlord_value
	deal = deal_value
	stream = stream_value
