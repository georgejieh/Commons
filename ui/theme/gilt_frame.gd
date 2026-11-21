class_name GiltFrame
extends RefCounted
## The game's one mark for "this is the thing": a gilt frame with a vermilion halo round
## a button, a card or a paper, drawn by whoever lights it (the arrival's TutorialGlow, a
## pointed paper in an open envelope). Nothing is clean (art/STYLE.md): the gilt is laid
## in uneven strokes at stage 0, and at each corruption stage more of it has flaked off.

const GILT: Color = Color("f6c955")
const HALO: Color = Color("b02a17")
const UNDER: Color = Color(0.09, 0.07, 0.05, 0.6)
const WIDTH: float = 4.0
const RADIUS: float = 10.0
## How many passes paint the halo.
const PASSES: int = 4
## The frame is laid in strokes about this long, each a little thicker or thinner.
const STROKE: float = 16.0
const UNEVEN: float = 0.22
## The share of strokes flaked off per corruption stage.
const FLAKED_PER_STAGE: float = 0.035
const SEED: int = 2617


## A closed path round rect with rounded corners, in strokes of about STROKE.
static func path(rect: Rect2, radius: float = RADIUS) -> PackedVector2Array:
	var round: float = minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var made: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [
		rect.position + Vector2(round, round),
		Vector2(rect.end.x - round, rect.position.y + round),
		rect.end - Vector2(round, round),
		Vector2(rect.position.x + round, rect.end.y - round),
	]
	for corner: int in 4:
		# Each corner's arc, then the straight edge to the next corner.
		for step: int in 5:
			var angle: float = PI + corner * PI / 2.0 + step * PI / 8.0
			made.append(corners[corner] + Vector2(cos(angle), sin(angle)) * round)
		var from: Vector2 = made[made.size() - 1]
		var next: int = (corner + 1) % 4
		var turn: float = PI + next * PI / 2.0
		var to: Vector2 = corners[next] + Vector2(cos(turn), sin(turn)) * round
		var strokes: int = maxi(1, roundi(from.distance_to(to) / STROKE))
		for step: int in range(1, strokes):
			made.append(from.lerp(to, float(step) / strokes))
	made.append(made[0])
	return made


## The soft light round the frame, reaching reach px past it, at alpha a pass.
static func halo(canvas: CanvasItem, frame: PackedVector2Array, reach: float, alpha: float) -> void:
	for step: int in PASSES:
		var wide: float = WIDTH + reach * 2.0 * float(PASSES - step) / PASSES
		canvas.draw_polyline(frame, Color(HALO, alpha), wide, true)


## The frame itself, stroke by stroke over a dark underline, so it reads on paper and on
## wood alike. shine fades it; salt varies the strokes from one frame to the next.
static func gild(canvas: CanvasItem, frame: PackedVector2Array, shine: float, salt: int) -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = SEED + 97 * salt
	canvas.draw_polyline(frame, Color(UNDER, UNDER.a * shine), WIDTH + 3.0, true)
	var flaked: float = FLAKED_PER_STAGE * ArtStages.art_stage()
	for index: int in frame.size() - 1:
		var uneven: float = 1.0 + random.randf_range(-UNEVEN, UNEVEN)
		if random.randf() < flaked:
			continue
		canvas.draw_line(frame[index], frame[index + 1], Color(GILT, shine), WIDTH * uneven, true)
