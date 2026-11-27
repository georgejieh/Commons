class_name YearClass
extends RefCounted
## The player's class at a run's end (ADR 0024): landlord if they held the landlord seat
## in at least half the rounds played in the final Year, peasant otherwise. The seat
## itself is cleared when each Quota ends, and one last round should not decide a class,
## so RunState keeps the Year's two counts instead.


## Counts a finished round, and whether the player was its landlord.
static func count_round(state: RunState, landlord: int, player: int) -> void:
	state.year_rounds += 1
	if landlord == player:
		state.year_landlord_rounds += 1


## A new Year counts from nothing.
static func new_year(state: RunState) -> void:
	state.year_rounds = 0
	state.year_landlord_rounds = 0


## True when seat held the landlord seat in any round of a Set's events: a round's
## holder is the seat named by its SEAT_KEPT or SEAT_LOST event (ADR 0031).
static func held_seat(events: Array[RunEvent], seat: int) -> bool:
	for event: RunEvent in events:
		var ends_round: bool = (
			event.type == RunEvent.Type.SEAT_KEPT or event.type == RunEvent.Type.SEAT_LOST
		)
		if ends_round and event.seat == seat:
			return true
	return false


## A Year with no rounds played is a peasant's.
static func is_landlord(state: RunState) -> bool:
	return state.year_rounds > 0 and state.year_landlord_rounds * 2 >= state.year_rounds
