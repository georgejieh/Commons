class_name CardMark
extends Control
## A mark that outlasts its round, drawn small in a card's corner (ADR 0021): a stamped
## card carries a red seal chop, the square of a name seal pressed in vermilion, and a
## Model card a gold rosette with two ribbon tails, like a prize pinned on a worker.
## Both are drawn, so they need no art, and both have a dark edge to read over pictures.

enum Kind { STAMP, MODEL }

## Each mark's box, in card pixels.
const SIZE: Vector2 = Vector2(28, 30)
const VERMILION: Color = Color("b02a17")
const GOLD: Color = Color("e0b84a")
const GOLD_DARK: Color = Color("8a5a12")
const PAPER: Color = Color("f6e6c4")
const EDGE: Color = Color("1e1a16")
const CHOP_TILT: float = -0.12
const PETALS: int = 8

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
	var side: float = minf(size.x, size.y) - 4.0
	draw_set_transform(size / 2.0, CHOP_TILT)
	var square: Rect2 = Rect2(Vector2.ONE * -side / 2.0, Vector2.ONE * side)
	draw_rect(square.grow(1.0), Color(EDGE, 0.6))
	draw_rect(square, VERMILION)
	draw_rect(square.grow(-3.0), PAPER, false, 1.5)
	var inner: float = side / 2.0 - 7.0
	for row: int in 3:
		var y: float = lerpf(-inner, inner, row / 2.0)
		draw_line(Vector2(-inner, y), Vector2(inner, y), PAPER, 2.0)
	draw_line(Vector2(0.0, -inner), Vector2(0.0, inner), PAPER, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)


## Petals round a gold boss, with two ribbon tails hanging below.
func _draw_rosette() -> void:
	var radius: float = size.x / 2.0 - 3.0
	var center: Vector2 = Vector2(size.x / 2.0, radius + 2.0)
	for side: float in [-1.0, 1.0]:
		var tail: PackedVector2Array = [
			center + Vector2(side * 2.0, 0.0),
			center + Vector2(side * 8.0, size.y - center.y),
			center + Vector2(side * 3.0, size.y - center.y - 3.0),
		]
		draw_colored_polygon(tail, VERMILION)
	for petal: int in PETALS:
		var at: Vector2 = center + Vector2.from_angle(TAU * petal / PETALS) * radius * 0.62
		draw_circle(at, radius * 0.42, GOLD_DARK)
		draw_circle(at, radius * 0.34, GOLD)
	draw_circle(center, radius * 0.5, GOLD_DARK)
	draw_circle(center, radius * 0.38, GOLD)
	draw_circle(center, radius * 0.16, VERMILION)
