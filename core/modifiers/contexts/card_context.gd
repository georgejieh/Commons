class_name CardContext
extends RefCounted
## Passed to the card scored hook.

var seat: int
var is_landlord: bool
var card: CardInstance
## This card's Grain, to edit.
var grain: float


func _init(
	seat_value: int,
	is_landlord_value: bool,
	card_value: CardInstance,
	grain_value: float,
) -> void:
	seat = seat_value
	is_landlord = is_landlord_value
	card = card_value
	grain = grain_value
