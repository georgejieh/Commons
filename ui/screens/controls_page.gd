class_name ControlsPage
extends VBoxContainer
## The Controls page (ADR 0035), a page of its own at the title and in the pause menu:
## on one paper sheet, each table action with its key on a ticket and its gamepad button
## beside it as the Steam Deck prints it, and a ticket that restores the defaults; under
## the sheet, Back. Pressing a key's ticket asks for a key, and the next key pressed after
## that is bound, so the Enter that pressed the ticket is not taken. Escape, the gamepad's
## back button or a click cancels the asking, and nothing under the page sees what it
## takes. Escape otherwise backs out. Menu keys are not on the page and never change, so
## no set of bindings can lock a player in or out of it. Changes apply and save at once.
## The Hint's row is left out while the player keeps the Hint off (HintSetting).

## Back was pressed, or Escape outside the asking.
signal leave

## Each gamepad button the actions use, by the end of its string key.
const PAD_NAMES: Dictionary[JoyButton, String] = {
	JOY_BUTTON_A: "a",
	JOY_BUTTON_B: "b",
	JOY_BUTTON_X: "x",
	JOY_BUTTON_Y: "y",
	JOY_BUTTON_BACK: "view",
	JOY_BUTTON_START: "menu",
	JOY_BUTTON_LEFT_SHOULDER: "l1",
	JOY_BUTTON_RIGHT_SHOULDER: "r1",
	JOY_BUTTON_DPAD_UP: "dpad_up",
	JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left",
	JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}
## The name of each key's ticket, for the focus and for tests.
const TICKET: String = "Key_%s"
const NAME_SIZE: int = 24
const PAD_SIZE: int = 22
## The most the rows stand before they scroll inside the sheet, so Back stays on screen
## at the largest text size (ADR 0034): in the pause menu, and under a page's header.
const ROWS_CAP: float = 600.0
const ROWS_CAP_UNDER_HEADER: float = 540.0

var _tickets: Dictionary[String, Button] = {}
## The Hint's row: its name, its ticket and its gamepad button.
var _hint_row: Array[Control] = []
var _rows_scroll: ProseScroll
var _rows_cap: float = 0.0
var _restore: Button
var _back: Button
## The action asking for a key, or "" while none is, and the frame the asking began in.
var _capturing: String = ""
var _capture_frame: int = -1


## With titled, the sheet carries the page's name, for a place with no header of its own;
## without, the rows leave room for the page's header.
func _init(titled: bool = false) -> void:
	add_theme_constant_override("separation", 16)
	var sheet: VBoxContainer = ScreenKit.card(Vector2(760, 0))
	sheet.add_theme_constant_override("separation", 14)
	if titled:
		sheet.add_child(ScreenKit.eyebrow(tr("controls.title")))
	sheet.add_child(ScreenKit.styled(tr("controls.help"), CommonsTheme.CAPTION))
	var grid: GridContainer = _rows()
	var rows: ProseScroll = ProseScroll.new(grid)
	_rows_scroll = rows
	_rows_cap = ROWS_CAP if titled else ROWS_CAP_UNDER_HEADER
	rows.fit_to(_rows_cap)
	grid.sort_children.connect(_whole_rows.bind(grid))
	ScrollFade.over(rows)
	sheet.add_child(rows)
	_restore = ScreenKit.button(tr("controls.restore"), CommonsTheme.GHOST)
	_restore.pressed.connect(restore_defaults)
	sheet.add_child(_restore)
	add_child(ScreenKit.card_panel(sheet))
	_back = ScreenKit.button(tr("settings.back"), CommonsTheme.PRIMARY)
	_back.size_flags_horizontal = Control.SIZE_FILL
	_back.pressed.connect(_leave)
	add_child(_back)
	_show_hint_row()
	visibility_changed.connect(_on_visibility)


## The rows' scroll, for tests.
func rows_scroll() -> ProseScroll:
	return _rows_scroll


## The scroll stops at the foot of the last row that fits under its cap, so no row is
## left sliced at the cut: the next one lies whole below it, with the fade over the edge.
func _whole_rows(grid: GridContainer) -> void:
	var tall: float = grid.get_combined_minimum_size().y
	if tall <= _rows_cap:
		_rows_scroll.fit_to(_rows_cap)
		return
	var fits: float = 0.0
	var cells: Array[Control] = []
	for child: Node in grid.get_children():
		if (child as Control).visible:
			cells.append(child as Control)
	var count: int = cells.size()
	for first: int in range(0, count, grid.columns):
		var foot: float = 0.0
		for index: int in range(first, mini(first + grid.columns, count)):
			var cell: Control = cells[index]
			foot = maxf(foot, cell.position.y + cell.size.y)
		if foot > _rows_cap:
			break
		fits = foot
	_rows_scroll.fit_to(fits if fits > 0.0 else _rows_cap)


## Up and down run through the tickets, Restore defaults and Back, and stop at the ends;
## left and right stay put, so the focus never drops into the scroll or off the page.
func _link_focus() -> void:
	var order: Array[Button] = []
	for action: String in KeyBindings.ACTIONS:
		if _tickets[action].visible:
			order.append(_tickets[action])
	order.append_array([_restore, _back])
	for index: int in order.size():
		var button: Button = order[index]
		var above: Button = order[maxi(index - 1, 0)]
		var below: Button = order[mini(index + 1, order.size() - 1)]
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		button.focus_previous = button.get_path_to(above)
		button.focus_next = button.get_path_to(below)
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)


## The Hint's row shows only while the Hint is on; the focus runs past it when it is not.
func _show_hint_row() -> void:
	for cell: Control in _hint_row:
		cell.visible = HintSetting.shown()
	_link_focus()


## The focus goes to the first key's ticket.
func focus_first() -> void:
	_tickets[KeyBindings.ACTIONS[0]].grab_focus()


func ticket(action: String) -> Button:
	return _tickets[action]


func restore_button() -> Button:
	return _restore


func back_button() -> Button:
	return _back


## The action asking for a key, or "".
func capturing() -> String:
	return _capturing


## Asks for the action's new key.
func capture(action: String) -> void:
	_capturing = action
	_capture_frame = Engine.get_process_frames()
	_tickets[action].text = tr("controls.press")


func cancel_capture() -> void:
	_capturing = ""
	_show_keys()


func restore_defaults() -> void:
	cancel_capture()
	Settings.bindings.restore_defaults()
	Settings.save()
	_show_keys()


## The gamepad button's name for an action, as the Deck prints it, or "" for none.
static func pad_name(action: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		if button != null and PAD_NAMES.has(button.button_index):
			return TranslationServer.translate("controls.pad." + PAD_NAMES[button.button_index])
	return ""


func _rows() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for heading: String in ["action", "key", "pad"]:
		grid.add_child(ScreenKit.eyebrow(tr("controls.heading." + heading)))
	for action: String in KeyBindings.ACTIONS:
		var name: Label = ScreenKit.label(tr("controls.action." + action), NAME_SIZE)
		name.custom_minimum_size = Vector2(200, 0)
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(name)
		var key: Button = ScreenKit.button("", CommonsTheme.SECONDARY)
		key.name = TICKET % action
		key.pressed.connect(capture.bind(action))
		_tickets[action] = key
		grid.add_child(key)
		var pad: Label = ScreenKit.label(ControlsPage.pad_name(action), PAD_SIZE)
		pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(pad)
		if action == HintSetting.ACTION:
			_hint_row.assign([name, key, pad])
	_show_keys()
	return grid


func _show_keys() -> void:
	for action: String in _tickets:
		_tickets[action].text = KeyBindings.label(Settings.bindings.key(action))


## While asking, every key, button and click is the page's: the next key press binds,
## Escape, the back button or a click cancels, and releases and the frame the asking
## began in are let go by, so the press that opened it is never the answer.
func _input(event: InputEvent) -> void:
	if _capturing.is_empty() or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null:
		if event is InputEventMouseButton or event.is_action_pressed("ui_cancel"):
			cancel_capture()
		return
	if Engine.get_process_frames() == _capture_frame:
		return
	var pressed: Key = KeyBindings.key_of(key)
	if pressed == KEY_ESCAPE:
		cancel_capture()
	elif KeyBindings.allowed(pressed):
		Settings.bindings.bind(_capturing, pressed)
		Settings.save()
		cancel_capture()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	cancel_capture()
	leave.emit()


func _on_visibility() -> void:
	if not is_visible_in_tree() and not _capturing.is_empty():
		cancel_capture()
	if is_visible_in_tree():
		_show_hint_row()
