class_name FileStamp
extends Control
## The family's file on the title (ADR 0022): while the profile's file holds an entry, a
## file card stands in the page's top right corner, chopped in vermilion with the
## household's file and how many entries it holds. It is drawn, so it needs no art.
## Nothing in the village is clean (art/STYLE.md): at stage 0 the card is yellowed and
## foxed and the chop patchy and a little doubled where it slipped, and each stage
## darkens the card, thins and breaks the ink, turns the red toward old blood and spreads
## a tea ring. It takes no input, so it never blocks a button, and it keeps to the
## corner, clear of the title.

const SIDE: float = 220.0
## From the screen's top and right edges.
const MARGIN: float = 48.0
const TILT: float = -0.12
## The card's and the chop's squares inside the box, so their tilted corners stay in it.
const CARD: float = 0.84
const CHOP: float = 0.72
const MANILA: Color = Color("d8bf86")
const BORDER: float = 0.05
const SEED: int = 8317
const FOXING: Vector2i = Vector2i(10, 60)
const THIN: Vector2i = Vector2i(20, 110)
const BREAKS: Vector2i = Vector2i(1, 6)
const NAME_SIZE: int = 16
const COUNT_SIZE: int = 22

var _entries: int = 0
var _font: Font = ScreenKit.DISPLAY_BOLD


func _init(entries: int = 0) -> void:
	_entries = entries
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -MARGIN - SIDE
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = MARGIN + SIDE


## The chop's two lines: the file's name and its count of entries.
func words() -> PackedStringArray:
	var count: String = Strings.count("file.stamp.entries", _entries)
	return [tr("file.stamp.name").to_upper(), count.to_upper()]


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	draw_set_transform(size / 2.0, TILT)
	_card(SIDE * CARD / 2.0, worn, rng)
	var ink: Color = BowlGrime.faded(ScreenKit.PRINT_RED, worn).lerp(
		BowlGrime.DRIED, 0.5 * (worn - 0.3)
	)
	ink.a = 0.92 - 0.25 * worn
	var half: float = SIDE * CHOP / 2.0
	# The chop slipped as it was pressed: a faint second impression beside the first.
	_chop(half, Color(ink, ink.a * 0.2), Vector2(2.0 + 3.0 * worn, 1.5))
	_chop(half, ink, Vector2.ZERO)
	_thin_ink(half, worn, rng)
	draw_set_transform(Vector2.ZERO, 0.0)


## The file card: corners out of true, a dark edge, foxing and, deeper in, a tea ring.
func _card(half: float, worn: float, rng: RandomNumberGenerator) -> void:
	var paper: Color = BowlGrime.aged(MANILA, worn * 0.7)
	var jitter: float = 1.0 + 3.0 * worn
	var corners: PackedVector2Array = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var nudge: Vector2 = Vector2(
			rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)
		)
		corners.append(corner * half + nudge)
	draw_colored_polygon(corners, paper)
	draw_polyline(corners + PackedVector2Array([corners[0]]), Color(ScreenKit.PAPER_EDGE, 0.7), 1.5)
	var fox: Color = Color(BowlGrime.TEA, 0.25 + 0.35 * worn)
	for _spot: int in roundi(lerpf(FOXING.x, FOXING.y, worn)):
		var at: Vector2 = Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half)) * 0.95
		draw_circle(at, rng.randf_range(0.6, 1.8), fox)
	var ring: Vector2 = Vector2(half * 0.55, half * 0.6)
	var tea: Color = Color(BowlGrime.TEA, 0.08 + 0.3 * worn)
	draw_arc(ring, half * (0.25 + 0.2 * worn), 0.3, TAU * 0.85, 32, tea, 1.5 + 2.0 * worn, true)


## The square chop: a heavy border, a rule and the two lines, offset to the side.
func _chop(half: float, ink: Color, offset: Vector2) -> void:
	var width: float = SIDE * BORDER
	var box: Rect2 = Rect2(Vector2(-half, -half) + offset, Vector2(half, half) * 2.0)
	draw_rect(box, ink, false, width)
	draw_rect(box.grow(-width * 1.6), ink, false, width * 0.35)
	draw_line(Vector2(-half * 0.75, 0) + offset, Vector2(half * 0.75, 0) + offset, ink, 2.0)
	var lines: PackedStringArray = words()
	_centered(lines[0], Vector2(0, -half * 0.32) + offset, NAME_SIZE, ink, half * 1.5)
	_centered(lines[1], Vector2(0, half * 0.42) + offset, COUNT_SIZE, ink, half * 1.5)


## Where the chop took no ink the card shows through: specks in the ink and breaks in
## the border, more at every stage.
func _thin_ink(half: float, worn: float, rng: RandomNumberGenerator) -> void:
	var paper: Color = Color(BowlGrime.aged(MANILA, worn * 0.7), 0.85)
	for _speck: int in roundi(lerpf(THIN.x, THIN.y, worn)):
		var at: Vector2 = Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		draw_circle(at, rng.randf_range(0.5, 1.2 + worn), paper)
	var width: float = SIDE * BORDER
	for _break: int in roundi(lerpf(BREAKS.x, BREAKS.y, worn)):
		var at: Vector2 = _on_edge(rng.randi_range(0, 3), rng.randf_range(-half, half), half)
		draw_circle(at, width * rng.randf_range(0.6, 1.0), paper)


static func _on_edge(side: int, along: float, half: float) -> Vector2:
	match side:
		0:
			return Vector2(along, -half)
		1:
			return Vector2(half, along)
		2:
			return Vector2(along, half)
	return Vector2(-half, along)


## A line of text centred on at, shrunk to fit most.
func _centered(text: String, at: Vector2, font_size: int, ink: Color, most: float) -> void:
	var shown: int = font_size
	var wide: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, shown).x
	if wide > most:
		shown = int(shown * most / wide)
		wide = most
	var baseline: Vector2 = at + Vector2(-wide / 2.0, shown * 0.36)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, shown, ink)
