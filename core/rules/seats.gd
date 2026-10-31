class_name Seats
extends RefCounted
## The one definition of seating order.

const COUNT: int = 3
const TURN_STEP: int = 1
const NONE: int = -1


static func next(seat: int) -> int:
	return (seat + TURN_STEP) % COUNT
