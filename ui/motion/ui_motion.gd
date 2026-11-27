class_name UiMotion
extends RefCounted
## Interface motion for every screen: buttons that lift on hover and sink when pressed,
## pieces that fade and settle in one after another, numbers that roll, and stamps that
## land. Motion uses scale and fade, never position, so containers keep their layout.
## Every tween belongs to the node it moves. Reduced motion shortens or skips it all.
## Each kind of motion has its own sound, filled in through Audio.fill only where
## the moment's event has none, and played under reduced motion too.

## The motion presets: how long each kind of motion takes, and the reduced-motion scale.
const PRESETS: MotionPresets = preload("res://data/ui/motion_presets.tres")
## The reduced-motion setting (ADR 0035).
const SETTING: String = "reduced_motion"
## A piece starts its entrance this much smaller.
const ENTER_SCALE: float = 0.96
## Where a control keeps its hover tween, so a new one replaces it.
const TWEEN_META: StringName = &"ui_motion_tween"
## Marks a control that lifts on hover. Its scale is its hover's, so an entrance only
## fades it.
const LIFTS: StringName = &"ui_motion_lifts"
## Marks a control whose pivot follows its size.
const CENTRED: StringName = &"ui_motion_centred"
## Where a rolling label keeps the width it had before the first roll reserved room.
const WIDTH_META: StringName = &"ui_motion_width"
## The digits a rolling label measures, so it keeps the room of its widest figure.
const DIGITS: String = "0123456789"


## True when the reduced-motion setting is on.
static func reduced() -> bool:
	return bool(Settings.value(SETTING))


## A motion's base duration in seconds, shortened when motion is reduced.
static func seconds(base: float) -> float:
	return base * (PRESETS.reduced_scale if reduced() else 1.0)


## Ends a tween where it stands, if there is one still alive.
static func end(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


## Lifts a control on hover or focus and sinks it while pressed.
static func hoverable(control: Control) -> void:
	control.set_meta(LIFTS, true)
	_center_pivot(control)
	control.mouse_entered.connect(_scale_to.bind(control, PRESETS.hover_scale))
	control.mouse_entered.connect(Audio.fill.bind(AudioEvents.MOTION_HOVER))
	control.mouse_exited.connect(_scale_to.bind(control, 1.0))
	control.focus_entered.connect(_scale_to.bind(control, PRESETS.hover_scale))
	control.focus_exited.connect(_scale_to.bind(control, 1.0))
	var button: BaseButton = control as BaseButton
	if button != null:
		button.button_down.connect(_scale_to.bind(control, PRESETS.press_scale))
		button.button_up.connect(_scale_to.bind(control, PRESETS.hover_scale))


## Fades and settles controls in one after another, slowly enough to be read and with
## the last one in by enter_within however many there are. Nothing waits on it: a button
## takes a press while it is still arriving.
static func enter(controls: Array[Control]) -> void:
	Audio.fill(AudioEvents.MOTION_ENTER)
	var stagger: float = PRESETS.enter_stagger
	if controls.size() > 1:
		var room: float = PRESETS.enter_within - PRESETS.enter_time
		stagger = minf(stagger, room / (controls.size() - 1))
	for index: int in controls.size():
		enter_at(controls[index], index * stagger)


## Brings one control in after delay seconds. A quiet piece (small print, a row of minor
## buttons) only fades, and so does a control that lifts on hover, whose scale is its
## hover's.
static func enter_at(control: Control, delay: float, quiet: bool = false) -> void:
	if reduced():
		return
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, PRESETS.enter_time).set_delay(delay)
	if quiet or control.has_meta(LIFTS):
		return
	_center_pivot(control)
	control.scale = Vector2.ONE * ENTER_SCALE
	tween.tween_property(control, "scale", Vector2.ONE, PRESETS.enter_time).set_delay(delay)


## Lays a full-screen picture down: from a little large to its size, about its middle.
static func settle(picture: Control) -> void:
	Audio.fill(AudioEvents.MOTION_SETTLE)
	if reduced():
		return
	_center_pivot(picture)
	picture.scale = Vector2.ONE * PRESETS.settle_from
	var tween: Tween = picture.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(picture, "scale", Vector2.ONE, PRESETS.settle_time)


## Rolls a label's number from one value to another; shown formats each step. Returns
## the tween, or null when the number was set at once. The label keeps room for its
## widest digits while it rolls and after, so a face whose digits differ in width (Oswald
## has no tabular figures) moves nothing beside it, with motion or without.
static func count(label: Label, from: float, to: float, shown: Callable) -> Tween:
	var last: String = shown.call(to)
	var ends: Array[String] = [last]
	if reduced() or is_equal_approx(from, to):
		label.text = last
		_reserve(label, ends)
		return null
	Audio.fill(AudioEvents.MOTION_COUNT)
	var both: Array[String] = [shown.call(from), last]
	_reserve(label, both)
	var tween: Tween = label.create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(value: float) -> void: label.text = shown.call(value), from, to, PRESETS.count_time
	)
	tween.tween_callback(_reserve.bind(label, ends))
	return tween


## The width a text takes with each of its digits as wide as the face's widest.
static func widest(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	var px: int = label.get_theme_font_size("font_size")
	var wide: String = DIGITS[0]
	var most: float = 0.0
	for digit: String in DIGITS:
		var across: float = font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if across > most:
			most = across
			wide = digit
	var padded: String = text
	for digit: String in DIGITS:
		padded = padded.replace(digit, wide)
	return ceilf(font.get_string_size(padded, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)


## Keeps a rolling label at least as wide as the widest of texts, and no narrower than
## it was asked to be before its first roll.
static func _reserve(label: Label, texts: Array[String]) -> void:
	if not label.has_meta(WIDTH_META):
		label.set_meta(WIDTH_META, label.custom_minimum_size.x)
	var room: float = label.get_meta(WIDTH_META)
	for text: String in texts:
		room = maxf(room, widest(label, text))
	label.custom_minimum_size.x = room


## Lands a control like an ink stamp: from large and tilted down to its place.
static func stamp(control: Control) -> Tween:
	Audio.fill(AudioEvents.MOTION_STAMP)
	_center_pivot(control)
	if reduced():
		return null
	control.scale = Vector2.ONE * PRESETS.stamp_from_scale
	control.rotation = PRESETS.stamp_tilt
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, PRESETS.stamp_time)
	tween.tween_property(control, "rotation", 0.0, PRESETS.stamp_time)
	tween.tween_property(control, "modulate:a", 1.0, PRESETS.stamp_time * 0.5)
	return tween


## A short swell to draw the eye to a change.
static func pulse(control: Control) -> void:
	Audio.fill(AudioEvents.MOTION_PULSE)
	_center_pivot(control)
	if reduced():
		return
	var tween: Tween = control.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE * 1.12, PRESETS.hover_time)
	tween.tween_property(control, "scale", Vector2.ONE, PRESETS.hover_time * 2.0)


static func _scale_to(control: Control, target: float) -> void:
	if reduced():
		control.scale = Vector2.ONE
		return
	if control.has_meta(TWEEN_META):
		var running: Tween = control.get_meta(TWEEN_META)
		if running != null and running.is_valid():
			running.kill()
	var tween: Tween = control.create_tween()
	control.set_meta(TWEEN_META, tween)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE * target, PRESETS.hover_time)


## Puts a control's pivot at its middle and keeps it there as its size changes: a control
## in a Container has no size until the Container has laid it out, which is after a page
## asks for its entrance.
static func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	if control.has_meta(CENTRED):
		return
	control.set_meta(CENTRED, true)
	control.resized.connect(_center_pivot.bind(control))
