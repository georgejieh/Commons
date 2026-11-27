class_name PaperTicket
extends RefCounted
## A small paper ticket as the village has it (art/STYLE.md, "Nothing is clean"): a
## ration-ticket stub with notched ends and a torn perforation, yellowed, foxed and
## thumbed from corruption stage 0, and worse at every stage by BowlGrime.wear(). Each
## ticket draws from its own fixed seed, so the same ticket always looks the same.

## Warm, like the other village papers, and aged gently, so a row of tickets never reads
## as grey.
const PAPER: Color = Color("ecd29a")
const SEED: int = 6143
const NOTCH: float = 5.0
const SPECKS: Vector2i = Vector2i(4, 26)
## How strongly the empty part of a meter band shows.
const CHANNEL_ALPHA: float = 0.18


## The ticket's paper at a wear: a little darker and duller as the stage deepens.
static func paper(worn: float) -> Color:
	return PAPER.lerp(BowlGrime.BONE, 0.2 * worn).darkened(0.02 + 0.15 * worn)


## The ticket filling rect, with a coloured band down its left end. fill is how much of
## the band is inked, from its foot: all of it at 1, a meter's share below that over a
## faint empty channel, and no band at all when negative.
static func draw(
	canvas: CanvasItem, rect: Rect2, worn: float, which: int, band: Color, fill: float = 1.0
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 97 * which
	var body: PackedVector2Array = _outline(rect, rng, worn)
	canvas.draw_colored_polygon(body, Color(paper(worn), 1.0))
	if fill >= 0.0:
		_band(canvas, rect, worn, band, minf(fill, 1.0))
	_perforate(canvas, rect, worn)
	_grime(canvas, rect, rng, worn)
	canvas.draw_polyline(
		body + PackedVector2Array([body[0]]), Color(ScreenKit.PAPER_EDGE, 0.6), 1.2
	)


## The band down the left end, inked from its foot to fill; an empty channel shows
## faintly above it, so a part-filled band reads as a meter.
static func _band(canvas: CanvasItem, rect: Rect2, worn: float, band: Color, fill: float) -> void:
	var strip: Rect2 = Rect2(rect.position + Vector2(3, 4), Vector2(5, rect.size.y - 8))
	var ink: Color = BowlGrime.aged(band, worn * 0.8)
	if fill < 1.0:
		canvas.draw_rect(strip, Color(ink, CHANNEL_ALPHA))
		canvas.draw_rect(strip, Color(ink, 0.85), false, 1.0)
	var inked: float = strip.size.y * fill
	var full: Rect2 = Rect2(strip.position + Vector2(0, strip.size.y - inked), Vector2(5, inked))
	canvas.draw_rect(full, Color(ink, 0.85))


## Corners out of true, a notch out of each end, and the top right thumbed round.
static func _outline(rect: Rect2, rng: RandomNumberGenerator, worn: float) -> PackedVector2Array:
	# Less than a third of a notch, so the notched ends never cross at the deep stages.
	var jitter: float = minf(0.6 + 1.4 * worn, NOTCH * 0.3)
	var middle: float = rect.position.y + rect.size.y / 2.0
	var thumb: float = 3.0 + 6.0 * worn
	var points: PackedVector2Array = [
		rect.position,
		Vector2(rect.end.x - thumb, rect.position.y),
		Vector2(rect.end.x, rect.position.y + thumb),
		Vector2(rect.end.x, middle - NOTCH),
		Vector2(rect.end.x - NOTCH, middle),
		Vector2(rect.end.x, middle + NOTCH),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.position.x, middle + NOTCH),
		Vector2(rect.position.x + NOTCH, middle),
		Vector2(rect.position.x, middle - NOTCH),
	]
	for index: int in points.size():
		points[index] += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	return points


## A torn line of holes across the stub, where it would be cut from the sheet.
static func _perforate(canvas: CanvasItem, rect: Rect2, worn: float) -> void:
	var y: float = rect.end.y - minf(14.0, rect.size.y * 0.22)
	var hole: Color = Color(ScreenKit.WORN_PRINT, 0.35 + 0.3 * worn)
	var x: float = rect.position.x + 10.0
	while x < rect.end.x - 6.0:
		canvas.draw_circle(Vector2(x, y), 0.9, hole)
		x += 5.0


## Foxing specks, a thumbprint smudge and, deeper in, a tea ring.
static func _grime(
	canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator, worn: float
) -> void:
	var speck: Color = Color(BowlGrime.TEA, 0.25 + 0.35 * worn)
	for _spot: int in roundi(lerpf(SPECKS.x, SPECKS.y, worn)):
		var at: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		canvas.draw_circle(at, rng.randf_range(0.5, 1.4), speck)
	var thumb: Vector2 = rect.position + Vector2(rng.randf_range(0.3, 0.8), 0.75) * rect.size
	canvas.draw_circle(thumb, rect.size.x * 0.16, Color(BowlGrime.TEA, 0.05 + 0.1 * worn))
	if worn > 0.5:
		var ring: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var tea: Color = Color(BowlGrime.TEA, 0.2 * worn)
		canvas.draw_arc(ring, rect.size.x * 0.3, 0.0, TAU, 20, tea, 1.5 + worn, true)
