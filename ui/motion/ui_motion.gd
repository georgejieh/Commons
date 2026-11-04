class_name UiMotion
extends RefCounted
## Interface motion for every screen: buttons that lift on hover and sink when pressed,
## pieces that fade and settle in one after another, numbers that roll, and stamps that
## land. Motion uses scale and fade, never position, so containers keep their layout.
## Every tween belongs to the node it moves. Reduced motion shortens or skips it all.

const PRESETS: MotionPresets = preload("res://data/ui/motion_presets.tres")
## A piece starts its entrance this much smaller.
const ENTER_SCALE: float = 0.96
## Where a control keeps its hover tween, so a new one replaces it.
const TWEEN_META: StringName = &"ui_motion_tween"


static func reduced() -> bool:
	return bool(Settings.value("reduced_motion"))


static func seconds(base: float) -> float:
	return base * (PRESETS.reduced_scale if reduced() else 1.0)


## Lifts a control on hover or focus and sinks it while pressed.
static func hoverable(control: Control) -> void:
	_center_pivot(control)
	control.resized.connect(_center_pivot.bind(control))
	control.mouse_entered.connect(_scale_to.bind(control, PRESETS.hover_scale))
	control.mouse_exited.connect(_scale_to.bind(control, 1.0))
	control.focus_entered.connect(_scale_to.bind(control, PRESETS.hover_scale))
	control.focus_exited.connect(_scale_to.bind(control, 1.0))
	var button: BaseButton = control as BaseButton
	if button != null:
		button.button_down.connect(_scale_to.bind(control, PRESETS.press_scale))
		button.button_up.connect(_scale_to.bind(control, PRESETS.hover_scale))


## Fades and settles controls in one after another.
static func enter(controls: Array[Control]) -> void:
	if reduced():
		return
	for index: int in controls.size():
		var control: Control = controls[index]
		_center_pivot(control)
		control.modulate.a = 0.0
		control.scale = Vector2.ONE * ENTER_SCALE
		var tween: Tween = control.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var delay: float = index * PRESETS.enter_stagger
		tween.tween_property(control, "modulate:a", 1.0, PRESETS.enter_time).set_delay(delay)
		tween.tween_property(control, "scale", Vector2.ONE, PRESETS.enter_time).set_delay(delay)


## Rolls a label's number from one value to another; shown formats each step.
static func count(label: Label, from: float, to: float, shown: Callable) -> void:
	if reduced() or is_equal_approx(from, to):
		label.text = shown.call(to)
		return
	var tween: Tween = label.create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(value: float) -> void: label.text = shown.call(value), from, to, PRESETS.count_time
	)


## Lands a control like an ink stamp: from large and tilted down to its place.
static func stamp(control: Control) -> Tween:
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


static func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
