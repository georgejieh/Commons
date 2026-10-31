class_name LandlordSeat
extends RefCounted
## Tracks who holds the landlord seat across the rounds of a Set. The holder keeps it
## until they lose a round. Then the seat is rebid.

var _holder: int = Seats.NONE


func holder() -> int:
	return _holder


func needs_bidding() -> bool:
	return _holder == Seats.NONE


func assign(seat: int) -> void:
	_holder = seat


func record_round(landlord_won: bool) -> void:
	if not landlord_won:
		_holder = Seats.NONE
