extends GdUnitTestSuite
## A run state survives serialization through JSON with every field intact.

const ITERATIONS: int = 2000
const SEED: int = 3101
const STREAM_DRAWS: int = 20
## Above 2^53, so a JSON number could not hold it.
const UNSAFE_JSON_VALUE: int = 9007199254740993


func test_round_trip_through_json_is_lossless_for_random_states() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var failures: int = 0
	for _i: int in ITERATIONS:
		var state: RunState = _random_state(rng)
		var restored: RunState = _through_json(state)
		if JSON.stringify(restored.to_dict()) != JSON.stringify(state.to_dict()):
			failures += 1
		elif not _same_fields(state, restored):
			failures += 1
	assert_int(failures).is_equal(0)


func test_restored_streams_continue_identically() -> void:
	var state: RunState = RunState.new(SEED)
	for stream_name: String in RandomStreams.NAMES:
		state.streams.stream(stream_name).next_int(0, 1000)
	var restored: RunState = _through_json(state)
	for stream_name: String in RandomStreams.NAMES:
		for _i: int in STREAM_DRAWS:
			var expected: int = state.streams.stream(stream_name).next_int(0, 1000000)
			assert_int(restored.streams.stream(stream_name).next_int(0, 1000000)).is_equal(expected)


func test_values_above_two_to_the_53_survive() -> void:
	var state: RunState = RunState.new(UNSAFE_JSON_VALUE)
	state.commons_pool = UNSAFE_JSON_VALUE
	var restored: RunState = _through_json(state)
	assert_int(restored.run_seed).is_equal(UNSAFE_JSON_VALUE)
	assert_int(restored.commons_pool).is_equal(UNSAFE_JSON_VALUE)


func _through_json(state: RunState) -> RunState:
	return RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))


func _random_state(rng: RandomNumberGenerator) -> RunState:
	var state: RunState = RunState.new(rng.randi() * rng.randi())
	for _i: int in rng.randi_range(0, 30):
		state.streams.stream(RandomStreams.NAMES[rng.randi_range(0, 5)]).next_float()
	state.phase = rng.randi_range(0, RunFlow.State.size() - 1) as RunFlow.State
	state.year = rng.randi_range(1, 8)
	state.set_index = rng.randi_range(0, 2)
	state.set_type = rng.randi_range(0, 2) as RunState.SetType
	state.round_index = rng.randi_range(0, 3)
	state.debuff_ladder.append(RunState.NO_DEBUFF)
	for _i: int in rng.randi_range(0, 3):
		state.debuff_ladder.append("debuff_%d" % rng.randi_range(0, 19))
	state.famine = rng.randi_range(0, 100)
	state.denunciation = rng.randi_range(0, 100)
	for i: int in rng.randi_range(0, 16):
		var entry: RosterEntry = RosterEntry.new("family_%d" % i)
		entry.status = rng.randi_range(0, 3) as RosterEntry.Status
		entry.return_timer = rng.randi_range(0, 3)
		state.roster.append(entry)
	_fill_inventory(rng, state.inventory)
	state.coupons = rng.randi_range(0, 10000)
	state.commons_pool = rng.randi() * rng.randi_range(1, 1 << 30)
	state.landlord_seat = rng.randi_range(-1, 2)
	for set_number: int in rng.randi_range(0, 24):
		var summary: SetSummary = SetSummary.new(set_number)
		for _i: int in rng.randi_range(0, 4):
			summary.add("family_%d" % rng.randi_range(0, 15), rng.randi_range(0, 3), 1)
		state.summaries.append(summary)
	return state


func _fill_inventory(rng: RandomNumberGenerator, inventory: RunInventory) -> void:
	for i: int in rng.randi_range(0, 5):
		inventory.cadres.append("cadre_%d" % i)
	for i: int in rng.randi_range(0, 2):
		inventory.consumables.append("campaign_%d" % i)
	for i: int in rng.randi_range(0, 8):
		var card: CardInstance = CardInstance.new(
			CardInstance.FIRST_PLOT_ID + i,
			rng.randi_range(0, 14),
			rng.randi_range(-1, 3),
			CardInstance.Origin.PLOT
		)
		inventory.plot.append(card)


func _same_fields(first: RunState, second: RunState) -> bool:
	return (
		first.run_seed == second.run_seed
		and first.phase == second.phase
		and first.year == second.year
		and first.set_index == second.set_index
		and first.set_type == second.set_type
		and first.round_index == second.round_index
		and first.debuff_ladder == second.debuff_ladder
		and first.famine == second.famine
		and first.denunciation == second.denunciation
		and first.roster.size() == second.roster.size()
		and first.inventory.cadres == second.inventory.cadres
		and first.inventory.consumables == second.inventory.consumables
		and first.inventory.plot.size() == second.inventory.plot.size()
		and first.coupons == second.coupons
		and first.commons_pool == second.commons_pool
		and first.landlord_seat == second.landlord_seat
		and first.summaries.size() == second.summaries.size()
	)
