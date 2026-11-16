class_name BalanceErrors
extends Logger
## Counts the errors Godot logs, script errors and failed asserts among them, by the
## thread that raised them, so a run on any worker can tell that it hit one. Warnings
## are not counted.

var _mutex: Mutex = Mutex.new()
var _counts: Dictionary[int, int] = {}
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
	_counts[thread] = _counts.get(thread, 0) + 1
	if not _first.has(thread):
		var text: String = rationale if not rationale.is_empty() else code
		_first[thread] = "%s (%s:%d %s)" % [text, file.get_file(), line, function]
	_mutex.unlock()


## Takes the calling thread's count and first message, and starts it again from none.
## Returns an empty string when the thread logged no error.
func take() -> String:
	var thread: int = OS.get_thread_caller_id()
	_mutex.lock()
	var count: int = _counts.get(thread, 0)
	var first: String = _first.get(thread, "")
	_counts.erase(thread)
	_first.erase(thread)
	_mutex.unlock()
	if count == 0:
		return ""
	return "%d script errors, first: %s" % [count, first]
