class_name GlassPane
extends Control
## Glass Walls at the table (ADR 0023): while both villagers see the player's hand, a pane
## of old window glass lies over it in a weathered frame, with pale diagonal sheen across
## it, grimy smears in its corners and a slip saying so. Where the cards' corners are it
## is faint, so it never hides a rank or suit; it is already grimy at corruption stage 0,
## and smears, clouds and cracks further with BowlGrime.wear(). Clicks pass through it.

const GLASS: Color = Color("a9bfc2")
const SHEEN: Color = Color("fbf8ee")
const FRAME: Color = Color("4a3a2a")
const FILL_ALPHA: float = 0.12
const SHEEN_ALPHA: float = 0.2
const SMEAR_ALPHA: float = 0.3
const CRACK_ALPHA: float = 0.4
const SHEEN_GAP: float = 210.0
const SHEEN_WIDE: float = 34.0
const SHEEN_THIN: float = 9.0
const FRAME_WIDTH: float = 8.0
const HIGHLIGHT_WIDTH: float = 2.0
## Smears keep to the frame's corners, this far in at most, clear of the cards' indexes.
const SMEAR_REACH: float = 52.0
const SEED: int = 2309
const SMEARS: Vector2i = Vector2i(3, 8)
const CRACKS: Vector2i = Vector2i(2, 9)
const FADE_TIME: float = 0.35
const SLIP_SIZE: int = 18
## Room inside the slip's printed border, so its line clears it.
const SLIP_PADDING: int = 22
const SLIP_GAP: float = 6.0

## The slip gives way (ADR 0034): it stands only where its left edge is right of this x,
## in the pane's parent's space, which is where the line over the hand ends; and never
## while a sheet lies over its place. The pane and the rules slip under the right seat
## still say Glass Walls.
var clear_of: float = 0.0
var covered: bool = false

var _slip: PanelContainer = PanelContainer.new()
var _words: Label = Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_slip.add_theme_stylebox_override("panel", ScreenKit.paper_style(SLIP_PADDING))
	_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.add_theme_font_size_override("font_size", TextSize.px(SLIP_SIZE))
	_words.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_words.add_theme_color_override("font_color", ScreenKit.INK)
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slip.add_child(_words)
	add_child(_slip)


## Shows or clears the glass; animate fades it in, as the round's beat.
func set_shown(on: bool, animate: bool) -> void:
	place_slip()
	if on == visible:
		return
	visible = on
	queue_redraw()
	if on and animate and not UiMotion.reduced():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)
	else:
		modulate.a = 1.0


## Stands the slip over the pane's right end, or puts it away where it would lie on the
## line over the hand or under a sheet.
func place_slip() -> void:
	_words.text = tr("table.glass_walls")
	_slip.reset_size()
	_slip.position = Vector2(size.x - _slip.size.x, -_slip.size.y - SLIP_GAP)
	_slip.visible = not covered and position.x + _slip.position.x >= clear_of


## The slip's words, for tests.
func shown_text() -> String:
	return _words.text if visible else ""


## The slip and its line, for tests.
func slip() -> PanelContainer:
	return _slip


func words() -> Label:
	return _words


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(BowlGrime.aged(GLASS, worn), FILL_ALPHA + 0.06 * worn))
	_draw_sheen(worn)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		_smear(rng, corner, worn)
	for _crack: int in _count(CRACKS, worn):
		_crack_line(rng, worn)
	var frame: Color = BowlGrime.aged(FRAME, worn).darkened(0.2 * worn)
	draw_rect(rect, Color(frame, 0.9), false, FRAME_WIDTH)
	var inner: Rect2 = rect.grow(-FRAME_WIDTH * 0.5 - HIGHLIGHT_WIDTH)
	draw_rect(inner, Color(SHEEN, 0.45 - 0.2 * worn), false, HIGHLIGHT_WIDTH)


## Pale diagonal sheen across the pane: a wide band and a thin one beside it, again and
## again, dulled as the glass wears.
func _draw_sheen(worn: float) -> void:
	var alpha: float = SHEEN_ALPHA * (1.0 - 0.45 * worn)
	var x: float = -size.y
	while x < size.x:
		for band: Vector2 in [Vector2(0.0, SHEEN_WIDE), Vector2(SHEEN_WIDE + 12.0, SHEEN_THIN)]:
			var left: float = x + band.x
			var streak: PackedVector2Array = [
				Vector2(left, size.y),
				Vector2(left + size.y, 0.0),
				Vector2(left + size.y + band.y, 0.0),
				Vector2(left + band.y, size.y),
			]
			draw_colored_polygon(streak, Color(SHEEN, alpha))
		x += SHEEN_GAP


## Grime gathered in a corner of the frame: overlapping blots of tea and soot.
func _smear(rng: RandomNumberGenerator, corner: Vector2, worn: float) -> void:
	var inward: Vector2 = Vector2(
		1.0 if corner.x < size.x / 2.0 else -1.0, 1.0 if corner.y < size.y / 2.0 else -1.0
	)
	for _blot: int in _count(SMEARS, worn):
		var reach: Vector2 = Vector2(rng.randf(), rng.randf()) * SMEAR_REACH * 0.6
		var radius: float = rng.randf_range(10.0, SMEAR_REACH * 0.45)
		var ink: Color = BowlGrime.TEA if rng.randf() < 0.6 else BowlGrime.CRACK
		draw_circle(corner + reach * inward, radius, Color(ink, SMEAR_ALPHA * (0.5 + worn)))


## A crack from the glass's bottom edge, kept to the band below the cards' corners.
func _crack_line(rng: RandomNumberGenerator, worn: float) -> void:
	var start: Vector2 = Vector2(rng.randf() * size.x, size.y)
	var points: PackedVector2Array = [start]
	for _step: int in 4:
		var last: Vector2 = points[-1]
		points.append(last + Vector2(rng.randf_range(-40.0, 40.0), -rng.randf_range(8.0, 22.0)))
	draw_polyline(points, Color(BowlGrime.CRACK, CRACK_ALPHA * (0.5 + worn)), 1.5)


static func _count(span: Vector2i, worn: float) -> int:
	return roundi(lerpf(span.x, span.y, clampf((worn - BowlGrime.BASE_WEAR) / 0.7, 0.0, 1.0)))
