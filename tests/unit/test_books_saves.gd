extends GdUnitTestSuite
## ADR 0022's books across saves (P4.19): a run with corrections replays to the same
## state, the dark flags survive a save and a reload, the family's file raises every
## target, a run with neither computes as before, the saved shapes validate strictly,
## and a schema 16 record migrates with empty books.

const SEED: int = 4719
const BOOKS: BooksParams = preload("res://data/run/books.tres")


func _loop(coupons: int = 10) -> RunLoop:
	var state: RunState = RunState.new(SEED)
	state.coupons = coupons
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


func _at_set_over() -> RunLoop:
	var loop: RunLoop = _loop()
	RunScript.new().play_until_set_over(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	return loop


func _json(loop: RunLoop) -> Dictionary:
	return JSON.parse_string(JSON.stringify(loop.record.to_dict(), "", true, true))


func test_a_run_with_corrections_replays_to_the_same_state() -> void:
	var loop: RunLoop = _loop(10)
	var script: RunScript = RunScript.new()
	for step: int in 6:
		script.act(loop)
	loop.player_books({"coupons": 30, "famine": 0, "progress": loop.target() / 3.0})
	for step: int in 4:
		script.act(loop)
	loop.player_books({"famine": 12})
	loop.player_books({"famine": 2, "norm": 3})
	var resumed: RunLoop = RunRecord.resume(_json(loop), RunScript.bots())
	assert_object(resumed).is_not_null()
	assert_str(JSON.stringify(resumed.state.to_dict())).is_equal(
		JSON.stringify(loop.state.to_dict())
	)


func test_dark_flags_survive_a_save_and_a_reload() -> void:
	var service: SaveService = SaveService.for_run(TestFolder.of("test_run_books") + "run.json")
	service.delete()
	var loop: RunLoop = _at_set_over()
	var famine: int = loop.state.famine + 20
	loop.player_books({"famine": famine})
	loop.player_books({"famine": 0, "coupons": loop.state.coupons + 5})
	assert_int(service.save(loop.record.to_dict())).is_equal(OK)
	var loaded: SaveLoad = service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var resumed: RunLoop = RunRecord.resume(loaded.data, RunScript.bots())
	assert_array(resumed.state.books.dark).contains_exactly(["famine"])
	assert_int(resumed.state.books.price_percent).is_equal(loop.state.books.price_percent)
	assert_int(resumed.state.famine).is_equal(famine)
	service.delete()


func test_the_file_raises_every_target_ten_percent_an_entry_up_to_double() -> void:
	assert_int(RunBooks.file_percent(0)).is_equal(0)
	assert_int(RunBooks.file_percent(1)).is_equal(BOOKS.entry_percent)
	assert_int(RunBooks.file_percent(3)).is_equal(30)
	assert_int(RunBooks.file_percent(10)).is_equal(BOOKS.entry_cap_percent)
	assert_int(RunBooks.file_percent(40)).is_equal(BOOKS.entry_cap_percent)
	var plain: RunLoop = _loop()
	for entries: int in [3, 15]:
		var state: RunState = RunState.new(SEED)
		state.identity.file_entries = entries
		var filed: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
		filed.start_set()
		var raise: float = 1.0 + RunBooks.file_percent(entries) / 100.0
		assert_float(filed.target()).is_equal_approx(plain.target() * raise, 0.001)


func test_no_file_and_no_correction_leave_every_target_as_it_was() -> void:
	var state: RunState = RunState.new(SEED)
	assert_float(RunBooks.raised_target(1875.0, state)).is_equal(1875.0)
	assert_int(RunBooks.priced(state, 7)).is_equal(7)


func test_the_books_validate_strictly() -> void:
	assert_bool(RunBooks.is_valid(RunBooks.new().to_dict())).is_true()
	for bad: Variant in [
		[],
		{
			"dark": ["grain"],
			"norm_percent": 0,
			"norm_in_force": 0,
			"price_percent": 0,
			"corrections": 0
		},
		{
			"dark": ["famine", "famine"],
			"norm_percent": 0,
			"norm_in_force": 0,
			"price_percent": 0,
			"corrections": 0
		},
		{"dark": [], "norm_percent": 5, "norm_in_force": 9, "price_percent": 0, "corrections": 0},
		{"dark": [], "norm_percent": 0, "norm_in_force": 0, "price_percent": -1, "corrections": 0},
		{"dark": [], "norm_percent": 0, "norm_in_force": 0, "price_percent": 0},
	]:
		assert_bool(RunBooks.is_valid(bad)).override_failure_message(str(bad)).is_false()


func test_a_record_with_a_malformed_books_command_is_damaged() -> void:
	var loop: RunLoop = _loop(10)
	loop.player_books({"coupons": 12})
	var data: Dictionary = _json(loop)
	assert_bool(RunRecordCheck.is_valid(data)).is_true()
	var commands: Array = data["commands"]
	var last: Dictionary = commands[-1]
	last["figures"] = {"coupons": "twelve"}
	assert_bool(RunRecordCheck.is_valid(data)).is_false()
	last.erase("figures")
	assert_bool(RunRecordCheck.is_valid(data)).is_false()


func test_a_schema_16_record_migrates_with_empty_books() -> void:
	var data: Dictionary = _json(_loop(10))
	var checkpoint: Dictionary = data["checkpoint"]
	var identity: Dictionary = checkpoint["identity"]
	checkpoint.erase("books")
	identity.erase("file_entries")
	assert_bool(RunRecordCheck.is_valid(data)).is_false()
	var migrated: Dictionary = RunRecordMigrations.migrate_from_16(data)
	assert_bool(RunRecordCheck.is_valid(migrated)).is_true()
	var state: RunState = RunState.from_dict(migrated["checkpoint"])
	assert_array(state.books.dark).is_empty()
	assert_int(state.books.norm_percent).is_equal(0)
	assert_int(state.identity.file_entries).is_equal(0)
