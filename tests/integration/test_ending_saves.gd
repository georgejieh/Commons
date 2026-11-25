extends GdUnitTestSuite
## ADR 0024 in a run: the loop counts each finished round and the player's rounds as
## landlord, a new Year starts them again, they survive a save, a schema 9 save migrates,
## and a save taken at the run's end, survived or dead by either meter, reloads to the
## same ending.

const SEED: int = 3505
const PATH: String = "user://test_ending_saves/run.json"
const METERS: MeterTable = preload("res://data/run/meters.tres")

var _service: SaveService = SaveService.for_run(PATH)


func after_test() -> void:
	_service.delete()


## A curve no Set can meet, so every round of every Set plays.
func _hard_sets() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e9)
	return SetConfig.new(params)


func _rounds(loop: RunLoop) -> int:
	var played: int = 0
	var as_landlord: int = 0
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.SEAT_KEPT or event.type == RunEvent.Type.SEAT_LOST:
			played += 1
			if event.seat == RunLoop.PLAYER:
				as_landlord += 1
	return played * 100 + as_landlord


func test_the_loop_counts_the_years_rounds_and_a_new_year_starts_them_again() -> void:
	var sets: SetConfig = _hard_sets()
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), sets)
	loop.start_set()
	var script: RunScript = RunScript.new()
	var counted: int = 0
	for set_index: int in SetConfig.SETS_PER_YEAR:
		script.play_until_set_over(loop)
		counted += _rounds(loop)
		assert_int(loop.state.year_rounds * 100 + loop.state.year_landlord_rounds).is_equal(counted)
		if loop.awaiting() != RunLoop.Awaiting.SET_OVER:
			return
		if set_index < SetConfig.SETS_PER_YEAR - 1:
			loop.next_set()
	assert_int(loop.state.year_rounds).is_equal(SetConfig.SETS_PER_YEAR * sets.max_rounds())
	loop.next_set()
	assert_int(loop.state.year).is_equal(2)
	assert_int(loop.state.year_rounds).is_equal(0)
	assert_int(loop.state.year_landlord_rounds).is_equal(0)


func test_the_counters_survive_a_save_and_a_resume_mid_set() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), _hard_sets())
	loop.start_set()
	var script: RunScript = RunScript.new()
	for _turn: int in 60:
		script.act(loop)
	assert_int(loop.state.year_rounds).is_greater(0)
	_service.save(loop.record.to_dict())
	var resumed: RunLoop = RunRecord.resume(
		_service.load_save().data, RunScript.bots(), _hard_sets()
	)
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.year_rounds).is_equal(loop.state.year_rounds)
	assert_int(resumed.state.year_landlord_rounds).is_equal(loop.state.year_landlord_rounds)


func test_a_schema_9_save_starts_its_counts_at_nothing() -> void:
	var record: RunRecord = RunRecord.new()
	record.mark(RunState.new(9))
	var data: Dictionary = record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("year_rounds")
	checkpoint.erase("year_landlord_rounds")
	assert_bool(RunRecord.is_valid(data)).is_false()
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 9, "data": data}))
	file.close()
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var state: RunState = RunState.from_dict(loaded.data["checkpoint"])
	assert_int(state.year_rounds).is_equal(0)
	assert_int(state.year_landlord_rounds).is_equal(0)
	assert_int(SaveService.SCHEMA_VERSION).is_greater_equal(10)


func test_counters_out_of_order_are_a_damaged_save() -> void:
	for counts: Array in [[-1, 0], [2, 3], [1.5, 0], ["4", 0]]:
		var record: RunRecord = RunRecord.new()
		record.mark(RunState.new(9))
		var data: Dictionary = record.to_dict()
		data["checkpoint"]["year_rounds"] = counts[0]
		data["checkpoint"]["year_landlord_rounds"] = counts[1]
		assert_bool(RunRecord.is_valid(data)).override_failure_message(str(counts)).is_false()


## A finished run at the run's end, saved and loaded back through the controller.
func _finished(famine: int, denunciation: int, landlord_rounds: int) -> RunState:
	var state: RunState = RunState.new(SEED)
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.famine = famine
	state.denunciation = denunciation
	state.year_rounds = 4
	state.year_landlord_rounds = landlord_rounds
	for family: FamilyDef in RunLoop.DEFAULT_VILLAGE.families:
		state.roster.append(RosterEntry.new(family.id))
	state.roster[2].status = RosterEntry.Status.DEAD
	return state


func test_a_save_at_the_runs_end_reloads_to_the_same_ending() -> void:
	var high: int = METERS.famine.high
	var death: int = METERS.famine.death
	var cases: Dictionary[String, Array] = {
		Endings.FULL_GRANARY: [high, 0, 3],
		Endings.THE_COMMONS: [0, 0, 0],
		Endings.DEATH_FAMINE: [death, 30, 1],
		Endings.DEATH_DENUNCIATION: [30, death, 1],
	}
	for expected: String in cases:
		var values: Array = cases[expected]
		var state: RunState = _finished(values[0], values[1], values[2])
		var record: RunRecord = RunRecord.new()
		record.mark(state)
		_service.save(record.to_dict())
		var controller: RunController = auto_free(RunController.new())
		assert_bool(controller.resume_saved(_service, RunScript.bots(), SetConfig.new())).is_true()
		assert_int(controller.awaiting()).is_equal(RunController.AWAIT_RUN_OVER)
		var view: EndingView = controller.ending()
		var fresh: EndingView = EndingView.of(state, RunPeople.player_surname(state))
		assert_str(view.id).override_failure_message(expected).is_equal(expected)
		assert_array(view.lines).is_equal(fresh.lines)
		assert_str(view.text).is_equal(fresh.text)
		assert_bool(controller.has_village()).is_true()


## A run that really dies, by a missed Quota whose Famine reaches death, saves at the
## run's end, and that save shows the same death.
func test_a_run_that_dies_in_play_reloads_to_its_death() -> void:
	var table: MeterTable = METERS.duplicate()
	var sources: Array[MeterSource] = []
	for row: MeterSource in METERS.sources:
		if row.id != RunMeters.MISSED_TARGET:
			sources.append(row)
	var miss: MeterSource = MeterSource.new()
	miss.id = RunMeters.MISSED_TARGET
	miss.meter = RunMeters.DENUNCIATION
	miss.amount = 100
	sources.append(miss)
	table.sources = sources
	var loop: RunLoop = RunLoop.new(
		RunState.new(SEED),
		RunScript.bots(),
		_hard_sets(),
		RunLoop.DEFAULT_PARAMS,
		RunPools.DEBUFFS.debuffs,
		table
	)
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)
	assert_str(Endings.outcome(loop.state, table)).is_equal(Endings.DEATH_DENUNCIATION)
	var resumed: RunLoop = RunRecord.resume(loop.record.to_dict(), RunScript.bots(), _hard_sets())
	assert_str(Endings.outcome(resumed.state, METERS)).is_equal(Endings.DEATH_DENUNCIATION)
	assert_int(resumed.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)
