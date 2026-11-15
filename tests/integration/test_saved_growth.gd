extends GdUnitTestSuite
## Schema 6 (P4.11): a run's saved card marks and hand levels. A schema 5 save gains
## them at their starting values, both survive a save and a load, and a damaged shape
## counts as damage, as in test_saves.gd.

const DIR: String = "user://test_saved_growth/"
const SEED: int = 3601

var _service: SaveService


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_service = SaveService.for_run(DIR + "run.json")
	_service.delete()


func after_test() -> void:
	_service.delete()


## A valid run record whose coupons stand for a turn number.
func _record(turn: int) -> Dictionary:
	var state: RunState = RunState.new(SEED)
	state.coupons = turn
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	return record.to_dict()


func _turn(data: Dictionary) -> int:
	return int(data["checkpoint"]["coupons"])


## A schema 5 run save, from before saved marks and hand levels (P4.11), loads with no
## card marked and every hand type at its first level, and both survive a save and a load.
func test_a_schema_5_run_save_gains_marks_and_levels_and_both_are_saved() -> void:
	var data: Dictionary = _record(7)
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("hand_levels")
	checkpoint.erase("card_marks")
	assert_bool(RunRecord.is_valid(data)).is_false()
	var file: FileAccess = FileAccess.open(_service.path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 5, "data": data}))
	file.close()
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_int(_turn(loaded.data)).is_equal(7)
	var migrated: RunState = RunState.from_dict(loaded.data["checkpoint"])
	assert_bool(migrated.card_marks.stamps.is_empty()).is_true()
	assert_bool(migrated.card_marks.enhancements.is_empty()).is_true()
	for level: int in migrated.hand_levels.to_array():
		assert_int(level).is_equal(HandLevels.FIRST_LEVEL)
	var state: RunState = RunState.new(SEED)
	state.hand_levels.raise(Pattern.Type.PAIR)
	state.hand_levels.raise(Pattern.Type.BOMB)
	state.hand_levels.raise(Pattern.Type.BOMB)
	CardMarks.stamp(state, CardInstance.from_deck_id(12), 0)
	CardMarks.make_model(state, CardInstance.from_deck_id(40))
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	_service.save(record.to_dict())
	var saved: RunState = RunState.from_dict(_service.load_save().data["checkpoint"])
	assert_int(saved.hand_levels.level_of(Pattern.Type.PAIR)).is_equal(2)
	assert_int(saved.hand_levels.level_of(Pattern.Type.BOMB)).is_equal(3)
	assert_int(saved.hand_levels.level_of(Pattern.Type.SINGLE)).is_equal(1)
	assert_dict(saved.card_marks.stamps).is_equal({12: 0})
	assert_dict(saved.card_marks.enhancements).is_equal({40: CardInstance.MODEL})
	assert_int(SaveService.SCHEMA_VERSION).is_equal(6)


## Marks and levels of the wrong shape are damage, as any other field of the wrong kind.
func test_damaged_marks_or_levels_fail_validation() -> void:
	var wrong: Array[Dictionary] = [
		{"hand_levels": {}},
		{"hand_levels": [1, 1, 1]},
		{"hand_levels": ["a", 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]},
		{"card_marks": []},
		{"card_marks": {"stamps": {}}},
		{"card_marks": {"stamps": {"x": 0}, "enhancements": {}}},
		{"card_marks": {"stamps": {}, "enhancements": {"4": 2}}},
	]
	for change: Dictionary in wrong:
		var data: Dictionary = _record(2)
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge(change, true)
		assert_bool(RunRecord.is_valid(data)).override_failure_message(str(change)).is_false()
	assert_bool(RunRecord.is_valid(_record(2))).is_true()
