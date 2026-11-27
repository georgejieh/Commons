extends GdUnitTestSuite
## ADR 0031: the run counts Quotas in a row the player ended without holding the
## landlord's seat in any round, and holding it once resets the count. Past the grace each
## further Quota adds Famine, a step more each time up to the most, through the meter
## change hook. It can kill the run, and the count is saved, schema 14 on.

const SEEDS: Array[int] = [3101, 3102, 3103, 3104, 3105, 3106, 3107, 3108]

static var _dir: String = TestFolder.of("test_unheld_seat")


## Doubles every meter change, as a harsher debuff would.
class Double:
	extends ModifierEffect

	func meter_change(context: MeterContext) -> void:
		context.delta *= 2


## The log and the modifiers the Sets counted here are told to, the suite's own.
var _log: SetLog = SetLog.new()
var _stack: ModifierStack = ModifierStack.new()


func before_test() -> void:
	_log = SetLog.new()
	_stack = ModifierStack.new()
	DirAccess.make_dir_recursive_absolute(_dir)


func after_test() -> void:
	SaveService.for_run(_dir + "run.json").delete()


## Every Quota is met in its first round, so missing one moves no Famine.
func _easy_sets() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1.0)
	return SetConfig.new(params)


## Plays one Quota from state, the player always making the given bid.
func _play_set(state: RunState, claim: bool) -> RunLoop:
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), _easy_sets())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while true:
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_BID:
			if loop.player_bid(claim) != RunLoop.Reason.OK:
				break
		elif not script.act(loop):
			break
	return loop


## A Quota the player ended without the seat, with the count back at none.
func _seatless_set(seed_value: int) -> RunLoop:
	var loop: RunLoop = _play_set(RunState.new(seed_value), false)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	assert_bool(YearClass.held_seat(loop.events(), RunLoop.PLAYER)).is_false()
	loop.state.seatless_sets = 0
	loop.state.famine = 0
	return loop


## The Sets stood by that the loop logged, and those the suite's own close did.
func _stood_by(loop: RunLoop) -> Array[RunEvent]:
	var events: Array[RunEvent] = loop.events().duplicate()
	events.append_array(_log.events())
	return events.filter(func(event: RunEvent) -> bool: return event.type == RunEvent.Type.STOOD_BY)


func test_held_seat_reads_every_round_of_the_set() -> void:
	var events: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.SEAT_KEPT, 1),
		RunEvent.new(RunEvent.Type.SEAT_LOST, 2),
	]
	assert_bool(YearClass.held_seat(events, 0)).is_false()
	events.append(RunEvent.new(RunEvent.Type.SEAT_LOST, 0))
	events.append(RunEvent.new(RunEvent.Type.SEAT_KEPT, 1))
	assert_bool(YearClass.held_seat(events, 0)).is_true()
	assert_bool(YearClass.held_seat([] as Array[RunEvent], 0)).is_false()


## Over several seeds, a player who bids is in the seat for some round of some Quotas,
## and those end with the count at none; the rest lengthen it and pay.
func test_holding_the_seat_in_any_round_resets_the_count() -> void:
	var held: int = 0
	var not_held: int = 0
	for seed_value: int in SEEDS:
		for claim: bool in [true, false]:
			var state: RunState = RunState.new(seed_value)
			state.seatless_sets = 6
			var loop: RunLoop = _play_set(state, claim)
			assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
			if YearClass.held_seat(loop.events(), RunLoop.PLAYER):
				held += 1
				assert_int(state.seatless_sets).is_equal(0)
				assert_array(_stood_by(loop)).is_empty()
			else:
				not_held += 1
				assert_int(state.seatless_sets).is_equal(7)
				assert_int(_stood_by(loop).size()).is_equal(1)
	assert_int(held).is_greater(0)
	assert_int(not_held).is_greater(0)


## Inside the grace nothing is paid; the last free Quota is logged with no steps; then
## each Quota pays a step more, up to the most, and each step is the stood_by row.
func test_steps_grow_by_one_a_quota_up_to_the_most() -> void:
	var loop: RunLoop = _seatless_set(SEEDS[0])
	var params: RunParams = RunDefaults.PARAMS
	var row: int = RunDefaults.METERS.source(RunMeters.STOOD_BY).amount
	assert_int(params.seat_grace_sets).is_equal(3)
	assert_int(params.seat_max_steps).is_equal(4)
	assert_int(row).is_equal(1)
	var expected: Array[int] = [0, 0, 0, 1, 2, 3, 4, 4, 4]
	for index: int in expected.size():
		var was: int = loop.state.famine
		var logged: int = _stood_by(loop).size()
		_count_standing_by(loop)
		var steps: int = expected[index]
		assert_int(loop.state.seatless_sets).is_equal(index + 1)
		assert_int(loop.state.famine - was).is_equal(steps * row)
		var found: Array[RunEvent] = _stood_by(loop)
		var count: int = index + 1
		if count < params.seat_grace_sets:
			assert_int(found.size()).is_equal(logged)
			continue
		assert_int(found.size()).is_equal(logged + 1)
		assert_int(found[-1].value).is_equal(steps)
		assert_float(found[-1].amount).is_equal(float(steps * row))


## The cost is the row times the steps, so a bigger row costs more.
func test_the_amount_is_the_steps_times_the_row() -> void:
	var state: RunState = RunState.new(SEEDS[0])
	var meters: MeterTable = RunDefaults.METERS.duplicate()
	var sources: Array[MeterSource] = []
	for source: MeterSource in RunDefaults.METERS.sources:
		if source.id != RunMeters.STOOD_BY:
			sources.append(source)
	var row: MeterSource = MeterSource.new()
	row.id = RunMeters.STOOD_BY
	row.meter = RunMeters.FAMINE
	row.amount = 5
	sources.append(row)
	meters.sources = sources
	var loop: RunLoop = RunLoop.new(
		state, RunScript.bots(), _easy_sets(), RunDefaults.PARAMS, RunPools.DEBUFFS.debuffs, meters
	)
	loop.start_set()
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER:
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_BID:
			assert_int(loop.player_bid(false)).is_equal(RunLoop.Reason.OK)
		elif not RunScript.new().act(loop):
			break
	assert_bool(YearClass.held_seat(loop.events(), RunLoop.PLAYER)).is_false()
	state.famine = 0
	state.seatless_sets = RunDefaults.PARAMS.seat_grace_sets + 1
	_count_standing_by(loop, meters)
	assert_int(state.famine).is_equal(2 * 5)


## A modifier on the meter change hook changes the cost, as it does every Famine source.
func test_the_cost_goes_through_the_meter_change_hook() -> void:
	var loop: RunLoop = _seatless_set(SEEDS[0])
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = ModifierDef.Kind.DEBUFF
	definition.hooks.assign([Hooks.METER_CHANGE])
	_stack.add_entry(ActiveModifier.new(definition, Double.new()))
	loop.state.seatless_sets = RunDefaults.PARAMS.seat_grace_sets + 2
	_count_standing_by(loop)
	var row: int = RunDefaults.METERS.source(RunMeters.STOOD_BY).amount
	assert_int(loop.state.famine).is_equal(3 * row * 2)
	assert_float(_stood_by(loop)[-1].amount).is_equal(float(3 * row * 2))


## A run one Famine short of death that pays the cost dies of Famine.
func test_a_run_that_dies_of_it_ends_as_a_famine_death() -> void:
	var died: int = 0
	for seed_value: int in SEEDS:
		var state: RunState = RunState.new(seed_value)
		state.famine = RunDefaults.METERS.famine.death - 1
		state.seatless_sets = RunDefaults.PARAMS.seat_grace_sets
		var loop: RunLoop = _play_set(state, false)
		var paid: Array[RunEvent] = _stood_by(loop)
		if paid.is_empty():
			continue
		assert_float(paid[0].amount).is_greater(0.0)
		assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)
		assert_int(loop.events()[-1].type).is_equal(RunEvent.Type.RUN_DIED)
		assert_str(loop.events()[-1].text).is_equal(RunMeters.FAMINE)
		died += 1
	assert_int(died).is_greater(0)


## The count is saved with the run and read back on resume.
func test_the_count_survives_save_and_resume() -> void:
	var loop: RunLoop = _play_set(RunState.new(SEEDS[1]), false)
	loop.state.seatless_sets = 2
	loop.record.mark(loop.state)
	var service: SaveService = SaveService.for_run(_dir + "run.json")
	assert_int(service.save(loop.record.to_dict())).is_equal(OK)
	var loaded: SaveLoad = service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var resumed: RunLoop = RunRecord.resume(loaded.data, RunScript.bots(), _easy_sets())
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.seatless_sets).is_equal(2)


## A negative, fractional or missing count is a damaged save.
func test_a_bad_count_is_a_damaged_save() -> void:
	var state: RunState = RunState.new(SEEDS[0])
	var data: Dictionary = {"checkpoint": state.to_dict(), "commands": []}
	data = RunRecordMigrations.migrate_from_12(data)
	assert_bool(RunRecordCheck.is_valid(data)).is_true()
	for wrong: Variant in [-1, 1.5, "2", null]:
		var broken: Dictionary = data.duplicate(true)
		broken["checkpoint"]["seatless_sets"] = wrong
		assert_bool(RunRecordCheck.is_valid(broken)).override_failure_message(str(wrong)).is_false()
	var missing: Dictionary = data.duplicate(true)
	var checkpoint: Dictionary = missing["checkpoint"]
	checkpoint.erase("seatless_sets")
	assert_bool(RunRecordCheck.is_valid(missing)).is_false()


## A schema 13 save has no count: it loads with none, and the run counts from there.
func test_a_schema_13_save_migrates() -> void:
	var loop: RunLoop = _play_set(RunState.new(SEEDS[1]), false)
	loop.record.mark(loop.state)
	var old: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = old["checkpoint"]
	checkpoint.erase("seatless_sets")
	assert_bool(RunRecordCheck.is_valid(old)).is_false()
	var migrated: Dictionary = RunRecordMigrations.migrate_from_13(old.duplicate(true))
	assert_bool(RunRecordCheck.is_valid(migrated)).is_true()
	assert_int(int(migrated["checkpoint"]["seatless_sets"])).is_equal(0)
	var file: FileAccess = FileAccess.open(_dir + "run.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 13, "data": old}))
	file.close()
	var loaded: SaveLoad = SaveService.for_run(_dir + "run.json").load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var resumed: RunLoop = RunRecord.resume(loaded.data, RunScript.bots(), _easy_sets())
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.seatless_sets).is_equal(0)


## Counts the Quota just played as one the player stood by in, or not, as the loop's close
## does, with its modifiers and log the suite's own.
func _count_standing_by(loop: RunLoop, meters: MeterTable = RunDefaults.METERS) -> void:
	var close: QuotaClose = QuotaClose.new(loop.state, _log, _stack, meters, RunDefaults.PARAMS)
	close.count_standing_by()
