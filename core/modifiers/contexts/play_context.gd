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
## The seat's plays before this one in the round, so effects need no state of their own.
var plays_before: int = 0
## Grain before the hooks: the hand type's base plus the scored cards.
var grain: float = 0.0
## Grain per base rank, for effects that score cards the play doesn't.
var card_grain: Array[int] = []
## The most Zeal the play may end with, after the bomb multiplier.
var zeal_cap: float = INF


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
