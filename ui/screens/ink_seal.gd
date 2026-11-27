class_name InkSeal
extends Control
## A round office seal in stamp ink: two rings and a word across the middle, pressed on
## at a slant. It marks what is settled: a purchase approved, a Quota met. press() lands
## it like a stamp; the ink is a little thin, so what is under it shows through.

const INK_ALPHA: float = 0.86
const TILT: float = -0.2
const RING: float = 0.07
const INNER: float = 0.8
const BAND: float = 0.36
const WORD_FIT: float = 0.82

var _word: String = ""
var _ink: Color = Color("b02a17")
var _font: Font = ScreenKit.DISPLAY_BOLD


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Sets the seal's word, ink and width. Its height equals its width.
func prepare(word: String, ink: Color, width: float) -> void:
	_word = word.to_upper()
	_ink = ink
	custom_minimum_size = Vector2.ONE * width
	size = Vector2.ONE * width
	pivot_offset = size / 2.0
	queue_redraw()


## Shows the seal and lands it like a stamp.
func press() -> void:
	visible = true
	rotation = 0.0
	UiMotion.stamp(self)


func word() -> String:
	return _word


func _draw() -> void:
	var radius: float = size.x / 2.0
	var ink: Color = Color(_ink, INK_ALPHA)
	draw_set_transform(size / 2.0, TILT)
	var width: float = radius * RING
	draw_arc(Vector2.ZERO, radius - width, 0.0, TAU, 64, ink, width, true)
	draw_arc(Vector2.ZERO, radius * INNER, 0.0, TAU, 64, ink, width * 0.4, true)
	var tall: float = radius * BAND
	var band: Rect2 = Rect2(-radius, -tall, radius * 2.0, tall * 2.0)
	draw_rect(band, Color(ScreenKit.STYLE.paper_bright, 0.9))
	draw_rect(band, ink, false, width * 0.6)
	var font_size: int = int(tall * 1.35)
	var text_width: float = _font.get_string_size(_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var most: float = radius * 2.0 * WORD_FIT
	if text_width > most:
		font_size = int(font_size * most / text_width)
		text_width = most
	var baseline: Vector2 = Vector2(-text_width / 2.0, font_size * 0.36)
	draw_string(_font, baseline, _word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	draw_set_transform(Vector2.ZERO, 0.0)
