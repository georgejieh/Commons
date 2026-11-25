class_name CrashKeep
extends RefCounted
## What the launch after an exit that was not clean keeps (ADR 0037): the run save, its
## backup, the profile, the private ledger and the last session's log, copied into a
## folder of their own under user://crashes/, before anything is loaded or written. Only
## the newest folders are kept. Nothing is saved from the crashing copy itself: the saves
## are already written so that a stop between any two steps leaves one that loads.
##
## The engine copies the last session's log to a file named after its base name with the
## time when the game starts, so by the time this runs that copy is the newest of them
## that holds the game's start line.

const ROOT: String = "user://crashes"
const LOG_PATH_SETTING: String = "debug/file_logging/log_path"
## How far into a log its start line is looked for: past the engine's own first lines.
const START_LINES: int = 40

var _files: Array[String]
var _root: String
var _log_path: String


## files are the saves to copy, by path; the log path is the engine's live log, whose
## dated copies sit beside it.
func _init(
	files: Array[String],
	root: String = ROOT,
	log_path: String = str(ProjectSettings.get_setting(LOG_PATH_SETTING))
) -> void:
	_files = files
	_root = root
	_log_path = log_path


## The files of the game's own saves, as the Saves autoload names them.
static func saves(run: SaveService, profile: SaveService) -> Array[String]:
	var found: Array[String] = [run.path(), run.backup_path(), profile.path()]
	found.append_array(run.companions)
	return found


## Copies what there is into a new folder named by stamp, drops the oldest folders past
## kept, and returns the new folder's path.
func preserve(stamp: String, kept: int) -> String:
	var folder: String = _root.path_join(stamp)
	DirAccess.make_dir_recursive_absolute(folder)
	var copied: Array[String] = _files.duplicate()
	var last_log: String = _last_log()
	if not last_log.is_empty():
		copied.append(last_log)
	for source: String in copied:
		if FileAccess.file_exists(source):
			DirAccess.copy_absolute(source, folder.path_join(source.get_file()))
	_prune(kept)
	return folder


## The folders kept now, oldest first.
func folders() -> Array[String]:
	var found: Array[String] = []
	for name: String in DirAccess.get_directories_at(_root):
		found.append(_root.path_join(name))
	found.sort()
	return found


## A folder name for now, in the order the folders sort.
static func stamp_now() -> String:
	return Time.get_datetime_string_from_system().replace(":", ".")


## The newest dated copy of the engine's log that the game itself wrote: a file beside it
## whose name is its base name followed by a time, with its extension, and whose first
## lines hold the game's start line. A tool or test run without its own --log-file logs
## to the same file, so its copies sit among the game's; they are passed over. Times sort
## as text.
func _last_log() -> String:
	var folder: String = _log_path.get_base_dir()
	var base: String = _log_path.get_file().get_basename()
	var extension: String = _log_path.get_extension()
	var dated: Array[String] = []
	for name: String in DirAccess.get_files_at(folder):
		if name == _log_path.get_file() or not name.begins_with(base):
			continue
		if name.get_extension() == extension:
			dated.append(name)
	dated.sort()
	dated.reverse()
	for name: String in dated:
		if _is_the_games(folder.path_join(name)):
			return folder.path_join(name)
	return ""


## True when the log's first lines hold the game's start line, which a launch prints
## before anything else of the game's.
static func _is_the_games(log_path: String) -> bool:
	var file: FileAccess = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return false
	for _line: int in START_LINES:
		if file.eof_reached():
			break
		if file.get_line().begins_with(GameLog.STARTED):
			return true
	return false


func _prune(kept: int) -> void:
	var found: Array[String] = folders()
	for at: int in maxi(found.size() - kept, 0):
		for name: String in DirAccess.get_files_at(found[at]):
			DirAccess.remove_absolute(found[at].path_join(name))
		DirAccess.remove_absolute(found[at])
