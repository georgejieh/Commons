class_name TableMotion
extends Node
## The table's motion: card moves as tweens bound to the moving node, so a freed card takes
## its tween with it; screen shake from a decaying trauma value; and a brief hit-stop when
## a bomb lands. Reduced motion shortens every move and turns shake and hit-stop off. Every
## number comes from MotionPresets.

## The node that shakes, usually the table's root.
var target: Control
## True while the table holds its motion: under reduced motion, and while it catches up on
## a replay or a skip, when every move is quick and nothing shakes.
var still: bool = false

var _trauma: float = 0.0
## Each seat's wind-up under way, so the next one replaces it.
var _winds: Dictionary[Control, Tween] = {}
var _origin: Vector2 = Vector2.ZERO
var _stopped_until: int = 0


func setup(shaken: Control, hold_still: bool) -> void:
	target = shaken
	_origin = shaken.position
	set_still(hold_still)


## Holding still also stops any shake or hit-stop under way.
func set_still(on: bool) -> void:
	still = on
	if on:
		_trauma = 0.0
		_stopped_until = 0


## Seconds for a preset duration, shortened while the table holds still.
func duration(seconds: float) -> float:
	return seconds * (UiMotion.PRESETS.reduced_scale if still else 1.0)


## Moves node to a position and rotation with the preset easing. The tween belongs to
## node, so it dies with it.
func move(node: Control, to: Vector2, angle: float, seconds: float) -> Tween:
	var view: CardView = node as CardView
	var tween: Tween = (view.tween() if view != null else node.create_tween()).set_parallel(true)
	# The presets are a preloaded constant, so the engine reads these fields as plain
	# numbers, loses their enum type and finds no member for them.
	@warning_ignore_start("int_as_enum_without_cast", "int_as_enum_without_match")
	tween.set_trans(UiMotion.PRESETS.move_transition)
	tween.set_ease(UiMotion.PRESETS.move_ease)
	@warning_ignore_restore("int_as_enum_without_cast", "int_as_enum_without_match")
	tween.tween_property(node, "position", to, duration(seconds))
	tween.tween_property(node, "rotation", angle, duration(seconds))
	return tween


## A bomb or rocket: shake and a moment's stillness, unless the table holds still.
func impact() -> void:
	if still:
		return
	_trauma = minf(1.0, _trauma + UiMotion.PRESETS.bomb_trauma)
	_stopped_until = Time.get_ticks_msec() + int(UiMotion.PRESETS.hit_stop * 1000.0)


## A smaller knock than a bomb's: shake only, sized by the caller.
func bump(knock: float) -> void:
	if not still:
		_trauma = minf(1.0, _trauma + knock)


## A villager's seat swells as they are about to play and settles as the cards fly, so
## the eye is on the seat before the cards leave it. Nothing while the table holds still.
func wind_up(seat: Control, seconds: float) -> void:
	if still or seconds <= 0.0:
		return
	Audio.fill(AudioEvents.MOTION_WIND)
	UiMotion.end(_winds.get(seat))
	seat.pivot_offset = seat.size / 2.0
	var tween: Tween = seat.create_tween()
	_winds[seat] = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(seat, "scale", Vector2.ONE * UiMotion.PRESETS.wind_scale, seconds)
	tween.tween_property(seat, "scale", Vector2.ONE, duration(UiMotion.PRESETS.fly_time))


## Drops a card onto the table: from a little larger and clear to its place, a beat
## after the card before it.
func drop(card: Control, rest_scale: float, order: int) -> void:
	if still:
		card.scale = Vector2.ONE * rest_scale
		return
	card.scale = Vector2.ONE * rest_scale * 1.3
	card.modulate.a = 0.0
	var view: CardView = card as CardView
	var tween: Tween = (view.tween() if view != null else card.create_tween()).set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var presets: MotionPresets = UiMotion.PRESETS
	var delay: float = order * presets.deal_stagger
	tween.tween_property(card, "scale", Vector2.ONE * rest_scale, presets.fly_time).set_delay(delay)
	tween.tween_property(card, "modulate:a", 1.0, presets.fly_time * 0.5).set_delay(delay)


func is_stopped() -> bool:
	return Time.get_ticks_msec() < _stopped_until


func trauma() -> float:
	return _trauma


func _process(delta: float) -> void:
	# With no shake left and the table back at its origin there is nothing to move.
	if target == null or (_trauma <= 0.0 and target.position == _origin):
		return
	var presets: MotionPresets = UiMotion.PRESETS
	_trauma = maxf(0.0, _trauma - presets.trauma_decay * delta)
	var amount: float = _trauma * _trauma * presets.max_shake
	var phase: float = Time.get_ticks_msec() / 1000.0
	var wave: Vector2 = Vector2(
		sin(phase * presets.shake_speed.x), cos(phase * presets.shake_speed.y)
	)
	target.position = _origin + wave * amount
