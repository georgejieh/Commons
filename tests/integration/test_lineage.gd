extends GdUnitTestSuite
## ADR 0025's lineage: every row of the table from a built final state, the loyal family
## rule with its ties and with nobody warm, The Commons' two, a death leaving nothing; the
## next run taking it once and clearing it from the profile, a family missing from its
## roster skipped, and starting amounts adding up with the household and the stake.

const DIR: String = "user://test_lineage/"
const PROFILE_PATH: String = DIR + "profile.json"
const START_TIME: int = 1_763_500_000
const METERS: MeterTable = RunLoop.DEFAULT_METERS
const MEMORY: MemoryParams = RunLoop.DEFAULT_MEMORY

var _profile: SaveService


func before_test() -> void:
	_profile = Profile.service(PROFILE_PATH)
	_profile.delete()


func after_test() -> void:
	_profile.delete()


## A full run at its end: Famine, Denunciation, Resentment and the final Year's rounds as
## landlord of four, with the village's first families.
func _ended(famine: int, denunciation: int, resentment: int, landlord_rounds: int) -> RunState:
	var state: RunState = RunState.new(9300)
	state.identity.kind = RunIdentity.Kind.FULL
	state.identity.id = "lineage-%d-%d-%d-%d" % [famine, denunciation, resentment, landlord_rounds]
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.famine = famine
	state.denunciation = denunciation
	state.resentment = resentment
	state.year_rounds = 4
	state.year_landlord_rounds = landlord_rounds
	Roster.start(state, RunLoop.DEFAULT_VILLAGE, [])
	return state


func _feed(state: RunState, family_id: String, fed: int, bombed: int = 0) -> void:
	var summary: SetSummary = SetSummary.new(0)
	summary.add(family_id, SetSummary.Kind.FED, fed)
	if bombed > 0:
		summary.add(family_id, SetSummary.Kind.BOMBED, bombed)
	state.memory.record(summary)


func _left(state: RunState) -> Dictionary:
	return RunLineage.left_by(state, METERS, MEMORY)


func test_every_row_of_the_table() -> void:
	var cases: Dictionary[String, Array] = {
		Endings.BENEVOLENT_LANDLORD: [30, 30, 40, 3],
		Endings.FULL_GRANARY: [85, 40, 40, 4],
		Endings.STRUGGLED: [40, 90, 40, 2],
		Endings.SECRET_CONTRACT: [30, 20, 40, 0],
		Endings.LEAN_YEARS: [80, 20, 40, 1],
		Endings.LABELED: [20, 80, 40, 1],
		Endings.THE_COMMONS: [10, 10, 0, 0],
		Endings.DEATH_FAMINE: [100, 40, 40, 3],
		Endings.DEATH_DENUNCIATION: [40, 100, 40, 1],
	}
	var kinds: Dictionary[String, String] = {
		Endings.BENEVOLENT_LANDLORD: RunLineage.HEIRLOOM,
		Endings.FULL_GRANARY: RunLineage.HEIRLOOM,
		Endings.STRUGGLED: RunLineage.HEIRLOOM,
		Endings.SECRET_CONTRACT: RunLineage.LOYAL,
		Endings.LEAN_YEARS: RunLineage.LOYAL,
		Endings.LABELED: RunLineage.LABEL,
		Endings.THE_COMMONS: RunLineage.LOYAL,
		Endings.DEATH_FAMINE: RunLineage.NONE,
		Endings.DEATH_DENUNCIATION: RunLineage.NONE,
	}
	for outcome: String in cases:
		var values: Array = cases[outcome]
		var state: RunState = _ended(values[0], values[1], values[2], values[3])
		_feed(state, "wang", 3)
		_feed(state, "li", 2)
		assert_str(Endings.outcome(state, METERS)).is_equal(outcome)
		var left: Dictionary = _left(state)
		assert_str(left["kind"]).override_failure_message(outcome).is_equal(kinds[outcome])
		var families: Array[String] = RunLineage.families(left["values"])
		match kinds[outcome]:
			RunLineage.HEIRLOOM:
				var rank: int = left["values"][RunLineage.RANK]
				assert_int(rank).is_between(Ranks.JACK, Ranks.ACE)
				assert_int(left["values"][RunLineage.SUIT]).is_between(0, Deck.SUITS - 1)
				assert_dict(left["values"]).is_equal(_left(state)["values"])
			RunLineage.LOYAL:
				var expected: Array[String] = ["wang"]
				if outcome == Endings.THE_COMMONS:
					expected = ["wang", "li"]
				assert_array(families).override_failure_message(outcome).is_equal(expected)
			_:
				assert_dict(left["values"]).is_empty()


func test_the_heirloom_varies_by_run_and_its_suits_are_even() -> void:
	var ranks: Dictionary[int, bool] = {}
	var suits: Dictionary[int, bool] = {}
	for seed_value: int in 60:
		var state: RunState = _ended(30, 30, 40, 3)
		state.run_seed = 9400 + seed_value
		var values: Dictionary = _left(state)["values"]
		ranks[int(values[RunLineage.RANK])] = true
		suits[int(values[RunLineage.SUIT])] = true
	assert_int(ranks.size()).is_equal(Ranks.ACE - Ranks.JACK + 1)
	assert_int(suits.size()).is_equal(Deck.SUITS)


func test_the_loyal_family_rule() -> void:
	# A tie goes to the earlier in roster order: wang before li.
	var state: RunState = _ended(30, 20, 40, 0)
	_feed(state, "li", 2)
	_feed(state, "wang", 2)
	assert_array(RunLineage.loyal_families(state, MEMORY, 1)).is_equal(["wang"])
	# The lowest grudge wins over roster order.
	_feed(state, "li", 1)
	assert_array(RunLoop.DEFAULT_VILLAGE.families.slice(0, 2).map(_id)).is_equal(["wang", "li"])
	assert_array(RunLineage.loyal_families(state, MEMORY, 1)).is_equal(["li"])
	# Only families still active count.
	Roster.entry(state, "li").status = RosterEntry.Status.DEAD
	Roster.entry(state, "wang").status = RosterEntry.Status.REEDUCATION
	assert_array(RunLineage.loyal_families(state, MEMORY, 2)).is_empty()
	# A grudge of zero or more is nobody's loyalty, and leaves no lineage.
	var cold: RunState = _ended(30, 20, 40, 0)
	_feed(cold, "zhao", 1, 1)
	assert_float(cold.memory.grudge("zhao", MEMORY)).is_greater_equal(0.0)
	assert_str(_left(cold)["kind"]).is_equal(RunLineage.NONE)
	# The Commons takes the two lowest that qualify, or the one there is.
	var commons: RunState = _ended(10, 10, 0, 0)
	_feed(commons, "sun", 1)
	assert_array(RunLineage.families(_left(commons)["values"])).is_equal(["sun"])
	_feed(commons, "chen", 5)
	_feed(commons, "gao", 3)
	assert_array(RunLineage.families(_left(commons)["values"])).is_equal(["chen", "gao"])


func test_a_sent_down_youth_is_never_loyal() -> void:
	var state: RunState = _ended(30, 20, 40, 0)
	var youth: RosterEntry = RosterEntry.new("youth_0")
	youth.template_id = "youth_a"
	state.roster.append(youth)
	_feed(state, "youth_0", 9)
	assert_array(RunLineage.loyal_families(state, MEMORY, 2)).is_empty()


func _write(kind: String, values: Dictionary, finished: int = 0) -> void:
	var data: ProfileData = ProfileData.new()
	data.lineage_kind = kind
	data.lineage_values = values
	data.finished_runs = finished
	data.stake = 5
	Profile.write(_profile, data)


func _start(household: String = "", stake: int = 0, seed_value: int = 9500) -> RunState:
	var request: RunRequest = RunRequest.new(RunRequest.FULL, seed_value, START_TIME)
	request.household = household
	request.stake = stake
	return RunStarter.state(request, _profile)


func test_the_heirloom_goes_into_the_plot_first_and_is_taken_once() -> void:
	_write(RunLineage.HEIRLOOM, {RunLineage.RANK: Ranks.KING, RunLineage.SUIT: 1}, 1)
	var state: RunState = _start("middle_peasants")
	assert_int(state.inventory.plot.size()).is_equal(3)
	var heirloom: CardInstance = state.inventory.plot[0]
	assert_int(heirloom.base_rank()).is_equal(Ranks.KING)
	assert_int(heirloom.suit()).is_equal(1)
	assert_str(heirloom.enhancement_id()).is_equal(CardInstance.MODEL)
	for card: CardInstance in state.inventory.plot.slice(1):
		assert_str(card.enhancement_id()).is_empty()
		assert_bool(card.base_rank() == Ranks.KING and card.suit() == 1).is_false()
	# Taken out of the profile at the start: the next run inherits nothing.
	assert_str(Profile.read(_profile).lineage_kind).is_empty()
	assert_int(_start().inventory.plot.size()).is_equal(0)


func test_a_loyal_family_is_set_to_four_feedings_after_the_carry_over() -> void:
	var data: ProfileData = ProfileData.new()
	var summary: SetSummary = SetSummary.new(0)
	summary.add("wang", SetSummary.Kind.BOMBED, 6)
	summary.add("li", SetSummary.Kind.FED, 6)
	data.memory.record(summary)
	data.lineage_kind = RunLineage.LOYAL
	data.lineage_values = {RunLineage.FAMILIES: ["wang", "tang"]}
	Profile.write(_profile, data)
	var state: RunState = _start()
	assert_float(state.memory.count("wang", SetSummary.Kind.FED)).is_equal(4.0)
	assert_float(state.memory.count("wang", SetSummary.Kind.BOMBED)).is_equal(0.0)
	# The others carry over as usual, and Tang, not in this run's roster, is skipped.
	assert_float(state.memory.count("li", SetSummary.Kind.FED)).is_equal(6.0 * MEMORY.kept_per_run)
	assert_object(Roster.entry(state, "tang")).is_null()
	assert_bool(state.memory.counts.has("tang")).is_false()
	assert_str(Profile.read(_profile).lineage_kind).is_empty()


func test_the_label_adds_to_the_household_and_the_stake() -> void:
	_write(RunLineage.LABEL, {}, 3)
	var state: RunState = _start("old_family", 4)
	assert_int(state.denunciation).is_equal(10 + 10 + 15)
	assert_int(state.famine).is_equal(10)
	assert_int(state.resentment).is_equal(15)


func test_a_finished_run_writes_the_next_lineage_and_a_death_none() -> void:
	var landlord: RunState = _ended(30, 30, 40, 3)
	ProfileCommits.commit(_profile, landlord, true)
	assert_str(Profile.read(_profile).lineage_kind).is_equal(RunLineage.HEIRLOOM)
	# The same record offered again writes nothing new.
	var again: Dictionary = Profile.read(_profile).lineage_values
	ProfileCommits.commit(_profile, landlord, true)
	assert_dict(Profile.read(_profile).lineage_values).is_equal(again)
	var died: RunState = _ended(100, 30, 40, 3)
	died.identity.id = "died"
	ProfileCommits.commit(_profile, died, true)
	assert_str(Profile.read(_profile).lineage_kind).is_empty()
	# A demo run neither takes nor clears one.
	_write(RunLineage.LABEL, {})
	var demo: RunState = RunStarter.state(
		RunRequest.new(RunRequest.DEMO, 9600, START_TIME), _profile
	)
	assert_int(demo.denunciation).is_equal(0)
	assert_str(Profile.read(_profile).lineage_kind).is_equal(RunLineage.LABEL)


func test_a_lineage_that_does_not_read_is_skipped() -> void:
	_write(RunLineage.HEIRLOOM, {"rank": "high"})
	assert_int(_start().inventory.plot.size()).is_equal(0)
	_write(RunLineage.LOYAL, {RunLineage.FAMILIES: 3})
	assert_object(_start()).is_not_null()


func _id(family: FamilyDef) -> String:
	return family.id
