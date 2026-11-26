class_name CardMark
extends Control
## A mark that outlasts its round, drawn small on a card's left edge (ADR 0021, ADR 0041).
## A stamped card carries a red seal chop, the square of a name seal pressed in vermilion.
## An enhanced card carries one of four, each its own shape so they tell apart in
## grayscale and at hand size: a Model card a red and gold rosette with two ribbon tails,
## like a prize pinned on a worker; a Sheaf card an ear of wheat bound with a band, in the
## Grain's ochre; a Pennant card a red pennant on its staff, in the Zeal's ink; a Surplus
## card a green ration coupon with both ends torn along its perforation.
## All are drawn, so they need no art, and all have a dark edge to read over pictures.
## None is ever fresh (art/STYLE.md): the chop prints with gaps where the ink did not take,
## the rosette and the wheat are tarnished, the pennant frays and the coupon is foxed, a
## little at stage 0 and more with every stage.

enum Kind { STAMP, MODEL, SHEAF, PENNANT, SURPLUS }

## Each mark's box, in card pixels.
const SIZE: Vector2 = Vector2(30, 32)
## The ink and gold only fade a little with the stage (BowlGrime.faded), so a mark reads at
## hand size at every stage.
const GOLD_DARK: Color = Color("8a5a12")
const CHOP_TILT: float = -0.12
## The coupon leans the other way from the chop, so the two never read as one.
const COUPON_TILT: float = 0.2
const PETALS: int = 8
## Grains on the ear, alternating sides up the stalk.
const KERNELS: int = 6
## Teeth along each torn end of the coupon.
const PERFORATIONS: int = 4
const SEED: int = 3307
## Spots where the chop's ink did not take, at stage 0 and at the last stage; the coupon's
## foxing takes the same count.
const GAPS: Vector2i = Vector2i(2, 7)
## Each enhancement's mark.
const KINDS: Dictionary[String, Kind] = {
	CardInstance.MODEL: Kind.MODEL,
	CardInstance.SHEAF: Kind.SHEAF,
	CardInstance.PENNANT: Kind.PENNANT,
	CardInstance.SURPLUS: Kind.SURPLUS,
}

var kind: Kind = Kind.STAMP


func _init(mark_kind: Kind) -> void:
	kind = mark_kind
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## True when the enhancement has a drawn mark.
static func draws(enhancement_id: String) -> bool:
	return KINDS.has(enhancement_id)


func _draw() -> void:
	match kind:
		Kind.STAMP:
			_draw_chop()
		Kind.MODEL:
			_draw_rosette()
		Kind.SHEAF:
			_draw_sheaf()
		Kind.PENNANT:
			_draw_pennant()
		Kind.SURPLUS:
			_draw_coupon()


## A square of red ink with a paper border cut inside it and three strokes and a stem,
## the way a carved name seal prints.
func _draw_chop() -> void:
	var worn: float = BowlGrime.wear()
	var red: Color = BowlGrime.faded(ScreenKit.RED, worn)
	var paper: Color = BowlGrime.aged(ScreenKit.CARD_STOCK, worn)
	var side: float = minf(size.x, size.y) - 4.0
	draw_set_transform(size / 2.0, CHOP_TILT)
	var square: Rect2 = Rect2(Vector2.ONE * -side / 2.0, Vector2.ONE * side)
	draw_rect(square.grow(1.5), Color(ScreenKit.INK, 0.85))
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
		draw_colored_polygon(tail, BowlGrime.faded(ScreenKit.RED, worn))
	var gold: Color = BowlGrime.faded(ScreenKit.GOLD, worn)
	var dark: Color = BowlGrime.faded(GOLD_DARK, worn)
	var red: Color = BowlGrime.faded(ScreenKit.RED, worn)
	# A dark edge round the whole rosette, so it reads over stock and art alike.
	draw_circle(center, radius * 1.08, Color(ScreenKit.INK, 0.8))
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


## An ear of wheat on its stalk: grains in turn up a leaning stem, two awns at the tip and
## a red band tied round the foot, ochre over a dark edge, the band rubbed with wear.
func _draw_sheaf() -> void:
	var worn: float = BowlGrime.wear()
	var ochre: Color = BowlGrime.faded(GOLD_DARK, worn)
	var gold: Color = BowlGrime.aged(ScreenKit.GOLD, worn * 0.6)
	var edge: Color = Color(ScreenKit.INK, 0.8)
	var foot: Vector2 = Vector2(size.x * 0.42, size.y - 2.0)
	var tip: Vector2 = Vector2(size.x * 0.6, 3.0)
	draw_line(foot, tip, edge, 4.0, true)
	draw_line(foot, tip, ochre, 2.0, true)
	var along: Vector2 = (tip - foot).normalized()
	var across: Vector2 = along.orthogonal()
	for kernel: int in KERNELS:
		var at: Vector2 = foot.lerp(tip, 0.32 + 0.6 * kernel / float(KERNELS))
		var side: float = -1.0 if kernel % 2 == 0 else 1.0
		draw_colored_polygon(_kernel(at + across * side * 3.2, along, side, 1.0), edge)
		draw_colored_polygon(_kernel(at + across * side * 3.0, along, side, 0.72), gold)
	for side: float in [-1.0, 1.0]:
		draw_line(tip, tip + (along + across * side * 0.5) * 5.0, ochre, 1.2, true)
	var band: Vector2 = foot.lerp(tip, 0.2)
	draw_line(band - across * 5.0, band + across * 5.0, edge, 4.5)
	draw_line(band - across * 4.0, band + across * 4.0, BowlGrime.faded(ScreenKit.RED, worn), 2.5)
	draw_circle(band + across * (1.0 - 2.0 * worn), 0.6 + worn, Color(BowlGrime.TEA, 0.5))


## A grain of the ear: a lozenge leaning out from the stalk, at share of its full size.
static func _kernel(at: Vector2, along: Vector2, side: float, share: float) -> PackedVector2Array:
	var lean: Vector2 = (along + along.orthogonal() * side * 0.6).normalized()
	var width: Vector2 = lean.orthogonal() * 2.4 * share
	return PackedVector2Array(
		[at - lean * 3.0 * share, at + width, at + lean * 4.0 * share, at - width]
	)


## A red pennant on a dark staff, long and pointed, with a paper stripe at its hoist and
## a cut in its fly that deepens as it frays.
func _draw_pennant() -> void:
	var worn: float = BowlGrime.wear()
	var staff_x: float = 6.0
	draw_line(
		Vector2(staff_x, 2.0), Vector2(staff_x, size.y - 1.0), Color(ScreenKit.INK, 0.85), 3.0
	)
	draw_circle(Vector2(staff_x, 2.5), 2.0, BowlGrime.aged(ScreenKit.GOLD, worn))
	var hoist_top: Vector2 = Vector2(staff_x + 1.0, 4.0)
	var hoist_foot: Vector2 = Vector2(staff_x + 1.0, 20.0)
	var fly: Vector2 = Vector2(size.x - 1.0, 12.0)
	var cut: Vector2 = fly.lerp(Vector2(staff_x + 1.0, 12.0), 0.12 + 0.16 * worn)
	var flag: PackedVector2Array = [
		hoist_top, fly + Vector2(0.0, -2.0), cut, fly + Vector2(0.0, 2.0), hoist_foot
	]
	draw_colored_polygon(flag, BowlGrime.faded(ScreenKit.RED, worn))
	var outline: PackedVector2Array = flag.duplicate()
	outline.append(hoist_top)
	draw_polyline(outline, Color(ScreenKit.INK, 0.8), 1.5, true)
	var paper: Color = BowlGrime.aged(ScreenKit.CARD_STOCK, worn)
	draw_line(hoist_top + Vector2(3.0, 2.0), hoist_foot + Vector2(3.0, -2.0), paper, 2.0)


## A ration coupon, wider than tall and leaning, green with a paper border inside it and
## two printed lines, both ends torn along the perforation; foxing spots it with wear.
func _draw_coupon() -> void:
	var worn: float = BowlGrime.wear()
	var paper: Color = BowlGrime.aged(ScreenKit.CARD_STOCK, worn)
	var half: Vector2 = Vector2(size.x / 2.0 - 2.0, 7.5)
	draw_set_transform(size / 2.0, COUPON_TILT)
	draw_colored_polygon(_torn_slip(half + Vector2(1.5, 1.5)), Color(ScreenKit.INK, 0.85))
	draw_colored_polygon(_torn_slip(half), BowlGrime.faded(ScreenKit.COUPON, worn))
	var border: Vector2 = half - Vector2(4.0, 2.5)
	draw_rect(Rect2(-border, border * 2.0), paper, false, 1.2)
	for row: float in [-1.5, 2.0]:
		draw_line(Vector2(-half.x + 7.0, row), Vector2(half.x - 7.0, row), paper, 1.3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 1
	for _spot: int in roundi(lerpf(GAPS.x, GAPS.y, worn)):
		var at: Vector2 = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * half * 0.85
		draw_circle(at, rng.randf_range(0.5, 1.0 + worn * 0.5), Color(BowlGrime.TEA, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0)


## The coupon's outline about its middle: straight long sides, and both short ends cut in
## teeth, as a coupon torn off its sheet.
static func _torn_slip(half: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	var teeth: int = PERFORATIONS * 2
	for tooth: int in range(1, teeth):
		var bite: float = 1.8 if tooth % 2 == 1 else 0.0
		points.append(Vector2(half.x - bite, lerpf(-half.y, half.y, tooth / float(teeth))))
	points.append(Vector2(half.x, half.y))
	points.append(Vector2(-half.x, half.y))
	for tooth: int in range(teeth - 1, 0, -1):
		var bite: float = 1.8 if tooth % 2 == 1 else 0.0
		points.append(Vector2(-half.x + bite, lerpf(-half.y, half.y, tooth / float(teeth))))
	return points
