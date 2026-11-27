class_name ScarceStamp
extends Control
## The office's mark on a Cadre that seldom reaches a counter (ModifierDef.Rarity.RARE): the word
## in a ruled box of stamp ink, pressed at a slant on the top right corner of the card's
## picture. A routine card has none, so a scarce one cannot be taken for one. At rest it
## is simply there, and it says the same thing in grayscale and with motion off; when a
## counter's cards arrive, press() lands it a beat after they are in. Like every stamp in
## the village it is patchy and a little doubled where it slipped, and each stage thins
## and breaks the ink further (art/STYLE.md).

## The size, in pixels, of the ruled box, before its slant.
const BOX: Vector2 = Vector2(150, 48)
## Room round the box for its slant, so its corners stay inside the control.
const ROOM: Vector2 = Vector2(8, 14)
## The slant the box is pressed at, in radians.
const TILT: float = 0.1
## How far, in pixels, the stamp overhangs the picture's right edge.
const OVERHANG: float = 10.0
## Where the stamp stands from the picture's top, in pixels; below zero is above the top.
const DROP: float = -4.0
## The width, in pixels, of the box's outer rule.
const BORDER: float = 3.0
## The word is art, like a seal's: it keeps its size at every text size.
const WORD_SIZE: int = 27
## The share of the box's width the word may fill; a longer word is shrunk to it.
const WORD_FIT: float = 0.84
## The ground under the ink, so the word reads over a picture.
const GROUND: float = 0.84
## The seed of the stamp's patchy ink, so it breaks the same way every time.
const SEED: int = 6143
## How many specks of ground show through the ink, from unworn (x) to worn through (y).
const THIN: Vector2i = Vector2i(14, 70)
## How many breaks the border gets, from unworn (x) to worn through (y).
const BREAKS: Vector2i = Vector2i(1, 5)

var _word: String = ""
var _ink: Color = ScreenKit.RED
var _font: Font = ScreenKit.DISPLAY_BOLD
var _pressing: Tween = null


func _init(text: String = "", ink: Color = ScreenKit.RED) -> void:
	_word = text.to_upper()
	_ink = ink
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BOX + ROOM * 2.0
	size = custom_minimum_size


## Puts the stamp on a picture of the given width, over its top right corner.
func place_on(wide: float) -> void:
	position = Vector2(wide - size.x + ROOM.x + OVERHANG, DROP)


## The word the stamp prints, in capitals; for tests.
func word() -> String:
	return _word


## Presses every stamp under root, after seconds: the cards are in first.
static func press_under(root: Node, after: float) -> void:
	for found: Node in root.find_children("*", "Control", true, false):
		var stamp: ScarceStamp = found as ScarceStamp
		if stamp != null:
			stamp.press(after)


## Lands the stamp after seconds. Nothing under reduced motion: it is already there.
func press(after: float) -> void:
	if UiMotion.reduced() or not is_inside_tree():
		return
	if _pressing != null and _pressing.is_valid():
		_pressing.kill()
	modulate.a = 0.0
	_pressing = create_tween()
	_pressing.tween_interval(after)
	_pressing.tween_callback(land)


## Lands the stamp now. The tween is returned so that a tool can hold its clock; null
## under reduced motion, where it is already down.
func land() -> Tween:
	return UiMotion.stamp(self)


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var ink: Color = BowlGrime.faded(_ink, worn)
	ink.a = 0.94 - 0.2 * worn
	var paper: Color = BowlGrime.aged(ScreenKit.STYLE.paper_bright, worn * 0.5)
	var box: Rect2 = Rect2(-BOX / 2.0, BOX)
	draw_set_transform(size / 2.0, TILT)
	draw_rect(box, Color(paper, GROUND))
	# The stamp slipped as it was pressed: a faint second impression beside the first.
	_impression(box, Color(ink, ink.a * 0.2), Vector2(2.0 + 2.0 * worn, 1.5))
	_impression(box, ink, Vector2.ZERO)
	_thin_ink(box, paper, worn, rng)
	draw_set_transform(Vector2.ZERO, 0.0)


## The box, a rule inside it and the word, offset to the side.
func _impression(box: Rect2, ink: Color, offset: Vector2) -> void:
	var moved: Rect2 = Rect2(box.position + offset, box.size)
	draw_rect(moved.grow(-BORDER / 2.0), ink, false, BORDER)
	draw_rect(moved.grow(-BORDER * 2.2), ink, false, 1.0)
	var font_size: int = WORD_SIZE
	var wide: float = _font.get_string_size(_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var most: float = BOX.x * WORD_FIT
	if wide > most:
		font_size = int(font_size * most / wide)
		wide = most
	var baseline: Vector2 = offset + Vector2(-wide / 2.0, font_size * 0.36)
	draw_string(_font, baseline, _word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Where the stamp took no ink the ground shows through: specks in the ink and breaks in
## the border, more at every stage, and never enough to cost the word.
func _thin_ink(box: Rect2, paper: Color, worn: float, rng: RandomNumberGenerator) -> void:
	for _speck: int in roundi(lerpf(THIN.x, THIN.y, worn)):
		var at: Vector2 = Vector2(
			rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y)
		)
		draw_circle(at, rng.randf_range(0.4, 0.9 + 0.5 * worn), paper)
	for _break: int in roundi(lerpf(BREAKS.x, BREAKS.y, worn)):
		var along: float = rng.randf_range(box.position.x, box.end.x)
		var edge: float = box.position.y if rng.randf() < 0.5 else box.end.y
		draw_circle(Vector2(along, edge), BORDER * rng.randf_range(0.7, 1.1), paper)
