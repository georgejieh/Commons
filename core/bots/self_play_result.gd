class_name SelfPlayResult
extends RefCounted
## How one bot-only round went.

## The seat that went out, or Seats.NONE if the round did not finish.
var winner: int = Seats.NONE
## The round's landlord seat.
var landlord: int = Seats.NONE
## How many bot decisions the round took.
var decisions: int = 0
## How many actions were rejected and replaced, over all seats.
var illegal_actions: int = 0
## Rejected actions per seat.
var illegal_by_seat: PackedInt32Array = PackedInt32Array([0, 0, 0])
## Per decision, when the round was given a clock.
var decision_usec: PackedInt64Array = PackedInt64Array()
## The seat behind each entry in decision_usec.
var decision_seats: PackedByteArray = PackedByteArray()
## Every action in order, for a game log.
var history: Array[PublicPlay] = []
## Cards played per seat.
var cards_played: PackedInt32Array = PackedInt32Array()
## Bombs and rockets played per seat.
var bombs: PackedInt32Array = PackedInt32Array([0, 0, 0])
## Plays made over each seat's play, as seat * Seats.COUNT + owner.
var answers: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])


## True when the landlord went out first.
func landlord_won() -> bool:
	return winner == landlord
