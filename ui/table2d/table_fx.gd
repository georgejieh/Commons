class_name TableFx
extends Control
## The table's loud moments, drawn over everything: a word stamped down where something
## just happened, and points flying from a play to the ledger. Labels are made once and
## reused in turn. Nothing here takes the mouse or carries information the table doesn't
## also show at rest, so reduced motion can drop the movement.

const STAMPS: int = 6
const FLIERS: int = 6
const STAMP_SIZE: int = 54
const FLY_SIZE: int = 38
## A stamp lands at this tilt, in radians, like a seal pressed by hand.
const STAMP_TILT: float = -0.07
const STAMP_HOLD: float = 0.9
const FADE: float = 0.25
const FLY_TIME: float = 0.5
const TWEEN_META: StringName = &"fx_tween"

var _stamps: Array[Label] = []
var _fliers: Array[Label] = []
var _next_stamp: int = 0
var _next_flier: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index: int in STAMPS:
		_stamps.append(_made(STAMP_SIZE))
	for _index: int in FLIERS:
		_fliers.append(_made(FLY_SIZE))


## Stamps text down with its middle at a point on screen, holds, and fades.
func stamp(text: String, at: Vector2, color: Color, font_size: int = STAMP_SIZE) -> void:
	var label: Label = _stamps[_next_stamp]
	_next_stamp = (_next_stamp + 1) % STAMPS
	_show(label, text.to_upper(), color, font_size)
	label.position = at - global_position - label.size / 2.0
	UiMotion.stamp(label)
	if not UiMotion.reduced():
		label.create_tween().tween_property(label, "rotation", STAMP_TILT, 0.01).set_delay(
			UiMotion.PRESETS.stamp_time
		)
	var tween: Tween = label.create_tween()
	label.set_meta(TWEEN_META, tween)
	tween.tween_interval(UiMotion.seconds(STAMP_HOLD))
	tween.tween_property(label, "modulate:a", 0.0, UiMotion.seconds(FADE))
	tween.tween_callback(label.hide)


## Sends text from one point on screen to another, shrinking as it lands. Reduced
## motion skips it: the ledger shows the same number.
func fly(text: String, from: Vector2, to: Vector2, color: Color) -> void:
	if UiMotion.reduced():
		return
	var label: Label = _fliers[_next_flier]
	_next_flier = (_next_flier + 1) % FLIERS
	_show(label, text, color, FLY_SIZE)
	var half: Vector2 = label.size / 2.0
	label.position = from - global_position - half
	label.scale = Vector2.ONE * 1.3
	var tween: Tween = label.create_tween().set_parallel(true)
	label.set_meta(TWEEN_META, tween)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "position", to - global_position - half, FLY_TIME)
	tween.tween_property(label, "scale", Vector2.ONE * 0.7, FLY_TIME)
	tween.chain().tween_callback(label.hide)


## The words now stamped on the table, for tests.
func stamped() -> PackedStringArray:
	var words: PackedStringArray = []
	for label: Label in _stamps:
		if label.visible:
			words.append(label.text)
	return words


func _show(label: Label, text: String, color: Color, font_size: int) -> void:
	if label.has_meta(TWEEN_META):
		var running: Tween = label.get_meta(TWEEN_META)
		if running != null and running.is_valid():
			running.kill()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE
	label.rotation = 0.0
	label.modulate.a = 1.0
	label.visible = true
	move_child(label, -1)


func _made(font_size: int) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = CommonsTheme.TITLE
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ScreenKit.paper_outline(label)
	label.visible = false
	add_child(label)
	return label
