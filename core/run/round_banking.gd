class_name RoundBanking
extends RefCounted
## Banks a finished round. The landlord keeps their own total. Peasant totals go into
## the Commons pool, which is then split by declared need and emptied. Only what reaches
## the player counts toward the Set's target.

const DEFAULT_AUDIT: AuditParams = preload("res://data/run/audit.tres")


## Records each seat's total, banks the landlord and fills the pool.
static func bank(
	state: RunState, totals: PackedFloat64Array, player: int, events: Array[RunEvent]
) -> void:
	var landlord: int = state.landlord_seat
	for seat: int in Seats.COUNT:
		events.append(RunEvent.new(RunEvent.Type.ROUND_SCORED, seat, 0, totals[seat]))
	events.append(RunEvent.new(RunEvent.Type.BANKED, landlord, 0, totals[landlord]))
	if landlord == player:
		state.set_progress += totals[landlord]
	for seat: int in Seats.COUNT:
		if seat != landlord:
			# Clamped before adding, so two saturated totals can't wrap past 2^63.
			var room: int = Banking.MAX_POOL - state.commons_pool
			state.commons_pool += mini(Banking.to_pool_units(totals[seat]), room)


## Bots declare on the ai stream. The player's need counts only when they are a peasant.
## A debuff's cut takes from the player's share before it counts (ADR 0023).
## Declarations are then audited: each seat rolls the audit die, and a face at or
## below audit_faces checks its claim. Caught seats are appended to caught, and their
## true need replaces the lie. Returns true when the pool fell short of the needs that
## stand, a Commons shortfall. The audit's shown faces, when it names any, are the faces
## the dice show: the arrival's authored rolls (ADR 0026).
static func split(
	state: RunState,
	player: int,
	player_need: int,
	configs: Array[BotConfig],
	params: RunParams,
	events: Array[RunEvent],
	audit_faces: int = 0,
	caught: Array[int] = [],
	audit: AuditParams = DEFAULT_AUDIT,
	cut: BankCut = null
) -> bool:
	var peasants: Array[int] = []
	var needs: PackedInt64Array = PackedInt64Array()
	for seat: int in Seats.COUNT:
		if seat == state.landlord_seat:
			continue
		var need: int = player_need
		if seat != player:
			need = Bot.declare_need(
				params.base_need,
				configs[seat],
				state.streams.stream(RandomStreams.AI),
				BotBudget.unlimited()
			)
		peasants.append(seat)
		needs.append(need)
		events.append(RunEvent.new(RunEvent.Type.NEED_DECLARED, seat, need))
	var stream: RandomStream = state.streams.stream(RandomStreams.AUDIT)
	caught.append_array(
		NeedAudit.run(
			peasants,
			needs,
			params.base_need,
			audit_faces,
			audit.die_sides,
			stream,
			events,
			audit.shown_faces
		)
	)
	var declared: int = 0
	for need: int in needs:
		declared += clampi(need, 0, Banking.MAX_NEED)
	var short: bool = state.commons_pool < declared
	var shares: PackedInt64Array = Banking.split(state.commons_pool, needs)
	for index: int in peasants.size():
		events.append(RunEvent.new(RunEvent.Type.SHARE_PAID, peasants[index], shares[index]))
		state.commons_paid = mini(state.commons_paid + shares[index], Banking.MAX_POOL)
		if peasants[index] == player:
			var kept: float = shares[index]
			if cut != null:
				kept = cut.apply(kept, player, events)
			state.set_progress += kept
			state.commons_received = mini(state.commons_received + shares[index], Banking.MAX_POOL)
	state.commons_pool = 0
	return short
