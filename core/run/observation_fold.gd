class_name ObservationFold
extends RefCounted
## Folds one round's events into the run's Observations: for every villager other than
## the player, their bids and calls, bombs, passes, plays over a teammate, first-out
## finishes and rounds as landlord. families maps seats to family IDs.


static func fold_round(
	observations: Observations, events: Array[RunEvent], player: int, families: Array[String]
) -> void:
	var landlord: int = Seats.NONE
	var owner: int = Seats.NONE
	for event: RunEvent in events:
		if event.type == RunEvent.Type.BID and event.seat != player:
			observations.add(families[event.seat], Observations.Kind.BIDS)
			if event.value == 1:
				observations.add(families[event.seat], Observations.Kind.CALLS)
		if event.round_event == null:
			continue
		var played: RoundEvent = event.round_event
		var family: String = families[played.seat] if played.seat != Seats.NONE else ""
		var watched: bool = played.seat != player and played.seat != Seats.NONE
		match played.type:
			RoundEvent.Type.ROUND_STARTED:
				landlord = played.seat
				if watched:
					observations.add(family, Observations.Kind.LANDLORD_ROUNDS)
			RoundEvent.Type.TRICK_WON:
				owner = Seats.NONE
			RoundEvent.Type.PASSED:
				if watched:
					observations.add(family, Observations.Kind.PASSES)
			RoundEvent.Type.PLAYED:
				if watched:
					_count_play(observations, family, played, owner, landlord)
				owner = played.seat
			RoundEvent.Type.ROUND_ENDED:
				if watched:
					observations.add(family, Observations.Kind.WENT_OUT)


static func _count_play(
	observations: Observations, family: String, played: RoundEvent, owner: int, landlord: int
) -> void:
	var type: Pattern.Type = played.pattern.type
	if type == Pattern.Type.BOMB or type == Pattern.Type.ROCKET:
		observations.add(family, Observations.Kind.BOMBS)
	var answered_teammate: bool = (
		owner != Seats.NONE
		and owner != played.seat
		and played.seat != landlord
		and owner != landlord
	)
	if answered_teammate:
		observations.add(family, Observations.Kind.BEAT_TEAMMATE)
