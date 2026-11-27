class_name StakeTicket
extends Button
## One stake at run setup (ADR 0025): a worn ration ticket with the stake's name inked on
## it (art/STYLE.md, "Nothing is clean"). The picked one is stamped round in red; focus
## and hover lift a ticket and ring it in faded gold. A locked stake is a blank ticket
## saying how it opens. Its paper and ink are the rank picker's
## tickets' (PaperTicket's warm paper, ink faded by the stage), and it is wide enough that
## its words sit at 16 px or more on one or two lines, never broken inside a word.

## The ticket's size in pixels.
const SIZE: Vector2 = Vector2(212, 92)
## How far, in pixels, the ticket and its words rise while it is hovered or focused.
const LIFT: float = 6.0
## The font size of an open stake's name, at Standard.
const NAME_SIZE: int = 22
## The font size of a locked stake's words, at Standard.
const LINE_SIZE: int = 18
## The band at the ticket's left, in pixels, which the words keep clear of.
const WORDS_LEFT: float = 14.0
## The margin at the ticket's right, in pixels, which the words keep clear of.
const WORDS_RIGHT: float = 8.0

## The stake this ticket stands for.
var stake: int = 0
## False for a stake not yet unlocked: it shows no name and picks nothing.
var open: bool = false
## True while it is the stake picked.
var picked: bool = false:
	set(value):
		picked = value
		queue_redraw()
## The stake's words on the ticket.
var words_label: Label


func _init(stake_number: int, unlocked: bool, label_text: String) -> void:
	stake = stake_number
	open = unlocked
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	accessibility_name = label_text
	for style: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var ink: Color = BowlGrime.faded(ScreenKit.TICKET_INK, BowlGrime.wear())
	words_label = ScreenKit.label("", NAME_SIZE if unlocked else LINE_SIZE, ink)
	var wide: float = SIZE.x - WORDS_LEFT - WORDS_RIGHT
	var base: int = TextSize.px(NAME_SIZE if unlocked else LINE_SIZE)
	NameFit.apply(words_label, label_text, wide, base, TextSize.least(NameFit.LEAST))
	words_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	words_label.offset_left = WORDS_LEFT
	words_label.offset_right = -WORDS_RIGHT
	words_label.offset_top = 4.0
	words_label.offset_bottom = -16.0
	add_child(words_label)
	for signal_name: String in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
		connect(signal_name, _lift)


## What the ticket prints, for tests.
func words() -> String:
	return words_label.text


func _lift() -> void:
	var lifted: bool = has_focus() or is_hovered()
	words_label.position.y = (4.0 - LIFT) if lifted else 4.0
	queue_redraw()


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var lifted: bool = has_focus() or is_hovered()
	var rect: Rect2 = Rect2(Vector2(0, -LIFT if lifted else 0.0), size)
	PaperTicket.draw(
		self, rect, worn, 40 + stake, ScreenKit.PICKED if open else ScreenKit.WORN_PRINT
	)
	if picked:
		draw_rect(rect.grow(-4.0), BowlGrime.faded(ScreenKit.PICKED, worn), false, 3.5)
	if lifted:
		draw_rect(
			rect.grow(2.5), Color(BowlGrime.aged(ScreenKit.FOCUS_RING, worn * 0.5), 0.9), false, 3.0
		)
