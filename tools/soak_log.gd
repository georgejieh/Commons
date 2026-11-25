class_name SoakLog
extends BalanceErrors
## Counts what BalanceErrors counts, and also, by thread, the game's own log lines for a
## save that failed and a load that fell back to its backup (GameLog), so a run on any
## worker can tell what it hit. A load that fails outright is counted by the driver that
## asked.

const SAVE_FAILED: String = GameLog.PREFIX + "save of "
const LOAD: String = GameLog.PREFIX + "load of "

var _save_failures: Dictionary[int, int] = {}
var _load_failures: Dictionary[int, int] = {}


func _log_message(message: String, _error: bool) -> void:
	if message.begins_with(SAVE_FAILED):
		_count(_save_failures, OS.get_thread_caller_id())
	elif message.begins_with(LOAD) and message.contains(GameLog.FELL_BACK):
		_count(_load_failures, OS.get_thread_caller_id())


## Takes the calling thread's counts into faults and returns its first error's text, or
## "" when it logged none; the thread starts again from none.
func take_into(faults: SoakFaults) -> String:
	var thread: int = OS.get_thread_caller_id()
	faults.errors += _take(_counts, thread)
	faults.save_failures += _take(_save_failures, thread)
	faults.load_failures += _take(_load_failures, thread)
	return _take_first(thread)
