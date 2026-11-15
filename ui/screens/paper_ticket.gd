class_name PaperTicket
extends RefCounted
## A small paper ticket as the village has it (art/STYLE.md, "Nothing is clean"): a
## ration-ticket stub with notched ends and a torn perforation, yellowed, foxed and
## thumbed from corruption stage 0, and worse at every stage by BowlGrime.wear(). Each
## ticket draws from its own fixed seed, so the same ticket always looks the same.

const PAPER: Color = Color("e2d1a6")
const EDGE: Color = Color("4a3a26")
const PERFORATION: Color = Color("7a6446")
const SEED: int = 6143
const NOTCH: float = 5.0
const SPECKS: Vector2i = Vector2i(4, 26)


## The ticket filling rect, with a coloured band down its left end.
static func draw(
	canvas: CanvasItem, rect: Rect2, worn: float, which: int, band: Color, alpha: float = 1.0
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 97 * which
	var body: PackedVector2Array = _outline(rect, rng, worn)
	canvas.draw_colored_polygon(body, Color(BowlGrime.aged(PAPER, worn), alpha))
	var strip: Rect2 = Rect2(rect.position + Vector2(3, 4), Vector2(5, rect.size.y - 8))
	canvas.draw_rect(strip, Color(BowlGrime.aged(band, worn * 0.8), alpha * 0.85))
	_perforate(canvas, rect, worn, alpha)
	_grime(canvas, rect, rng, worn, alpha)
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), Color(EDGE, alpha * 0.6), 1.2)


## Corners out of true, a notch out of each end, and the top right thumbed round.
static func _outline(rect: Rect2, rng: RandomNumberGenerator, worn: float) -> PackedVector2Array:
	var jitter: float = 0.6 + 1.4 * worn
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
static func _perforate(canvas: CanvasItem, rect: Rect2, worn: float, alpha: float) -> void:
	var y: float = rect.end.y - minf(14.0, rect.size.y * 0.22)
	var hole: Color = Color(PERFORATION, alpha * (0.35 + 0.3 * worn))
	var x: float = rect.position.x + 10.0
	while x < rect.end.x - 6.0:
		canvas.draw_circle(Vector2(x, y), 0.9, hole)
		x += 5.0


## Foxing specks, a thumbprint smudge and, deeper in, a tea ring.
static func _grime(
	canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator, worn: float, alpha: float
) -> void:
	var speck: Color = Color(BowlGrime.TEA, alpha * (0.25 + 0.35 * worn))
	for _spot: int in roundi(lerpf(SPECKS.x, SPECKS.y, worn)):
		var at: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		canvas.draw_circle(at, rng.randf_range(0.5, 1.4), speck)
	var thumb: Vector2 = rect.position + Vector2(rng.randf_range(0.3, 0.8), 0.75) * rect.size
	canvas.draw_circle(thumb, rect.size.x * 0.16, Color(BowlGrime.TEA, alpha * (0.05 + 0.1 * worn)))
	if worn > 0.5:
		var ring: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var tea: Color = Color(BowlGrime.TEA, alpha * 0.2 * worn)
		canvas.draw_arc(ring, rect.size.x * 0.3, 0.0, TAU, 20, tea, 1.5 + worn, true)
