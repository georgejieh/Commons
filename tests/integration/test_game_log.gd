extends GdUnitTestSuite
## ADR 0037's log lines: one at start, one when a run starts, resumes or ends, one for a
## save that fails and for a load that fails or falls back to its backup, and none of
## them holding the family's name, a path outside the game's folder or anything typed.

const SEED: int = 4417
## A family name as a player might type one.
const FAMILY: String = "Zhaoqiandu"

static var _folder: String = TestFolder.of("test_game_log")
static var _save_path: String = _folder + "run.json"


class Lines:
	extends Logger
	var said: Array[String] = []

	func _log_message(message: String, _error: bool) -> void:
		if message.begins_with(GameLog.PREFIX):
			said.append(message.strip_edges())


var _lines: Lines
var _app: App


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	_lines = Lines.new()
	OS.add_logger(_lines)
	_app = AppKit.make(self)
	_app.controller.live_search = false


func after_test() -> void:
	OS.remove_logger(_lines)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	for folder: String in DirAccess.get_directories_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(folder))
	for folder: String in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(folder))


func _said(part: String) -> bool:
	for line: String in _lines.said:
		if line.contains(part):
			return true
	return false


func test_a_run_logs_its_start_resume_and_end_with_its_seed() -> void:
	GameLog.started()
	assert_bool(_said("renderer, screen ")).is_true()
	# The crash step knows the game's own log by how this line begins.
	assert_str(_lines.said[0]).starts_with(GameLog.STARTED.strip_edges())
	assert_bool(_app.new_run(SEED)).is_true()
	(
		assert_bool(
			_said("demo run started, seed %d, save schema %d" % [SEED, SaveService.SCHEMA_VERSION])
		)
		. is_true()
	)
	assert_bool(_app.continue_run()).is_true()
	assert_bool(_said("run resumed, seed %d" % SEED)).is_true()
	_app.leave_run()
	assert_bool(_said("run abandoned, seed %d" % SEED)).is_true()
	assert_int(_lines.said.size()).is_equal(4)


func test_a_save_that_fails_and_loads_that_fall_back_or_fail_are_logged() -> void:
	var service: SaveService = SaveService.new(_folder.path_join("blocked.json"))
	# A folder where the temporary file would go: the write cannot open it.
	DirAccess.make_dir_recursive_absolute(service.path() + SaveService.TEMP_SUFFIX)
	assert_int(service.save({"a": 1})).is_not_equal(OK)
	assert_bool(_said("save of blocked.json failed: ")).is_true()
	var fallback: SaveService = SaveService.new(_folder.path_join("fallback.json"))
	fallback.save({"a": 1})
	fallback.save({"a": 2})
	var damaged: FileAccess = FileAccess.open(fallback.path(), FileAccess.WRITE)
	damaged.store_string("{")
	damaged.close()
	assert_int(fallback.load_save().status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_bool(_said("load of fallback.json " + GameLog.FELL_BACK)).is_true()
	var backup: FileAccess = FileAccess.open(fallback.backup_path(), FileAccess.WRITE)
	backup.store_string("{")
	backup.close()
	assert_int(fallback.load_save().status).is_equal(SaveLoad.Status.UNREADABLE)
	assert_bool(_said("load of fallback.json failed")).is_true()
	fallback.delete()


## Every line the game adds, from a run of a family with a typed name through a failed
## save, names files by their names alone and holds nothing of the player's.
func test_no_line_holds_anything_personal() -> void:
	var profile: ProfileData = Profile.read(Saves.profile_service())
	profile.surname = FAMILY
	Profile.write(Saves.profile_service(), profile)
	GameLog.started()
	assert_bool(_app.new_run(SEED)).is_true()
	_app.continue_run()
	_app.leave_run()
	var service: SaveService = SaveService.new(_folder.path_join("blocked.json"))
	DirAccess.make_dir_recursive_absolute(service.path() + SaveService.TEMP_SUFFIX)
	service.save({})
	GameLog.crash_kept("user://crashes/2000-01-01T00.00.00")
	assert_int(_lines.said.size()).is_greater_equal(5)
	var user_folder: String = OS.get_user_data_dir()
	var account: String = OS.get_environment("USERNAME" if OS.has_feature("windows") else "USER")
	for line: String in _lines.said:
		assert_str(line).not_contains(FAMILY).not_contains(user_folder).not_contains("user://")
		assert_str(line).not_contains(":/").not_contains(":\\")
		if not account.is_empty():
			assert_str(line).not_contains(account)
