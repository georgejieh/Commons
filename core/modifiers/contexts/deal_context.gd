class_name DealContext
extends RefCounted
## Passed to the on deal hook.

var landlord: int
var deal: DealResult
## The deal stream, for effects that draw while dealing.
var stream: RandomStream
## The Year in play, for an effect whose size grows with the run (ADR 0043).
var year: int


func _init(
	landlord_value: int,
	deal_value: DealResult,
	stream_value: RandomStream = null,
	year_value: int = 1,
) -> void:
	landlord = landlord_value
	deal = deal_value
	stream = stream_value
	year = year_value
