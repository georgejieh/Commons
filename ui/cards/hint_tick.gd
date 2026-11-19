class_name HintTick
extends Control
## The hint's second mark (ADR 0035): a pencilled tick over the top of a hinted card's
## left edge, the strip a fanned hand leaves showing, so a hint reads by shape as well as
## by its gold edge. It stays when the card is also selected, armed or under the cursor.
## It sits outside the card and takes no clicks, so the card's layout and hit box are as
## they were. A pale paper edge under the graphite keeps it readable over the table.
## Nothing is clean (art/STYLE.md): at stage 0 the pencil is gone over twice and wobbles,
## and each stage shakes the hand more, adds strokes and smudges the graphite.

## The tick's box, in card pixels, above the card's top left corner.
const SIZE: Vector2 = Vector2(30, 28)
const AT: Vector2 = Vector2(6, -32)
const GRAPHITE: Color = Color("2e2b27")
const EDGE: Color = Color("efe3c8")
const WIDTH: float = 3.0
const EDGE_WIDTH: float = 6.5
const SEED: int = 8821
## The short stroke's start, its foot and the long stroke's end, as shares of the box.
const SHORT: Vector2 = Vector2(0.08, 0.55)
const FOOT: Vector2 = Vector2(0.38, 0.92)
const LONG: Vector2 = Vector2(0.95, 0.06)
## Pencil passes at stage 0 and at the last stage, and the smudge specks.
const PASSES: Vector2i = Vector2i(2, 4)
const SMUDGES: Vector2i = Vector2i(1, 9)

## Varies the strokes from card to card, so a hint of several cards is not one stamp.
var salt: int = 0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	position = AT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows or hides the tick, drawn again at the stage the art shows now.
func show_on(on: bool, card_salt: int = 0) -> void:
	if on and (not visible or salt != card_salt):
		salt = card_salt
		queue_redraw()
	visible = on


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 131 * salt
	var shake: float = 0.6 + 2.4 * worn
	var stroke: PackedVector2Array = [SHORT * size, FOOT * size, LONG * size]
	draw_polyline(stroke, Color(EDGE, 0.85), EDGE_WIDTH, true)
	var graphite: Color = BowlGrime.faded(GRAPHITE, worn)
	for _pass: int in roundi(lerpf(PASSES.x, PASSES.y, worn)):
		var shaken: PackedVector2Array = []
		for point: Vector2 in stroke:
			shaken.append(point + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake)
		draw_polyline(shaken, Color(graphite, rng.randf_range(0.6, 0.95)), WIDTH, true)
	var smudge: Color = Color(graphite, 0.18 + 0.2 * worn)
	for _spot: int in roundi(lerpf(SMUDGES.x, SMUDGES.y, worn)):
		var along: Vector2 = stroke[1].lerp(stroke[rng.randi_range(0, 2)], rng.randf())
		var off: Vector2 = Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)) * (0.5 + worn)
		draw_circle(along + off, rng.randf_range(0.6, 1.6 + worn), smudge)
