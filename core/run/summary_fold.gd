class_name SummaryFold
extends RefCounted
## Folds one round's events into the Set's summary, by ADR 0012: what the player did to
## each villager. families maps seats to family IDs.


static func fold_round(
	summary: SetSummary, events: Array[RunEvent], player: int, families: Array[String]
) -> void:
	var landlord: int = Seats.NONE
	var owner: int = Seats.NONE
	var player_banked: bool = false
	for event: RunEvent in events:
		if event.round_event != null:
			var played: RoundEvent = event.round_event
			match played.type:
				RoundEvent.Type.ROUND_STARTED:
					landlord = played.seat
				RoundEvent.Type.TRICK_WON:
					owner = Seats.NONE
				RoundEvent.Type.PLAYED:
					if played.seat == player and owner != Seats.NONE and owner != player:
						_count_answer(summary, played.pattern, owner, landlord, player, families)
					owner = played.seat
		elif event.type == RunEvent.Type.ROUND_SCORED and event.seat == player:
			player_banked = landlord != player and Banking.to_pool_units(event.amount) > 0
		elif event.type == RunEvent.Type.SHARE_PAID and event.seat != player:
			if player_banked and event.value > 0:
				summary.add(families[event.seat], SetSummary.Kind.FED)


static func _count_answer(
	summary: SetSummary,
	pattern: Pattern,
	owner: int,
	landlord: int,
	player: int,
	families: Array[String]
) -> void:
	if pattern.type == Pattern.Type.BOMB or pattern.type == Pattern.Type.ROCKET:
		summary.add(families[owner], SetSummary.Kind.BOMBED)
	if player != landlord and owner != landlord:
		summary.add(families[owner], SetSummary.Kind.BETRAYED)
