class_name HanziSeal
extends Control
## A square red seal carrying Chinese characters as decoration only (ADR 0024, Plan:
## English only), top to bottom, pressed a little off true and worn with the stage. It
## is drawn only from a face that holds every character, so it never shows the boxes of
## missing glyphs: without such a face, can_draw() is false and the screen leaves it out.

## How opaque the red ink is at corruption stage 0; each stage thins it.
const INK_ALPHA: float = 0.88
## The slant the seal is pressed at, in radians.
const TILT: float = 0.05
## The width of the seal's border, as a share of its side.
const BORDER: float = 0.06
## Each character's size as a share of the seal's side, per character.
const CHARACTER: float = 0.84

var _text: String = ""
var _font: Font = null


## A seal width wide, tall enough for the characters one above another.
func _init(text: String = "", width: float = 0.0) -> void:
	_text = text
	_font = _face_for(text)
	custom_minimum_size = Vector2(width, width * maxi(text.length(), 1) * 0.86)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The face that holds every character of text: the art library's Chinese face, or the
## display face. Null when neither does.
static func _face_for(text: String) -> Font:
	for face: Font in [ScreenKit.ART.hanzi_font, ScreenKit.DISPLAY_BOLD]:
		if face != null and _holds(face, text):
			return face
	return null


## True when text is not empty and a face holds every character of it, so the seal can be drawn.
static func can_draw(text: String) -> bool:
	return not text.is_empty() and _face_for(text) != null


static func _holds(face: Font, text: String) -> bool:
	for index: int in text.length():
		if not face.has_char(text.unicode_at(index)):
			return false
	return true


func _draw() -> void:
	if _font == null or _text.is_empty():
		return
	var worn: float = BowlGrime.wear()
	var ink: Color = Color(BowlGrime.faded(ScreenKit.RED, worn), INK_ALPHA - 0.2 * worn)
	draw_set_transform(size / 2.0, TILT)
	var half: Vector2 = size / 2.0
	var line: float = size.x * BORDER
	draw_rect(Rect2(-half, size), ink, false, line)
	var count: int = _text.length()
	var step: float = (size.y - line * 3.0) / count
	var font_size: int = int(minf(step, size.x - line * 3.0) * CHARACTER)
	for index: int in count:
		var glyph: String = _text[index]
		var wide: float = _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var top: float = -half.y + line * 1.5 + step * index
		var baseline: Vector2 = Vector2(-wide / 2.0, top + step * 0.8)
		draw_string(_font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	draw_set_transform(Vector2.ZERO, 0.0)
