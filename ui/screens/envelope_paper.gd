class_name EnvelopePaper
extends RefCounted
## Envelopes as the village has them (art/STYLE.md, "Nothing is clean"). The state store's
## Directive envelope is yellow manila closed by a string wound round two card buttons;
## its Campaign envelope is darker brown paper under a red wax seal; the black market's
## Parcel is wrapped in old newspaper, tied with twine, with a manila label tucked under
## the string. At corruption stage 0 each is already handled: a fold, foxing, a tea ring,
## a softened corner. Every stage adds more by BowlGrime.wear(). opened, from 0 to 1, is
## the one beat of opening: the string unwinds or the seal breaks, or the twine is cut,
## and the flap lifts or the paper tears across the top.

const STRING_TIE: int = 0
const WAX_SEAL: int = 1
const PARCEL: int = 2
const MANILA: Color = Color("d4b373")
const KRAFT: Color = Color("9a6f42")
const NEWSPRINT: Color = Color("d6cfb8")
const TAG: Color = Color("e2cd9c")
const STRING: Color = Color("efe4c8")
const BUTTON: Color = Color("7d5f3c")
const TWINE: Color = Color("9c7a44")
const WAX: Color = Color("9a1d12")
const INSIDE: Color = Color("4a3622")
const PRINT: Color = Color("4b463c")
const EDGE: Color = Color("3e3020")
const SEED: int = 6143
## The flap's depth as a share of the height, kept within a few pixels on a small sheet.
const FLAP: float = 0.17
const FLAP_LEAST: float = 14.0
## Below this size a sheet has not been laid out yet, and nothing is drawn.
const SMALLEST: float = 12.0


## The wrapping's paper after handling: never clean, darker as the stage deepens.
static func paper(wrapping: int, worn: float) -> Color:
	var clean: Color = MANILA
	if wrapping == WAX_SEAL:
		clean = KRAFT
	elif wrapping == PARCEL:
		clean = NEWSPRINT
	return BowlGrime.aged(clean, worn)


## One envelope or parcel filling rect.
static func draw(
	canvas: CanvasItem,
	rect: Rect2,
	wrapping: int,
	worn: float,
	which: int,
	opened: float = 0.0,
	alpha: float = 1.0
) -> void:
	if rect.size.x < SMALLEST or rect.size.y < SMALLEST:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 131 * which + 17 * wrapping
	var body: PackedVector2Array = _outline(rect, rng, worn)
	canvas.draw_colored_polygon(body, Color(paper(wrapping, worn), alpha))
	if wrapping == PARCEL:
		_newsprint(canvas, rect, rng, worn, alpha)
		_grime(canvas, rect, rng, worn, alpha)
		_parcel_open(canvas, rect, worn, opened, alpha)
		_label(canvas, rect, worn, alpha)
		_twine(canvas, rect, worn, alpha * clampf(1.0 - opened * 2.0, 0.0, 1.0))
	else:
		_grime(canvas, rect, rng, worn, alpha)
		var tip: Vector2 = _flap(canvas, rect, wrapping, worn, opened, alpha)
		if wrapping == WAX_SEAL:
			_seal(canvas, tip, rect, worn, opened, alpha)
		else:
			_tie(canvas, tip, rect, worn, opened, alpha)
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), Color(EDGE, alpha * 0.6), 1.4)


## The flap: a shallow V from the top corners. Opening lifts it over the top edge and
## shows the dark inside. Returns where its tip now is.
static func _flap(
	canvas: CanvasItem, rect: Rect2, wrapping: int, worn: float, opened: float, alpha: float
) -> Vector2:
	var depth: float = maxf(rect.size.y * FLAP, FLAP_LEAST)
	var left: Vector2 = rect.position
	var right: Vector2 = Vector2(rect.end.x, rect.position.y)
	var middle: float = rect.get_center().x
	var seam: Color = Color(EDGE, alpha * (0.18 + 0.12 * worn))
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), rect.get_center(), seam, 1.0)
	canvas.draw_line(rect.end, rect.get_center(), seam, 1.0)
	if opened > 0.0:
		var mouth: PackedVector2Array = [left, right, Vector2(middle, left.y + depth)]
		canvas.draw_colored_polygon(mouth, Color(BowlGrime.aged(INSIDE, worn), alpha * opened))
	var tip: Vector2 = Vector2(middle, left.y + depth * (1.0 - 2.0 * opened))
	var shade: Color = BowlGrime.aged(paper(wrapping, worn).darkened(0.08), worn * 0.3)
	canvas.draw_colored_polygon(PackedVector2Array([left, right, tip]), Color(shade, alpha))
	var edge: Color = Color(EDGE, alpha * 0.55)
	canvas.draw_polyline(PackedVector2Array([left, tip, right]), edge, 1.2)
	return tip


## A red wax seal on the flap's tip, its edge uneven. Opening cracks it in two halves that
## part as the flap lifts.
static func _seal(
	canvas: CanvasItem, tip: Vector2, rect: Rect2, worn: float, opened: float, alpha: float
) -> void:
	var radius: float = clampf(rect.size.x * 0.05, 6.0, 30.0)
	var wax: Color = Color(BowlGrime.aged(WAX, worn * 0.6), alpha)
	var part: float = radius * 1.6 * opened
	var lip: Color = Color(wax.darkened(0.35), alpha)
	for side: int in [-1, 1]:
		var at: Vector2 = tip + Vector2(side * part, part * 0.4)
		var from: float = PI * 0.5 if side < 0 else -PI * 0.5
		var points: PackedVector2Array = [at]
		for step: int in 13:
			var angle: float = from + PI * step / 12.0
			var wobble: float = 1.0 + 0.12 * sin(angle * 5.0 + 1.3)
			points.append(at + Vector2.from_angle(angle) * radius * wobble)
		canvas.draw_colored_polygon(points, wax)
		canvas.draw_arc(at, radius * 0.55, from, from + PI, 10, lip, 1.4, true)
	if opened <= 0.0:
		canvas.draw_line(tip + Vector2(0, -radius * 0.4), tip + Vector2(0, radius * 0.4), lip, 1.2)


## Two card buttons, one on the flap and one below it on the body, with the string wound
## round both in a figure of eight. Opening unwinds it: the string falls loose.
static func _tie(
	canvas: CanvasItem, tip: Vector2, rect: Rect2, worn: float, opened: float, alpha: float
) -> void:
	var radius: float = clampf(rect.size.x * 0.03, 4.5, 18.0)
	var below: Vector2 = Vector2(tip.x, rect.position.y + maxf(rect.size.y * FLAP, FLAP_LEAST))
	below.y += radius * 2.4
	var button: Color = Color(BowlGrime.aged(BUTTON, worn * 0.5), alpha)
	var string: Color = Color(BowlGrime.aged(STRING, worn), alpha)
	var wound: float = clampf(1.0 - opened * 2.0, 0.0, 1.0)
	for at: Vector2 in [tip, below]:
		canvas.draw_circle(at, radius, button)
		canvas.draw_circle(at, radius * 0.25, Color(EDGE, alpha * 0.7))
	if wound > 0.0:
		var tight: Color = Color(string, alpha * wound)
		var width: float = maxf(radius * 0.28, 1.2)
		canvas.draw_line(tip + Vector2(-radius, 0), below + Vector2(radius, 0), tight, width)
		canvas.draw_line(tip + Vector2(radius, 0), below + Vector2(-radius, 0), tight, width)
		canvas.draw_arc(tip, radius * 1.05, PI, TAU, 10, tight, width, true)
		canvas.draw_arc(below, radius * 1.05, 0.0, PI, 10, tight, width, true)
	# The free end, hanging down the body, longer once it is unwound.
	var hang: float = radius * (3.0 + 6.0 * opened)
	var end: Vector2 = below + Vector2(radius * 1.6, hang)
	var loose: PackedVector2Array = [below, below + Vector2(radius * 1.8, hang * 0.5), end]
	canvas.draw_polyline(loose, string, maxf(radius * 0.25, 1.1), true)


## Old newspaper: three columns of grey lines and a dark headline bar, printed at a slant.
static func _newsprint(
	canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator, worn: float, alpha: float
) -> void:
	var ink: Color = Color(BowlGrime.aged(PRINT, worn * 0.4), alpha * (0.32 - 0.08 * worn))
	var column: float = (rect.size.x - 16.0) / 3.0
	var step: float = maxf(rect.size.y * 0.035, 3.0)
	for index: int in 3:
		var x: float = rect.position.x + 8.0 + index * column
		var y: float = rect.position.y + 6.0 + rng.randf_range(0.0, step)
		if index == 1:
			var bar: Rect2 = Rect2(x + 2.0, y, column - 6.0, step * 1.6)
			canvas.draw_rect(bar, Color(ink, ink.a * 1.6))
			y += step * 2.6
		while y < rect.end.y - 6.0:
			var short: float = rng.randf_range(0.0, column * 0.3) if rng.randf() < 0.2 else 0.0
			canvas.draw_line(Vector2(x + 2.0, y), Vector2(x + column - 6.0 - short, y), ink, 1.0)
			y += step


## The manila label tucked under the twine, where the counter's words sit.
static func _label(canvas: CanvasItem, rect: Rect2, worn: float, alpha: float) -> void:
	var tag: Rect2 = Rect2(
		rect.position + Vector2(rect.size.x * 0.04, rect.size.y * 0.14),
		Vector2(rect.size.x * 0.92, rect.size.y * 0.5)
	)
	canvas.draw_rect(tag, Color(BowlGrime.aged(TAG, worn), alpha))
	canvas.draw_rect(tag, Color(EDGE, alpha * 0.45), false, 1.0)
	var hole: Vector2 = Vector2(tag.end.x - tag.size.y * 0.16, tag.get_center().y)
	canvas.draw_circle(hole, maxf(tag.size.y * 0.06, 2.0), Color(EDGE, alpha * 0.5))
	var speck: Color = Color(BowlGrime.TEA, alpha * (0.2 + 0.3 * worn))
	canvas.draw_circle(tag.position + tag.size * Vector2(0.7, 0.75), tag.size.y * 0.12, speck)


## Twine once round each way, knotted where it crosses, near the top right.
static func _twine(canvas: CanvasItem, rect: Rect2, worn: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var twine: Color = Color(BowlGrime.aged(TWINE, worn * 0.6), alpha)
	var width: float = clampf(rect.size.y * 0.025, 1.6, 6.0)
	var across: float = rect.position.y + rect.size.y * 0.075
	var down: float = rect.position.x + rect.size.x * 0.84
	canvas.draw_line(Vector2(rect.position.x, across), Vector2(rect.end.x, across), twine, width)
	canvas.draw_line(Vector2(down, rect.position.y), Vector2(down, rect.end.y), twine, width)
	var knot: Vector2 = Vector2(down, across)
	var loop: float = width * 2.2
	canvas.draw_arc(knot + Vector2(-loop, 0), loop, 0.0, TAU, 12, twine, width * 0.7, true)
	canvas.draw_arc(knot + Vector2(loop, 0), loop, 0.0, TAU, 12, twine, width * 0.7, true)
	canvas.draw_circle(knot, width * 0.9, Color(twine.darkened(0.3), alpha))


## Opening tears the newspaper across the top: a ragged edge falls as it opens, and the
## dark inside shows above it.
static func _parcel_open(
	canvas: CanvasItem, rect: Rect2, worn: float, opened: float, alpha: float
) -> void:
	if opened <= 0.0:
		return
	var fall: float = rect.size.y * 0.3 * opened
	var teeth: int = 14
	var points: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y)]
	for index: int in range(teeth, -1, -1):
		var x: float = rect.position.x + rect.size.x * index / teeth
		var jag: float = (3.0 + 3.0 * worn) * (1.0 if index % 2 == 0 else -1.0)
		points.append(Vector2(x, rect.position.y + fall + jag * opened))
	canvas.draw_colored_polygon(points, Color(BowlGrime.aged(INSIDE, worn), alpha * opened))


## Corners out of true, the bottom right softened, more so as the stage deepens.
static func _outline(rect: Rect2, rng: RandomNumberGenerator, worn: float) -> PackedVector2Array:
	var jitter: float = 0.7 + 1.5 * worn
	var soft: float = minf(5.0 + 9.0 * worn, rect.size.y * 0.2)
	var points: PackedVector2Array = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.end.y - soft),
		Vector2(rect.end.x - soft * 0.7, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	]
	for index: int in points.size():
		points[index] += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	return points


## A fold across, foxing, a thumbed smudge and a tea ring.
static func _grime(
	canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator, worn: float, alpha: float
) -> void:
	var fold: Color = Color(EDGE, alpha * (0.14 + 0.2 * worn))
	var across: float = rect.position.y + rect.size.y * rng.randf_range(0.55, 0.68)
	canvas.draw_line(Vector2(rect.position.x + 2, across), Vector2(rect.end.x - 2, across), fold)
	var speck: Color = Color(BowlGrime.TEA, alpha * (0.25 + 0.35 * worn))
	for _spot: int in roundi(lerpf(8, 50, worn)):
		var at: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		canvas.draw_circle(at, rng.randf_range(0.6, 1.8), speck)
	var thumb: Vector2 = rect.position + Vector2(rng.randf_range(0.1, 0.3), 0.85) * rect.size
	canvas.draw_circle(thumb, rect.size.x * 0.08, Color(BowlGrime.TEA, alpha * (0.06 + 0.1 * worn)))
	var ring: Vector2 = rect.position + Vector2(rng.randf(), rng.randf_range(0.4, 0.9)) * rect.size
	var tea: Color = Color(BowlGrime.TEA, alpha * (0.07 + 0.17 * worn))
	canvas.draw_arc(
		ring, rect.size.x * rng.randf_range(0.1, 0.18), 0.0, TAU, 28, tea, 2.0 + 2.0 * worn, true
	)
