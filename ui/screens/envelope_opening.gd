class_name EnvelopeOpening
extends RefCounted
## The envelope's opening act (ADR 0021): it comes from its offer to the middle, opens in
## one beat, and its papers slide out into their row. An envelope is opened many times a
## run and the papers are what the player came for, so a click or an accept ends the act
## at once; EnvelopeOverlay then lays everything out at rest. The papers not kept fall
## away at the end (fall()).

## The envelope's size once it reaches the middle.
const FIGURE: Vector2 = Vector2(540, 340)
## Seconds the envelope takes to arrive in the middle.
const ARRIVE_TIME: float = 0.3
## Seconds of the envelope's opening beat.
const OPEN_TIME: float = 0.5
## Seconds each paper takes to slide out into its place in the row.
const FAN_TIME: float = 0.32
## Seconds between one paper starting to slide and the next.
const FAN_STAGGER: float = 0.07
## Seconds the envelope takes to fade once its papers are out.
const FIGURE_FADE: float = 0.22
## Seconds a paper not kept takes to fall.
const FALL_TIME: float = 0.38
## A paper leaves the envelope at this scale and settles at full size.
const FAN_FROM: float = 0.35
## How far a paper not kept falls, in pixels.
const FALL: float = 340.0
## How far a paper not kept turns as it falls, in radians.
const FALL_TURN: float = 0.3
## The envelope stands this far above the middle, over the row its papers will take.
const RAISED: Vector2 = Vector2(0, -40)
## Each paper leaves the envelope turned this much more than the one before, in radians.
const FAN_TURN: float = 0.12

## Every tween of the act still running.
var _tweens: Array[Tween] = []


## True for the input that ends the act: a left click, accept or cancel.
static func ends(event: InputEvent) -> bool:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null:
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")


## The papers fall away one after another, each turning, and fade.
static func fall(falling: Array[ChoicePaper]) -> void:
	Audio.fill(AudioEvents.MOTION_FLY)
	for index: int in falling.size():
		var paper: ChoicePaper = falling[index]
		paper.keep.disabled = true
		var tween: Tween = paper.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var delay: float = index * FAN_STAGGER
		var turn: float = FALL_TURN * (1.0 if index % 2 == 0 else -1.0)
		var time: float = FALL_TIME
		tween.tween_property(paper, "position:y", FALL, time).set_delay(delay)
		tween.tween_property(paper, "rotation", turn, time).set_delay(delay)
		tween.tween_property(paper, "modulate:a", 0.0, time).set_delay(delay)


## Plays the act over overlay, from where the offer stood, then calls done.
func play(
	overlay: Control,
	dim: Control,
	figure: EnvelopeFigure,
	column: Control,
	papers: Array[ChoicePaper],
	from: Rect2,
	done: Callable
) -> void:
	dim.modulate.a = 0.0
	column.modulate.a = 0.0
	figure.visible = true
	figure.position = from.position - overlay.global_position
	figure.size = from.size
	# The overlay covers the page, which may not have been laid out yet: aim by the screen.
	var middle: Vector2 = overlay.get_viewport_rect().size / 2.0 - overlay.global_position
	var target: Vector2 = middle - FIGURE / 2.0 + RAISED
	var fan: float = FAN_TIME + FAN_STAGGER * papers.size()
	var tween: Tween = overlay.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(dim, "modulate:a", 1.0, ARRIVE_TIME)
	tween.parallel().tween_property(figure, "position", target, ARRIVE_TIME)
	tween.parallel().tween_property(figure, "size", FIGURE, ARRIVE_TIME)
	var open: PropertyTweener = tween.tween_property(figure, "opened", 1.0, OPEN_TIME)
	open.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_fan.bind(figure, column, papers))
	tween.tween_interval(fan)
	tween.tween_property(figure, "modulate:a", 0.0, FIGURE_FADE)
	tween.tween_callback(_end.bind(done))
	_tweens.append(tween)


## True while any tween of the act is still running.
func is_playing() -> bool:
	return not _tweens.is_empty()


## Stops the act where it is. The caller lays the pieces out at rest.
func stop() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()


## Each paper slides out of the open envelope to its place in the row, one after another.
func _fan(figure: EnvelopeFigure, column: Control, papers: Array[ChoicePaper]) -> void:
	Audio.fill(AudioEvents.MOTION_ENTER)
	var mouth: Vector2 = figure.global_position + figure.size / 2.0
	var heading: Tween = column.create_tween()
	heading.tween_property(column, "modulate:a", 1.0, FAN_TIME)
	_tweens.append(heading)
	for index: int in papers.size():
		var paper: ChoicePaper = papers[index]
		var place: Control = paper.get_parent() as Control
		paper.position = mouth - place.global_position - paper.size / 2.0
		paper.scale = Vector2.ONE * FAN_FROM
		paper.rotation = (index - (papers.size() - 1) / 2.0) * FAN_TURN
		var tween: Tween = paper.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var delay: float = index * FAN_STAGGER
		var seconds: float = FAN_TIME
		tween.tween_property(paper, "position", Vector2.ZERO, seconds).set_delay(delay)
		tween.tween_property(paper, "scale", Vector2.ONE, seconds).set_delay(delay)
		tween.tween_property(paper, "rotation", 0.0, seconds).set_delay(delay)
		_tweens.append(tween)


func _end(done: Callable) -> void:
	_tweens.clear()
	done.call()
