class_name RoundContext
extends RefCounted
## Passed to the round start and round end hook.

var landlord: int
## Seats.NONE at round start.
var winner: int
var finish: RoundEvent.Finish
## At round end: multiplies the peasants' totals before they fill the Commons, to edit.
var commons_scale: float = 1.0


func _init(
	landlord_value: int,
	winner_value: int,
	finish_value: RoundEvent.Finish,
) -> void:
	landlord = landlord_value
	winner = winner_value
	finish = finish_value
