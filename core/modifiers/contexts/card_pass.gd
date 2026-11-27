class_name CardPass
extends RefCounted
## Cards a debuff moved from one hand to another before play (ADR 0023).

## The seat the cards left.
var from_seat: int
## The seat the cards went to.
var to_seat: int
## The IDs of the cards moved, a copy.
var card_ids: Array[int]


func _init(from_value: int, to_value: int, ids: Array[int]) -> void:
	from_seat = from_value
	to_seat = to_value
	card_ids = ids.duplicate()
