class_name ReadingPicker
extends Control
## Asks how the chosen cards are played when they can be played more than one way now (ADR
## 0029): a paper slip beside the chosen cards it asks about, placed as every slip is
## (SlipPlacer: above them first, never on them or on a button), listing each reading in
## words, strongest first. Focus starts on the strongest; up and down move it, confirm
## plays the one focused and cancel closes the slip with the selection kept. A click
## outside the slip cancels too. The table stays visible, a little dimmed, so the lifted
## cards can still be seen. Buttons sound as every button does.

signal chosen(reading: Pattern)
signal closed

## The highest the slip's top may sit, under the HUD, and its gap from the cards.
const TOP: float = 96.0
const GAP: float = 8.0
const WIDTH: float = 520.0
const DIM: Color = Color(0.05, 0.03, 0.02, 0.45)
const PADDING: int = 22
const FONT_SIZE: int = 22

## Holds the slip and carries its fit, so the slip's own scale stays the entrance's.
var _holder: Control = Control.new()
var _slip: PanelContainer = PanelContainer.new()
var _list: VBoxContainer = VBoxContainer.new()
var _cancel: Button
var _buttons: Array[Button] = []
var _readings: Array[Pattern] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_slip.add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	_slip.custom_minimum_size = Vector2(WIDTH, 0)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_holder.add_child(_slip)
	_list.add_theme_constant_override("separation", 10)
	_slip.add_child(_list)
	_list.add_child(ScreenKit.eyebrow(tr("reading.title")))
	_cancel = ScreenKit.button(tr("reading.cancel"), CommonsTheme.GHOST)
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(close)
	_list.add_child(_cancel)
	visible = false


## Opens the slip on these readings, strongest first, with focus on the first, beside the
## cards they read, a rectangle on screen.
func open(readings: Array[Pattern], beside: Rect2) -> void:
	_readings = readings.duplicate()
	for button: Button in _buttons:
		_list.remove_child(button)
		button.queue_free()
	_buttons.clear()
	var words: PackedStringArray = ReadingText.describe_all(_readings)
	for index: int in _readings.size():
		var kind: String = CommonsTheme.PRIMARY if index == 0 else CommonsTheme.SECONDARY
		var button: Button = ScreenKit.button(words[index], kind)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", TextSize.px(FONT_SIZE))
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_choose.bind(index))
		_list.add_child(button)
		_list.move_child(button, index + 1)
		_buttons.append(button)
	_cancel.focus_mode = Control.FOCUS_ALL
	visible = true
	move_to_front()
	_place(beside)
	_keep_focus_inside()
	_buttons[0].grab_focus()
	UiMotion.enter([_slip] as Array[Control])


## Closes the slip without playing; the selection stays as it was.
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Keyboard and gamepad while the slip is open: up and down move the focus, confirm plays
## the reading focused, cancel closes. Every other key is kept from the table. Returns true
## when the slip is open, so the table acts on nothing else.
func handle(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_down", true):
		_step(1)
	elif event.is_action_pressed("ui_up", true):
		_step(-1)
	elif event.is_action_pressed("ui_accept"):
		var at: int = focused()
		if at >= 0 and at < _buttons.size():
			_choose(at)
		elif at == _buttons.size():
			close()
	return true


## The index of the focused choice, the readings' count for Cancel, or -1.
func focused() -> int:
	for index: int in _buttons.size():
		if _buttons[index].has_focus():
			return index
	return _buttons.size() if _cancel.has_focus() else -1


## The readings' words as listed, for tests and playtests.
func shown() -> PackedStringArray:
	var words: PackedStringArray = []
	for button: Button in _buttons:
		words.append(button.text)
	return words


## The slip's rectangle on screen.
func slip_rect() -> Rect2:
	return _slip.get_global_rect()


func choice(index: int) -> Button:
	return _buttons[index]


func cancel_button() -> Button:
	return _cancel


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	var outside: bool = click != null and not slip_rect().has_point(click.global_position)
	if outside and click.pressed:
		close()
		accept_event()


func _step(by: int) -> void:
	var count: int = _buttons.size() + 1
	var at: int = clampi(focused() + by, 0, count - 1)
	if at == _buttons.size():
		_cancel.grab_focus()
	else:
		_buttons[at].grab_focus()


func _choose(index: int) -> void:
	var reading: Pattern = _readings[index]
	visible = false
	chosen.emit(reading)


## Up and down run through the choices and Cancel and stop at the ends; left and right
## stay put, so focus never leaves the slip for the table behind it.
func _keep_focus_inside() -> void:
	var order: Array[Button] = _buttons.duplicate()
	order.append(_cancel)
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


## Stands the slip beside the cards, by the rule every slip keeps, its top no higher
## than TOP. Four wild cards in one play can read more than a dozen ways: a slip taller
## than the room over the cards is drawn smaller, whole, so every reading and Cancel can
## still be clicked.
func _place(beside: Rect2) -> void:
	_slip.reset_size()
	var tall: float = _slip.get_combined_minimum_size().y
	var room: float = beside.position.y - GAP - TOP
	var fit: float = minf(1.0, room / tall) if room > 0.0 else 1.0
	_slip.size = Vector2(WIDTH, tall)
	_slip.position = Vector2.ZERO
	_holder.scale = Vector2(fit, fit)
	var screen: Rect2 = Rect2(Vector2(0.0, TOP), get_viewport_rect().size - Vector2(0.0, TOP))
	var placed: Vector2 = Vector2(WIDTH, tall) * fit
	_holder.position = SlipPlacer.place(placed, beside, GAP, screen, get_parent(), self)
