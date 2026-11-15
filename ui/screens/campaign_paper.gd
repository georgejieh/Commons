class_name CampaignPaper
extends RefCounted
## Campaign paper as the village has it (art/STYLE.md, "Nothing is clean"): a leaflet,
## a tray's empty place or a folded note, never white and never crisp. At corruption
## stage 0 it is already yellowed, with a fold line, a tea stain, foxing and a worn
## corner; every stage adds more, by BowlGrime.wear(). Each sheet draws from its own
## fixed seed, so the same leaflet always looks the same.

## Warm, like the other village papers, so a leaflet never reads as greyed out.
const PAPER: Color = Color("ecd7a2")
const SHADE: Color = Color("c9b68a")
const FOLD: Color = Color("8a7653")
const EDGE: Color = Color("4a3a26")
const PRIVATE_BAND: Color = Color("2b2622")
const COLLECTIVE_BAND: Color = Color("9e2a1d")
const SEED: int = 7907
const FOXING: Vector2i = Vector2i(6, 40)
const STAINS: Vector2i = Vector2i(1, 4)


## The paper's colour after handling: never white, darker as the stage deepens.
static func paper(worn: float) -> Color:
	return BowlGrime.aged(PAPER, worn)


## A band or ink colour, faded a little: printing outlasts the paper it is on.
static func ink(clean: Color, worn: float) -> Color:
	return BowlGrime.aged(clean, worn * 0.3)


## A leaflet sheet filling rect: aged paper with a coloured head band, a fold across the
## middle, foxing, a tea stain and a dog-eared corner.
static func leaflet(
	canvas: CanvasItem, rect: Rect2, private: bool, worn: float, which: int, alpha: float = 1.0
) -> void:
	var rng: RandomNumberGenerator = _rng(which)
	var body: PackedVector2Array = _worn_outline(rect, rng, worn)
	canvas.draw_colored_polygon(body, Color(paper(worn), alpha))
	var band_color: Color = PRIVATE_BAND if private else COLLECTIVE_BAND
	var band: Rect2 = Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 9))
	canvas.draw_rect(band, Color(ink(band_color, worn), alpha * 0.9))
	_wear(canvas, rect, rng, worn, alpha)
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), Color(EDGE, alpha * 0.55), 1.5)


## An empty place in a tray: a faint outline where a leaflet would lie, smudged.
static func empty_place(canvas: CanvasItem, rect: Rect2, worn: float, which: int) -> void:
	var rng: RandomNumberGenerator = _rng(which + 50)
	var outline: PackedVector2Array = _worn_outline(rect, rng, worn)
	canvas.draw_colored_polygon(outline, Color(SHADE, 0.18 + 0.12 * worn))
	canvas.draw_polyline(
		outline + PackedVector2Array([outline[0]]), Color(EDGE, 0.3 + 0.2 * worn), 1.0
	)


## A folded note: a small sheet folded in half, the crease and its shadow showing.
static func note(canvas: CanvasItem, rect: Rect2, worn: float, alpha: float = 1.0) -> void:
	var rng: RandomNumberGenerator = _rng(91)
	var body: PackedVector2Array = _worn_outline(rect, rng, worn)
	canvas.draw_colored_polygon(body, Color(paper(worn), alpha))
	var crease: float = rect.position.y + rect.size.y * 0.45
	var shadow: Rect2 = Rect2(rect.position.x, crease, rect.size.x, rect.size.y * 0.55)
	canvas.draw_rect(shadow, Color(SHADE, alpha * 0.45))
	canvas.draw_line(
		Vector2(rect.position.x, crease), Vector2(rect.end.x, crease), Color(FOLD, alpha), 1.5
	)
	_wear(canvas, rect, rng, worn, alpha)
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), Color(EDGE, alpha * 0.6), 1.5)


## The sheet's outline, its corners a little out of true and the bottom right one worn
## or dog-eared, more so as the stage deepens.
static func _worn_outline(
	rect: Rect2, rng: RandomNumberGenerator, worn: float
) -> PackedVector2Array:
	var jitter: float = 0.8 + 1.6 * worn
	var ear: float = 6.0 + 10.0 * worn
	var points: PackedVector2Array = [
		rect.position + _nudge(rng, jitter),
		Vector2(rect.end.x, rect.position.y) + _nudge(rng, jitter),
		Vector2(rect.end.x, rect.end.y - ear) + _nudge(rng, jitter),
		Vector2(rect.end.x - ear, rect.end.y) + _nudge(rng, jitter),
		Vector2(rect.position.x, rect.end.y) + _nudge(rng, jitter),
	]
	return points


## A fold line, foxing specks and a tea ring.
static func _wear(
	canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator, worn: float, alpha: float
) -> void:
	var fold_y: float = rect.position.y + rect.size.y * rng.randf_range(0.48, 0.58)
	var fold: Color = Color(FOLD, alpha * (0.25 + 0.3 * worn))
	canvas.draw_line(Vector2(rect.position.x + 2, fold_y), Vector2(rect.end.x - 2, fold_y), fold)
	var speck: Color = Color(BowlGrime.TEA, alpha * (0.25 + 0.35 * worn))
	for _spot: int in roundi(lerpf(FOXING.x, FOXING.y, worn)):
		var at: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		canvas.draw_circle(at, rng.randf_range(0.6, 1.8), speck)
	var tea: Color = Color(BowlGrime.TEA, alpha * (0.08 + 0.16 * worn))
	for _stain: int in roundi(lerpf(STAINS.x, STAINS.y, worn)):
		var middle: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var radius: float = minf(rect.size.x, rect.size.y) * rng.randf_range(0.12, 0.26)
		canvas.draw_arc(middle, radius, 0.0, TAU, 28, tea, 2.0 + 2.0 * worn, true)


static func _nudge(rng: RandomNumberGenerator, amount: float) -> Vector2:
	return Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount))


static func _rng(which: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 131 * which
	return rng
