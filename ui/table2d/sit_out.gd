class_name SitOut
extends Node
## Sitting out a trick. When it is the player's turn to follow and the legal-move generator
## gives them nothing but a pass, a Sit out button stands beside Pass. Pressed, it passes
## for them for the rest of the trick while the villagers play at a faster step. On each of
## the player's turns in that trick the generator is asked again, for the seat's rank order
## can change mid-trick: the moment any play is legal, a bomb or rocket included, sitting
## out stops and the turn is theirs. It ends with the trick and never carries into the
## next. Every pass it makes is the Pass button's own command, sent through the controller;
## nothing else changes the run. It is never offered during the arrival.

## The table's step is to be read again: sitting out began or ended.
signal pace_changed

var _controller: RunController
var _actions: ActionBar
var _player: EventPlayer
## True while the arrival plays, when sitting out is never offered.
var _blocked: Callable = Callable()
var _active: bool = false


func setup(
	controller: RunController,
	actions: ActionBar,
	commands: TableCommands,
	player: EventPlayer,
	blocked: Callable
) -> void:
	_controller = controller
	_actions = actions
	_player = player
	_blocked = blocked
	var before: Callable = commands.prompt
	commands.prompt = func() -> String:
		if _active:
			return tr("table.sitting_out")
		return before.call() if before.is_valid() else ""
	actions.sit_out.pressed.connect(_on_pressed)
	player.queued.connect(_offer)
	player.drained.connect(_on_drained)
	player.played.connect(_on_played)
	_offer()


func is_active() -> bool:
	return _active


## What the table's step is multiplied by: faster while sitting out.
func pace() -> float:
	return TableMotion.PRESETS.sit_out_scale if _active else 1.0


## True when the player may sit out now: their turn to follow, nothing legal but a pass,
## and not the arrival.
func offered() -> bool:
	if _active or not _my_turn() or not _controller.table.pass_refusal().is_empty():
		return false
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	return _following() and _controller.table.legal_moves().is_empty()


func _on_pressed() -> void:
	if not offered():
		return
	_set_active(true)
	_pass()


## On each of the player's turns while sitting out: pass again if still nothing is legal,
## else hand the turn back. A drain on another seat's turn, as while a villager's play is
## still being searched, waits for the next; the trick's end is _on_played's.
func _on_drained() -> void:
	if _active:
		if not _my_turn():
			return
		if not _following() or not _controller.table.legal_moves().is_empty():
			_set_active(false)
		else:
			_pass()
			return
	_offer()


## The trick's end, the round's end or a new deal ends sitting out.
func _on_played(event: RunEvent) -> void:
	if not _active:
		return
	var ends: bool = event.type in [RunEvent.Type.DEALT, RunEvent.Type.SET_STARTED]
	if event.type == RunEvent.Type.ROUND:
		var kind: RoundEvent.Type = event.round_event.type
		ends = kind == RoundEvent.Type.TRICK_WON or kind == RoundEvent.Type.ROUND_ENDED
	if ends:
		_set_active(false)


## The Pass button's own command, as a click sends it.
func _pass() -> void:
	_actions.pass_turn.pressed.emit()


func _offer() -> void:
	_actions.show_sit_out(offered())


func _set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	pace_changed.emit()
	_offer()


func _my_turn() -> bool:
	return _player.is_idle() and _controller.awaiting() == RunController.AWAIT_PLAY


## True when there is a play on the table to follow, so a pass is open to the player.
func _following() -> bool:
	var view: SeatView = _controller.table.seat_view()
	return view != null and view.public.current_play != null
