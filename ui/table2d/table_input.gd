class_name TableInput
extends RefCounted
## Keyboard and gamepad at the table. Shortcuts press the same buttons a click
## does, and Deck opens the deck sheet as the menu's Deck does (ADR 0041); Escape or the
## gamepad's B closes the rules card or opens the menu; on the player's turn the cursor
## actions move along the hand and pick cards.

## The Campaign tray, which takes its keys first.
var tray: CampaignTray = null
## The reading picker, which takes every key while it is open (ADR 0029).
var picker: ReadingPicker = null

var _pause: PauseMenu
var _cheat_sheet: CheatSheet
var _actions: ActionBar
var _hand_view: HandView
var _controller: RunController
var _open_pause: Callable
var _open_deck: Callable


## Gives the input the menu, the rules card, the action bar, the hand and the run it acts on, and
## the callables that open the menu and the deck sheet.
func setup(
	pause: PauseMenu,
	cheat_sheet: CheatSheet,
	actions: ActionBar,
	hand_view: HandView,
	controller: RunController,
	open_pause: Callable,
	open_deck: Callable
) -> void:
	_pause = pause
	_cheat_sheet = cheat_sheet
	_actions = actions
	_hand_view = hand_view
	_controller = controller
	_open_pause = open_pause
	_open_deck = open_deck


## Acts on event and returns true when it used it.
func handle(event: InputEvent) -> bool:
	if picker != null and picker.handle(event):
		return true
	if _handle_tray(event):
		return true
	if event.is_action_pressed("ui_cancel") and not _pause.visible:
		if _cheat_sheet.visible:
			_cheat_sheet.visible = false
		else:
			_open_pause.call()
		return true
	if _pause.visible or _cheat_sheet.visible:
		return false
	if event.is_action_pressed(KeyBindings.DECK):
		_open_deck.call()
		return true
	return _hand_cursor(event) or _shortcut(event)


## The tray goes first, so Cancel takes back an armed Campaign before it opens the menu.
func _handle_tray(event: InputEvent) -> bool:
	return tray != null and not _pause.visible and not _cheat_sheet.visible and tray.handle(event)


func _shortcut(event: InputEvent) -> bool:
	var shortcuts: Dictionary[String, Button] = {
		KeyBindings.PLAY: _play_button(),
		KeyBindings.PASS:
		_actions.decline if _actions.decline.is_visible_in_tree() else _actions.pass_turn,
		KeyBindings.SIT_OUT: _actions.sit_out,
		KeyBindings.HINT: _actions.hint,
		KeyBindings.SORT: _actions.sort,
		KeyBindings.RULES: _actions.rules,
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


func _play_button() -> Button:
	if _actions.call_landlord.is_visible_in_tree():
		return _actions.call_landlord
	return _actions.play_on if _actions.play_on.is_visible_in_tree() else _actions.play


func _hand_cursor(event: InputEvent) -> bool:
	var choosing: Array[int] = [RunController.AWAIT_PLAY, RunController.AWAIT_OPENING]
	if not choosing.has(_controller.awaiting()):
		return false
	if event.is_action_pressed(KeyBindings.CURSOR_LEFT, true):
		_hand_view.move_cursor(-1)
	elif event.is_action_pressed(KeyBindings.CURSOR_RIGHT, true):
		_hand_view.move_cursor(1)
	elif event.is_action_pressed(KeyBindings.SELECT):
		_hand_view.toggle_cursor()
	else:
		return false
	return true
