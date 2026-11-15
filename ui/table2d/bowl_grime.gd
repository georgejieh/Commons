class_name BowlGrime
extends RefCounted
## The wear on the dice bowl and its dice. Nothing in the village is clean: at corruption
## stage 0 the glaze is already yellowed, crazed and tea-stained, and each stage adds
## cracks, chips and dirt until the bowl is filthy and the red 1 looks back (ADR 0018).
## It is drawn by rule from fixed seeds, so the same bowl comes out every time.

## Wear at stage 0, and the stage from which the 1 becomes an eye.
const BASE_WEAR: float = 0.3
const EYE_STAGE: int = 7
const BONE: Color = Color("d9cba6")
const CLAY: Color = Color("7d6248")
const CRACK: Color = Color("3a2c1e")
const TEA: Color = Color("5a3d1e")
const DRIED: Color = Color("47120f")
const SEED: int = 5417
const CRACKS: Vector2i = Vector2i(9, 34)
const SPECKS: Vector2i = Vector2i(40, 170)
const CHIPS: Vector2i = Vector2i(2, 7)
const BLOTCHES: Vector2i = Vector2i(4, 11)
const SCRATCHES: Vector2i = Vector2i(2, 7)


## How worn things are now, from BASE_WEAR at stage 0 to 1 at the last stage.
static func wear() -> float:
	var last: float = maxf(BoardState.CORRUPTION_STAGES - 1.0, 1.0)
	return lerpf(BASE_WEAR, 1.0, clampf(ArtStages.stage() / last, 0.0, 1.0))


## True once the stage is deep enough for the 1 to be an eye.
static func watching() -> bool:
	return ArtStages.stage() >= EYE_STAGE


## A clean colour as it looks after years of handling: pulled toward bone and dulled.
static func aged(clean: Color, worn: float) -> Color:
	return clean.lerp(BONE, 0.22 + 0.38 * worn).darkened(0.04 + 0.2 * worn)


## The bowl's grime over its glaze: tea stains in the well, crazing through the glaze,
## dirt, chips out of the rim down to the clay, and at the worst stages a dried ring.
static func bowl(canvas: CanvasItem, at: Vector2, radius: float, alpha: float, worn: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var stain: Color = Color(TEA, alpha * (0.07 + 0.2 * worn))
	canvas.draw_arc(at, radius * 0.47, 0.0, TAU, 72, stain, radius * 0.07, true)
	for _blotch: int in _count(BLOTCHES, worn):
		var spot: Vector2 = at + _in_disc(rng, radius * 0.8)
		canvas.draw_circle(spot, radius * rng.randf_range(0.04, 0.13), stain)
	var hair: Color = Color(CRACK, alpha * (0.22 + 0.45 * worn))
	for _crack: int in _count(CRACKS, worn):
		canvas.draw_polyline(_crack_line(rng, at, radius), hair, 1.0 + worn, true)
	var dirt: Color = Color(CRACK, alpha * (0.3 + 0.4 * worn))
	for _speck: int in _count(SPECKS, worn):
		canvas.draw_circle(at + _in_disc(rng, radius * 0.97), rng.randf_range(0.8, 2.6), dirt)
	for _chip: int in _count(CHIPS, worn):
		var edge: Vector2 = at + Vector2.from_angle(rng.randf() * TAU) * radius
		canvas.draw_circle(edge, radius * rng.randf_range(0.02, 0.05), Color(CLAY, alpha))
	var dried: float = clampf((worn - 0.6) / 0.4, 0.0, 1.0)
	if dried > 0.0:
		var ring: Color = Color(DRIED, alpha * 0.5 * dried)
		canvas.draw_arc(at, radius * 0.3, 0.3, TAU * 0.86, 48, ring, radius * 0.09, true)


## A die's wear, drawn in the die's own space (its middle at the origin): scratches
## across the face, grime along the edges and a knocked corner. Each die has its own.
static func die(canvas: CanvasItem, side: float, alpha: float, worn: float, which: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 97 * (which + 1)
	var half: float = side / 2.0
	var mark: Color = Color(CRACK, alpha * (0.2 + 0.35 * worn))
	for _scratch: int in _count(SCRATCHES, worn):
		var from: Vector2 = (
			Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half)) * 0.8
		)
		var reach: Vector2 = (
			Vector2.from_angle(rng.randf() * TAU) * side * rng.randf_range(0.15, 0.4)
		)
		var to: Vector2 = (from + reach).clamp(
			Vector2.ONE * -half * 0.85, Vector2.ONE * half * 0.85
		)
		canvas.draw_line(from, to, mark, 1.0, true)
	var edge: Color = Color(TEA, alpha * (0.12 + 0.3 * worn))
	var inset: float = half * 0.86
	canvas.draw_rect(Rect2(-inset, -inset, inset * 2.0, inset * 2.0), edge, false, 3.0)
	var corner: Vector2 = Vector2(1 if which % 2 == 0 else -1, 1) * half * 0.84
	canvas.draw_circle(corner, side * (0.05 + 0.07 * worn), Color(CLAY, alpha * 0.85))


## The red 1 as an eye: a dark iris ring, a pupil and a wet glint, over the pip.
static func eye(canvas: CanvasItem, radius: float, alpha: float) -> void:
	canvas.draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 32, Color(DRIED, alpha), 2.0, true)
	canvas.draw_circle(Vector2.ZERO, radius * 0.42, Color(0.04, 0.03, 0.03, alpha))
	canvas.draw_circle(Vector2(-0.2, -0.22) * radius, radius * 0.12, Color(1, 1, 1, alpha * 0.8))


static func _count(span: Vector2i, worn: float) -> int:
	return roundi(lerpf(span.x, span.y, worn))


static func _in_disc(rng: RandomNumberGenerator, radius: float) -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())


## One craze line: a few short, bent strokes running outward from somewhere in the glaze.
static func _crack_line(
	rng: RandomNumberGenerator, at: Vector2, radius: float
) -> PackedVector2Array:
	var line: PackedVector2Array = PackedVector2Array()
	var point: Vector2 = at + _in_disc(rng, radius * 0.75)
	var heading: float = rng.randf() * TAU
	line.append(point)
	for _bend: int in rng.randi_range(2, 4):
		heading += rng.randf_range(-0.7, 0.7)
		point += Vector2.from_angle(heading) * radius * rng.randf_range(0.06, 0.16)
		if point.distance_to(at) > radius * 0.98:
			break
		line.append(point)
	return line
