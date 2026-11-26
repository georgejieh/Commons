class_name EndingPaper
extends PanelContainer
## The aged sheet an ending is printed on (ADR 0024): the card stock with a printed double
## frame and corner marks in red ink, and the grime of years on it. Nothing is clean: at
## stage 0 it is already foxed, tea-ringed and handled at the edges, and each stage adds
## more until the frame is broken and a corner torn (art/STYLE.md). The stains keep to the
## margins and stay faint inside, so the words over them always read. Drawn by rule from a
## fixed seed, so the same sheet comes out every time.

const TEA: Color = Color("6b4a24")
const DIRT: Color = Color("3a2c1e")
const SEED: int = 7703
## The printed frame's insets from the paper's edge, and its corner marks.
const OUTER: float = 18.0
const INNER: float = 26.0
const CORNER: float = 22.0
## The outer rule is printed in this many pieces a side, and at full wear this share of
## them is gone.
const SEGMENTS: int = 24
const BREAK: float = 0.3
## How far from the edge the heavy stains stay, as a share of the short side.
const EDGE_BAND: float = 0.1
const RINGS: Vector2i = Vector2i(2, 6)
const BLOTCHES: Vector2i = Vector2i(6, 22)
const SPECKS: Vector2i = Vector2i(40, 220)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ScreenKit.paper_style(48))


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	_stains(rng, worn)
	_frame(worn)


## The printed frame: two rules and corner marks, a little off true. The outer rule
## breaks in places as the sheet wears.
func _frame(worn: float) -> void:
	var ink: Color = Color(BowlGrime.faded(ScreenKit.ENDING_INK, worn), 0.7 - 0.25 * worn)
	var outer: Rect2 = Rect2(Vector2(1.5, -1.0), size).grow(-OUTER)
	var inner: Rect2 = Rect2(Vector2.ZERO, size).grow(-INNER)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var points: Array[Vector2] = _corners(outer)
	for side: int in points.size():
		var from: Vector2 = points[side]
		var to: Vector2 = points[(side + 1) % points.size()]
		for piece: int in SEGMENTS:
			if rng.randf() < BREAK * worn:
				continue
			var start: Vector2 = from.lerp(to, float(piece) / SEGMENTS)
			var end: Vector2 = from.lerp(to, float(piece + 1) / SEGMENTS)
			draw_line(start, end, ink, 3.0)
	draw_rect(inner, Color(ink, ink.a * 0.7), false, 1.5)
	for corner: Vector2 in _corners(inner):
		var toward: Vector2 = (inner.get_center() - corner).sign()
		var mark: Rect2 = Rect2(corner + toward * 6.0 - Vector2.ONE * 4.0, Vector2.ONE * 8.0)
		draw_rect(mark, ink)
		draw_line(corner, corner + Vector2(toward.x * CORNER, 0), ink, 2.0)
		draw_line(corner, corner + Vector2(0, toward.y * CORNER), ink, 2.0)


static func _corners(box: Rect2) -> Array[Vector2]:
	return [
		box.position,
		Vector2(box.end.x, box.position.y),
		box.end,
		Vector2(box.position.x, box.end.y)
	]


## Foxing, tea rings and handling dirt, heavy at the margins and faint inside; at the
## worst stages a dried ring and a torn corner.
func _stains(rng: RandomNumberGenerator, worn: float) -> void:
	var band: float = minf(size.x, size.y) * EDGE_BAND
	for _ring: int in _count(RINGS, worn):
		var at: Vector2 = _near_edge(rng, band)
		var radius: float = rng.randf_range(30.0, 70.0)
		var tea: Color = Color(TEA, 0.06 + 0.12 * worn)
		draw_arc(at, radius, rng.randf() * TAU, rng.randf() * TAU + 4.5, 48, tea, 3.0, true)
	for _blotch: int in _count(BLOTCHES, worn):
		var spot: Vector2 = _near_edge(rng, band)
		var reach: float = rng.randf_range(14.0, 46.0) * (0.7 + worn)
		var wash: Color = Color(TEA, 0.04 + 0.08 * worn)
		draw_circle(spot, reach, wash)
		draw_circle(spot + Vector2(reach * 0.4, -reach * 0.3), reach * 0.6, wash)
	for _speck: int in _count(SPECKS, worn):
		var at: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_circle(at, rng.randf_range(0.6, 1.8), Color(DIRT, 0.1 + 0.2 * worn))
	var torn: float = clampf((worn - 0.6) / 0.4, 0.0, 1.0)
	if torn > 0.0:
		var reach: float = 90.0 * torn
		var corner: PackedVector2Array = [
			Vector2(size.x, size.y - reach),
			Vector2(size.x, size.y),
			Vector2(size.x - reach, size.y)
		]
		draw_colored_polygon(corner, Color(0.05, 0.03, 0.02, 0.85))
		var dried: Color = Color(BowlGrime.DRIED, 0.18 * torn)
		draw_arc(Vector2(size.x * 0.12, size.y * 0.85), 54.0, 0.4, TAU * 0.8, 40, dried, 6.0, true)


## A point in the band along one of the sheet's four edges.
func _near_edge(rng: RandomNumberGenerator, band: float) -> Vector2:
	var at: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
	match rng.randi_range(0, 3):
		0:
			at.x = rng.randf() * band
		1:
			at.x = size.x - rng.randf() * band
		2:
			at.y = rng.randf() * band
		_:
			at.y = size.y - rng.randf() * band
	return at


static func _count(span: Vector2i, worn: float) -> int:
	return roundi(lerpf(span.x, span.y, worn))
