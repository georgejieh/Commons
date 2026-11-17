class_name SurnameTicket
extends Button
## One offered surname on the first-launch page (ADR 0028): a small worn ration ticket
## with the name inked on it, from the same paper as the stake tickets (PaperTicket, aged
## by the stage). Focus and hover lift it and ring it in faded gold; the one in the field
## is stamped round in red.

const SIZE: Vector2 = Vector2(120, 56)
const INK: Color = Color("120d09")
const PICKED: Color = Color("9e2a1d")
const RING: Color = Color("b98a2c")
const BAND: Color = Color("7a6446")
const LIFT: float = 4.0
const NAME_SIZE: int = 24
## Seeds after the stake tickets', so no surname ticket wears like a stake's.
const SEED_BASE: int = 80

## The surname it offers.
var surname: String = ""
var index: int = 0
## True while it is the surname in the field.
var picked: bool = false:
	set(value):
		picked = value
		queue_redraw()
var _words: Label


func _init(offered: String, place: int) -> void:
	surname = offered
	index = place
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	accessibility_name = offered
	for style: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_words = ScreenKit.label(offered, NAME_SIZE, BowlGrime.faded(INK, BowlGrime.wear()))
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.set_anchors_preset(Control.PRESET_FULL_RECT)
	_words.offset_left = 12.0
	add_child(_words)
	for signal_name: String in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
		connect(signal_name, _lift)


func _lift() -> void:
	_words.position.y = -LIFT if has_focus() or is_hovered() else 0.0
	queue_redraw()


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var lifted: bool = has_focus() or is_hovered()
	var rect: Rect2 = Rect2(Vector2(0, -LIFT if lifted else 0.0), size)
	PaperTicket.draw(self, rect, worn, SEED_BASE + index, BAND)
	if picked:
		draw_rect(rect.grow(-4.0), BowlGrime.faded(PICKED, worn), false, 3.0)
	if lifted:
		draw_rect(rect.grow(2.5), Color(BowlGrime.aged(RING, worn * 0.5), 0.9), false, 3.0)
