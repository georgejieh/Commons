extends GdUnitTestSuite
## Names (ADR 0028, P4.17): 10,000 runs named through RunStarter's own path, with every
## family, youth arriving, generations 1 to 6 and the player's surname each of the
## offered, village and youth surnames, hold no given name twice and no blocked name. A
## run's names survive a save, a load and a replay; the migration from schema 14 names an
## old save the same way twice; the demo and the arrival name nobody new; a youth never
## shares the player's surname; the surname stays across runs while the given name
## changes; run setup shows the name the run then really uses; the pages that introduce
## a person print the full name and the table the surname alone.

const DIR: String = "user://test_run_names/"
const RUN_PATH: String = DIR + "run.json"
const PROFILE_PATH: String = DIR + "profile.json"
const RUNS: int = 10_000
const GENERATIONS: int = 6
## Youth arrivals forced in each simulated run: two at a time, all four times.
const ARRIVALS: int = 4
const START_TIME: int = 1_763_200_000
const BOOK: NameBook = preload("res://data/villagers/names.tres")

var _saves: SaveService
var _profile: SaveService


func before_test() -> void:
	_saves = SaveService.for_run(RUN_PATH)
	_profile = Profile.service(PROFILE_PATH)
	_saves.delete()
	_profile.delete()


func after_test() -> void:
	_saves.delete()
	_profile.delete()


## Every surname the player could hold for the test: the offered ones and every village
## and youth surname's text.
func _surnames() -> Array[String]:
	var all: Array[String] = Surnames.offered()
	for text: String in Surnames.texts().values():
		if not all.has(text):
			all.append(text)
	return all


func _full(seed_value: int, generation: int, surname: String) -> RunRequest:
	var request: RunRequest = RunRequest.new(RunRequest.FULL, seed_value, START_TIME)
	request.all_open = true
	request.generation = generation
	request.surname = surname
	return request


## Sends every family still in the village away, so youth arrive in pairs.
func _bring_youth(state: RunState, times: int) -> void:
	var events: RandomStream = state.streams.stream(RandomStreams.EVENTS)
	for _time: int in times:
		for entry: RosterEntry in state.roster:
			entry.status = RosterEntry.Status.DEAD
		Roster.prepare_set(state, RunDefaults.VILLAGE, events)


## Each person's surname as it reads, by the ID their given name is kept under.
func _surname_of(state: RunState, family_id: String) -> String:
	if family_id == RunNames.PLAYER:
		return state.names.player_surname
	var entry: RosterEntry = Roster.entry(state, family_id)
	return tr(Roster.name_key(RunDefaults.VILLAGE, entry))


func test_ten_thousand_runs_hold_no_name_twice_and_no_blocked_name() -> void:
	var surnames: Array[String] = _surnames()
	var began: int = Time.get_ticks_msec()
	var problems: PackedStringArray = []
	for run: int in RUNS:
		var surname: String = surnames[run % surnames.size()]
		var request: RunRequest = _full(run * 7919 + 17, 1 + run % GENERATIONS, surname)
		var state: RunState = RunStarter.state(request)
		_bring_youth(state, ARRIVALS)
		var people: int = state.roster.size() + 1
		if state.names.given.size() != people:
			problems.append("run %d named %d of %d" % [run, state.names.given.size(), people])
		var held: Dictionary[String, String] = {}
		for family_id: String in state.names.given:
			var given: String = state.names.given[family_id]
			var full: String = "%s %s" % [_surname_of(state, family_id), given]
			if given.is_empty() or held.has(given):
				problems.append("run %d: %s twice or empty" % [run, full])
			if BOOK.blocked(_surname_of(state, family_id), given):
				problems.append("run %d: blocked %s" % [run, full])
			held[given] = full
		for entry: RosterEntry in state.roster:
			if not entry.template_id.is_empty() and tr(entry.name_key) == surname:
				problems.append("run %d: a youth shares %s" % [run, surname])
		if problems.size() > 20:
			break
	print("10,000 named runs took %d ms" % (Time.get_ticks_msec() - began))
	assert_array(problems).is_empty()


func test_a_pool_that_runs_dry_hands_on_to_the_next() -> void:
	var state: RunState = RunState.new(5)
	var first: NamePool = BOOK.pools[0]
	for index: int in first.names.size():
		state.names.given["taken_%d" % index] = first.names[index]
	state.names.active = true
	state.names.generation = 1
	var entry: RosterEntry = RosterEntry.new("youth_0")
	entry.name_key = "villager.youth.hu"
	RunNames.name_arrival(state, entry)
	assert_array(BOOK.pools[1].names).contains([state.names.given_name("youth_0")])


func test_the_demo_and_the_arrival_name_nobody_new() -> void:
	for request: RunRequest in [RunRequest.new(RunRequest.DEMO, 9), RunStarter.tutorial()]:
		var state: RunState = RunStarter.state(request)
		assert_bool(state.names.active).is_false()
		assert_dict(state.names.given).is_empty()
		assert_str(RunPeople.player_full_name(state)).is_equal(BOOK.fallback_surname)


func test_naming_moves_no_other_draw() -> void:
	var named: RunState = RunStarter.state(_full(77, 3, "Zhang"))
	var plain: RunState = RunState.new(77)
	var streams: Dictionary = named.streams.to_dict()["states"]
	var untouched: Dictionary = plain.streams.to_dict()["states"]
	for stream_name: String in RandomStreams.NAMES:
		if stream_name != RandomStreams.NAMING:
			assert_str(streams[stream_name]).is_equal(untouched[stream_name])
	assert_str(streams[RandomStreams.NAMING]).is_not_equal(untouched[RandomStreams.NAMING])


func test_a_youth_never_shares_the_players_surname() -> void:
	for key: String in RunDefaults.VILLAGE.youth_surnames:
		var surname: String = tr(key)
		for seed_value: int in 20:
			var state: RunState = RunStarter.state(_full(seed_value, 2, surname))
			_bring_youth(state, 6)
			for entry: RosterEntry in state.roster:
				if not entry.template_id.is_empty():
					assert_str(entry.name_key).override_failure_message(surname).is_not_equal(key)


func test_names_survive_a_save_a_load_and_a_replay() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.live_search = false
	var request: RunRequest = RunRequest.new(RunRequest.FULL, 4321, START_TIME)
	assert_bool(controller.start(request, _saves, _profile)).is_true()
	var script: ControllerScript = ControllerScript.new()
	for _step: int in 6:
		script.act(controller)
	var names: Dictionary = controller.state_copy().names.to_dict()
	assert_bool(names["active"]).is_true()
	assert_str(controller.player_name()).contains(" ")
	var again: RunController = auto_free(RunController.new())
	again.live_search = false
	assert_bool(again.continue_saved(_saves, _profile)).is_true()
	assert_dict(again.state_copy().names.to_dict()).is_equal(names)
	assert_str(again.player_name()).is_equal(controller.player_name())
	assert_str(again.seated_full_name(1)).is_equal(controller.seated_full_name(1))


func test_youth_named_mid_run_survive_a_round_trip() -> void:
	var state: RunState = RunStarter.state(_full(31, 4, "Hu"))
	_bring_youth(state, 2)
	var copy: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_dict(copy.names.to_dict()).is_equal(state.names.to_dict())
	assert_str(copy.names.given_name("youth_3")).is_equal(state.names.given_name("youth_3"))


## A schema 14 save: a full run's record with its names, drift and names stream taken out.
func _old_record(seed_value: int, generation: int) -> Dictionary:
	var state: RunState = RunStarter.state(_full(seed_value, generation, ""))
	state.identity.generation = generation
	_bring_youth(state, 1)
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	var data: Dictionary = record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("names")
	checkpoint.erase("drift")
	var streams: Dictionary = checkpoint["streams"]
	var states: Dictionary = streams["states"]
	states.erase(RandomStreams.NAMING)
	return JSON.parse_string(JSON.stringify(data))


func test_the_migration_names_an_old_save_the_same_way_twice() -> void:
	var old: Dictionary = _old_record(606, 3)
	var texts: Dictionary[String, String] = Surnames.texts()
	var first: Dictionary = RunRecordMigrations.migrate_from_14(old.duplicate(true), texts)
	var second: Dictionary = RunRecordMigrations.migrate_from_14(old.duplicate(true), texts)
	assert_dict(first).is_equal(second)
	assert_bool(RunRecordCheck.is_valid(first)).is_true()
	var names: RunNames = RunNames.from_dict(first["checkpoint"]["names"])
	assert_bool(names.active).is_true()
	assert_str(names.player_surname).is_equal(BOOK.fallback_surname)
	var roster: Array = old["checkpoint"]["roster"]
	assert_int(names.given.size()).is_equal(roster.size() + 1)
	# The player's is the name a run of that seed and generation would have drawn.
	var expected: String = RunNames.player_given(606, 3, BOOK.fallback_surname)
	assert_str(names.player_given_name()).is_equal(expected)
	assert_dict(first["checkpoint"]["drift"]).is_empty()


func test_an_old_save_on_disk_loads_named() -> void:
	SaveService.new(RUN_PATH, {}, 14).save(_old_record(707, 2))
	var loaded: SaveLoad = _saves.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var state: RunState = RunState.from_dict(loaded.data["checkpoint"])
	assert_str(state.names.player_given_name()).is_not_empty()
	var again: SaveLoad = _saves.load_save()
	assert_dict(again.data).is_equal(loaded.data)


func test_a_damaged_names_field_fails_validation() -> void:
	var record: RunRecord = RunRecord.new()
	record.mark(RunStarter.state(_full(5, 1, "")))
	var data: Dictionary = JSON.parse_string(JSON.stringify(record.to_dict()))
	data["checkpoint"]["names"]["given"] = {"player": 3}
	assert_bool(RunRecordCheck.is_valid(data)).is_false()
	data["checkpoint"]["names"] = []
	assert_bool(RunRecordCheck.is_valid(data)).is_false()


func test_the_surname_stays_across_runs_while_the_given_name_changes() -> void:
	var data: ProfileData = ProfileData.new()
	data.surname = "Huang"
	Profile.write(_profile, data)
	var first: RunState = RunStarter.state(
		RunRequest.new(RunRequest.FULL, 11, START_TIME), _profile
	)
	var second: RunState = RunStarter.state(
		RunRequest.new(RunRequest.FULL, 11, START_TIME + 1), _profile
	)
	assert_str(first.names.player_surname).is_equal("Huang")
	assert_str(second.names.player_surname).is_equal("Huang")
	# Generations 1 and 2 draw from different pools, so the given name must change.
	assert_int(second.identity.generation).is_equal(first.identity.generation + 1)
	assert_str(second.names.player_given_name()).is_not_equal(first.names.player_given_name())
	assert_str(RunPeople.player_full_name(second)).ends_with(" Huang")


func test_run_setup_shows_the_name_the_run_then_uses() -> void:
	var data: ProfileData = ProfileData.new()
	data.surname = "Cai"
	data.generation = 3
	Profile.write(_profile, data)
	for seed_value: int in [1, 99, 1_763_000_000]:
		var view: SetupView = SetupView.of(_profile, seed_value)
		# The run starts from a copy of the same profile, which it moves a generation on.
		var copy: SaveService = Profile.service(DIR + "copy.json")
		Profile.write(copy, data)
		var request: RunRequest = RunRequest.new(RunRequest.FULL, seed_value, START_TIME)
		var state: RunState = RunStarter.state(request, copy)
		copy.delete()
		assert_int(state.identity.generation).is_equal(view.generation)
		assert_str(view.player_name).is_equal(RunPeople.player_full_name(state))
		assert_str(view.player_name).ends_with(" Cai")


func test_introductions_print_full_names_and_the_table_surnames() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.live_search = false
	controller.start(RunRequest.new(RunRequest.FULL, 2468, START_TIME))
	for seat: int in [1, 2]:
		var surname: String = tr(controller.seated_name_key(seat))
		var full: String = controller.seated_full_name(seat)
		assert_str(full).ends_with(" " + surname)
		assert_int(full.split(" ").size()).is_equal(2)
	var demo: RunController = auto_free(RunController.new())
	demo.start(RunRequest.new(RunRequest.DEMO, 2468, START_TIME))
	assert_str(demo.seated_full_name(1)).is_equal(tr(RunStarter.DEMO_RUN.name_keys[1]))
	assert_str(demo.player_name()).is_equal(BOOK.fallback_surname)
