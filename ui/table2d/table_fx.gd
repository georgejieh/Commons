class_name TableFx
extends Control
## Numbers in flight over the table: a play's points leaving the tally for the ledger, and
## the small tags of what each thing that fired added to a play's score, beside it. Labels
## are made once and reused in turn. Nothing here takes the mouse. A flight carries nothing
## the table doesn't show at rest, so reduced motion drops it; a tag still shows under
## reduced motion, standing still, since it says what the tally's figures only show the sum
## of.

const FLIERS: int = 6
const FLY_SIZE: int = 38
const FLY_TIME: float = 0.5
const TAGS: int = 6
const TAG_SIZE: int = 22
## A tag stands this far above what it labels, and never higher than the bar's foot.
const TAG_GAP: float = 4.0
const TAG_TOP: float = 82.0

var _fliers: Array[Label] = []
var _next_flier: int = 0
var _tags: Array[Label] = []
var _next_tag: int = 0
## Each label's flight or tag under way, so the label's next use replaces it.
var _tweens: Dictionary[Label, Tween] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index: int in FLIERS:
		_fliers.append(_made(FLY_SIZE))
	for _index: int in TAGS:
		_tags.append(_made(TAG_SIZE))


## Shows a short tag, such as "+30 Grain", just above a box on screen, or below it when
## there is no room above. It rises a little as it fades, or under reduced motion stands
## still until it goes. Returns the tag, for tests.
func tag(text: String, around: Rect2, color: Color) -> Label:
	var label: Label = _tags[_next_tag]
	_next_tag = (_next_tag + 1) % TAGS
	_show(label, text, color, TAG_SIZE)
	var at: Vector2 = Vector2(
		around.get_center().x - label.size.x / 2.0, around.position.y - TAG_GAP - label.size.y
	)
	if at.y < TAG_TOP:
		at.y = around.end.y + TAG_GAP
	at.x = clampf(at.x, TAG_GAP, maxf(TAG_GAP, size.x - label.size.x - TAG_GAP))
	label.position = at - global_position
	var hold: float = UiMotion.PRESETS.score_label_time
	var tween: Tween = label.create_tween()
	_tweens[label] = tween
	if UiMotion.reduced():
		tween.tween_interval(hold)
	else:
		tween.set_parallel(true)
		tween.tween_property(
			label, "position:y", label.position.y - UiMotion.PRESETS.score_label_rise, hold
		)
		tween.tween_property(label, "modulate:a", 0.0, hold * 0.4).set_delay(hold * 0.6)
		tween.chain()
	tween.tween_callback(label.hide)
	return label


## The tags showing now, for tests.
func shown_tags() -> Array[Label]:
	var shown: Array[Label] = []
	for label: Label in _tags:
		if label.visible:
			shown.append(label)
	return shown


## Sends text from one point on screen to another, shrinking as it lands. Reduced
## motion skips it: the ledger shows the same number.
func fly(text: String, from: Vector2, to: Vector2, color: Color) -> void:
	if UiMotion.reduced():
		return
	Audio.fill(AudioEvents.MOTION_FLY)
	var label: Label = _fliers[_next_flier]
	_next_flier = (_next_flier + 1) % FLIERS
	_show(label, text, color, FLY_SIZE)
	var half: Vector2 = label.size / 2.0
	label.position = from - global_position - half
	label.scale = Vector2.ONE * 1.3
	var tween: Tween = label.create_tween().set_parallel(true)
	_tweens[label] = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "position", to - global_position - half, FLY_TIME)
	tween.tween_property(label, "scale", Vector2.ONE * 0.7, FLY_TIME)
	tween.chain().tween_callback(label.hide)


func _show(label: Label, text: String, color: Color, font_size: int) -> void:
	UiMotion.end(_tweens.get(label))
	label.text = text
	label.add_theme_font_size_override("font_size", TextSize.px(font_size))
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
	label.add_theme_font_size_override("font_size", TextSize.px(font_size))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ScreenKit.paper_outline(label)
	label.visible = false
	add_child(label)
	return label
