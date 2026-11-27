class_name HighlightRing
extends Control
## The arrival's red ring (ADR 0026): a loop drawn round the one thing the step asks for,
## in brush ink that wavers and thins as a hand-drawn line does, with a blot where the
## brush paused. Nothing is clean (art/STYLE.md): more blots and a shakier hand at each
## corruption stage. It takes no input.

const INK: Color = Color("9e1b16")
const WIDTH: float = 5.0
const PAD: float = 14.0
const POINTS: int = 48
## How far the line wanders from a true ellipse, as a share of the pad, at stage 0 and
## added at each stage.
const WOBBLE: float = 0.35
const WOBBLE_PER_STAGE: float = 0.08
const BLOTS: int = 2
const SEED: int = 2617

var _rect: Rect2 = Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	visible = false


## Rings rect, in screen space; an empty rect hides the ring.
func ring(rect: Rect2) -> void:
	if not rect.has_area():
		visible = false
		return
	if rect != _rect or not visible:
		_rect = rect
		global_position = rect.position - Vector2.ONE * PAD * 2.0
		size = rect.size + Vector2.ONE * PAD * 4.0
		queue_redraw()
	visible = true


func ringed() -> Rect2:
	return _rect if visible else Rect2()


func _draw() -> void:
	var stage: int = ArtStages.art_stage()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = SEED
	var middle: Vector2 = size / 2.0
	var radius: Vector2 = _rect.size / 2.0 + Vector2.ONE * PAD
	var wobble: float = PAD * (WOBBLE + WOBBLE_PER_STAGE * stage)
	var line: PackedVector2Array = PackedVector2Array()
	# A little past a full turn, so the brush overlaps where it began.
	for index: int in POINTS + 4:
		var angle: float = TAU * index / POINTS - PI * 0.6
		var drift: float = random.randf_range(-wobble, wobble)
		line.append(middle + Vector2(cos(angle), sin(angle)) * (radius + Vector2.ONE * drift))
	for index: int in line.size() - 1:
		var thin: float = 1.0 - 0.45 * absf(sin(float(index) / line.size() * PI * 3.0))
		draw_line(line[index], line[index + 1], INK, WIDTH * thin, true)
	for _blot: int in BLOTS + stage:
		var at: Vector2 = line[random.randi_range(0, line.size() - 1)]
		draw_circle(at, random.randf_range(2.0, 4.5), INK)
