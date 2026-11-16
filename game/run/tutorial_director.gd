class_name TutorialDirector
extends RefCounted
## Walks the arrival's steps (ADR 0026). Screens report where they stand once they have
## settled; when the run waits on the next step's action there, that step's prompt shows
## and only its one action is allowed. Every other action is refused, which changes
## nothing and makes the prompt pulse. An accepted action shows the step's follow-up,
## which stays for a beat and until the next prompt, or opens a board preview, or waits
## for the step's closing button. With no director, screens accept everything as before.

signal changed
signal refused
## A board preview of the meter's high band should play now; preview_done() ends it.
signal preview_started(meter: String)
signal finished

enum Phase { BETWEEN, PROMPT, UNTIL, PREVIEW, DONE }

## The names screens send for the run's own actions; a button sends its own name.
const BID_CALL: String = "bid_call"
const BID_PASS: String = "bid_pass"
const PLAY: String = "play"
const PASS: String = "pass"
const NEED: String = "need"
const NOTHING: int = -1

var _script: TutorialScript
var _index: int = 0
var _phase: Phase = Phase.BETWEEN
## The step whose follow-up shows, or null before the first.
var _last: TutorialStep = null
## True while a follow-up holds its beat; release() ends it.
var _held: bool = false
var _screen: String = ""
var _awaiting: int = NOTHING


func _init(script: TutorialScript = RunTutorial.SCRIPT) -> void:
	_script = script


## The step under way, or null once every step is done.
func step() -> TutorialStep:
	return _script.steps[_index] if _index < _script.steps.size() else null


func index() -> int:
	return _index


func phase() -> Phase:
	return _phase


func is_done() -> bool:
	return _phase == Phase.DONE


## True while a follow-up holds its beat before the next prompt may show.
func is_held() -> bool:
	return _held


## Seconds a follow-up holds before the next prompt, and a board preview lasts.
func follow_seconds() -> float:
	return _script.follow_seconds


func preview_seconds() -> float:
	return _script.preview_seconds


func preview_value() -> int:
	return _script.preview_value


## The screen now shown and what the run waits on, once that screen has settled.
func ready(screen: String, awaiting: int) -> void:
	_screen = screen
	_awaiting = awaiting
	_evaluate()


## The slip's line now: the prompt, the last follow-up, or nothing.
func line_key() -> String:
	match _phase:
		Phase.PROMPT:
			return step().prompt_key
		Phase.DONE:
			return ""
	return "" if _last == null else _last.then_key


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
	_evaluate()


## The board preview has played.
func preview_done() -> void:
	if _phase == Phase.PREVIEW:
		_advance(false)


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


static func _same_cards(detail: Variant, cards: PackedInt32Array) -> bool:
	if not detail is Array:
		return false
	var sent: Array = detail
	var given: Array = sent.duplicate()
	var wanted: Array = Array(cards)
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
	elif not current.preview.is_empty():
		_phase = Phase.PREVIEW
		changed.emit()
		preview_started.emit(current.preview)
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
