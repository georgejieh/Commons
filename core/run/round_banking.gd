class_name RoundBanking
extends RefCounted
## Banks a finished round. The landlord keeps their own total. Peasant totals go into
## the Commons pool, which is then split by declared need and emptied. Only what reaches
## the player counts toward the Set's target.


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
static func split(
	state: RunState,
	player: int,
	player_need: int,
	configs: Array[BotConfig],
	params: RunParams,
	events: Array[RunEvent]
) -> void:
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
	var shares: PackedInt64Array = Banking.split(state.commons_pool, needs)
	for index: int in peasants.size():
		events.append(RunEvent.new(RunEvent.Type.SHARE_PAID, peasants[index], shares[index]))
		if peasants[index] == player:
			state.set_progress += shares[index]
	state.commons_pool = 0
