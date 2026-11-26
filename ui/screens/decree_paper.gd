class_name DecreePaper
extends RefCounted
## A Reform's paper as the village has it (art/STYLE.md, "Nothing is clean"): a small
## printed decree, pinned up, never white and never crisp. At corruption stage 0 it is
## already yellowed, with a red head band printed a little off register, two thin rules,
## a pin hole torn at the top, folds, foxing, a tea ring and an invented office stamp
## faded in the corner. Every stage adds more by BowlGrime.wear(). Each sheet draws from
## its own fixed seed, so the same decree always looks the same.

const PAPER: Color = Color("e6d5ab")
const BAND: Color = Color("a8281a")
const RULE: Color = Color("5a3a26")
const PIN: Color = Color("2b2119")
const SEED: int = 8231
const SPECKS: Vector2i = Vector2i(8, 46)
## How far the band's red slips off its line, in pixels, at stage 0 and at the last.
const REGISTER: Vector2 = Vector2(1.0, 3.0)
## Below this size a sheet has not been laid out yet, and nothing is drawn.
const SMALLEST: float = 12.0


static func paper(worn: float) -> Color:
	return BowlGrime.aged(PAPER, worn)


## A decree poster filling rect: band, rules, pin, folds, grime and the faded stamp.
static func poster(
	canvas: CanvasItem, rect: Rect2, worn: float, which: int, alpha: float = 1.0
) -> void:
	if rect.size.x < SMALLEST or rect.size.y < SMALLEST:
		return
	var rng: RandomNumberGenerator = _rng(which)
	var body: PackedVector2Array = _outline(rect, rng, worn)
	canvas.draw_colored_polygon(body, Color(paper(worn), alpha))
	var slip: float = lerpf(REGISTER.x, REGISTER.y, worn)
	var band: Rect2 = Rect2(
		rect.position + Vector2(6 + slip, 6),
		Vector2(rect.size.x - 12, minf(8.0, rect.size.y * 0.08))
	)
	canvas.draw_rect(band, Color(BowlGrime.aged(BAND, worn * 0.8), alpha * 0.92))
	var rule: Color = Color(BowlGrime.aged(RULE, worn * 0.5), alpha * 0.55)
	for line: int in 2:
		var y: float = band.end.y + 3.0 + line * 3.0
		canvas.draw_line(Vector2(rect.position.x + 8, y), Vector2(rect.end.x - 8, y), rule, 1.0)
	_stamp(canvas, rect, rng, worn, alpha)
	_grime(canvas, rect, rng, worn, alpha)
	_pin(canvas, Vector2(rect.get_center().x, rect.position.y + 4.0), worn, alpha)
	canvas.draw_polyline(
		body + PackedVector2Array([body[0]]), Color(ScreenKit.PAPER_EDGE, alpha * 0.6), 1.4
	)


## A small pinned slip for the strip of Reforms in force: the same paper and band in
## little, its pin at the left end.
static func tag(
	canvas: CanvasItem, rect: Rect2, worn: float, which: int, alpha: float = 1.0
) -> void:
	if rect.size.x < SMALLEST or rect.size.y < SMALLEST:
		return
	var rng: RandomNumberGenerator = _rng(which + 70)
	var body: PackedVector2Array = _outline(rect, rng, worn * 0.6, false)
	canvas.draw_colored_polygon(body, Color(paper(worn), alpha))
	var band: Rect2 = Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, 4))
	canvas.draw_rect(band, Color(BowlGrime.aged(BAND, worn * 0.8), alpha * 0.9))
	var speck: Color = Color(BowlGrime.TEA, alpha * (0.25 + 0.35 * worn))
	for _spot: int in roundi(lerpf(3, 14, worn)):
		var at: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		canvas.draw_circle(at, rng.randf_range(0.5, 1.3), speck)
	_pin(canvas, Vector2(rect.position.x + 7.0, rect.get_center().y + 2.0), worn, alpha)
	canvas.draw_polyline(
		body + PackedVector2Array([body[0]]), Color(ScreenKit.PAPER_EDGE, alpha * 0.55), 1.1
	)


## Corners out of true, the top edge torn a little near the pin, the bottom right worn.
## A slip too small for the tear keeps a plain top, so the outline never crosses itself.
static func _outline(
	rect: Rect2, rng: RandomNumberGenerator, worn: float, torn: bool = true
) -> PackedVector2Array:
	var jitter: float = 0.7 + 1.5 * worn
	var wear: float = minf(4.0 + 8.0 * worn, rect.size.y * 0.3)
	var middle: float = rect.get_center().x
	var points: PackedVector2Array = [rect.position]
	if torn:
		points.append(Vector2(middle - 6.0, rect.position.y))
		points.append(Vector2(middle - 3.0, rect.position.y + 2.0 + 2.0 * worn))
		points.append(Vector2(middle + 2.0, rect.position.y))
	points.append(Vector2(rect.end.x, rect.position.y))
	points.append(Vector2(rect.end.x, rect.end.y - wear))
	points.append(Vector2(rect.end.x - wear * 0.6, rect.end.y))
	points.append(Vector2(rect.position.x, rect.end.y))
	# The tear's points are close together, so only the corners move out of true.
	for index: int in points.size():
		if torn and index >= 1 and index <= 3:
			continue
		points[index] += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	return points


## An office stamp of no real office: two rings and ticks, faded red, low in a corner.
static func _stamp(
	canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator, worn: float, alpha: float
) -> void:
	var radius: float = minf(rect.size.x, rect.size.y) * 0.13
	var at: Vector2 = rect.end - Vector2(radius + 10.0, radius + 10.0)
	at += Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
	var ink: Color = Color(BowlGrime.aged(BAND, worn), alpha * (0.32 - 0.1 * worn))
	canvas.draw_arc(at, radius, 0.0, TAU, 28, ink, 2.0, true)
	canvas.draw_arc(at, radius * 0.62, 0.4, TAU - 0.6, 20, ink, 1.2, true)
	for tick: int in 7:
		var angle: float = tick * TAU / 7.0 + rng.randf_range(-0.1, 0.1)
		var from: Vector2 = at + Vector2.from_angle(angle) * radius * 0.25
		canvas.draw_line(from, at + Vector2.from_angle(angle) * radius * 0.5, ink, 1.0)


## Folds across and down, foxing specks, a thumbed smudge and a tea ring.
static func _grime(
	canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator, worn: float, alpha: float
) -> void:
	var fold: Color = Color(ScreenKit.FOLD, alpha * (0.22 + 0.3 * worn))
	var across: float = rect.position.y + rect.size.y * rng.randf_range(0.46, 0.56)
	canvas.draw_line(Vector2(rect.position.x + 2, across), Vector2(rect.end.x - 2, across), fold)
	var down: float = rect.position.x + rect.size.x * rng.randf_range(0.45, 0.55)
	canvas.draw_line(Vector2(down, rect.position.y + 3), Vector2(down, rect.end.y - 3), fold)
	var speck: Color = Color(BowlGrime.TEA, alpha * (0.25 + 0.35 * worn))
	for _spot: int in roundi(lerpf(SPECKS.x, SPECKS.y, worn)):
		var at: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		canvas.draw_circle(at, rng.randf_range(0.6, 1.7), speck)
	var thumb: Vector2 = rect.position + Vector2(rng.randf_range(0.15, 0.4), 0.82) * rect.size
	var smudge: Color = Color(BowlGrime.TEA, alpha * (0.05 + 0.1 * worn))
	canvas.draw_circle(thumb, rect.size.x * 0.1, smudge)
	var ring: Vector2 = rect.position + Vector2(rng.randf(), rng.randf_range(0.3, 0.9)) * rect.size
	var tea: Color = Color(BowlGrime.TEA, alpha * (0.07 + 0.17 * worn))
	canvas.draw_arc(
		ring, rect.size.x * rng.randf_range(0.12, 0.2), 0.0, TAU, 28, tea, 2.0 + 2.0 * worn, true
	)


## A drawing pin's dark head and the small tear it made.
static func _pin(canvas: CanvasItem, at: Vector2, worn: float, alpha: float) -> void:
	canvas.draw_circle(at + Vector2(0.8, 1.2), 3.4, Color(PIN, alpha * 0.25))
	canvas.draw_circle(at, 3.0, Color(BowlGrime.aged(PIN, worn * 0.3), alpha))
	canvas.draw_line(
		at, at + Vector2(1.5, 4.0 + 3.0 * worn), Color(ScreenKit.PAPER_EDGE, alpha * 0.5), 1.0
	)


static func _rng(which: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 131 * which
	return rng
