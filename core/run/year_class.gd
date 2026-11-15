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


## A Year with no rounds played is a peasant's.
static func is_landlord(state: RunState) -> bool:
	return state.year_rounds > 0 and state.year_landlord_rounds * 2 >= state.year_rounds
