extends GdUnitTestSuite
## Saves survive a kill at every state boundary and mid-round, fall back to the backup
## when damaged, migrate old versions, and stay small.

const DIR: String = "user://test_saves/"
const SEED: int = 3601
## A small and a large Set, so the move between Sets is covered too.
const SETS: int = 2
const MAX_BYTES: int = 64 * 1024
const STRINGS: String = "res://data/strings/strings.csv"

var _service: SaveService


func before_test() -> void:
	_service = SaveService.new(DIR + "run.json")
	_service.delete()


func after_test() -> void:
	_service.delete()
	SaveService.new(DIR + "profile.json").delete()


func test_a_kill_at_any_boundary_or_command_continues_exactly() -> void:
	var snapshots: PackedStringArray = []
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots())
	loop.on_boundary = func() -> void: snapshots.append(_saved_text(loop))
	snapshots.append(_saved_text(loop))
	loop.start_set()
	var expected: String = _drive(loop, snapshots)
	assert_int(snapshots.size()).is_greater(20)
	var mismatches: int = 0
	var largest: int = 0
	for text: String in snapshots:
		largest = maxi(largest, text.length())
		var file: FileAccess = FileAccess.open(_service.path(), FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var loaded: SaveLoad = _service.load_save()
		assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
		var resumed: RunLoop = RunRecord.resume(loaded.data, RunScript.bots())
		if _drive(resumed, PackedStringArray()) != expected:
			mismatches += 1
	assert_int(mismatches).is_equal(0)
	assert_int(largest).is_less(MAX_BYTES)


func test_a_damaged_save_falls_back_to_the_backup_with_a_notice() -> void:
	_service.save({"turn": 1})
	_service.save({"turn": 2})
	_damage(_service.path())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_int(int(loaded.data["turn"])).is_equal(1)
	assert_str(loaded.notice_key).is_equal(SaveService.RESTORED_KEY)
	assert_bool(_string_keys().has(loaded.notice_key)).is_true()


func test_two_damaged_saves_are_unreadable_with_a_notice() -> void:
	_service.save({"turn": 1})
	_service.save({"turn": 2})
	_damage(_service.path())
	_damage(_service.backup_path())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.UNREADABLE)
	assert_bool(_string_keys().has(loaded.notice_key)).is_true()


func test_no_save_is_missing_not_damaged() -> void:
	assert_int(_service.load_save().status).is_equal(SaveLoad.Status.MISSING)


func test_a_save_left_mid_rename_loads_the_backup() -> void:
	_service.save({"turn": 1})
	_service.save({"turn": 2})
	DirAccess.remove_absolute(_service.path())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_int(int(loaded.data["turn"])).is_equal(1)


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
	_service.save({"turn": 1})
	_service.save({"turn": 2})
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


## Plays to the end of the last Set and returns the final state as text. Saves after
## every player command, which is how a quit mid-round is kept.
func _drive(loop: RunLoop, snapshots: PackedStringArray) -> String:
	var script: RunScript = RunScript.new()
	while true:
		if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
			if loop.set_number() >= SETS - 1:
				break
			loop.next_set()
		elif script.act(loop):
			snapshots.append(_saved_text(loop))
		else:
			break
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	return JSON.stringify(loop.state.to_dict(), "", true, true)


func _saved_text(loop: RunLoop) -> String:
	_service.save(loop.record.to_dict())
	return FileAccess.get_file_as_string(_service.path())


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
