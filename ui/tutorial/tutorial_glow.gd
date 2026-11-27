class_name TutorialGlow
extends Control
## The arrival's light on what a step asks for (ADR 0026, amended 2026-11-20): a gilt
## frame (GiltFrame) hugging each button or card, with a vermilion halo that breathes, so
## the thing itself is lit and nothing is drawn round it by hand. The frame swells once
## when it moves to a new thing and comes back to rest; under reduced motion it stands
## still. At later corruption stages the lamp gutters. It takes no input.

## How far the frame stands off the thing.
const OFF: float = 6.0
## How far the halo reaches at rest.
const REACH: float = 14.0
## How much further the halo reaches at the top of a breath.
const BREATH_REACH: float = 8.0
## How long a breath of the halo takes, in seconds.
const BREATH: float = 1.5
## Moving to a new thing: seconds the frame takes to close in.
const SWELL: float = 0.3
## How much further out the frame stands when it has just moved to a new thing.
const SWELL_BY: float = 18.0
## How deep the lamp gutters per corruption stage.
const GUTTER_PER_STAGE: float = 0.05
## Two sets of things are the same while no corner has moved further than this.
const SAME: float = 3.0

## 1 when the light has just moved, falling to 0 as the frame closes in.
var swell: float = 0.0

var _rects: Array[Rect2] = []
var _time: float = 0.0
var _closing: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Lights these things, given in screen space; none puts the light out.
func light(rects: Array[Rect2]) -> void:
	var lit_now: Array[Rect2] = []
	for rect: Rect2 in rects:
		if rect.has_area():
			lit_now.append(rect)
	if lit_now.is_empty():
		_rects = lit_now
		visible = false
		return
	var moved: bool = not visible or not _same(lit_now)
	_rects = lit_now
	visible = true
	if moved:
		_close_in()
		queue_redraw()


## The things lit now, and the box that holds them all; nothing while the light is out.
func lit() -> Array[Rect2]:
	return _rects if visible else ([] as Array[Rect2])


## The box that holds every thing lit now, or an empty box while none is.
func lit_area() -> Rect2:
	var area: Rect2 = Rect2()
	for rect: Rect2 in lit():
		area = rect if not area.has_area() else area.merge(rect)
	return area


func _process(delta: float) -> void:
	if visible and not UiMotion.reduced():
		_time += delta
		queue_redraw()


func _same(lit_now: Array[Rect2]) -> bool:
	if lit_now.size() != _rects.size():
		return false
	for index: int in lit_now.size():
		var was: Rect2 = _rects[index]
		var apart: float = maxf(
			lit_now[index].position.distance_to(was.position),
			lit_now[index].end.distance_to(was.end)
		)
		if apart > SAME:
			return false
	return true


func _close_in() -> void:
	Audio.fill(AudioEvents.MOTION_PULSE)
	if _closing != null and _closing.is_valid():
		_closing.kill()
	if UiMotion.reduced():
		swell = 0.0
		return
	swell = 1.0
	_closing = create_tween()
	_closing.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_closing.tween_property(self, "swell", 0.0, SWELL)


func _draw() -> void:
	var stage: int = ArtStages.art_stage()
	var still: bool = UiMotion.reduced()
	var breath: float = 0.5 if still else 0.5 + 0.5 * sin(_time * TAU / BREATH)
	# A lamp that gutters: the light drops for a moment, more often at later stages.
	var gutter: float = 0.0
	if not still and stage > 0:
		gutter = GUTTER_PER_STAGE * stage * maxf(0.0, sin(_time * 23.0) * sin(_time * 7.3))
	var shine: float = clampf(1.0 - swell * 0.6 - gutter, 0.0, 1.0)
	for index: int in _rects.size():
		var off: float = OFF + SWELL_BY * maxf(swell, 0.0)
		var frame: PackedVector2Array = GiltFrame.path(_rects[index].grow(off))
		GiltFrame.halo(self, frame, REACH + BREATH_REACH * breath, (0.1 + 0.07 * breath) * shine)
		GiltFrame.gild(self, frame, shine, index)
