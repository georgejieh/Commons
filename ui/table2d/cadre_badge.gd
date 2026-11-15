class_name CadreBadge
extends Control
## What a Cadre card on the notice board says over its art (ADR 0021): a short count on
## a worn paper ticket pinned to its foot, such as the coupons Ration Coupon has earned
## this Quota, and, on a Cadre with no art yet, its name inked on the stock. Drawn, not
## labelled, so the card stays one picture.

const TICKET: Vector2 = Vector2(72, 32)
const COUNT_SIZE: int = 21
## A name is set at NAME_SIZE, smaller only as far as its longest word needs to fit the
## card's width, and never below LEAST_NAME. Nothing is abbreviated or clipped.
const NAME_SIZE: int = 16
const LEAST_NAME: int = 13
const NAME_MARGIN: float = 5.0
const INK: Color = Color("1e1a16")
const BAND: Color = Color("3f6338")

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


## The size a name is set at to fit wide: each word on one line.
static func name_size(font: Font, text: String, wide: float) -> int:
	return NameFit.size_for(font, text, wide, NAME_SIZE, LEAST_NAME)


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
	PaperTicket.draw(self, Rect2(at, TICKET), worn, _count.hash() & 0xFF, BAND)
	var baseline: Vector2 = at + Vector2(6, TICKET.y * 0.72)
	draw_string(font, baseline, _count, HORIZONTAL_ALIGNMENT_CENTER, TICKET.x - 6, COUNT_SIZE, ink)
