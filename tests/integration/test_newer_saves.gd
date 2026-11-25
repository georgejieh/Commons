extends GdUnitTestSuite
## ADR 0037's amendment of 2026-11-25: a save a newer build wrote is never deleted or
## written over by this one. Before this build first writes over or deletes its path, it
## is moved aside beside it, one aside a path, the latest, and the move is logged; a write
## whose move fails is refused and the newer file stays. A load reports it as from a newer
## version, never as damaged. It holds for the run save and the profile.

const DIR: String = "user://test_newer_saves/"
const PATH: String = DIR + "save.json"
const OLDER: int = 5
const NEWER: int = 6
const STRINGS: String = "res://data/strings/strings.csv"


class Lines:
	extends Logger
	var said: Array[String] = []

	func _log_message(message: String, _error: bool) -> void:
		if message.begins_with(GameLog.PREFIX):
			said.append(message.strip_edges())


var _older: SaveService
var _newer: SaveService
var _lines: Lines


func before_test() -> void:
	_older = SaveService.new(PATH, {}, OLDER)
	# The newer build reads this build's saves, as a real one migrates them.
	var steps: Dictionary[int, Callable] = {
		OLDER: func(data: Dictionary) -> Dictionary: return data
	}
	_newer = SaveService.new(PATH, steps, NEWER)
	_clear()
	_lines = Lines.new()
	OS.add_logger(_lines)


func after_test() -> void:
	OS.remove_logger(_lines)
	_clear()


## Removes every file and folder the tests made, asides included, which delete() keeps.
func _clear() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for folder: String in DirAccess.get_directories_at(DIR):
		for name: String in DirAccess.get_files_at(DIR + folder):
			DirAccess.remove_absolute(DIR.path_join(folder).path_join(name))
		DirAccess.remove_absolute(DIR + folder)
	for name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _turn(service: SaveService) -> int:
	return int(service.load_save().data["turn"])


func _said(part: String) -> bool:
	for line: String in _lines.said:
		if line.contains(part):
			return true
	return false


func test_a_newer_save_is_moved_aside_on_the_first_write_not_deleted() -> void:
	_newer.save({"turn": 1})
	var newer_text: String = _text(PATH)
	assert_int(_older.save({"turn": 2})).is_equal(OK)
	assert_str(_text(PATH + SaveService.NEWER_SUFFIX)).is_equal(newer_text)
	assert_int(_turn(_older)).is_equal(2)
	assert_bool(_said("save.json is from a newer version and was moved aside")).is_true()


func test_two_writes_keep_the_newer_save_and_its_newer_backup() -> void:
	_newer.save({"turn": 1})
	_newer.save({"turn": 2})
	var main_text: String = _text(PATH)
	var backup_text: String = _text(_newer.backup_path())
	_older.save({"turn": 3})
	_older.save({"turn": 4})
	assert_str(_text(PATH + SaveService.NEWER_SUFFIX)).is_equal(main_text)
	assert_str(_text(_older.backup_path() + SaveService.NEWER_SUFFIX)).is_equal(backup_text)
	assert_int(_turn(_older)).is_equal(4)
	assert_int(int(JSON.parse_string(_text(_older.backup_path()))["data"]["turn"])).is_equal(3)


func test_a_newer_save_loads_as_from_a_newer_version_and_is_left_as_it_is() -> void:
	_newer.save({"turn": 1})
	_newer.save({"turn": 2})
	var main_text: String = _text(PATH)
	var loaded: SaveLoad = _older.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.NEWER_VERSION)
	assert_str(loaded.notice_key).is_equal(SaveService.NEWER_KEY)
	assert_bool(_string_keys().has(loaded.notice_key)).is_true()
	assert_str(_text(PATH)).is_equal(main_text)
	assert_bool(_said("load of save.json found a save from a newer version")).is_true()
	assert_bool(_said("failed")).is_false()


func test_a_newer_main_file_over_this_builds_backup_loads_the_backup_and_says_why() -> void:
	_older.save({"turn": 1})
	_newer.save({"turn": 2})
	var loaded: SaveLoad = _older.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_int(int(loaded.data["turn"])).is_equal(1)
	assert_str(loaded.notice_key).is_equal(SaveService.NEWER_KEY)


func test_a_path_keeps_one_aside_the_latest() -> void:
	_newer.save({"turn": 1})
	_older.save({"turn": 2})
	_newer.save({"turn": 3})
	var latest: String = _text(PATH)
	_older.save({"turn": 4})
	assert_str(_text(PATH + SaveService.NEWER_SUFFIX)).is_equal(latest)
	var asides: int = 0
	for name: String in DirAccess.get_files_at(DIR):
		if name.ends_with(SaveService.NEWER_SUFFIX):
			asides += 1
	assert_int(asides).is_equal(1)


func test_a_write_whose_move_aside_fails_is_refused_and_the_newer_save_stays() -> void:
	_newer.save({"turn": 1})
	var newer_text: String = _text(PATH)
	# A folder that holds a file where the aside would go: the rename cannot happen.
	var blocked: String = PATH + SaveService.NEWER_SUFFIX
	DirAccess.make_dir_recursive_absolute(blocked)
	FileAccess.open(blocked.path_join("held"), FileAccess.WRITE).store_string("x")
	assert_int(_older.save({"turn": 2})).is_not_equal(OK)
	assert_str(_text(PATH)).is_equal(newer_text)
	assert_bool(_said("save of save.json failed")).is_true()


func test_delete_moves_a_newer_save_aside() -> void:
	_newer.save({"turn": 1})
	_newer.save({"turn": 2})
	var main_text: String = _text(PATH)
	var backup_text: String = _text(_newer.backup_path())
	_older.delete()
	assert_bool(FileAccess.file_exists(PATH)).is_false()
	assert_bool(FileAccess.file_exists(_older.backup_path())).is_false()
	assert_str(_text(PATH + SaveService.NEWER_SUFFIX)).is_equal(main_text)
	assert_str(_text(_older.backup_path() + SaveService.NEWER_SUFFIX)).is_equal(backup_text)


func test_the_run_save_and_the_profile_keep_a_newer_file() -> void:
	var run: SaveService = SaveService.for_run(DIR + "run.json")
	var newer_run: String = _write_newer(run.path(), SaveService.SCHEMA_VERSION + 1)
	assert_int(run.load_save().status).is_equal(SaveLoad.Status.NEWER_VERSION)
	var record: RunRecord = RunRecord.new()
	record.mark(RunState.new(7))
	assert_int(run.save(record.to_dict())).is_equal(OK)
	assert_str(_text(run.path() + SaveService.NEWER_SUFFIX)).is_equal(newer_run)
	var profile: SaveService = Profile.service(DIR + "profile.json")
	var newer_profile: String = _write_newer(profile.path(), Profile.SCHEMA_VERSION + 1)
	assert_int(profile.load_save().status).is_equal(SaveLoad.Status.NEWER_VERSION)
	assert_int(ProfileSeen.mark(profile, ProfileSeen.TUTORIAL)).is_equal(OK)
	assert_str(_text(profile.path() + SaveService.NEWER_SUFFIX)).is_equal(newer_profile)
	assert_bool(ProfileSeen.has(profile, ProfileSeen.TUTORIAL)).is_true()


## A file as a newer build writes one, with data this build has never seen.
func _write_newer(path: String, version: int) -> String:
	var text: String = JSON.stringify({"schema_version": version, "data": {"unknown": 1}})
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return text


func _string_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	var file: FileAccess = FileAccess.open(STRINGS, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row.is_empty():
			keys.append(row[0])
	return keys
