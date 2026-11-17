class_name WildRibbon
extends Control
## The mark of a wild card (ADR 0029): a short red ribbon hung down the card's left edge
## under its index, in the strip a fanned hand and a spread play leave showing, with a
## swallowtail cut and a gold thread down it. It is drawn, so it needs no art, with a dark
## edge to read over pictures. Nothing in the village is new (art/STYLE.md): at stage 0 the
## silk is creased, the tails fray and tea has spotted it; each stage fades and darkens it
## toward old blood, frays it further and at the last stages tears a hole through it.

## The ribbon's box in card pixels, and where it hangs: under the suit pip, above the chop.
const SIZE: Vector2 = Vector2(13, 36)
const AT: Vector2 = Vector2(1, 90)
const RED: Color = Color("b8231a")
const FOLD: Color = Color("6e120d")
const GOLD: Color = Color("d9a93c")
const EDGE: Color = Color("1e1a16")
const STOCK: Color = Color("f6e6c4")
## How deep the swallowtail cuts, and the room under the tails the frayed threads hang
## in, so no thread reaches the chop below, in pixels.
const NOTCH: float = 6.0
const FRAY: float = 5.0
const SEED: int = 7741
## Frayed threads at the tails at stage 0 and at the last stage, and the stage from which a
## hole is torn through the silk.
const THREADS: Vector2i = Vector2i(2, 9)
const CREASES: Vector2i = Vector2i(1, 4)
const TORN_FROM: float = 0.75

## Varies the grime from card to card, so a hand of wild cards is not one stamp repeated.
var salt: int = 0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	position = AT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows or hides the ribbon, drawn again at the stage the art shows now.
func show_on(on: bool, card_salt: int = 0) -> void:
	visible = on
	salt = card_salt
	if on:
		queue_redraw()


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var red: Color = BowlGrime.faded(RED, worn).lerp(BowlGrime.DRIED, 0.45 * (worn - 0.3))
	var outline: PackedVector2Array = _outline()
	var edged: PackedVector2Array = _outline(1.2)
	draw_colored_polygon(edged, Color(EDGE, 0.85))
	draw_colored_polygon(outline, red)
	# The fold where the ribbon is tucked under the card's edge.
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(0, 5)]),
		BowlGrime.faded(FOLD, worn)
	)
	var thread: Color = Color(BowlGrime.faded(GOLD, worn), 0.9 - 0.4 * worn)
	var bottom: float = size.y - FRAY
	draw_line(Vector2(size.x / 2.0, 5), Vector2(size.x / 2.0, bottom - NOTCH - 2), thread, 1.0)
	_draw_grime(worn, red)


## The ribbon's shape: a strip with a swallowtail cut, grown by grow pixels for its edge.
func _outline(grow: float = 0.0) -> PackedVector2Array:
	var mid: float = size.x / 2.0
	var bottom: float = size.y - FRAY
	return PackedVector2Array(
		[
			Vector2(-grow, -grow),
			Vector2(size.x + grow, -grow),
			Vector2(size.x + grow, bottom + grow),
			Vector2(mid, bottom - NOTCH + grow),
			Vector2(-grow, bottom + grow),
		]
	)


## Creases, a tea stain, frayed threads at the tails and, late, a hole.
func _draw_grime(worn: float, red: Color) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + salt * 31
	var crease: Color = Color(red.darkened(0.35), 0.8)
	for _crease: int in roundi(lerpf(CREASES.x, CREASES.y, worn)):
		var y: float = rng.randf_range(8.0, size.y - FRAY - NOTCH - 4.0)
		draw_line(
			Vector2(0.5, y), Vector2(size.x - 0.5, y + rng.randf_range(-3.0, 3.0)), crease, 1.0
		)
	var stain: Vector2 = Vector2(rng.randf_range(3.0, size.x - 3.0), rng.randf_range(10.0, 24.0))
	draw_circle(stain, 2.5 + 2.0 * worn, Color(BowlGrime.TEA, 0.2 + 0.35 * worn))
	for _thread: int in roundi(lerpf(THREADS.x, THREADS.y, worn)):
		var left: bool = rng.randf() < 0.5
		var x: float = rng.randf_range(0.5, size.x / 2.0 - 1.0)
		var tail: float = size.y - FRAY - x * NOTCH / size.x * 2.0
		var from: Vector2 = Vector2(x if left else size.x - x, tail)
		var hang: Vector2 = Vector2(
			rng.randf_range(-1.5, 1.5), rng.randf_range(1.5, FRAY * (0.5 + 0.5 * worn))
		)
		draw_line(from, from + hang, Color(red.darkened(0.2), 0.9), 1.0)
	if worn >= TORN_FROM:
		# The card shows through the hole, ringed with the torn silk's dark edge.
		var hole: Vector2 = Vector2(rng.randf_range(4.0, size.x - 4.0), rng.randf_range(14.0, 26.0))
		var radius: float = 1.2 + 8.0 * (worn - TORN_FROM)
		draw_circle(hole, radius + 0.8, Color(EDGE, 0.8))
		draw_circle(hole, radius, BowlGrime.aged(STOCK, worn))
