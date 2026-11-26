class_name Seats
extends RefCounted
## The one definition of seating order.

const COUNT: int = 3
const TURN_STEP: int = 1
const NONE: int = -1
## The seat of the person playing.
const PLAYER: int = 0
## The villager who plays after the player, seated on the player's right.
const RIGHT: int = 1
## The villager who plays before the player, seated on the player's left (left(PLAYER)).
const LEFT: int = 2


static func next(seat: int) -> int:
	return (seat + TURN_STEP) % COUNT


## The other peasant's seat when seat is a peasant in a round whose landlord is landlord,
## else NONE.
static func teammate(seat: int, landlord: int) -> int:
	if landlord == NONE or seat == NONE or seat == landlord:
		return NONE
	for other: int in COUNT:
		if other != seat and other != landlord:
			return other
	return NONE


## The seat on this seat's left. Turn order runs to the right, so it is the seat before.
static func left(seat: int) -> int:
	return (seat + COUNT - TURN_STEP) % COUNT
