extends GdUnitTestSuite
## ADR 0025 through the run loop: a Quota ended in high Famine takes a seated family, a
## met boss Quota against a risen villager deposes it until the next Year, and a warm
## family covers for the player only as the player's teammate.

const SEED: int = 6610
const MEMORY: MemoryParams = preload("res://data/villagers/memory.tres")


## A curve every Set meets with its first scored play.
func _easy_sets() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1.0)
	return SetConfig.new(params)


func _roster_state(seed_value: int = SEED) -> RunState:
	var state: RunState = RunState.new(seed_value)
	Roster.start(state, RunDefaults.VILLAGE, [])
	return state


func _events_of(loop: RunLoop, type: RunEvent.Type) -> Array[RunEvent]:
	var found: Array[RunEvent] = []
	for event: RunEvent in loop.events():
		if event.type == type:
			found.append(event)
	return found


func test_a_quota_ended_in_high_famine_takes_a_seated_family() -> void:
	var state: RunState = _roster_state()
	state.famine = RunDefaults.METERS.famine.high
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), _easy_sets())
	loop.start_set()
	var seated: Array[String] = state.table.slice(1)
	RunScript.new().play_until_set_over(loop)
	assert_int(RunDefaults.METERS.famine.band(state.famine)).is_equal(MeterBands.Band.HIGH)
	var starved: Array[RunEvent] = _events_of(loop, RunEvent.Type.STARVED)
	assert_int(starved.size()).is_equal(1)
	var dead: String = starved[0].text
	assert_bool(seated.has(dead)).is_true()
	assert_int(Roster.entry(state, dead).status).is_equal(RosterEntry.Status.DEAD)
	# The dead family never sits again this run, and the Year's other high-Famine Quotas
	# take nobody: one death a Year.
	for set_count: int in 2:
		state.famine = RunDefaults.METERS.famine.high
		RunScript.next_set(loop)
		assert_bool(state.table.has(dead)).is_false()
		RunScript.new().play_until_set_over(loop)
		assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
		assert_int(state.year).is_equal(1)
		assert_array(_events_of(loop, RunEvent.Type.STARVED)).is_empty()
	assert_int(state.year_starved).is_equal(1)
	# The next Year may take another.
	state.famine = RunDefaults.METERS.famine.high
	RunScript.next_set(loop)
	assert_int(state.year).is_equal(2)
	assert_int(state.year_starved).is_equal(0)
	RunScript.new().play_until_set_over(loop)
	assert_int(_events_of(loop, RunEvent.Type.STARVED).size()).is_equal(1)


func test_nobody_starves_while_famine_is_below_its_high_band() -> void:
	var state: RunState = _roster_state()
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), _easy_sets())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	assert_array(_events_of(loop, RunEvent.Type.STARVED)).is_empty()


func test_a_met_boss_quota_deposes_the_risen_villager_until_the_next_year() -> void:
	var state: RunState = _roster_state()
	state.year = 2
	state.set_index = 2
	state.set_type = RunState.SetType.BOSS
	state.risen.assign(["zhao"])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), _easy_sets())
	loop.start_set()
	assert_str(state.boss_family).is_equal("zhao")
	RunScript.new().play_until_set_over(loop)
	assert_bool(state.set_progress >= loop.target()).is_true()
	assert_int(_events_of(loop, RunEvent.Type.DEPOSED).size()).is_equal(1)
	assert_int(Roster.entry(state, "zhao").status).is_equal(RosterEntry.Status.DEPOSED)
	assert_bool(state.risen_used.has("zhao")).is_true()
	RunScript.next_set(loop)
	assert_int(state.year).is_equal(3)
	assert_int(Roster.entry(state, "zhao").status).is_equal(RosterEntry.Status.ACTIVE)


## Every family fed often: as the player's teammate a family's loyalty is warmth times
## loyal_cooperation; as an opponent it is nothing, and its cooperation is untouched.
func test_loyalty_is_for_the_players_teammate_only() -> void:
	var state: RunState = _roster_state()
	var summary: SetSummary = SetSummary.new(0)
	for entry: RosterEntry in state.roster:
		summary.add(entry.family_id, SetSummary.Kind.FED, 20)
	state.memory.record(summary)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	var script: RunScript = RunScript.new()
	var seen_teammate: bool = false
	var seen_opponent: bool = false
	var guard: int = 0
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER and guard < 400:
		guard += 1
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY:
			var configs: Array[BotConfig] = loop.get("_configs")
			for seat: int in range(1, Seats.COUNT):
				var teammate: bool = state.landlord_seat != 0 and state.landlord_seat != seat
				var expected: float = MEMORY.loyal_cooperation if teammate else 0.0
				assert_float(configs[seat].loyalty).is_equal_approx(expected, 0.0001)
				seen_teammate = seen_teammate or teammate
				seen_opponent = seen_opponent or not teammate
		if not script.act(loop):
			break
	assert_bool(seen_teammate).is_true()
	assert_bool(seen_opponent).is_true()
