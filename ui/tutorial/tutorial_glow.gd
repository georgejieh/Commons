class_name TutorialGlow
extends Control
## The arrival's light on what a step asks for (ADR 0026, amended 2026-11-20): a gilt
## frame hugging each button or card, with a vermilion halo that breathes, so the thing
## itself is lit and nothing is drawn round it by hand. The frame swells once when it
## moves to a new thing and comes back to rest; under reduced motion it stands still.
## Nothing is clean (art/STYLE.md): the gilt is laid unevenly at stage 0, and at each
## corruption stage more of it has flaked off and the lamp gutters. It takes no input.

const GILT: Color = Color("f6c955")
const HALO: Color = Color("b02a17")
const UNDER: Color = Color(0.09, 0.07, 0.05, 0.6)
## How far the frame stands off the thing, its line, and its corners.
const OFF: float = 6.0
const WIDTH: float = 4.0
const RADIUS: float = 10.0
## The halo: how far it reaches at rest, how much further at the top of a breath, how
## many passes paint it and how long a breath takes.
const REACH: float = 12.0
const BREATH_REACH: float = 6.0
const PASSES: int = 4
const BREATH: float = 1.5
## Moving to a new thing: seconds the frame takes to close in, and from how far out.
const SWELL: float = 0.3
const SWELL_BY: float = 18.0
## The frame is laid in strokes about this long, each a little thicker or thinner.
const STROKE: float = 16.0
const UNEVEN: float = 0.22
## The share of strokes flaked off per corruption stage, and how deep the lamp gutters.
const FLAKED_PER_STAGE: float = 0.035
const GUTTER_PER_STAGE: float = 0.05
const SEED: int = 2617
## Two sets of things are the same while no corner has moved further than this.
const SAME: float = 3.0

var _rects: Array[Rect2] = []
var _time: float = 0.0
## 1 when the light has just moved, falling to 0 as the frame closes in.
var _swell: float = 0.0
var _closing: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Lights these things, given in screen space; none puts the light out.
func light(rects: Array[Rect2]) -> void:
	var lit: Array[Rect2] = []
	for rect: Rect2 in rects:
		if rect.has_area():
			lit.append(rect)
	if lit.is_empty():
		_rects = lit
		visible = false
		return
	var moved: bool = not visible or not _same(lit)
	_rects = lit
	visible = true
	if moved:
		_close_in()
		queue_redraw()


## The things lit now, and the box that holds them all; nothing while the light is out.
func lit() -> Array[Rect2]:
	return _rects if visible else ([] as Array[Rect2])


func lit_area() -> Rect2:
	var area: Rect2 = Rect2()
	for rect: Rect2 in lit():
		area = rect if not area.has_area() else area.merge(rect)
	return area


func _process(delta: float) -> void:
	if visible and not UiMotion.reduced():
		_time += delta
		queue_redraw()


func _same(lit: Array[Rect2]) -> bool:
	if lit.size() != _rects.size():
		return false
	for index: int in lit.size():
		var was: Rect2 = _rects[index]
		var apart: float = maxf(
			lit[index].position.distance_to(was.position), lit[index].end.distance_to(was.end)
		)
		if apart > SAME:
			return false
	return true


func _close_in() -> void:
	if _closing != null and _closing.is_valid():
		_closing.kill()
	if UiMotion.reduced():
		_swell = 0.0
		return
	_swell = 1.0
	_closing = create_tween()
	_closing.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_closing.tween_property(self, "_swell", 0.0, SWELL)


func _draw() -> void:
	var stage: int = ArtStages.art_stage()
	var still: bool = UiMotion.reduced()
	var breath: float = 0.5 if still else 0.5 + 0.5 * sin(_time * TAU / BREATH)
	# A lamp that gutters: the light drops for a moment, more often at later stages.
	var gutter: float = 0.0
	if not still and stage > 0:
		gutter = GUTTER_PER_STAGE * stage * maxf(0.0, sin(_time * 23.0) * sin(_time * 7.3))
	var shine: float = clampf(1.0 - _swell * 0.6 - gutter, 0.0, 1.0)
	for index: int in _rects.size():
		var path: PackedVector2Array = TutorialGlow.frame(
			_rects[index].grow(OFF + SWELL_BY * maxf(_swell, 0.0)), RADIUS
		)
		var reach: float = REACH + BREATH_REACH * breath
		for step: int in PASSES:
			var wide: float = WIDTH + reach * 2.0 * float(PASSES - step) / PASSES
			var alpha: float = (0.07 + 0.05 * breath) * shine
			draw_polyline(path, Color(HALO, alpha), wide, true)
		_gild(path, stage, shine, index)


## The frame itself, stroke by stroke over a dark underline, so it reads on paper and on
## wood alike.
func _gild(path: PackedVector2Array, stage: int, shine: float, salt: int) -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = SEED + 97 * salt
	draw_polyline(path, Color(UNDER, UNDER.a * shine), WIDTH + 3.0, true)
	var flaked: float = FLAKED_PER_STAGE * stage
	for index: int in path.size() - 1:
		var uneven: float = 1.0 + random.randf_range(-UNEVEN, UNEVEN)
		if random.randf() < flaked:
			continue
		draw_line(path[index], path[index + 1], Color(GILT, shine), WIDTH * uneven, true)


## A closed path round rect with rounded corners, in strokes of about STROKE.
static func frame(rect: Rect2, radius: float) -> PackedVector2Array:
	var round: float = minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var path: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [
		rect.position + Vector2(round, round),
		Vector2(rect.end.x - round, rect.position.y + round),
		rect.end - Vector2(round, round),
		Vector2(rect.position.x + round, rect.end.y - round),
	]
	for corner: int in 4:
		# Each corner's arc, then the straight edge to the next corner.
		for step: int in 5:
			var angle: float = PI + corner * PI / 2.0 + step * PI / 8.0
			path.append(corners[corner] + Vector2(cos(angle), sin(angle)) * round)
		var from: Vector2 = path[path.size() - 1]
		var next: int = (corner + 1) % 4
		var turn: float = PI + next * PI / 2.0
		var to: Vector2 = corners[next] + Vector2(cos(turn), sin(turn)) * round
		var strokes: int = maxi(1, roundi(from.distance_to(to) / STROKE))
		for step: int in range(1, strokes):
			path.append(from.lerp(to, float(step) / strokes))
	path.append(path[0])
	return path
