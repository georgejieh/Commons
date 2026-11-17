class_name BooksNotice
extends Control
## The state's notice that the books were corrected (ADR 0022). It hears the run's live
## events, never a replay: when BOOKS_CORRECTED arrives it takes the screen over whatever
## screen the player is on, above everything, with the sound of the office's stamp. One
## button acknowledges it, by mouse, keyboard or gamepad, and the focus stays on it while
## it shows; every key and button press goes to it, so nothing under it moves. A table
## that holds its event queue here waits until it is acknowledged. A second correction
## waits its turn behind the first. It shows every time, the first and every one after.

signal acknowledged

const DIM: Color = Color(0.05, 0.03, 0.02, 0.82)
const WIDTH: float = 900.0
const BODY_SIZE: int = 24
const LINE_SIZE: int = 22
## Over the pause menu, which draws over the arrival's layer.
const DRAW_ORDER: int = TutorialLayer.DRAW_ORDER + 2

var _controller: RunController = null
var _queue: Array[BooksNoticeText] = []
var _shown: BooksNoticeText = null
var _sheet: VBoxContainer
var _eyebrow: Label
var _title: Label
var _body: Label
var _lines: VBoxContainer = VBoxContainer.new()
var _filed: Label
var _ok: Button
## Nodes whose processing waits while a notice shows, such as the table's event queue,
## held weakly: a screen that is left goes with its nodes.
var _held: Array[WeakRef] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = DRAW_ORDER
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_sheet = ScreenKit.card(Vector2(WIDTH, 0))
	_sheet.add_theme_constant_override("separation", 14)
	_eyebrow = ScreenKit.eyebrow("")
	_title = ScreenKit.styled("", CommonsTheme.HEADLINE)
	_title.add_theme_color_override("font_color", ScreenKit.RED)
	_body = ScreenKit.label("", BODY_SIZE, ScreenKit.INK)
	_lines.add_theme_constant_override("separation", 6)
	_filed = ScreenKit.label("", LINE_SIZE, ScreenKit.INK)
	_ok = ScreenKit.button(tr("notice.ok"), CommonsTheme.PRIMARY)
	_ok.pressed.connect(_acknowledge)
	for piece: Control in [_eyebrow, _title, _body, _lines, _filed, _ok]:
		_sheet.add_child(piece)
	center.add_child(ScreenKit.card_panel(_sheet))
	visible = false
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Hears the controller's live events. The replay a screen plays when it joins a run is
## read from the log, not heard here, so it never shows a notice.
func watch(controller: RunController) -> void:
	_controller = controller
	controller.event_emitted.connect(_on_event)


## node does not process while a notice shows, so a table's queue holds still behind it.
func hold(node: Node) -> void:
	var kept: Array[WeakRef] = []
	for held: WeakRef in _held:
		if held.get_ref() != null and held.get_ref() != node:
			kept.append(held)
	kept.append(weakref(node))
	_held = kept
	if visible:
		node.set_process(false)


func is_showing() -> bool:
	return visible


## The lines on the notice showing now, for tests and the playtest.
func shown_lines() -> PackedStringArray:
	return PackedStringArray() if _shown == null else _shown.all_lines()


func acknowledge_button() -> Button:
	return _ok


## Notices still waiting behind the one showing.
func waiting() -> int:
	return _queue.size()


func _on_event(event: RunEvent) -> void:
	if event.type != RunEvent.Type.BOOKS_CORRECTED:
		return
	var dark: Array[String] = []
	if _controller != null and _controller.has_run():
		dark = _controller.state_copy().books.dark
	_queue.append(BooksNoticeText.of(event.correction, dark))
	if not visible:
		_show_next()


func _show_next() -> void:
	_shown = _queue.pop_front()
	_eyebrow.text = _shown.eyebrow.to_upper()
	_title.text = _shown.title
	_body.text = _shown.body
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for line: String in _shown.lines:
		_lines.add_child(ScreenKit.label(line, LINE_SIZE, ScreenKit.INK))
	_lines.visible = not _shown.lines.is_empty()
	_filed.text = _shown.filed
	visible = true
	move_to_front()
	_process_held(false)
	Audio.play(AudioEvents.STORE_BUY)
	UiMotion.stamp(ScreenKit.card_panel(_sheet))
	_ok.grab_focus()


func _acknowledge() -> void:
	if not _queue.is_empty():
		_show_next()
		return
	visible = false
	_shown = null
	_process_held(true)
	acknowledged.emit()


func _process_held(on: bool) -> void:
	for held: WeakRef in _held:
		var found: Object = held.get_ref()
		var node: Node = found as Node
		if node != null:
			node.set_process(on)


## While the notice shows it takes every key and button: accept acknowledges it, and
## nothing else reaches the screen under it. The mouse goes through the GUI, where the
## dim stops it short of the screen.
func _input(event: InputEvent) -> void:
	if not visible or event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		_acknowledge()
	elif not _ok.has_focus():
		_ok.grab_focus()


## A screen that opens under the notice takes the focus for itself; it comes back here.
func _on_focus_changed(control: Control) -> void:
	if visible and control != _ok:
		_ok.grab_focus.call_deferred()
