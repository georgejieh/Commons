extends GdUnitTestSuite
## ADR 0022's seal on the save (P4.19): what a save service writes always verifies when it
## is read back, the run save and the profile both, through the backup path too, over
## real saves taken all through a run and over values JSON does not round-trip. A file
## from before the seal is no offence; a hand edit, a missing seal or a changed extra
## still loads and is noticed; a file only reformatted still verifies; a write that reads
## back changed fails.

const DIR: String = "user://test_save_seal/"
const RUN_PATH: String = DIR + "run.json"
const PROFILE_PATH: String = DIR + "profile.json"
const SEED: int = 6113


## A disk that hands back other bytes than were written to it.
class ChangingDisk:
	extends SaveService

	func _store(file_path: String, text: String) -> Error:
		return super(file_path, text.replace("7", "8"))


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


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _edit(path: String, change: Callable) -> void:
	var save: Dictionary = JSON.parse_string(_text(path))
	change.call(save)
	_write_text(path, JSON.stringify(save, "", true, true))


func _assert_sealed(service: SaveService, what: String) -> void:
	var loaded: SaveLoad = service.load_save()
	assert_int(loaded.status).override_failure_message(what).is_equal(SaveLoad.Status.OK)
	assert_bool(loaded.tampered).override_failure_message(what).is_false()
	assert_str(service.take_tampered()).override_failure_message(what).is_empty()


func test_every_run_save_of_a_run_verifies_after_a_write_and_a_read() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	loop.start_set()
	var script: RunScript = RunScript.new()
	var saves: int = 0
	for set_played: int in 2:
		while script.act(loop):
			assert_int(_saves.save(loop.record.to_dict(), {"ledger": saves})).is_equal(OK)
			_assert_sealed(_saves, "save %d" % saves)
			saves += 1
		if loop.awaiting() != RunLoop.Awaiting.SET_OVER:
			break
		loop.open_shop()
		_saves.save(loop.record.to_dict())
		_assert_sealed(_saves, "shop")
		loop.next_set()
	assert_int(saves).is_greater(10)


func test_values_json_does_not_round_trip_still_verify() -> void:
	var generic: SaveService = SaveService.new(DIR + "values.json")
	var data: Dictionary = {
		"sum": 0.1 + 0.2,
		"tiny": 1e-300,
		"third": 1.0 / 3.0,
		"long": 123456789.123456789,
		"negative_zero": -0.0,
		"past_doubles": 9007199254740993,
		"large": 1e300,
		"text": 'Wáng "quoted" \\ \n tab\t 中文',
		"nested": [[1, 2.5, [true, false, null]], {"b": 1, "a": {"z": [], "y": {}}}],
		"empty": "",
	}
	for round_trip: int in 3:
		assert_int(generic.save(data, {"ledger": round_trip})).is_equal(OK)
		_assert_sealed(generic, "values %d" % round_trip)
	generic.delete()


## The bytes on disk are not the bytes written: the write fails, and the save it would
## have replaced is still the one that loads, with its seal whole.
func test_a_file_that_reads_back_changed_is_a_failed_write() -> void:
	var path: String = DIR + "changed.json"
	var kept: SaveService = SaveService.new(path)
	assert_int(kept.save({"turn": 1})).is_equal(OK)
	assert_int(ChangingDisk.new(path).save({"turn": 7})).is_equal(ERR_FILE_CORRUPT)
	var loaded: SaveLoad = kept.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_int(int(loaded.data["turn"])).is_equal(1)
	assert_bool(loaded.tampered).is_false()
	kept.delete()


func test_the_backup_verifies_on_its_own() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	loop.start_set()
	_saves.save(loop.record.to_dict())
	RunScript.new().act(loop)
	_saves.save(loop.record.to_dict())
	_write_text(RUN_PATH, "{broken")
	var loaded: SaveLoad = _saves.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_bool(loaded.tampered).is_false()


func test_a_save_from_before_the_seal_is_no_offence() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	loop.start_set()
	var data: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("books")
	_write_text(RUN_PATH, JSON.stringify({"schema_version": 16, "data": data}))
	var loaded: SaveLoad = _saves.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_bool(loaded.tampered).is_false()
	assert_str(_saves.take_tampered()).is_empty()
	# Its next write seals it.
	_saves.save(loaded.data)
	var written: Dictionary = JSON.parse_string(_text(RUN_PATH))
	assert_bool(written.has(SaveService.SEAL_KEY)).is_true()
	_assert_sealed(_saves, "sealed on its next write")


func test_a_hand_edited_save_still_loads_and_is_noticed() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	loop.start_set()
	_saves.save(loop.record.to_dict())
	_edit(RUN_PATH, func(save: Dictionary) -> void: save["data"]["checkpoint"]["coupons"] = 99)
	var loaded: SaveLoad = _saves.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_int(int(loaded.data["checkpoint"]["coupons"])).is_equal(99)
	assert_bool(loaded.tampered).is_true()
	assert_str(loaded.seal).is_not_empty()
	assert_str(_saves.take_tampered()).is_equal(loaded.seal)
	assert_str(_saves.take_tampered()).is_empty()


func test_a_missing_or_malformed_seal_is_noticed() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	loop.start_set()
	for change: Callable in [
		func(save: Dictionary) -> void: save.erase(SaveService.SEAL_KEY),
		func(save: Dictionary) -> void: save[SaveService.SEAL_KEY] = "abc",
		func(save: Dictionary) -> void: save[SaveService.SEAL_KEY] = 7,
	]:
		_saves.save(loop.record.to_dict())
		_edit(RUN_PATH, change)
		var loaded: SaveLoad = _saves.load_save()
		assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
		assert_bool(loaded.tampered).is_true()


func test_a_changed_extra_is_noticed() -> void:
	_profile.save(ProfileData.new().to_dict(), {"ledger": 4})
	_edit(PROFILE_PATH, func(save: Dictionary) -> void: save[SaveService.EXTRA_KEY]["ledger"] = 40)
	var loaded: SaveLoad = _profile.load_save()
	assert_bool(loaded.tampered).is_true()
	assert_int(int(loaded.extras["ledger"])).is_equal(40)


func test_a_reformatted_save_still_verifies() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	loop.start_set()
	_saves.save(loop.record.to_dict())
	# Whitespace between tokens only, as an editor saving with its own line endings adds.
	var text: String = _text(RUN_PATH)
	_write_text(RUN_PATH, "\r\n{\r\n\t" + text.substr(1) + "\r\n")
	_assert_sealed(_saves, "reformatted")


func test_the_profile_is_sealed_and_an_old_one_is_no_offence() -> void:
	var data: ProfileData = ProfileData.new()
	data.corruption = 0.1 + 0.2
	data.surname = "Wáng"
	assert_int(Profile.write(_profile, data)).is_equal(OK)
	_assert_sealed(_profile, "profile")
	Profile.write(_profile, data)
	_write_text(PROFILE_PATH, "{broken")
	var restored: SaveLoad = _profile.load_save()
	assert_int(restored.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_bool(restored.tampered).is_false()
	_profile.delete()
	var old: Dictionary = ProfileData.new().to_dict()
	old.erase(Profile.FILE_KEY)
	_write_text(PROFILE_PATH, JSON.stringify({"schema_version": 3, "data": old}))
	var loaded: SaveLoad = _profile.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	assert_bool(loaded.tampered).is_false()
	assert_array(Profile.read(_profile).file).is_empty()
	assert_str(_profile.take_tampered()).is_empty()


func test_a_hand_edited_profile_still_loads_and_is_noticed() -> void:
	Profile.write(_profile, ProfileData.new())
	_edit(PROFILE_PATH, func(save: Dictionary) -> void: save["data"]["wins"] = 9)
	assert_int(Profile.read(_profile).wins).is_equal(9)
	assert_str(_profile.take_tampered()).is_not_empty()


func test_the_canonical_form_ignores_key_order_and_number_kind() -> void:
	var one: String = SaveSeal.of(17, {"a": 1, "b": [2.0, "x"]}, {})
	var two: String = SaveSeal.of(17, {"b": [2, "x"], "a": 1.0}, {})
	assert_str(one).is_equal(two)
	assert_str(SaveSeal.of(17, {"a": 1}, {})).is_not_equal(SaveSeal.of(17, {"a": 2}, {}))
	assert_str(SaveSeal.of(17, {"a": 1}, {})).is_not_equal(SaveSeal.of(16, {"a": 1}, {}))
	assert_bool(SaveSeal.is_shaped(one)).is_true()
