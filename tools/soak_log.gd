class_name SoakLog
extends Logger
## Counts, by the thread that raised them, the errors Godot logs (script errors and
## failed asserts among them, warnings not) and the game's own log lines for a save that
## failed and a load that fell back to its backup (GameLog), so a run on any worker can
## tell what it hit. A load that fails outright is counted by the driver that asked.

const SAVE_FAILED: String = GameLog.PREFIX + "save of "
const LOAD: String = GameLog.PREFIX + "load of "

var _mutex: Mutex = Mutex.new()
## By thread: the errors, the save lines and the load lines, and the first error's text.
var _counts: Dictionary[int, Vector3i] = {}
var _first: Dictionary[int, String] = {}


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var thread: int = OS.get_thread_caller_id()
	_mutex.lock()
	_counts[thread] = _counts.get(thread, Vector3i.ZERO) + Vector3i(1, 0, 0)
	if not _first.has(thread):
		var text: String = rationale if not rationale.is_empty() else code
		_first[thread] = "%s (%s:%d %s)" % [text, file.get_file(), line, function]
	_mutex.unlock()


func _log_message(message: String, _error: bool) -> void:
	var found: Vector3i = Vector3i.ZERO
	if message.begins_with(SAVE_FAILED):
		found = Vector3i(0, 1, 0)
	elif message.begins_with(LOAD) and message.contains(GameLog.FELL_BACK):
		found = Vector3i(0, 0, 1)
	else:
		return
	var thread: int = OS.get_thread_caller_id()
	_mutex.lock()
	_counts[thread] = _counts.get(thread, Vector3i.ZERO) + found
	_mutex.unlock()


## Takes the calling thread's counts into faults and returns its first error's text, or
## "" when it logged none; the thread starts again from none.
func take(faults: SoakFaults) -> String:
	var thread: int = OS.get_thread_caller_id()
	_mutex.lock()
	var counts: Vector3i = _counts.get(thread, Vector3i.ZERO)
	var first: String = _first.get(thread, "")
	_counts.erase(thread)
	_first.erase(thread)
	_mutex.unlock()
	faults.errors += counts.x
	faults.save_failures += counts.y
	faults.load_failures += counts.z
	return first
