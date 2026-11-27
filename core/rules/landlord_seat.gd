class_name LandlordSeat
extends RefCounted
## Tracks who holds the landlord seat across the rounds of a Set. The holder keeps it
## until they lose a round. Then the seat is rebid.

var _holder: int = Seats.NONE


## The seat that holds the landlord seat, or Seats.NONE when it is to be bid for.
func holder() -> int:
	return _holder


## True when no seat holds the landlord seat, so the next round opens with bidding.
func needs_bidding() -> bool:
	return _holder == Seats.NONE


## Seats a holder directly, as a resumed run does with the landlord it was saved with.
func assign(seat: int) -> void:
	_holder = seat


## The holder keeps the seat when the landlord won the round and loses it when they did not.
func record_round(landlord_won: bool) -> void:
	if not landlord_won:
		_holder = Seats.NONE
