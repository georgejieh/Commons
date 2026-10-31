class_name SelfPlayResult
extends RefCounted
## How one bot-only round went.

var winner: int = Seats.NONE
var landlord: int = Seats.NONE
var decisions: int = 0
var illegal_actions: int = 0
## Per decision, when the round was given a clock.
var decision_usec: PackedInt64Array = PackedInt64Array()
## Cards played per seat.
var cards_played: PackedInt32Array = PackedInt32Array()


func landlord_won() -> bool:
	return winner == landlord
