class_name Seats
extends RefCounted
## The one definition of seating order.

const COUNT: int = 3
const TURN_STEP: int = 1
const NONE: int = -1


static func next(seat: int) -> int:
	return (seat + TURN_STEP) % COUNT


## The seat on this seat's left. Turn order runs to the right, so it is the seat before.
static func left(seat: int) -> int:
	return (seat + COUNT - TURN_STEP) % COUNT
