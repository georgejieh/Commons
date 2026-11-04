class_name TableMotion
extends Node
## The table's motion (P3B.6): card moves as tweens bound to the moving node, so a
## freed card takes its tween with it; screen shake from a decaying trauma value; and a
## brief hit-stop when a bomb lands. Reduced motion shortens every move and turns shake
## and hit-stop off. Every number comes from MotionPresets.

const PRESETS: MotionPresets = preload("res://data/ui/motion_presets.tres")

## The node that shakes, usually the table's root.
var target: Control
var reduced: bool = false

var _trauma: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _stopped_until: int = 0


func setup(shaken: Control, reduced_motion: bool) -> void:
	target = shaken
	_origin = shaken.position
	reduced = reduced_motion


## Seconds for a preset duration, shortened under reduced motion.
func duration(seconds: float) -> float:
	return seconds * (PRESETS.reduced_scale if reduced else 1.0)


## Moves node to a position and rotation with the preset easing. The tween belongs to
## node, so it dies with it.
func move(node: Control, to: Vector2, angle: float, seconds: float) -> Tween:
	var tween: Tween = node.create_tween().set_parallel(true)
	tween.set_trans(PRESETS.transition as Tween.TransitionType)
	tween.set_ease(PRESETS.ease as Tween.EaseType)
	tween.tween_property(node, "position", to, duration(seconds))
	tween.tween_property(node, "rotation", angle, duration(seconds))
	return tween


## A bomb or rocket: shake and a moment's stillness, unless motion is reduced.
func impact() -> void:
	if reduced:
		return
	_trauma = minf(1.0, _trauma + PRESETS.bomb_trauma)
	_stopped_until = Time.get_ticks_msec() + int(PRESETS.hit_stop * 1000.0)


func is_stopped() -> bool:
	return Time.get_ticks_msec() < _stopped_until


func trauma() -> float:
	return _trauma


func _process(delta: float) -> void:
	if target == null:
		return
	_trauma = maxf(0.0, _trauma - PRESETS.trauma_decay * delta)
	var amount: float = _trauma * _trauma * PRESETS.max_shake
	var phase: float = Time.get_ticks_msec() / 1000.0
	target.position = _origin + Vector2(sin(phase * 47.0), cos(phase * 53.0)) * amount
