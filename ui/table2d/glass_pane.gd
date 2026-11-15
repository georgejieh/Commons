class_name GlassPane
extends Control
## Glass Walls at the table (ADR 0023): while both villagers see the player's hand, a pane
## of old window glass lies over it, streaked and smudged, with a slip saying so. The
## glass is faint where the cards are, so it never hides a rank; it is already grimy at
## corruption stage 0 and cracks and clouds further with BowlGrime.wear(). Clicks pass
## through it.

const GLASS: Color = Color("9fb4b8")
const STREAK: Color = Color("f4f1e6")
const FILL_ALPHA: float = 0.07
const STREAK_ALPHA: float = 0.1
const SMUDGE_ALPHA: float = 0.07
const CRACK_ALPHA: float = 0.32
const STREAK_GAP: float = 150.0
const STREAK_WIDTH: float = 26.0
const EDGE: float = 4.0
const SEED: int = 2309
const SMUDGES: Vector2i = Vector2i(6, 22)
const CRACKS: Vector2i = Vector2i(2, 9)
const FADE_TIME: float = 0.35
const SLIP_SIZE: int = 18
const SLIP_PADDING: int = 12

var _slip: PanelContainer = PanelContainer.new()
var _words: Label = Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_slip.add_theme_stylebox_override("panel", ScreenKit.paper_style(SLIP_PADDING))
	_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.add_theme_font_size_override("font_size", SLIP_SIZE)
	_words.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_words.add_theme_color_override("font_color", ScreenKit.INK)
	_slip.add_child(_words)
	add_child(_slip)


## Shows or clears the glass; animate fades it in, as the round's beat.
func set_shown(on: bool, animate: bool) -> void:
	_words.text = tr("table.glass_walls")
	_slip.reset_size()
	_slip.position = Vector2(size.x - _slip.size.x, -_slip.size.y - EDGE)
	if on == visible:
		return
	visible = on
	queue_redraw()
	if on and animate and not UiMotion.reduced():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)
	else:
		modulate.a = 1.0


## The slip's words, for tests.
func shown_text() -> String:
	return _words.text if visible else ""


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(BowlGrime.aged(GLASS, worn), FILL_ALPHA + 0.05 * worn))
	draw_rect(rect, Color(BowlGrime.aged(GLASS, worn).darkened(0.5), 0.5), false, EDGE)
	var x: float = -size.y
	while x < size.x:
		var streak: PackedVector2Array = [
			Vector2(x, size.y),
			Vector2(x + size.y, 0.0),
			Vector2(x + size.y + STREAK_WIDTH, 0.0),
			Vector2(x + STREAK_WIDTH, size.y),
		]
		draw_colored_polygon(streak, Color(STREAK, STREAK_ALPHA * (1.0 - 0.5 * worn)))
		x += STREAK_GAP
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for _smudge: int in _count(SMUDGES, worn):
		var at: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var radius: float = rng.randf_range(12.0, 40.0)
		draw_circle(at, radius, Color(BowlGrime.TEA, SMUDGE_ALPHA * (0.6 + worn)))
	for _crack: int in _count(CRACKS, worn):
		_crack_line(rng, worn)


## A crack from the glass's edge, kept to the bottom band below the cards' corners.
func _crack_line(rng: RandomNumberGenerator, worn: float) -> void:
	var start: Vector2 = Vector2(rng.randf() * size.x, size.y)
	var points: PackedVector2Array = [start]
	for _step: int in 4:
		var last: Vector2 = points[-1]
		points.append(last + Vector2(rng.randf_range(-40.0, 40.0), -rng.randf_range(8.0, 22.0)))
	draw_polyline(points, Color(BowlGrime.CRACK, CRACK_ALPHA * (0.5 + worn)), 1.5)


static func _count(span: Vector2i, worn: float) -> int:
	return roundi(lerpf(span.x, span.y, clampf((worn - BowlGrime.BASE_WEAR) / 0.7, 0.0, 1.0)))
