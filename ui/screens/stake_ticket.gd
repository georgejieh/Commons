class_name StakeTicket
extends Button
## One stake at run setup (ADR 0025): a worn ration ticket with the stake's name inked on
## it (art/STYLE.md, "Nothing is clean"). The picked one is stamped round in red; focus
## and hover lift a ticket and ring it in faded gold. A locked stake is a blank ticket,
## and the first locked one says how it opens.

const SIZE: Vector2 = Vector2(172, 92)
const INK: Color = Color("120d09")
const PICKED: Color = Color("9e2a1d")
const RING: Color = Color("b98a2c")
const BAND: Color = Color("5a6b3c")
const LOCKED_BAND: Color = Color("7a6446")
const LIFT: float = 6.0
const NAME_SIZE: int = 22
const LINE_SIZE: int = 16

## The stake this ticket stands for.
var stake: int = 0
## False for a stake not yet unlocked: it shows no name and picks nothing.
var open: bool = false
## True while it is the stake picked.
var picked: bool = false:
	set(value):
		picked = value
		queue_redraw()
var _words: Label


func _init(stake_number: int, unlocked: bool, words: String) -> void:
	stake = stake_number
	open = unlocked
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	accessibility_name = words
	for style: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var ink: Color = BowlGrime.faded(INK, BowlGrime.wear())
	_words = ScreenKit.label(words, NAME_SIZE if unlocked else LINE_SIZE, ink)
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.set_anchors_preset(Control.PRESET_FULL_RECT)
	_words.offset_left = 14.0
	_words.offset_right = -8.0
	_words.offset_top = 4.0
	_words.offset_bottom = -16.0
	add_child(_words)
	for signal_name: String in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
		connect(signal_name, _lift)


## What the ticket prints, for tests.
func words() -> String:
	return _words.text


func _lift() -> void:
	var lifted: bool = has_focus() or is_hovered()
	_words.position.y = (4.0 - LIFT) if lifted else 4.0
	queue_redraw()


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var lifted: bool = has_focus() or is_hovered()
	var rect: Rect2 = Rect2(Vector2(0, -LIFT if lifted else 0.0), size)
	PaperTicket.draw(self, rect, worn, 40 + stake, BAND if open else LOCKED_BAND)
	if picked:
		draw_rect(rect.grow(-4.0), BowlGrime.faded(PICKED, worn), false, 3.5)
	if lifted:
		draw_rect(rect.grow(2.5), Color(BowlGrime.aged(RING, worn * 0.5), 0.9), false, 3.0)
