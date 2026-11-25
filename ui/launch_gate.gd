class_name LaunchGate
extends Control
## What a launch of the game itself does before it opens (ADR 0037). It logs the start
## line and reads the session file. With none, the app opens at once. With one gone
## stale, the last session did not close: its saves and log are copied into a folder
## under user://crashes/ first, and the app opens with that folder for the title's
## notice. With one still being written, another copy is open: the gate shows the notice
## that says so and lets nothing load or write until the player chooses, Quit or Open
## anyway. It keeps reading the file at every beat, and when the file goes stale or goes
## away the notice closes itself and the launch carries on.
##
## From the moment the app opens the gate writes the file at every beat, and removes it
## as the game closes. Only a launch of the main scene by the engine has a gate: a tool
## or a test runs under a script of its own and never writes or reads the file.

## The app opens; kept is the folder the last session's files were copied to, or empty.
signal opened(kept: String)

const PARAMS: SessionParams = preload("res://data/session/session_params.tres")

var _params: SessionParams
var _file: SessionFile
var _keep: CrashKeep
var _timer: Timer = Timer.new()
var _notice: SessionNotice = null


## Tests pass their own numbers and files; the game uses its own.
func _init(
	params: SessionParams = PARAMS, file: SessionFile = null, keep: CrashKeep = null
) -> void:
	_params = params
	_file = file if file != null else SessionFile.new(params)
	if keep == null:
		keep = CrashKeep.new(CrashKeep.saves(Saves.run_service(), Saves.profile_service()))
	_keep = keep


## True for the app the engine launched as the main scene, with no tool's script running
## the tree.
static func guards(app: Node) -> bool:
	var tree: SceneTree = app.get_tree()
	return tree.get_script() == null and tree.current_scene == app


## The most seconds the "already open" notice can stand once the other copy has stopped:
## the stale beats, and the beat it is read at.
static func wait_seconds(params: SessionParams) -> int:
	return ceili(params.stale_after() + params.beat_seconds)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer.wait_time = _params.beat_seconds
	_timer.timeout.connect(_on_beat)
	add_child(_timer)
	GameLog.started()
	match _file.look(_now()):
		SessionFile.Found.LIVE:
			_show_notice()
		SessionFile.Found.STALE:
			_open_after_crash()
		_:
			_open("")


## The copy is closing: its file goes with it.
func _exit_tree() -> void:
	_file.end()


## The notice showing while another copy looks open, or null.
func notice() -> SessionNotice:
	return _notice


func _show_notice() -> void:
	_notice = SessionNotice.already_open(wait_seconds(_params), get_tree().quit, _open_anyway)
	add_child(_notice)
	_timer.start()


func _open_anyway() -> void:
	_close_notice()
	_open("")


func _close_notice() -> void:
	_notice.close()
	_notice = null


## While the notice shows, each beat reads the file again; once the app is open, each
## beat writes it.
func _on_beat() -> void:
	if _notice == null:
		_file.beat(_now())
		return
	var found: SessionFile.Found = _file.look(_now())
	if found == SessionFile.Found.LIVE:
		return
	_close_notice()
	if found == SessionFile.Found.STALE:
		_open_after_crash()
	else:
		_open("")


func _open_after_crash() -> void:
	var folder: String = _keep.preserve(CrashKeep.stamp_now(), _params.crash_folders_kept)
	GameLog.crash_kept(folder)
	_open(folder)


func _open(kept: String) -> void:
	_file.begin(_now())
	_timer.start()
	opened.emit(kept)


func _now() -> float:
	return Time.get_unix_time_from_system()
