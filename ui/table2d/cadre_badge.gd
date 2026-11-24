class_name CadreBadge
extends Control
## What a Cadre card on the notice board says over its art (ADR 0021): a short count on
## a worn paper ticket pinned to its foot, such as the coupons Ration Coupon has earned
## this Quota out of the most it pays, with the ticket's band filled to match, and, on a
## Cadre with no art yet, its name inked on the stock. Drawn, not
## labelled, so the card stays one picture.

const TICKET: Vector2 = Vector2(72, 32)
const COUNT_SIZE: int = 21
## A name is set at NAME_SIZE, smaller only as far as its longest word needs to fit the
## card's width, and never below LEAST_NAME. Nothing is abbreviated or clipped.
const NAME_SIZE: int = 16
const LEAST_NAME: int = 14
## Room kept between the count and the ticket's edges, in pixels.
const COUNT_PAD: Vector2 = Vector2(12, 2)
const NAME_MARGIN: float = 5.0
const INK: Color = Color("1e1a16")
const BAND: Color = Color("3f6338")
## The band's fill for a count that is not a meter: no band.
const NO_METER: float = -1.0

var _count: String = ""
var _name: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The count on the ticket, or none when empty.
func show_count(count: String) -> void:
	_count = count
	queue_redraw()


## The name printed on a card with no art, or none when empty.
func show_name(cadre_name: String) -> void:
	_name = cadre_name
	queue_redraw()


func count() -> String:
	return _count


## How full the ticket's band stands for a count (P5.2a): a count of so many out of so
## many, such as Ration Coupon's "2/3", fills it that share, step by step, and it empties
## when the count starts again. Any other count, a number, a factor or a rank, has no band,
## so nothing on the ticket looks like a meter that is stuck. Negative for no band.
static func meter(count: String) -> float:
	var parts: PackedStringArray = count.split("/")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return NO_METER
	var whole: int = parts[1].to_int()
	if whole <= 0:
		return NO_METER
	return clampf(float(parts[0].to_int()) / whole, 0.0, 1.0)


## How full the band stands now, for tests.
func fill() -> float:
	return meter(_count)


## The size a name is set at to fit wide: each word on one line.
static func name_size(font: Font, text: String, wide: float) -> int:
	return NameFit.size_for(font, text, wide, TextSize.px(NAME_SIZE), TextSize.least(LEAST_NAME))


## The count's size: grown with the text size as far as the ticket holds it.
static func count_size(font: Font, text: String) -> int:
	var fits: Callable = func(font_size: int) -> bool:
		var wide: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return (
			wide <= TICKET.x - COUNT_PAD.x and font.get_height(font_size) <= TICKET.y + COUNT_PAD.y
		)
	return TextSize.fit(COUNT_SIZE, COUNT_SIZE, fits)


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var ink: Color = BowlGrime.faded(INK, worn)
	var font: Font = get_theme_default_font()
	if not _name.is_empty():
		var wide: float = size.x - NAME_MARGIN * 2.0
		var font_size: int = name_size(font, _name, wide)
		var top: Vector2 = Vector2(NAME_MARGIN, size.y * 0.3)
		draw_multiline_string(
			font, top, _name, HORIZONTAL_ALIGNMENT_CENTER, wide, font_size, 4, ink
		)
	if _count.is_empty():
		return
	var at: Vector2 = Vector2((size.x - TICKET.x) / 2.0, size.y - TICKET.y - 4.0)
	var fill: float = meter(_count)
	PaperTicket.draw(self, Rect2(at, TICKET), worn, _count.hash() & 0xFF, BAND, 1.0, fill)
	var baseline: Vector2 = at + Vector2(6, TICKET.y * 0.72)
	var count_px: int = count_size(font, _count)
	draw_string(font, baseline, _count, HORIZONTAL_ALIGNMENT_CENTER, TICKET.x - 6, count_px, ink)
