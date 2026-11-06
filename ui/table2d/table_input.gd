class_name TableInput
extends RefCounted
## Keyboard and gamepad at the table (P3B.11). Shortcuts press the same buttons a click
## does; Escape or the gamepad's B closes the rules card or opens the menu; on the
## player's turn the cursor actions move along the hand and pick cards.

var _pause: PauseMenu
var _cheat_sheet: CheatSheet
var _actions: ActionBar
var _hand_view: HandView
var _controller: RunController
var _open_pause: Callable


func setup(
	pause: PauseMenu,
	cheat_sheet: CheatSheet,
	actions: ActionBar,
	hand_view: HandView,
	controller: RunController,
	open_pause: Callable
) -> void:
	_pause = pause
	_cheat_sheet = cheat_sheet
	_actions = actions
	_hand_view = hand_view
	_controller = controller
	_open_pause = open_pause


## Acts on event and returns true when it used it.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") and not _pause.visible:
		if _cheat_sheet.visible:
			_cheat_sheet.visible = false
		else:
			_open_pause.call()
		return true
	if _pause.visible or _cheat_sheet.visible:
		return false
	return _hand_cursor(event) or _shortcut(event)


func _shortcut(event: InputEvent) -> bool:
	var shortcuts: Dictionary[String, Button] = {
		"commons_play": _actions.call if _actions.call.is_visible_in_tree() else _actions.play,
		"commons_pass":
		_actions.decline if _actions.decline.is_visible_in_tree() else _actions.pass_turn,
		"commons_hint": _actions.hint,
		"commons_sort": _actions.sort,
		"commons_rules": _actions.rules,
	}
	for action: String in shortcuts:
		var button: Button = shortcuts[action]
		if event.is_action_pressed(action) and button.is_visible_in_tree() and not button.disabled:
			if button.toggle_mode:
				button.button_pressed = not button.button_pressed
			else:
				button.pressed.emit()
			return true
	return false


func _hand_cursor(event: InputEvent) -> bool:
	if _controller.awaiting() != RunController.AWAIT_PLAY:
		return false
	if event.is_action_pressed("commons_cursor_left", true):
		_hand_view.move_cursor(-1)
	elif event.is_action_pressed("commons_cursor_right", true):
		_hand_view.move_cursor(1)
	elif event.is_action_pressed("commons_select"):
		_hand_view.toggle_cursor()
	else:
		return false
	return true
