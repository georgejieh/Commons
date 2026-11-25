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
	var count: int = _take(_counts, thread)
	var first: String = _take_first(thread)
	if count == 0:
		return ""
	return "%d script errors, first: %s" % [count, first]


## Adds one to thread's count in counts, under the lock.
func _count(counts: Dictionary[int, int], thread: int) -> void:
	_mutex.lock()
	counts[thread] = counts.get(thread, 0) + 1
	_mutex.unlock()


## Takes thread's count out of counts, leaving none.
func _take(counts: Dictionary[int, int], thread: int) -> int:
	_mutex.lock()
	var count: int = counts.get(thread, 0)
	counts.erase(thread)
	_mutex.unlock()
	return count


## Takes thread's first error's text, leaving none; "" when it logged none.
func _take_first(thread: int) -> String:
	_mutex.lock()
	var first: String = _first.get(thread, "")
	_first.erase(thread)
	_mutex.unlock()
	return first
