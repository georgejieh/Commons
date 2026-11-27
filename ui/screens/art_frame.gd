class_name ArtFrame
extends Control
## The printed frame a Cadre's picture sits in, standing empty while the Cadre has no art
## yet: a ruled border and corner marks in faded ink on the card stock, the size the art
## will take, so a picture drops in without moving anything. Like all village print it is
## a little off true and fades with the stage (art/STYLE.md).

const INK: Color = Color("5a4a36")
const INSET: float = 4.0
const CORNER: float = 14.0


func _init(extent: Vector2 = Vector2.ZERO) -> void:
	custom_minimum_size = extent
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var ink: Color = Color(BowlGrime.aged(INK, worn * 0.4), 0.55)
	var outer: Rect2 = Rect2(Vector2.ZERO, size).grow(-INSET)
	draw_rect(outer, ink, false, 1.5)
	var inner: Rect2 = outer.grow(-5.0)
	draw_rect(inner, Color(ink, ink.a * 0.6), false, 1.0)
	for corner: Vector2 in [
		inner.position,
		Vector2(inner.end.x, inner.position.y),
		inner.end,
		Vector2(inner.position.x, inner.end.y)
	]:
		var toward: Vector2 = (inner.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(toward.x * CORNER, 0), ink, 2.0)
		draw_line(corner, corner + Vector2(0, toward.y * CORNER), ink, 2.0)
