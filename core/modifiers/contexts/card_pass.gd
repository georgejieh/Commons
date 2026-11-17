class_name CardPass
extends RefCounted
## Cards a debuff moved from one hand to another before play (ADR 0023).

var from_seat: int
var to_seat: int
var card_ids: Array[int]


func _init(from_value: int, to_value: int, ids: Array[int]) -> void:
	from_seat = from_value
	to_seat = to_value
	card_ids = ids.duplicate()
