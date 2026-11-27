extends GdUnitTestSuite
## ADR 0022's bait and seal, through the controller as the game runs them, with
## acting turned on for a controller built here and a profile in this suite's folder.
## The ledger is written with every save and removed with it; a changed ledger is taken,
## in play and on continue, and filed once; a missing, unreadable or older ledger is
## nothing. A hand-edited run save or profile still loads and is filed once; a
## development build only logs a broken seal.

static var _dir: String = TestFolder.of("test_bait_and_seal")

var _kit: FileWatchKit = FileWatchKit.new(_dir)


func before_test() -> void:
	_kit.reset()


func after_test() -> void:
	_kit.reset()
	ArtStages.latch_value(0.0)


func _controller(acting: bool) -> RunController:
	return auto_free(_kit.controller(acting))


func _started(acting: bool) -> RunController:
	var controller: RunController = _controller(acting)
	assert_bool(controller.start(FileWatchKit.full(), _kit.saves, _kit.profile)).is_true()
	return controller


func _continued(acting: bool) -> RunController:
	var controller: RunController = _controller(acting)
	assert_bool(controller.continue_saved(_kit.saves, _kit.profile)).is_true()
	return controller


func _ledger() -> String:
	return FileAccess.get_file_as_string(_kit.ledger_path()).strip_edges()


func test_the_ledger_is_written_with_every_save_and_removed_with_it() -> void:
	var controller: RunController = _started(true)
	assert_bool(_kit.one_command(controller)).is_true()
	assert_int(_ledger().to_int()).is_equal(controller.state_copy().coupons)
	assert_str(_kit.ledger_path().get_file()).is_equal(BaitLedger.FILE_NAME)
	_kit.saves.delete()
	assert_bool(FileAccess.file_exists(_kit.ledger_path())).is_false()


func test_a_changed_ledger_is_taken() -> void:
	var controller: RunController = _started(true)
	assert_bool(_kit.one_command(controller)).is_true()
	FileWatchKit.write_text(_kit.ledger_path(), "77\n")
	assert_bool(_kit.one_command(controller)).is_true()
	assert_int(controller.state_copy().coupons).is_equal(77)
	assert_int(_kit.entries().size()).is_equal(1)
	assert_str(_kit.entries()[0].detector).is_equal(FileEntry.BAIT)
	assert_str(_ledger()).is_equal("77")
	# Changed again while the game was closed, it is taken on continue.
	FileWatchKit.write_text(_kit.ledger_path(), "88")
	var again: RunController = _continued(true)
	assert_int(again.state_copy().coupons).is_equal(88)
	assert_int(_kit.entries().size()).is_equal(2)
	# And a second load of that save files nothing more.
	_continued(true)
	assert_int(_kit.entries().size()).is_equal(2)
	assert_array(Array(_kit.lines)).is_empty()


func test_a_development_build_only_logs_a_changed_ledger() -> void:
	var controller: RunController = _started(false)
	assert_bool(_kit.one_command(controller)).is_true()
	var coupons: int = controller.state_copy().coupons
	FileWatchKit.write_text(_kit.ledger_path(), "77")
	assert_bool(_kit.one_command(controller)).is_true()
	assert_int(controller.state_copy().coupons).is_equal(coupons)
	assert_array(_kit.entries()).is_empty()
	assert_int(_kit.lines.size()).is_equal(1)
	assert_bool(_kit.lines[0].begins_with(FileWatch.LOG_LINE)).is_true()


func test_a_missing_or_unreadable_ledger_is_nothing() -> void:
	var controller: RunController = _started(true)
	assert_bool(_kit.one_command(controller)).is_true()
	DirAccess.remove_absolute(_kit.ledger_path())
	assert_bool(_kit.one_command(controller)).is_true()
	assert_bool(FileAccess.file_exists(_kit.ledger_path())).is_true()
	FileWatchKit.write_text(_kit.ledger_path(), "a great many")
	assert_bool(_kit.one_command(controller)).is_true()
	FileWatchKit.write_text(_kit.ledger_path(), "-3")
	_continued(true)
	assert_array(_kit.entries()).is_empty()
	assert_array(Array(_kit.lines)).is_empty()


## A save read from its backup may be older than the ledger, so the ledger is held to
## nothing until the next write.
func test_a_save_restored_from_its_backup_holds_the_ledger_to_nothing() -> void:
	var controller: RunController = _started(true)
	for step: int in 3:
		assert_bool(_kit.one_command(controller)).is_true()
	FileWatchKit.write_text(_kit.saves.path(), "{broken")
	FileWatchKit.write_text(_kit.ledger_path(), "5")
	_continued(true)
	assert_array(_kit.entries()).is_empty()
	assert_array(Array(_kit.lines)).is_empty()


## A crash between the save and the ledger leaves the ledger one write behind: the save
## keeps the number the ledger held before, so that is no offence.
func test_a_ledger_one_write_behind_is_no_offence() -> void:
	var controller: RunController = _started(true)
	assert_bool(_kit.one_command(controller)).is_true()
	var was: String = _ledger()
	FileWatchKit.loop_of(controller).state.coupons += 9
	controller.reseal_book()
	assert_bool(_kit.one_command(controller)).is_true()
	assert_str(_ledger()).is_not_equal(was)
	FileWatchKit.write_text(_kit.ledger_path(), was)
	_continued(true)
	assert_array(_kit.entries()).is_empty()
	assert_array(Array(_kit.lines)).is_empty()


func test_a_hand_edited_run_save_loads_and_is_filed_once() -> void:
	var controller: RunController = _started(true)
	assert_bool(_kit.one_command(controller)).is_true()
	FileWatchKit.edit(
		_kit.saves.path(),
		func(save: Dictionary) -> void: save["data"]["checkpoint"]["seatless_sets"] = 2
	)
	var again: RunController = _continued(true)
	assert_int(again.state_copy().seatless_sets).is_equal(2)
	var entries: Array[FileEntry] = _kit.entries()
	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0].detector).is_equal(FileEntry.SEAL)
	assert_array(entries[0].figures.keys()).is_empty()
	assert_int(FileWatchKit.corrections(again)).is_equal(1)
	# Its next write seals it again, so the next load is quiet.
	assert_bool(_kit.one_command(again)).is_true()
	_continued(true)
	assert_int(_kit.entries().size()).is_equal(1)
	assert_array(Array(_kit.lines)).is_empty()


func test_a_hand_edited_profile_is_filed_when_a_run_starts() -> void:
	var data: ProfileData = ProfileData.new()
	data.surname = "Wang"
	Profile.write(_kit.profile, data)
	FileWatchKit.edit(_kit.profile.path(), func(save: Dictionary) -> void: save["data"]["wins"] = 3)
	var controller: RunController = _started(true)
	var entries: Array[FileEntry] = _kit.entries()
	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0].detector).is_equal(FileEntry.SEAL)
	assert_int(Profile.read(_kit.profile).wins).is_equal(3)
	assert_int(FileWatchKit.corrections(controller)).is_equal(1)
	assert_bool(_kit.one_command(controller)).is_true()
	assert_int(_kit.entries().size()).is_equal(1)
	assert_array(Array(_kit.lines)).is_empty()


func test_a_development_build_logs_a_broken_seal_and_files_nothing() -> void:
	var controller: RunController = _started(false)
	assert_bool(_kit.one_command(controller)).is_true()
	FileWatchKit.edit(
		_kit.saves.path(), func(save: Dictionary) -> void: save.erase(SaveService.SEAL_KEY)
	)
	_continued(false)
	assert_array(_kit.entries()).is_empty()
	assert_int(_kit.lines.size()).is_equal(1)
	assert_bool(_kit.lines[0].begins_with(FileWatch.LOG_LINE)).is_true()
