extends GdUnitTestSuite
## ADR 0037's launch: with no session file the app opens at once; a stale one has the
## last session's saves and newest log copied into a folder under crashes/ before the app
## opens, and only the newest folders stay; a live one shows the "already open" notice,
## with Quit focused, and nothing opens until the player chooses or the file goes stale,
## when the notice closes itself. The gate writes the file once open and removes it as
## it goes. A test, like every tool, never has a gate.

const FOLDER: String = "user://test_launch_gate"
const APP: String = "res://ui/main.tscn"
const PARAMS: SessionParams = preload("res://data/session/session_params.tres")
const SAVE_NAMES: Array[String] = ["run.json", "run.json.bak", "profile.json", "private_ledger.txt"]
## The live log, the last session's dated copy, and a newer copy a tool's run left.
const LOGS: Array[String] = [
	"commons.log", "commons2026-11-01T09.00.00.log", "commons2026-11-02T09.00.00.log"
]
const ENGINE_LINE: String = "Godot Engine v4.7.2.stable.official"

var _params: SessionParams
var _file: SessionFile
var _keep: CrashKeep
var _opened: Array[String] = []


func before_test() -> void:
	_clear(FOLDER)
	for folder: String in ["saves", "logs", "crashes"]:
		DirAccess.make_dir_recursive_absolute(FOLDER.path_join(folder))
	# A quick beat, so a notice that closes itself does so within the test.
	_params = PARAMS.duplicate()
	_params.beat_seconds = 0.05
	_file = SessionFile.new(_params, FOLDER.path_join("session.json"))
	var saves: Array[String] = []
	for name: String in SAVE_NAMES:
		saves.append(FOLDER.path_join("saves").path_join(name))
		_write(saves.back(), "the %s as the last session left it" % name)
	var game_log: String = "%s\n%sunnumbered, development build\n" % [ENGINE_LINE, GameLog.STARTED]
	_write(FOLDER.path_join("logs").path_join(LOGS[0]), game_log)
	_write(FOLDER.path_join("logs").path_join(LOGS[1]), game_log)
	_write(FOLDER.path_join("logs").path_join(LOGS[2]), "%s\nA tool's run.\n" % ENGINE_LINE)
	var log_path: String = FOLDER.path_join("logs").path_join(LOGS[0])
	_keep = CrashKeep.new(saves, FOLDER.path_join("crashes"), log_path)
	_opened.clear()


func after_test() -> void:
	_clear(FOLDER)


func _clear(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for name: String in DirAccess.get_directories_at(folder):
		_clear(folder.path_join(name))
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A session file as another copy leaves it, last written at beat.
func _other_copy(beat: float) -> void:
	var other: SessionFile = SessionFile.new(_params, _file.path())
	other.begin(beat)


func _gate() -> LaunchGate:
	var gate: LaunchGate = LaunchGate.new(_params, _file, _keep)
	gate.opened.connect(func(kept: String) -> void: _opened.append(kept))
	add_child(gate)
	return auto_free(gate)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
	await await_idle_frame()


func _pad_accept() -> void:
	for down: bool in [true, false]:
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		pad.pressed = down
		Input.parse_input_event(pad)
		Input.flush_buffered_events()
	await await_idle_frame()


func test_no_file_opens_at_once_and_the_gate_keeps_the_file_until_it_goes() -> void:
	var gate: LaunchGate = _gate()
	assert_array(_opened).is_equal([""])
	assert_object(gate.notice()).is_null()
	assert_bool(_file.is_mine()).is_true()
	var now: float = Time.get_unix_time_from_system()
	assert_int(_file.look(now)).is_equal(SessionFile.Found.LIVE)
	assert_array(_keep.folders()).is_empty()
	remove_child(gate)
	assert_bool(FileAccess.file_exists(_file.path())).is_false()


## The copies are made before the app is told to open, and are the files as they were.
func test_a_stale_file_keeps_the_saves_and_the_last_log_before_anything_opens() -> void:
	_other_copy(Time.get_unix_time_from_system() - _params.stale_after() - 1.0)
	var seen_at_open: Array[PackedStringArray] = []
	var gate: LaunchGate = LaunchGate.new(_params, _file, _keep)
	gate.opened.connect(
		func(kept: String) -> void:
			_opened.append(kept)
			seen_at_open.append(DirAccess.get_files_at(kept))
	)
	add_child(gate)
	auto_free(gate)
	assert_int(_opened.size()).is_equal(1)
	var kept: String = _opened[0]
	assert_str(kept.get_base_dir()).is_equal(FOLDER.path_join("crashes"))
	var expected: Array[String] = SAVE_NAMES.duplicate()
	# The game's own last log, not the newer one a tool's run left.
	expected.append(LOGS[1])
	assert_array(Array(seen_at_open[0])).contains_exactly_in_any_order(expected)
	for name: String in SAVE_NAMES:
		var copy: String = FileAccess.get_file_as_string(kept.path_join(name))
		assert_str(copy).is_equal("the %s as the last session left it" % name)
	# The originals are where they were, untouched, and the file is this copy's now.
	for name: String in SAVE_NAMES:
		assert_bool(FileAccess.file_exists(FOLDER.path_join("saves").path_join(name))).is_true()
	assert_bool(_file.is_mine()).is_true()


func test_only_the_newest_crash_folders_stay() -> void:
	for day: int in range(1, 8):
		var old: String = FOLDER.path_join("crashes").path_join("2026-10-0%dT08.00.00" % day)
		DirAccess.make_dir_recursive_absolute(old)
		_write(old.path_join("run.json"), "old")
	var kept: String = _keep.preserve("2026-11-24T10.00.00", _params.crash_folders_kept)
	var folders: Array[String] = _keep.folders()
	assert_int(folders.size()).is_equal(_params.crash_folders_kept)
	assert_str(folders.back()).is_equal(kept)
	assert_str(folders[0].get_file()).is_equal("2026-10-04T08.00.00")


func test_a_live_file_shows_the_notice_and_opens_nothing_until_the_player_chooses() -> void:
	# The other copy keeps beating through the test: well ahead of the clock.
	_other_copy(Time.get_unix_time_from_system() + 3600.0)
	var before: String = FileAccess.get_file_as_string(_file.path())
	var gate: LaunchGate = _gate()
	await await_idle_frame()
	var notice: SessionNotice = gate.notice()
	assert_object(notice).is_not_null()
	assert_array(_opened).is_empty()
	assert_bool(_file.is_mine()).is_false()
	await await_millis(200)
	assert_array(_opened).is_empty()
	assert_str(FileAccess.get_file_as_string(_file.path())).is_equal(before)
	var buttons: Array[Button] = notice.buttons()
	assert_str(buttons[0].text).is_equal(tr("session.open.quit"))
	assert_str(buttons[1].text).is_equal(tr("session.open.anyway"))
	assert_object(get_viewport().gui_get_focus_owner()).is_same(buttons[0])
	await _key(KEY_RIGHT)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(buttons[1])
	await _pad_accept()
	assert_array(_opened).is_equal([""])
	assert_object(gate.notice()).is_null()
	assert_bool(_file.is_mine()).is_true()
	assert_array(_keep.folders()).is_empty()


## The other copy stops beating: within a few beats the notice goes by itself and the
## launch carries on as after an exit that was not clean.
func test_the_notice_closes_itself_when_the_file_goes_stale() -> void:
	_other_copy(Time.get_unix_time_from_system())
	var gate: LaunchGate = _gate()
	await await_idle_frame()
	assert_object(gate.notice()).is_not_null()
	var wait_msec: int = int((_params.stale_after() + 3.0 * _params.beat_seconds) * 1000.0)
	await await_millis(wait_msec)
	assert_object(gate.notice()).is_null()
	assert_int(_opened.size()).is_equal(1)
	assert_array(Array(DirAccess.get_files_at(_opened[0]))).contains(["run.json"])
	assert_bool(_file.is_mine()).is_true()


## The app a test builds is not launched by the engine: it has no gate, and the game's
## own session file is left exactly as it was, there or not.
func test_a_test_never_has_a_gate_or_touches_the_session_file() -> void:
	var real: String = SessionFile.PATH
	var was: String = FileAccess.get_file_as_string(real) if FileAccess.file_exists(real) else ""
	var had: bool = FileAccess.file_exists(real)
	var app: DemoApp = auto_free((load(APP) as PackedScene).instantiate())
	Saves.use_run_path(FOLDER.path_join("app/run.json"))
	add_child(app)
	await await_idle_frame()
	assert_bool(LaunchGate.guards(app)).is_false()
	for child: Node in app.get_children():
		assert_bool(child is LaunchGate).is_false()
	assert_bool(FileAccess.file_exists(real)).is_equal(had)
	if had:
		assert_str(FileAccess.get_file_as_string(real)).is_equal(was)
	Saves.run_service().delete()
	Saves.profile_service().delete()


## Quit on the notice ends the tree, which frees the app and its gate. The app never
## opened, and nothing it made to open with is left outside the tree.
func test_quit_from_the_notice_leaves_nothing_of_the_app() -> void:
	_other_copy(Time.get_unix_time_from_system() + 3600.0)
	var before: String = FileAccess.get_file_as_string(_file.path())
	var orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	# The app as it stands behind its gate: made, and not yet opened.
	var app: DemoApp = (load(APP) as PackedScene).instantiate()
	var gate: LaunchGate = LaunchGate.new(_params, _file, _keep)
	var quit: Array[bool] = []
	gate.leave = func() -> void: quit.append(true)
	gate.opened.connect(func(kept: String) -> void: _opened.append(kept))
	add_child(gate)
	await await_idle_frame()
	await _key(KEY_ENTER)
	assert_array(quit).is_equal([true])
	assert_array(_opened).is_empty()
	# What quitting the tree does to them.
	gate.free()
	app.free()
	await await_idle_frame()
	var left: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	assert_float(left).is_equal(orphans)
	assert_str(FileAccess.get_file_as_string(_file.path())).is_equal(before)


## With only tools' logs beside the live one, no log is kept, and the saves still are.
func test_a_tools_log_is_never_kept_as_the_games() -> void:
	DirAccess.remove_absolute(FOLDER.path_join("logs").path_join(LOGS[1]))
	var kept: String = _keep.preserve("2026-11-24T10.00.00", _params.crash_folders_kept)
	var expected: Array[String] = SAVE_NAMES.duplicate()
	assert_array(Array(DirAccess.get_files_at(kept))).contains_exactly_in_any_order(expected)
