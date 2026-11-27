extends GdUnitTestSuite
## ADR 0022's second book, through the controller as the game runs it, with acting
## turned on for a controller built here and a profile in this suite's folder. A figure
## changed while nobody acted is put back and taken as official through the books
## command, and filed once; a development build and a run outside the profile only log;
## a tool that says so may change the figures; and the book stays quiet over old saves
## migrated and played on, a full Year continued at every stopping point, and whole
## seeded runs.

static var _dir: String = TestFolder.of("test_second_book")

var _kit: FileWatchKit = FileWatchKit.new(_dir)


func before_test() -> void:
	_kit.reset()


func after_test() -> void:
	_kit.reset()
	ArtStages.latch_value(0.0)


func _controller(acting: bool) -> RunController:
	return auto_free(_kit.controller(acting))


## A full run unless a request names another.
func _started(acting: bool, request: RunRequest = null) -> RunController:
	var controller: RunController = _controller(acting)
	var asked: RunRequest = FileWatchKit.full() if request == null else request
	assert_bool(controller.start(asked, _kit.saves, _kit.profile)).is_true()
	return controller


func _continued(acting: bool) -> RunController:
	var controller: RunController = _controller(acting)
	assert_bool(controller.continue_saved(_kit.saves, _kit.profile)).is_true()
	return controller


func test_a_changed_figure_is_put_back_and_taken_as_official() -> void:
	var controller: RunController = _started(true)
	var corruption: float = Profile.read(_kit.profile).corruption
	var loop: RunLoop = FileWatchKit.loop_of(controller)
	var true_coupons: int = loop.state.coupons
	loop.state.coupons = true_coupons + 40
	assert_bool(_kit.one_command(controller)).is_true()
	var state: RunState = controller.state_copy()
	assert_int(state.coupons).is_equal(true_coupons + 40)
	assert_int(state.books.corrections).is_equal(1)
	var ratio: float = float(true_coupons + 40) / maxi(true_coupons, 1)
	var cap: int = RunBooks.DEFAULT_PARAMS.norm_cap_percent
	assert_int(state.books.norm_percent).is_equal(RunBooks.compound(0, ratio, cap))
	assert_int(state.books.price_percent).is_equal(state.books.norm_percent)
	assert_bool(FileWatchKit.has_books_command(controller)).is_true()
	assert_int(FileWatchKit.corrections(controller)).is_equal(1)
	var entries: Array[FileEntry] = _kit.entries()
	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0].detector).is_equal(FileEntry.BOOK)
	assert_str(entries[0].run_id).is_equal(state.identity.id)
	assert_float(entries[0].figures["coupons"]).is_equal(float(true_coupons + 40))
	var now: float = Profile.read(_kit.profile).corruption
	assert_float(now).is_equal(ProfileFile.corrupted(corruption))
	assert_int(controller.file_watch.notices.size()).is_equal(1)
	# A reload replays the books command and files nothing more.
	var shown: String = FileWatchKit.state_text(controller)
	var again: RunController = _continued(true)
	assert_str(FileWatchKit.state_text(again)).is_equal(shown)
	assert_bool(_kit.one_command(again)).is_true()
	assert_int(_kit.entries().size()).is_equal(1)
	assert_array(Array(_kit.lines)).is_empty()


func test_a_lowered_meter_goes_dark_and_its_true_value_returns() -> void:
	var controller: RunController = _started(true)
	var loop: RunLoop = FileWatchKit.loop_of(controller)
	assert_int(controller.books({"famine": 25})).is_equal(RunController.OK)
	var famine: int = loop.state.famine
	loop.state.famine = 0
	assert_bool(_kit.one_command(controller)).is_true()
	var state: RunState = controller.state_copy()
	assert_int(state.famine).is_equal(famine)
	assert_array(state.books.dark).contains_exactly(["famine"])
	assert_int(_kit.entries().size()).is_equal(1)
	assert_array(Array(_kit.lines)).is_empty()


func test_a_development_build_only_logs() -> void:
	var controller: RunController = _started(false)
	var corruption: float = Profile.read(_kit.profile).corruption
	var loop: RunLoop = FileWatchKit.loop_of(controller)
	var cheated: int = loop.state.coupons + 40
	loop.state.coupons = cheated
	assert_bool(_kit.one_command(controller)).is_true()
	var state: RunState = controller.state_copy()
	assert_int(state.coupons).is_equal(cheated)
	assert_int(state.books.corrections).is_equal(0)
	assert_int(state.books.norm_percent).is_equal(0)
	assert_bool(FileWatchKit.has_books_command(controller)).is_false()
	assert_int(FileWatchKit.corrections(controller)).is_equal(0)
	assert_array(_kit.entries()).is_empty()
	assert_float(Profile.read(_kit.profile).corruption).is_equal(corruption)
	assert_int(_kit.lines.size()).is_equal(1)
	assert_bool(_kit.lines[0].begins_with(FileWatch.LOG_LINE)).is_true()
	# The book took the figures as they were, so the next command is quiet.
	assert_bool(_kit.one_command(controller)).is_true()
	assert_int(_kit.lines.size()).is_equal(1)


func test_a_run_outside_the_profile_only_logs() -> void:
	var controller: RunController = _controller(true)
	controller.start_run(FileWatchKit.SEED, RunScript.bots(), SetConfig.new(), _kit.saves)
	FileWatchKit.loop_of(controller).state.coupons += 30
	assert_bool(_kit.one_command(controller)).is_true()
	assert_int(controller.state_copy().books.corrections).is_equal(0)
	assert_int(_kit.lines.size()).is_equal(1)


func test_a_change_a_tool_declares_or_makes_through_the_loop_is_no_offence() -> void:
	var controller: RunController = _started(true)
	FileWatchKit.loop_of(controller).state.coupons += 30
	controller.reseal_book()
	assert_bool(_kit.one_command(controller)).is_true()
	# A loop driven past the controller moved its record, so the book is sealed again,
	# not compared.
	var loop: RunLoop = FileWatchKit.loop_of(controller)
	assert_int(loop.player_books({"coupons": 99})).is_equal(RunLoop.Reason.OK)
	assert_bool(_kit.one_command(controller)).is_true()
	assert_int(controller.state_copy().coupons).is_equal(99)
	assert_array(_kit.entries()).is_empty()
	assert_array(Array(_kit.lines)).is_empty()


## A run save and a profile from before the file, loaded, played on and saved: every
## detector stays quiet, and the next write seals both.
func test_old_saves_load_play_on_and_save_quietly() -> void:
	var controller: RunController = _started(true)
	for step: int in 8:
		assert_bool(_kit.one_command(controller)).is_true()
	var record: Dictionary = FileWatchKit.loop_of(controller).record.to_dict()
	var checkpoint: Dictionary = record["checkpoint"]
	var identity: Dictionary = checkpoint["identity"]
	checkpoint.erase("books")
	identity.erase("file_entries")
	_kit.saves.delete()
	var old: String = JSON.stringify({"schema_version": 16, "data": record}, "", true, true)
	FileWatchKit.write_text(_kit.saves.path(), old)
	var profile: Dictionary = Profile.read(_kit.profile).to_dict()
	profile.erase(Profile.FILE_KEY)
	_kit.profile.delete()
	var old_profile: String = JSON.stringify({"schema_version": 3, "data": profile})
	FileWatchKit.write_text(_kit.profile.path(), old_profile)
	for reload: int in 3:
		var again: RunController = _continued(true)
		for step: int in 10:
			if not _kit.one_command(again):
				break
	# The profile is written when a Quota ends, so the last stretch plays past one.
	var last: RunController = _continued(true)
	var quota: int = last.state_copy().set_index
	var commands: int = 0
	while last.state_copy().set_index == quota and commands < FileWatchKit.MAX_COMMANDS:
		if not _kit.one_command(last):
			break
		commands += 1
	assert_array(_kit.entries()).is_empty()
	assert_array(Array(_kit.lines)).is_empty()
	for path: String in [_kit.saves.path(), _kit.profile.path()]:
		var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_bool(written.has(SaveService.SEAL_KEY)).override_failure_message(path).is_true()


## A full run through its first Year with acting on, continued from the save the first
## time each kind of stopping point is met and every few commands besides: nothing is
## ever filed or logged.
func test_a_full_year_continued_at_every_stopping_point_is_quiet() -> void:
	var controller: RunController = _started(true)
	var seen: Dictionary[int, bool] = {}
	var commands: int = 0
	while commands < FileWatchKit.MAX_COMMANDS and controller.state_copy().year == 1:
		var awaiting: int = controller.awaiting()
		if not seen.has(awaiting) or commands % FileWatchKit.CONTINUE_EVERY == 0:
			seen[awaiting] = true
			controller = _continued(true)
		if not _kit.one_command(controller):
			break
		commands += 1
	assert_int(commands).is_greater(20)
	assert_bool(seen.has(RunController.AWAIT_STORE)).is_true()
	assert_array(_kit.entries()).is_empty()
	assert_array(Array(_kit.lines)).is_empty()


## Whole demo runs to their end through the controller, shops and reeducation as they
## come, with saves, each continued the first time each kind of stopping point is met.
func test_whole_seeded_runs_through_the_controller_are_quiet() -> void:
	for seed_value: int in [11, 2027, 90031]:
		_kit.saves.delete()
		var request: RunRequest = RunRequest.new(
			RunRequest.DEMO, seed_value, FileWatchKit.START_TIME
		)
		var controller: RunController = _started(true, request)
		var seen: Dictionary[int, bool] = {}
		var commands: int = 0
		while commands < FileWatchKit.MAX_COMMANDS:
			var awaiting: int = controller.awaiting()
			if not seen.has(awaiting):
				seen[awaiting] = true
				controller = _continued(true)
			if not _kit.one_command(controller):
				break
			commands += 1
		assert_int(controller.awaiting()).override_failure_message(str(seed_value)).is_equal(
			RunController.AWAIT_RUN_OVER
		)
	assert_array(_kit.entries()).is_empty()
	assert_array(Array(_kit.lines)).is_empty()
