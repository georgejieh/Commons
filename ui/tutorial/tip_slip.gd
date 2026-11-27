class_name TipSlip
extends Control
## A one-time tooltip (ADR 0026): a paper slip over a light scrim with one line of text
## and "Got it", which takes the focus. Dismissing it is what the profile remembers, so
## each shows once per profile, the first time its subject comes up in a full run. Tips
## due together show one after another. It stands in the middle of the screen, or of
## its right half where the screen's own sheet fills the left.

## Emitted with the tip's id when the player takes Got it, which the profile remembers.
signal dismissed(tip_id: String)

## The scrim laid over the screen behind the slip.
const DIM: Color = Color(0.05, 0.03, 0.02, 0.45)
## The slip's width in pixels.
const WIDTH: float = 620.0
## The type size of the tip's line, at Standard.
const TEXT_SIZE: int = 24

var _app: App
var _queue: Array[String] = []
var _shown: String = ""
var _paper: PanelContainer
var _text: Label
var _got_it: Button
var _before: Control = null
var _right_half: bool = false


## Adds a slip to host for whichever of tip_ids are due now, and shows the first. Returns
## the slip, or null when none is due. right_half keeps it off a sheet on the left.
static func offer(
	host: Control, app: App, tip_ids: Array[String], right_half: bool = false
) -> TipSlip:
	var due: Array[String] = []
	for tip_id: String in tip_ids:
		if app.arrival.tip_due(tip_id):
			due.append(tip_id)
	if due.is_empty():
		return null
	var slip: TipSlip = TipSlip.new()
	slip._app = app
	slip._queue = due
	slip._right_half = right_half
	host.add_child(slip)
	slip._next.call_deferred()
	return slip


func _ready() -> void:
	# Offsets too: anchors alone leave a new control with no size, and the slip in a corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _right_half:
		center.anchor_left = 0.5
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_paper = PanelContainer.new()
	_paper.add_theme_stylebox_override("panel", ScreenKit.paper_style(22))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_paper.add_child(column)
	_text = ScreenKit.label("", TEXT_SIZE, ScreenKit.INK)
	_text.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(_text)
	_got_it = ScreenKit.button(tr("tip.got_it"), CommonsTheme.PRIMARY)
	_got_it.size_flags_horizontal = Control.SIZE_SHRINK_END
	_got_it.pressed.connect(_dismiss)
	column.add_child(_got_it)
	center.add_child(_paper)


## The tooltip shown now, or "" once all are dismissed.
func shown() -> String:
	return _shown


## The Got it button, for tests.
func got_it_button() -> Button:
	return _got_it


## Where the paper stands on screen.
func paper_rect() -> Rect2:
	return _paper.get_global_rect()


func _next() -> void:
	# The screen may have gone, and the slip with it, before a deferred call lands.
	if not is_inside_tree():
		return
	if _queue.is_empty():
		_shown = ""
		if _before != null and is_instance_valid(_before) and _before.is_visible_in_tree():
			_before.grab_focus()
		queue_free()
		return
	if _before == null:
		_before = get_viewport().gui_get_focus_owner()
	_shown = _queue.pop_front()
	_text.text = tr(_shown)
	move_to_front()
	_got_it.grab_focus()


func _dismiss() -> void:
	var tip_id: String = _shown
	_app.arrival.tip_seen(tip_id)
	dismissed.emit(tip_id)
	_next()
