class_name RankChip
extends Button
## One rank in the rank picker: a worn ration ticket with the rank inked on it, not a
## clean button (art/STYLE.md, "Nothing is clean"). Hover and focus lift it and ring it
## in faded gold, so keyboard and gamepad see where they are.

const SIZE: Vector2 = Vector2(62, 86)
const INK: Color = Color("2b2119")
const RED_INK: Color = Color("8c2a1c")
const RING: Color = Color("b98a2c")
const BAND: Color = Color("9e2a1d")
const FONT_SIZE: int = 34

var rank: int = Ranks.INVALID
var _label: String = ""


func _init(chip_rank: int, label: String) -> void:
	rank = chip_rank
	_label = label
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	tooltip_text = label
	for style: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


## The rank as the chip prints it, for tests.
func label() -> String:
	return _label


func _draw() -> void:
	var lifted: bool = has_focus() or is_hovered()
	var rect: Rect2 = Rect2(Vector2(0, -4.0 if lifted else 0.0), size)
	PaperTicket.draw(self, rect, BowlGrime.wear(), rank, BAND)
	var font: Font = get_theme_default_font()
	var ink: Color = RED_INK if rank == Ranks.TWO else INK
	var faded: Color = BowlGrime.aged(ink, BowlGrime.wear() * 0.4)
	var width: float = rect.size.x
	var baseline: Vector2 = rect.position + Vector2(0, rect.size.y * 0.58)
	draw_string(font, baseline, _label, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE, faded)
	if lifted:
		var ring: Rect2 = rect.grow(2.0)
		draw_rect(ring, Color(BowlGrime.aged(RING, BowlGrime.wear() * 0.5), 0.9), false, 2.5)
