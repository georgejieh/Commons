class_name TrickContext
extends RefCounted
## Passed to the trick won hook.

var winner: int
var landlord: int


func _init(
	winner_value: int,
	landlord_value: int,
) -> void:
	winner = winner_value
	landlord = landlord_value
