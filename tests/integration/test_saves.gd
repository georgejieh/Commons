extends GdUnitTestSuite
## Saves survive a kill at every state boundary and mid-round, fall back to the backup
## when damaged, migrate old versions, and stay small.

const DIR: String = "user://test_saves/"
const SEED: int = 3601
const MAX_BYTES: int = 64 * 1024
const STRINGS: String = "res://data/strings/strings.csv"

var _service: SaveService


func before_test() -> void:
	_service = SaveService.for_run(DIR + "run.json")
	_service.delete()


func after_test() -> void:
	_service.delete()
	SaveService.new(DIR + "profile.json").delete()


## One Year, so the boss, the Year's end and the run's end are all saved and resumed.
func test_a_kill_at_any_boundary_or_command_continues_exactly() -> void:
	var snapshots: PackedStringArray = []
	var waits: Array[int] = []
	var loop: RunLoop = _one_year_loop(RunState.new(SEED))
	loop.on_boundary = func(at: RunLoop) -> void: _snapshot(at, snapshots, waits, -1)
	loop.start_set()
	var expected: String = _drive(loop, snapshots, waits)
	var expected_log: PackedStringArray = _log_lines(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)
	assert_int(snapshots.size()).is_greater(20)
	var mismatches: int = 0
	var wrong_waits: int = 0
	var largest: int = 0
	for index: int in snapshots.size():
		largest = maxi(largest, snapshots[index].to_utf8_buffer().size())
		var resumed: RunLoop = _resume(snapshots[index])
		if waits[index] >= 0 and resumed.awaiting() != waits[index]:
			wrong_waits += 1
		# A Set's end has folded its log into the summary, so only a resume inside the
		# last Set rebuilds that log.
		var inside_set: bool = resumed.awaiting() < RunLoop.Awaiting.SET_OVER
		if _drive(resumed, PackedStringArray(), [] as Array[int]) != expected:
			mismatches += 1
		elif inside_set and resumed.set_number() == loop.set_number():
			if _log_lines(resumed) != expected_log:
				mismatches += 1
	assert_int(mismatches).is_equal(0)
	assert_int(wrong_waits).is_equal(0)
	assert_int(largest).is_less(MAX_BYTES)


func test_the_last_autosave_resumes_at_the_run_end() -> void:
	var snapshots: PackedStringArray = []
	var waits: Array[int] = []
	var loop: RunLoop = _one_year_loop(RunState.new(SEED))
	loop.on_boundary = func(at: RunLoop) -> void: _snapshot(at, snapshots, waits, -1)
	loop.start_set()
	_drive(loop, PackedStringArray(), [] as Array[int])
	assert_int(_resume(snapshots[-1]).awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)


## A resumed Set rebuilds its whole log, not only the round in progress.
func test_a_resumed_set_has_the_same_log() -> void:
	var loop: RunLoop = _one_year_loop(RunState.new(SEED))
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.state.round_index == 0 and script.act(loop):
		pass
	script.act(loop)
	assert_int(loop.awaiting()).is_less(RunLoop.Awaiting.SET_OVER)
	assert_int(loop.state.round_index).is_greater(0)
	var resumed: RunLoop = _resume(_saved_text(loop))
	assert_array(_log_lines(resumed)).is_equal(_log_lines(loop))


func test_a_save_whose_commands_no_longer_apply_resumes_to_null() -> void:
	var loop: RunLoop = _one_year_loop(RunState.new(SEED))
	loop.start_set()
	var data: Dictionary = loop.record.to_dict()
	data["commands"] = [{"type": "need", "need": 1}, {"type": "need", "need": 1}]
	assert_object(RunRecord.resume(data, RunScript.bots(), _one_year())).is_null()


func test_a_damaged_save_falls_back_to_the_backup_with_a_notice() -> void:
	_service.save(_record(1))
	_service.save(_record(2))
	_damage(_service.path())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_int(_turn(loaded.data)).is_equal(1)
	assert_str(loaded.notice_key).is_equal(SaveService.RESTORED_KEY)
	assert_bool(_string_keys().has(loaded.notice_key)).is_true()


func test_two_damaged_saves_are_unreadable_with_a_notice() -> void:
	_service.save(_record(1))
	_service.save(_record(2))
	_damage(_service.path())
	_damage(_service.backup_path())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.UNREADABLE)
	assert_bool(_string_keys().has(loaded.notice_key)).is_true()


func test_no_save_is_missing_not_damaged() -> void:
	assert_int(_service.load_save().status).is_equal(SaveLoad.Status.MISSING)


func test_a_save_after_recovery_keeps_the_good_backup() -> void:
	_service.save(_record(1))
	_service.save(_record(2))
	_damage(_service.path())
	assert_int(_service.load_save().status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	_service.save(_record(3))
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_int(_turn(loaded.data)).is_equal(3)
	DirAccess.remove_absolute(_service.path())
	assert_int(_turn(_service.load_save().data)).is_equal(1)


func test_a_save_that_parses_but_lost_its_shape_falls_back() -> void:
	_service.save(_record(1))
	_service.save(_record(2))
	var file: FileAccess = FileAccess.open(_service.path(), FileAccess.WRITE)
	file.store_string('{"schema_version": 1, "data": {}}')
	file.close()
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_int(_turn(loaded.data)).is_equal(1)
	var broken: Dictionary = _record(3)
	broken["commands"] = [{"type": "play"}]
	assert_bool(RunRecord.is_valid(broken)).is_false()


func test_a_save_left_mid_rename_loads_the_backup() -> void:
	_service.save(_record(1))
	_service.save(_record(2))
	DirAccess.remove_absolute(_service.path())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_int(_turn(loaded.data)).is_equal(1)


func test_an_old_version_is_migrated_one_step_at_a_time() -> void:
	_service.save({"turn": 1})
	var add_field: Callable = func(data: Dictionary) -> Dictionary:
		data["added"] = true
		return data
	var newer: SaveService = SaveService.new(_service.path(), {1: add_field}, 2)
	var loaded: SaveLoad = newer.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_bool(loaded.data["added"]).is_true()
	var unregistered: SaveService = SaveService.new(_service.path(), {}, 3)
	assert_int(unregistered.load_save().status).is_equal(SaveLoad.Status.UNREADABLE)


func test_a_save_from_a_newer_version_is_not_read() -> void:
	SaveService.new(_service.path(), {}, SaveService.SCHEMA_VERSION + 1).save({"turn": 1})
	assert_int(_service.load_save().status).is_equal(SaveLoad.Status.UNREADABLE)


func test_run_and_profile_saves_are_separate_files() -> void:
	var profile: SaveService = SaveService.new(DIR + "profile.json")
	profile.save({"surname": "Wang"})
	_service.save(_record(1))
	_service.save(_record(2))
	_service.delete()
	var loaded: SaveLoad = profile.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_str(str(loaded.data["surname"])).is_equal("Wang")
	assert_str(SaveService.RUN_PATH).is_not_equal(SaveService.PROFILE_PATH)


func test_a_long_run_save_stays_under_64_kb() -> void:
	var state: RunState = RunState.new(SEED)
	for index: int in 16:
		state.roster.append(RosterEntry.new("family_%d" % index))
	for index: int in 8:
		state.inventory.plot.append(
			CardInstance.new(CardInstance.FIRST_PLOT_ID + index, 12, 0, CardInstance.Origin.PLOT)
		)
	for set_number: int in 24:
		var summary: SetSummary = SetSummary.new(set_number)
		for index: int in 16:
			for kind: int in SetSummary.KIND_COUNT:
				summary.add("family_%d" % index, kind as SetSummary.Kind, 999)
		state.summaries.append(summary)
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	for index: int in 60:
		record.add({"type": "play", "cards": [index, index + 1, index + 2, index + 3]})
	_service.save(record.to_dict())
	var size: int = FileAccess.get_file_as_string(_service.path()).length()
	assert_int(size).is_less(MAX_BYTES)


## Plays to the run's end and returns the final state and the last Set's log as text.
## Saves after every player command, which is how a quit mid-round is kept.
func _drive(loop: RunLoop, snapshots: PackedStringArray, waits: Array[int]) -> String:
	var script: RunScript = RunScript.new()
	while loop.awaiting() != RunLoop.Awaiting.RUN_OVER:
		if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
			loop.next_set()
		elif script.act(loop):
			_snapshot(loop, snapshots, waits, loop.awaiting())
		else:
			break
	return JSON.stringify(loop.state.to_dict(), "", true, true)


## wait is what the loop is waiting for when saved, or -1 inside a move.
func _snapshot(loop: RunLoop, snapshots: PackedStringArray, waits: Array[int], wait: int) -> void:
	snapshots.append(_saved_text(loop))
	waits.append(wait)


func _resume(text: String) -> RunLoop:
	var file: FileAccess = FileAccess.open(_service.path(), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	return RunRecord.resume(loaded.data, RunScript.bots(), _one_year())


func _saved_text(loop: RunLoop) -> String:
	_service.save(loop.record.to_dict())
	return FileAccess.get_file_as_string(_service.path())


func _one_year() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.years = 1
	params.targets = params.targets.slice(0, SetConfig.SETS_PER_YEAR)
	return SetConfig.new(params)


func _one_year_loop(state: RunState) -> RunLoop:
	return RunLoop.new(state, RunScript.bots(), _one_year())


func _log_lines(loop: RunLoop) -> PackedStringArray:
	var lines: PackedStringArray = []
	for event: RunEvent in loop.events():
		lines.append(event.describe())
	return lines


## A valid run record whose coupons stand for a turn number.
func _record(turn: int) -> Dictionary:
	var state: RunState = RunState.new(SEED)
	state.coupons = turn
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	return record.to_dict()


func _turn(data: Dictionary) -> int:
	return int(data["checkpoint"]["coupons"])


func _damage(file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string('{"schema_version": 1, "data": {')
	file.close()


func _string_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var file: FileAccess = FileAccess.open(STRINGS, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row.is_empty():
			keys[row[0]] = true
	return keys
