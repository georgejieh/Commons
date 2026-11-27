class_name SessionFile
extends RefCounted
## The sign that a copy of the game is open (ADR 0037): a small file holding the time the
## copy started and the time it last wrote, written again at every beat while it runs and
## removed when it closes. The engine can only ask whether a process it started itself is
## running, so a file that keeps being written stands in for asking about another copy.
## A file left unwritten for longer than the stale beats is a copy that did not close.
## Only the copy that began the file removes it, so a second copy that quits leaves the
## first one's file alone. Times are seconds of the system clock, passed in by the caller.

## What look finds: no file, a file left unwritten too long, or one still being written.
enum Found { NONE, STALE, LIVE }

## Where the sign is kept.
const PATH: String = "user://session.json"
## The key of the time the copy started.
const STARTED_KEY: String = "started"
## The key of the time the copy last wrote the file.
const BEAT_KEY: String = "beat"

var _path: String
var _params: SessionParams
var _started: float = 0.0
var _mine: bool = false


func _init(params: SessionParams, file_path: String = PATH) -> void:
	_params = params
	_path = file_path


## The path of the file, for tests.
func path() -> String:
	return _path


## What the file says at now: no copy, a copy that stopped, or one still writing. A file
## that cannot be read was cut off as its copy stopped. A beat ahead of now, as after the
## clock was set back, counts as live: the notice's Open anyway answers that case.
func look(now: float) -> Found:
	if not FileAccess.file_exists(_path):
		return Found.NONE
	# Parsed quietly: a cut-off file is expected here, not an error.
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK or not json.data is Dictionary:
		return Found.STALE
	var written: Dictionary = json.data
	if not written.get(BEAT_KEY) is float:
		return Found.STALE
	var last_beat: float = written[BEAT_KEY]
	return Found.STALE if now - last_beat > _params.stale_after() else Found.LIVE


## This copy is open from now: the file is written, and is this copy's to remove.
func begin(now: float) -> Error:
	_started = now
	_mine = true
	return beat(now)


## Writes the file again with now as its latest beat.
func beat(now: float) -> Error:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(JSON.stringify({STARTED_KEY: _started, BEAT_KEY: now}))
	file.close()
	return OK if stored else ERR_FILE_CANT_WRITE


## This copy closes: its file goes. A copy that never began leaves the file as it is.
func end() -> void:
	if _mine and FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	_mine = false


## True while this copy began the file and has not ended it, for tests.
func is_mine() -> bool:
	return _mine
