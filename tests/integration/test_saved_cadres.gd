extends GdUnitTestSuite
## Schema 7 (ADR 0021): each Cadre's own run state. A schema 6 save gains it empty, it
## survives a save and a load, and a damaged shape counts as damage, as in
## test_saved_growth.gd.

const DIR: String = "user://test_saved_cadres/"
const SEED: int = 3701

var _service: SaveService


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_service = SaveService.for_run(DIR + "run.json")
	_service.delete()


func after_test() -> void:
	_service.delete()


func _record(turn: int) -> Dictionary:
	var state: RunState = RunState.new(SEED)
	state.coupons = turn
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	return record.to_dict()


func test_a_schema_6_save_gains_empty_cadre_state_and_the_state_is_saved() -> void:
	assert_int(SaveService.SCHEMA_VERSION).is_greater_equal(7)
	var data: Dictionary = _record(9)
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("cadre_memos")
	assert_bool(RunRecordCheck.is_valid(data)).is_false()
	var file: FileAccess = FileAccess.open(_service.path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 6, "data": data}))
	file.close()
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_int(int(loaded.data["checkpoint"]["coupons"])).is_equal(9)
	var migrated: RunState = RunState.from_dict(loaded.data["checkpoint"])
	assert_array(migrated.cadre_memos.ids()).is_empty()
	var state: RunState = RunState.new(SEED)
	state.inventory.cadres.assign(["rehabilitation", "stakhanovite", "ration_coupon"])
	state.cadre_memos.entry("rehabilitation").put(CadreMemo.RANK, Ranks.JACK)
	state.cadre_memos.entry("rehabilitation").put(CadreMemo.YEARS, 2)
	state.cadre_memos.entry("stakhanovite").put(StakhanoviteEffect.LONG_STRAIGHTS, 3)
	state.cadre_memos.entry("ration_coupon").put(RationCouponEffect.EARNED, 1)
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	_service.save(record.to_dict())
	var saved: RunState = RunState.from_dict(_service.load_save().data["checkpoint"])
	var rehabilitation: CadreMemo = saved.cadre_memos.peek("rehabilitation")
	assert_int(rehabilitation.value(CadreMemo.RANK)).is_equal(Ranks.JACK)
	assert_int(rehabilitation.value(CadreMemo.YEARS)).is_equal(2)
	var growth: int = saved.cadre_memos.peek("stakhanovite").value(
		StakhanoviteEffect.LONG_STRAIGHTS
	)
	assert_int(growth).is_equal(3)
	var earned: int = saved.cadre_memos.peek("ration_coupon").value(RationCouponEffect.EARNED)
	assert_int(earned).is_equal(1)


func test_damaged_cadre_state_fails_validation() -> void:
	var wrong: Array[Dictionary] = [
		{"cadre_memos": []},
		{"cadre_memos": {"seed_grain": []}},
		{"cadre_memos": {"seed_grain": {"met": "two"}}},
	]
	for change: Dictionary in wrong:
		var data: Dictionary = _record(2)
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge(change, true)
		assert_bool(RunRecordCheck.is_valid(data)).override_failure_message(str(change)).is_false()
	var fine: Dictionary = _record(2)
	var fine_checkpoint: Dictionary = fine["checkpoint"]
	fine_checkpoint["cadre_memos"] = {"seed_grain": {"met": 2.0}}
	assert_bool(RunRecordCheck.is_valid(fine)).is_true()
