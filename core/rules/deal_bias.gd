class_name DealBias
extends RefCounted
## Asks the allocation hook to send a rank to a seat more often than chance.

var seat: int
var rank: int
## How many times likelier each copy is to reach the seat. 1 or less changes nothing.
var multiplier: float


func _init(target_seat: int, target_rank: int, target_multiplier: float) -> void:
	seat = target_seat
	rank = target_rank
	multiplier = target_multiplier
