class_name CardMark
extends Control
## A mark that outlasts its round, drawn small on a card's left edge (ADR 0021): a stamped
## card carries a red seal chop, the square of a name seal pressed in vermilion, and a
## Model card a red and gold rosette with two ribbon tails, like a prize pinned on a
## worker.
## Both are drawn, so they need no art, and both have a dark edge to read over pictures.
## Neither is ever fresh (art/STYLE.md): the chop prints with gaps where the ink did not
## take and the rosette is tarnished, a little at stage 0 and more with every stage.

enum Kind { STAMP, MODEL }

## Each mark's box, in card pixels.
const SIZE: Vector2 = Vector2(30, 32)
## How far the ink and gold age with the stage: they wear, but stay solid enough to read
## at hand size at every stage.
const INK_WEAR: float = 0.3
const VERMILION: Color = Color("b02a17")
const GOLD: Color = Color("e0b84a")
const GOLD_DARK: Color = Color("8a5a12")
const PAPER: Color = Color("f6e6c4")
const EDGE: Color = Color("1e1a16")
const CHOP_TILT: float = -0.12
const PETALS: int = 8
const SEED: int = 3307
## Spots where the chop's ink did not take, at stage 0 and at the last stage.
const GAPS: Vector2i = Vector2i(2, 7)

var kind: Kind = Kind.STAMP


func _init(mark_kind: Kind) -> void:
	kind = mark_kind
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	if kind == Kind.STAMP:
		_draw_chop()
	else:
		_draw_rosette()


## A square of red ink with a paper border cut inside it and three strokes and a stem,
## the way a carved name seal prints.
func _draw_chop() -> void:
	var worn: float = BowlGrime.wear()
	var red: Color = BowlGrime.aged(VERMILION, worn * INK_WEAR)
	var paper: Color = BowlGrime.aged(PAPER, worn)
	var side: float = minf(size.x, size.y) - 4.0
	draw_set_transform(size / 2.0, CHOP_TILT)
	var square: Rect2 = Rect2(Vector2.ONE * -side / 2.0, Vector2.ONE * side)
	draw_rect(square.grow(1.5), Color(EDGE, 0.85))
	draw_rect(square, red)
	draw_rect(square.grow(-3.0), paper, false, 1.5)
	var inner: float = side / 2.0 - 7.0
	for row: int in 3:
		var y: float = lerpf(-inner, inner, row / 2.0)
		draw_line(Vector2(-inner, y), Vector2(inner, y), paper, 2.0)
	draw_line(Vector2(0.0, -inner), Vector2(0.0, inner), paper, 2.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for _gap: int in roundi(lerpf(GAPS.x, GAPS.y, worn)):
		var at: Vector2 = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * side * 0.45
		draw_circle(at, rng.randf_range(0.6, 1.1 + worn * 0.6), Color(paper, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0)


## Petals round a gold boss, with two ribbon tails hanging below.
func _draw_rosette() -> void:
	var worn: float = BowlGrime.wear()
	var radius: float = size.x / 2.0 - 3.0
	var center: Vector2 = Vector2(size.x / 2.0, radius + 2.0)
	for side: float in [-1.0, 1.0]:
		var tail: PackedVector2Array = [
			center + Vector2(side * 2.0, 0.0),
			center + Vector2(side * 8.0, size.y - center.y),
			center + Vector2(side * 3.0, size.y - center.y - 3.0),
		]
		draw_colored_polygon(tail, BowlGrime.aged(VERMILION, worn * INK_WEAR))
	var gold: Color = BowlGrime.aged(GOLD, worn * INK_WEAR)
	var dark: Color = BowlGrime.aged(GOLD_DARK, worn * INK_WEAR)
	var red: Color = BowlGrime.aged(VERMILION, worn * INK_WEAR)
	# A dark edge round the whole rosette, so it reads over stock and art alike.
	draw_circle(center, radius * 1.08, Color(EDGE, 0.8))
	for petal: int in PETALS:
		var at: Vector2 = center + Vector2.from_angle(TAU * petal / PETALS) * radius * 0.62
		draw_circle(at, radius * 0.42, red if petal % 2 == 0 else dark)
		draw_circle(at, radius * 0.32, gold)
	draw_circle(center, radius * 0.5, red)
	draw_circle(center, radius * 0.36, gold)
	draw_circle(center, radius * 0.16, red)
	# Tarnish creeps round the boss from one side.
	var tarnish: Color = Color(BowlGrime.TEA, 0.25 + 0.45 * worn)
	draw_arc(center, radius * 0.44, 0.6, 0.6 + PI * (0.4 + 0.8 * worn), 16, tarnish, 1.5, true)
