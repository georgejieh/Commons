class_name PlayContext
extends RefCounted
## Passed to the play scored hook.

var seat: int
var is_landlord: bool
var pattern: Pattern
## Summed, then applied before add_zeal.
var add_grain: float
## Summed, then applied before mul_zeal.
var add_zeal: float
## Multiplied last.
var mul_zeal: float


func _init(
	seat_value: int,
	is_landlord_value: bool,
	pattern_value: Pattern,
	add_grain_value: float,
	add_zeal_value: float,
	mul_zeal_value: float,
) -> void:
	seat = seat_value
	is_landlord = is_landlord_value
	pattern = pattern_value
	add_grain = add_grain_value
	add_zeal = add_zeal_value
	mul_zeal = mul_zeal_value
