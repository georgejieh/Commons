class_name EpilogueList
extends ScrollContainer
## The epilogue's lines (ADR 0024), arriving one after another a short beat apart, or all
## at once under reduced motion or when skipped. When they outgrow the page the list
## scrolls: by wheel, and by up and down on a keyboard or gamepad while it has focus,
## handing focus on once it reaches the end.

## Sent once every line has been shown, so the page can hand the focus on.
signal revealed

## The size of an epilogue line, at Standard text.
const LINE_SIZE: int = 22
## The gap between lines, in pixels.
const LINE_GAP: int = 14
## Seconds a line takes to fade in.
const FADE: float = 0.2
## How far one up or down press scrolls.
const STEP: int = 90

var _column: VBoxContainer = VBoxContainer.new()
var _lines: Array[Label] = []
var _shown: int = 0
var _tween: Tween = null
var _done: bool = false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = false
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", LINE_GAP)
	add_child(_column)
	get_v_scroll_bar().changed.connect(_update_focus)


## Fills the list with a label for each line, hidden until it is revealed.
func set_lines(lines: Array[String]) -> void:
	for line: String in lines:
		var label: Label = ScreenKit.label(line, LINE_SIZE, ScreenKit.INK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.modulate.a = 0.0
		_column.add_child(label)
		_lines.append(label)


## The line labels in order, for tests and the playtest.
func line_labels() -> Array[Label]:
	return _lines.duplicate()


## Brings the lines in one a beat apart, or all at once under reduced motion.
func reveal(beat: float) -> void:
	if UiMotion.reduced() or _lines.is_empty():
		show_all()
		return
	_tween = create_tween()
	for index: int in _lines.size():
		_tween.tween_interval(beat)
		_tween.tween_callback(_show_line.bind(index))
	_tween.tween_callback(_finish)


## True until every line has been shown.
func is_revealing() -> bool:
	return not _done


## How many lines are showing.
func shown_count() -> int:
	return _shown


## Shows every line at once, as a skip does.
func show_all() -> void:
	if _tween != null:
		_tween.kill()
	for label: Label in _lines:
		label.modulate.a = 1.0
	_shown = _lines.size()
	_finish()


func _show_line(index: int) -> void:
	Audio.fill(AudioEvents.MOTION_PULSE)
	_shown = index + 1
	var label: Label = _lines[index]
	var fade: Tween = label.create_tween()
	fade.tween_property(label, "modulate:a", 1.0, FADE)
	ensure_control_visible(label)


func _finish() -> void:
	_tween = null
	if _done:
		return
	_done = true
	revealed.emit()


## Focus is offered only while there is something to scroll to.
func _update_focus() -> void:
	var bar: VScrollBar = get_v_scroll_bar()
	focus_mode = Control.FOCUS_ALL if bar.max_value > bar.page + 1.0 else Control.FOCUS_NONE


## True while the lines outgrow the page, so the list takes the focus for up and down.
func can_scroll() -> bool:
	return focus_mode == Control.FOCUS_ALL


func _gui_input(event: InputEvent) -> void:
	var bar: VScrollBar = get_v_scroll_bar()
	var bottom: float = bar.max_value - bar.page
	if event.is_action_pressed("ui_down") and scroll_vertical < bottom - 1.0:
		scroll_vertical += STEP
		accept_event()
	elif event.is_action_pressed("ui_up") and scroll_vertical > 0:
		scroll_vertical -= STEP
		accept_event()
