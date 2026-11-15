class_name CorruptionEvents
extends RefCounted
## What one finished Quota adds to the hidden corruption (ADR 0025): the events the
## player caused, as IDs in the order they happened, read from the Quota's log and the
## state at its end. Each is an attribution rule: the game counts the circumstance and
## does not claim to prove the cause. The Quota's list is kept in RunState, so a save
## loaded at the Quota's end still holds it; the profile applies it once.

const DECLARED_OVER: String = "declared_over"
const CAUGHT_LYING: String = "caught_lying"
const BOMBED_TEAMMATE: String = "bombed_teammate"
const HOSTILE_CAMPAIGN: String = "hostile_campaign"
const LANDLORD_EVERY_ROUND: String = "landlord_every_round"
const FAMINE_PURCHASE: String = "famine_purchase"
const STARVED_WHILE_RICH: String = "starved_while_rich"
const REEDUCATED_VICTIM: String = "reeducated_victim"
## Every event, in the ADR's order.
const ALL: Array[String] = [
	DECLARED_OVER,
	CAUGHT_LYING,
	BOMBED_TEAMMATE,
	HOSTILE_CAMPAIGN,
	LANDLORD_EVERY_ROUND,
	FAMINE_PURCHASE,
	STARVED_WHILE_RICH,
	REEDUCATED_VICTIM,
]
const DEFAULT_PARAMS: CorruptionParams = preload("res://data/run/corruption.tres")
## Landlord in every round counts only over at least this many rounds.
const LANDLORD_ROUNDS: int = 2
const MAX_VALUE: float = 100.0


## A black-market purchase: counted when Famine is in its high band. A reroll is no
## purchase. The count is saved with the run and goes to the next Quota to end, since
## purchases fall between two Quotas.
static func note_purchase(state: RunState, famine: MeterBands) -> void:
	if famine.band(state.famine) == MeterBands.Band.HIGH:
		state.famine_market_buys += 1


## Ends a Quota: its events go into the state, and the purchase count starts again.
static func close_quota(
	state: RunState,
	events: Array[RunEvent],
	true_need: int,
	params: CorruptionParams = DEFAULT_PARAMS,
	player: int = 0
) -> void:
	state.quota_corruption = detect(events, state, true_need, params, player)
	state.famine_market_buys = 0


## The Quota's events, in order: the purchases made before it, then what its log holds.
## Landlord in every round is placed where the Quota's last round ended.
static func detect(
	events: Array[RunEvent],
	state: RunState,
	true_need: int,
	params: CorruptionParams = DEFAULT_PARAMS,
	player: int = 0
) -> Array[String]:
	var found: Array[String] = []
	for _purchase: int in state.famine_market_buys:
		found.append(FAMINE_PURCHASE)
	var landlord: int = Seats.NONE
	var owner: int = Seats.NONE
	var rounds: int = 0
	var as_landlord: int = 0
	var last_round_end: int = found.size()
	for event: RunEvent in events:
		if event.round_event != null:
			var played: RoundEvent = event.round_event
			match played.type:
				RoundEvent.Type.ROUND_STARTED:
					landlord = played.seat
					owner = Seats.NONE
					rounds += 1
					as_landlord += 1 if landlord == player else 0
				RoundEvent.Type.TRICK_WON:
					owner = Seats.NONE
				RoundEvent.Type.PLAYED:
					if played.seat == player and _bombs_teammate(played, owner, landlord):
						found.append(BOMBED_TEAMMATE)
					owner = played.seat
			continue
		var event_id: String = _event_id(event, state, true_need, params, player)
		if not event_id.is_empty():
			found.append(event_id)
		if event.type == RunEvent.Type.SEAT_KEPT or event.type == RunEvent.Type.SEAT_LOST:
			last_round_end = found.size()
	if rounds >= LANDLORD_ROUNDS and as_landlord == rounds:
		found.insert(last_round_end, LANDLORD_EVERY_ROUND)
	return found


## The corruption after a Quota's events, applied in order: each adds its weight times
## (1 + growth * corruption / 100), with corruption as it stands, clamped after each.
static func added(
	corruption: float, event_ids: Array[String], params: CorruptionParams = DEFAULT_PARAMS
) -> float:
	var value: float = clampf(corruption, 0.0, MAX_VALUE)
	for event_id: String in event_ids:
		var step: float = params.weight(event_id) * (1.0 + params.growth * value / MAX_VALUE)
		value = clampf(value + step, 0.0, MAX_VALUE)
	return value


## A run event that counts, or "".
static func _event_id(
	event: RunEvent, state: RunState, true_need: int, params: CorruptionParams, player: int
) -> String:
	match event.type:
		RunEvent.Type.NEED_DECLARED:
			if event.seat == player and event.value > true_need:
				return DECLARED_OVER
		RunEvent.Type.AUDITED:
			if event.seat == player and event.value == 1:
				return CAUGHT_LYING
		RunEvent.Type.CAMPAIGN_USED:
			if event.seat == player and params.hostile_campaigns.has(event.text):
				return HOSTILE_CAMPAIGN
		RunEvent.Type.STARVED:
			# Nothing after a Quota's starvation pays coupons, so the count now is the count
			# then.
			if state.coupons >= params.coupon_threshold:
				return STARVED_WHILE_RICH
		RunEvent.Type.ROSTER_CHANGED:
			if event.value == RosterEntry.Status.REEDUCATION and _touched(state, event.text):
				return REEDUCATED_VICTIM
	return ""


## The player's Bomb or Rocket answering a play their teammate made: the player is a
## peasant and the trick's owner is the other peasant.
static func _bombs_teammate(played: RoundEvent, owner: int, landlord: int) -> bool:
	var kind: Pattern.Type = played.pattern.type
	if kind != Pattern.Type.BOMB and kind != Pattern.Type.ROCKET:
		return false
	return (
		owner != Seats.NONE
		and owner != played.seat
		and landlord != played.seat
		and owner != landlord
	)


## True when the Quota's summary says the player bombed or denounced the family.
static func _touched(state: RunState, family_id: String) -> bool:
	if state.summaries.is_empty():
		return false
	var summary: SetSummary = state.summaries[-1]
	var bombed: int = summary.count(family_id, SetSummary.Kind.BOMBED)
	return bombed + summary.count(family_id, SetSummary.Kind.DENOUNCED) > 0
