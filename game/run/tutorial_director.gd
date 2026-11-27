class_name TutorialDirector
extends RefCounted
## Walks the arrival's steps (ADR 0026). Screens report where they stand once they have
## settled; when the run waits on the next step's action there, that step's prompt shows
## and only its one action is allowed. Every other action is refused, which changes
## nothing and makes the prompt pulse. An accepted action shows the step's follow-up,
## which stays for a beat and until the next prompt, or waits for the step's closing
## button. A follow-up to an action at the table waits until the table has shown the
## run's answer to it (answered(), or the table's next report), so Wang never speaks of a
## villager's play before it is on the table. With no director, screens accept
## everything.

## Emitted when the step, the phase or what shows changes, so the layer redraws.
signal changed
## Emitted when an action is refused, so the prompt pulses.
signal refused
## Emitted once the last step is done.
signal finished

## Where the step under way stands: between steps, its prompt showing, its follow-up
## held until the next prompt, or every step done.
enum Phase { BETWEEN, PROMPT, UNTIL, DONE }

## The name screens send for the player's bid to be landlord. This and the names below
## are the run's own actions; a button sends its own name.
const BID_CALL: String = "bid_call"
## The name screens send for the player's pass in the bidding.
const BID_PASS: String = "bid_pass"
## The name screens send for the player's play.
const PLAY: String = "play"
## The name screens send for the player's pass in a round.
const PASS: String = "pass"
## The name screens send for the player's declared need.
const NEED: String = "need"
## What the run waits on before a screen has reported one.
const NOTHING: int = -1

var _script: TutorialScript
var _index: int = 0
var _phase: Phase = Phase.BETWEEN
## The step whose follow-up shows, or null before the first.
var _last: TutorialStep = null
## True while a follow-up holds its beat; release() ends it.
var _held: bool = false
## True while a follow-up waits for the table to show the run's answer to the action.
var _unseen: bool = false
var _screen: String = ""
var _awaiting: int = NOTHING


func _init(script: TutorialScript = RunTutorial.SCRIPT) -> void:
	_script = script


## The step under way, or null once every step is done.
func step() -> TutorialStep:
	return _script.steps[_index] if _index < _script.steps.size() else null


## The index of the step under way; the step count once every step is done.
func index() -> int:
	return _index


## Where the step under way stands.
func phase() -> Phase:
	return _phase


## True while a follow-up shows and holds its beat before the next prompt may show.
func is_held() -> bool:
	return _held and not _unseen


## Seconds a follow-up holds before the next prompt.
func follow_seconds() -> float:
	return _script.follow_seconds


## The screen now shown and what the run waits on, once that screen has settled.
func ready(shown: String, awaiting: int) -> void:
	_screen = shown
	_awaiting = awaiting
	if awaiting != NOTHING:
		_unseen = false
	_evaluate()


## The table has shown the run's answer to the last action as far as a new deal: the
## follow-up may show now.
func answered() -> void:
	if _unseen:
		_unseen = false
		changed.emit()


## The slip's line now: the prompt, the last follow-up, or nothing.
func line_key() -> String:
	match _phase:
		Phase.PROMPT:
			return step().prompt_key
		Phase.DONE:
			return ""
	return "" if _last == null or _unseen else _last.then_key


## The target to ring on the screen now shown, or "" for none.
func highlight() -> String:
	if _phase == Phase.UNTIL:
		return _last.until
	if _phase != Phase.PROMPT:
		return ""
	var current: TutorialStep = step()
	if not current.via.is_empty() and _screen == current.via_screen:
		return current.via
	return current.highlight if _screen == current.screen else ""


## The screen the slip belongs on now, or "" for none.
func screen() -> String:
	if _phase == Phase.PROMPT:
		var current: TutorialStep = step()
		return current.via_screen if _screen == current.via_screen else current.screen
	return _screen


## The cards the step asks the player to play, or none.
func cards() -> PackedInt32Array:
	if _phase != Phase.PROMPT or step().action != TutorialStep.Action.PLAY:
		return PackedInt32Array()
	return step().cards


## True and taken when action is the one the step asks for; otherwise refused.
func attempt(action: String, detail: Variant = null) -> bool:
	var current: TutorialStep = step()
	if _phase == Phase.PROMPT:
		if not current.via.is_empty() and action == current.via and _screen == current.via_screen:
			return true
		if matches(current, action, detail):
			_accept(current)
			return true
	refused.emit()
	return false


## A closing button was pressed. It is never refused; it ends a step waiting on it.
func note(action: String) -> void:
	if _phase == Phase.UNTIL and _last.until == action:
		_advance(false)


## Ends the follow-up's beat, so the next prompt may show.
func release() -> void:
	_held = false
	_unseen = false
	_evaluate()


## True when action, with its detail, is exactly the step's own.
static func matches(current: TutorialStep, action: String, detail: Variant) -> bool:
	match current.action:
		TutorialStep.Action.BID_CALL:
			return action == BID_CALL
		TutorialStep.Action.BID_PASS:
			return action == BID_PASS
		TutorialStep.Action.PASS:
			return action == PASS
		TutorialStep.Action.NEED:
			return action == NEED and detail is int and detail == current.need
		TutorialStep.Action.PLAY:
			return action == PLAY and _same_cards(detail, current.cards)
	var slot_fits: bool = current.slot < 0 or (detail is int and detail == current.slot)
	return action == current.button and slot_fits


static func _same_cards(detail: Variant, expected: PackedInt32Array) -> bool:
	if not detail is Array:
		return false
	var sent: Array = detail
	var given: Array = sent.duplicate()
	var wanted: Array = Array(expected)
	given.sort()
	wanted.sort()
	return given == wanted


func _accept(current: TutorialStep) -> void:
	_last = current
	# The table reports again once the run's answer has played; a button leaves the run
	# where it was, so its report still holds.
	if current.action != TutorialStep.Action.BUTTON:
		_awaiting = NOTHING
	if not current.until.is_empty():
		_phase = Phase.UNTIL
		changed.emit()
	else:
		_advance(true)


func _advance(hold: bool) -> void:
	_index += 1
	if _index >= _script.steps.size():
		_phase = Phase.DONE
		changed.emit()
		finished.emit()
		return
	_phase = Phase.BETWEEN
	_held = hold and _last != null and not _last.then_key.is_empty()
	# A button leaves the run where it was; any other action is answered at the table.
	_unseen = _held and _last.action != TutorialStep.Action.BUTTON
	_evaluate()


func _evaluate() -> void:
	var current: TutorialStep = step()
	if current == null:
		return
	if _phase == Phase.BETWEEN and not _held and _due(current):
		_phase = Phase.PROMPT
	changed.emit()


## True when the screen shown and what the run waits on are the step's.
func _due(current: TutorialStep) -> bool:
	if _awaiting == NOTHING:
		return false
	if _screen != current.screen and (current.via.is_empty() or _screen != current.via_screen):
		return false
	match current.action:
		TutorialStep.Action.BID_CALL, TutorialStep.Action.BID_PASS:
			return _awaiting == RunController.AWAIT_BID
		TutorialStep.Action.PLAY, TutorialStep.Action.PASS:
			return _awaiting == RunController.AWAIT_PLAY
		TutorialStep.Action.NEED:
			return _awaiting == RunController.AWAIT_NEED
	return true
