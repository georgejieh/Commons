class_name SoakDriver
extends BalanceDriver
## One run of the soak (ADR 0037): the balance harness's run, written through the real
## SaveService into a folder of its own as the app writes it, after every command and
## boundary. At every Set's end the save is loaded back into a new controller, which
## must hold the same run, state for state and waiting on the same thing, and play goes
## on from it. Refused commands, refused bot actions, errors, failed saves and loads,
## and mismatches after a resume are counted in faults; any of them fails the run.

## What the run hit.
var faults: SoakFaults = SoakFaults.new()

var _log: SoakLog
## Bot actions refused by the loops already handed over, which the last loop's count
## leaves out.
var _refused_before: int = 0
## True from a resume at a Set's end until the run moves past it.
var _resumed: bool = false


func _init(strategy: BalanceStrategy, stake: int, run_log: SoakLog, folder: String) -> void:
	super(strategy, stake)
	_log = run_log
	saves = SaveService.for_run(folder.path_join("run.json"))


func play(seed_value: int) -> BalanceResult:
	saves.delete()
	_log.take(SoakFaults.new())
	super(seed_value)
	var first: String = _log.take(faults)
	if faults.errors > 0:
		_fail("%d errors, first: %s" % [faults.errors, first])
	if faults.save_failures + faults.load_failures > 0:
		_fail("%d saves and %d loads failed" % [faults.save_failures, faults.load_failures])
	if not result.failed():
		saves.delete()
	return result


func _step() -> void:
	if _controller.awaiting() == RunController.AWAIT_SET_OVER and not _resumed:
		_resumed = true
		_resume()
		return
	_resumed = false
	super()


func _send(command: String, reason: int) -> void:
	if reason != RunController.OK:
		faults.refused_commands += 1
	super(command, reason)


func _finish() -> void:
	var loop: RunLoop = _controller.get("_loop")
	faults.bot_actions += _refused_before + loop.refused_bot_actions
	if _refused_before > 0:
		_fail("%d bot actions refused before the last resume" % _refused_before)
	super()


## Loads the save back into a new controller, checks it holds this run as it stands, and
## plays on from it.
func _resume() -> void:
	var before: Dictionary = _controller.state_copy().to_dict()
	var awaited: int = _controller.awaiting()
	var resumed: RunController = new_controller()
	if not resumed.continue_saved(saves):
		resumed.free()
		faults.load_failures += 1
		_fail("the save at Year %d did not load" % _year())
		return
	if resumed.state_copy().to_dict() != before or resumed.awaiting() != awaited:
		faults.mismatches += 1
		_fail("the run resumed at Year %d is not the run saved" % _year())
	var loop: RunLoop = _controller.get("_loop")
	_refused_before += loop.refused_bot_actions
	_controller.event_emitted.disconnect(_on_event)
	_controller.free()
	_controller = resumed
	_controller.event_emitted.connect(_on_event)
