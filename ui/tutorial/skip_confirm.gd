class_name SkipConfirm
extends Control
## Asks once before the arrival is skipped (ADR 0026): "Skip the arrival?" with Skip and
## Stay. Stay has the focus, so a stray accept press keeps the player in, and Cancel
## stays too.

signal skipped
signal stayed

const DIM: Color = Color(0.05, 0.03, 0.02, 0.7)
const QUESTION_SIZE: int = 28

var _question: Label
var _stay: Button
var _skip: Button
var _before: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var sheet: VBoxContainer = ScreenKit.card(Vector2(460, 0))
	sheet.add_theme_constant_override("separation", 14)
	_question = ScreenKit.label(tr("tutorial.skip.confirm"), QUESTION_SIZE, ScreenKit.INK)
	sheet.add_child(_question)
	_stay = ScreenKit.button(tr("tutorial.skip.no"), CommonsTheme.PRIMARY)
	_stay.pressed.connect(_answer.bind(false))
	_skip = ScreenKit.button(tr("tutorial.skip.yes"), CommonsTheme.GHOST)
	_skip.pressed.connect(_answer.bind(true))
	for button: Button in [_stay, _skip]:
		button.size_flags_horizontal = Control.SIZE_FILL
		sheet.add_child(button)
	center.add_child(ScreenKit.card_panel(sheet))
	visible = false


## Asks, at the text size chosen now: the question outlives screens.
func ask() -> void:
	_question.add_theme_font_size_override("font_size", TextSize.px(QUESTION_SIZE))
	_before = get_viewport().gui_get_focus_owner()
	visible = true
	move_to_front()
	_stay.grab_focus()


func is_asking() -> bool:
	return visible


func stay_button() -> Button:
	return _stay


func skip_button() -> Button:
	return _skip


func _answer(skip: bool) -> void:
	visible = false
	if skip:
		skipped.emit()
		return
	if _before != null and is_instance_valid(_before) and _before.is_visible_in_tree():
		_before.grab_focus()
	stayed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_answer(false)
		get_viewport().set_input_as_handled()
