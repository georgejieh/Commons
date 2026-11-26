class_name RunSeating
extends RefCounted
## Who sits at the table for a Set and how the villagers there play: the roster's two
## families by their personalities, a boss Set's boss and what it does to the seats,
## and at each round's start the grudge, memory and effort each villager plays with.
## The draws are on the events stream and on each seat's own seed, in the order the
## loop calls these.


## Seats two families from the roster and plays them by their personalities. A run
## with no roster keeps the seats and configs it was given.
static func seat_roster(state: RunState, configs: Array[BotConfig]) -> void:
	if state.roster.is_empty():
		return
	Roster.prepare_set(state, RunDefaults.VILLAGE, state.streams.stream(RandomStreams.EVENTS))
	for seat: int in range(1, Seats.COUNT):
		var entry: RosterEntry = Roster.entry(state, state.table[seat])
		configs[seat] = Roster.config_for(
			RunDefaults.VILLAGE, entry, _seat_seed(state, seat), state.drift
		)
		if Roster.definition(RunDefaults.VILLAGE, entry).mirrors_player:
			PlayerStyle.mirror(configs[seat], state.styles, RunPools.BOSSES)


## A boss Set gets its boss: a Purge destroys Cadres now, a risen villager takes seat 1
## as landlord, and the New Landlord makes seat 1 play like the player.
static func choose_boss(
	state: RunState, configs: Array[BotConfig], years: int, set_log: SetLog
) -> void:
	state.boss_id = RunState.NO_BOSS
	state.boss_family = ""
	if state.set_type != RunState.SetType.BOSS:
		return
	var stream: RandomStream = state.streams.stream(RandomStreams.EVENTS)
	var boss: ModifierDef = Bosses.choose(state, RunPools.BOSSES, years, stream)
	state.boss_id = boss.id
	set_log.add(RunEvent.new(RunEvent.Type.BOSS_CHOSEN, Seats.NONE, 0, 0.0, boss.id))
	var purge: int = boss.parameters.get(BossMarkerEffect.PURGE, 0)
	for cadre_id: String in Bosses.purge(state.inventory, purge, stream):
		set_log.add(RunEvent.new(RunEvent.Type.CADRE_PURGED, RunLoop.PLAYER, 0, 0.0, cadre_id))
	state.cadre_memos.keep_only(state.inventory.cadres)
	if boss == RunPools.BOSSES.risen:
		# The risen family takes seat 1; if the roster already sat it in seat 2, the two
		# seats trade so no family sits twice.
		if state.table[2] == state.boss_family:
			state.table[2] = state.table[1]
			var moved: BotConfig = configs[1]
			configs[1] = configs[2]
			configs[2] = moved
		state.table[1] = state.boss_family
		var entry: RosterEntry = Roster.entry(state, state.boss_family)
		if entry != null:
			configs[1] = Roster.config_for(
				RunDefaults.VILLAGE, entry, _seat_seed(state, 1), state.drift
			)
		state.landlord_seat = 1
	elif boss == RunPools.BOSSES.new_landlord:
		PlayerStyle.mirror(configs[1], state.styles, RunPools.BOSSES)


## Every bot holds the player's Resentment against them, plus its family's memory.
## The player's teammate, when they have one, slacks as the player's Commons share grows,
## and covers for the player more as its family's warmth grows.
static func aim_grudges(state: RunState, configs: Array[BotConfig]) -> void:
	var held: float = Resentment.grudge(state.resentment, RunDefaults.RESENTMENT)
	var share: float = FreeRiding.share(state)
	for seat: int in Seats.COUNT:
		if seat == RunLoop.PLAYER:
			continue
		var memory: PackedFloat32Array = configs[seat].memory
		memory[RunLoop.PLAYER] = held + state.memory.pull(state.table[seat], RunDefaults.MEMORY)
		configs[seat].memory = memory
		var teammate: bool = state.landlord_seat != RunLoop.PLAYER and state.landlord_seat != seat
		configs[seat].effort = 1.0
		# Loyalty is for the player's teammate only: it never throws a game (ADR 0025).
		configs[seat].loyalty = 0.0
		if teammate:
			var warmth: float = state.memory.warmth(state.table[seat], RunDefaults.MEMORY)
			configs[seat].loyalty = warmth * RunDefaults.MEMORY.loyal_cooperation
			configs[seat].effort = FreeRiding.effort(
				share, configs[seat].team_cooperation(), RunDefaults.FREE_RIDE
			)


static func _seat_seed(state: RunState, seat: int) -> int:
	return RandomStreams.derive_seed(state.run_seed, "seat:%d:%d" % [state.set_number(), seat])
