class_name DebuffScript
extends RefCounted
## Runs for the debuff tests (ADR 0023): a Set with a chosen debuff in force from a chosen
## round, played by RunScript, with a hook that sees each round once it waits on the
## player. A Set's target no one can meet keeps every round in play.

const POOL: DebuffPool = preload("res://data/run/debuff_pool.tres")
const STEPS: int = 3000


static func definition(debuff_id: String) -> ModifierDef:
	for debuff: ModifierDef in POOL.debuffs:
		if debuff.id == debuff_id:
			return debuff
	return null


## A pool of just these debuffs, for ladders drawn the real way.
static func pool(ids: Array[String]) -> Array[ModifierDef]:
	var chosen: Array[ModifierDef] = []
	for debuff_id: String in ids:
		chosen.append(definition(debuff_id))
	return chosen


## A curve no Set can meet, so every round plays.
static func hard_sets() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e9)
	return SetConfig.new(params)


## A Set with debuff_id in force from round from on: the ladder is set by hand once drawn,
## so it is never replayed from a record. setup gets the state before the Set starts.
static func loop_with(
	seed_value: int, debuff_id: String, from: int = 1, setup: Callable = Callable()
) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	if setup.is_valid():
		setup.call(state)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), hard_sets())
	loop.start_set()
	var ladder: Array[String] = []
	for _round: int in loop.sets().max_rounds():
		ladder.append(RunState.NO_DEBUFF)
	ladder[from] = debuff_id
	state.debuff_ladder = ladder
	return loop


## A Set whose ladder the real draw made from a pool of the one debuff, from the first
## seed at or after seed_value where it comes into force by round by.
static func drawn(
	seed_value: int, debuff_id: String, by: int = 3, setup: Callable = Callable()
) -> RunLoop:
	for offset: int in 200:
		var state: RunState = RunState.new(seed_value + offset)
		if setup.is_valid():
			setup.call(state)
		var loop: RunLoop = RunLoop.new(
			state, RunScript.bots(), hard_sets(), RunLoop.DEFAULT_PARAMS, pool([debuff_id])
		)
		loop.start_set()
		var at: int = state.debuff_ladder.find(debuff_id)
		if at > 0 and at <= by:
			return loop
	return null


## Plays the player's seat to the Set's end. check gets the loop once in each round, the
## first time the round waits on the player; it may act for the player and returns true
## when it did.
static func play(loop: RunLoop, check: Callable = Callable()) -> void:
	var script: RunScript = RunScript.new()
	var seen: int = -1
	for _step: int in STEPS:
		if loop.round_state() != null and loop.state.round_index != seen and _waits(loop):
			seen = loop.state.round_index
			if check.is_valid() and bool(check.call(loop)):
				continue
		if not script.act(loop):
			return


## Plays the player's seat until the round round_index has seen at least plays plays.
static func play_into(loop: RunLoop, round_index: int, plays: int) -> bool:
	var script: RunScript = RunScript.new()
	for _step: int in STEPS:
		var round_state: RoundState = loop.round_state()
		if (
			loop.state.round_index == round_index
			and round_state != null
			and round_state.public_view().history.size() >= plays
			and _waits(loop)
		):
			return true
		if not script.act(loop):
			return false
	return false


## The events of type in each round, by round index: a round runs from the end of the one
## before, so what happens at its start, before the deal, counts in it.
static func per_round(loop: RunLoop, type: RunEvent.Type) -> Dictionary[int, Array]:
	var rounds: Dictionary[int, Array] = {}
	var round_index: int = 0
	for event: RunEvent in loop.events():
		if event.type == type:
			if not rounds.has(round_index):
				rounds[round_index] = []
			rounds[round_index].append(event)
		if event.type == RunEvent.Type.SEAT_KEPT or event.type == RunEvent.Type.SEAT_LOST:
			round_index += 1
	return rounds


## Every event of type in the Set.
static func all_of(loop: RunLoop, type: RunEvent.Type) -> Array[RunEvent]:
	var found: Array[RunEvent] = []
	for event: RunEvent in loop.events():
		if event.type == type:
			found.append(event)
	return found


## Each change of a meter in the Set, in order.
static func rises(loop: RunLoop, meter: String) -> PackedInt32Array:
	var changes: PackedInt32Array = []
	for event: RunEvent in all_of(loop, RunEvent.Type.METER_CHANGED):
		if event.text == meter:
			changes.append(event.value)
	return changes


static func sum(values: PackedInt32Array) -> int:
	var total: int = 0
	for value: int in values:
		total += value
	return total


## The state, the round's hands and public view, and the log, as text to compare.
static func snapshot(loop: RunLoop) -> String:
	var parts: PackedStringArray = [JSON.stringify(loop.state.to_dict(), "", true)]
	var round_state: RoundState = loop.round_state()
	if round_state != null:
		for seat: int in Seats.COUNT:
			var ids: Array[int] = []
			for card: CardInstance in round_state.view_for(seat).own_cards:
				ids.append(card.id())
			ids.sort()
			parts.append("seat %d %s %s" % [seat, ids, round_state.view_for(seat).exposed])
		parts.append(str(round_state.public_view().kitty_counts))
	for event: RunEvent in loop.events():
		parts.append(event.describe())
	parts.append("awaiting %d" % loop.awaiting())
	return "\n".join(parts)


static func _waits(loop: RunLoop) -> bool:
	return (
		[
			RunLoop.Awaiting.PLAYER_PLAY,
			RunLoop.Awaiting.PLAYER_SWAP,
			RunLoop.Awaiting.PLAYER_OPENING,
		]
		. has(loop.awaiting())
	)
