class_name PlayFacts
extends RefCounted
## What the round knows about a play being scored, for the hooks that read it (ADR 0021):
## the landlord, the cards the seat keeps once it is made, and each seat's plays so far
## and the Grain its last one scored.

var landlord: int = Seats.NONE
## -1 when unknown.
var cards_left: int = -1
var seat_plays: PackedInt32Array = PackedInt32Array()
var seat_grain: PackedFloat64Array = PackedFloat64Array()


func _init(
	landlord_value: int,
	cards_left_value: int,
	seat_plays_value: PackedInt32Array,
	seat_grain_value: PackedFloat64Array
) -> void:
	landlord = landlord_value
	cards_left = cards_left_value
	seat_plays = seat_plays_value
	seat_grain = seat_grain_value
