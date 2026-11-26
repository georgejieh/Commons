class_name DetailSlip
extends PanelContainer
## One shared slip that explains whatever a shop's compact pieces point at (ADR 0021):
## the item's name over its rules with each keyword's meaning, as the Keywords.slip
## tooltip has it, on aged paper. It shows while a piece is hovered or holds focus, and
## stands right beside that piece, above or below it first, as SlipPlacer places every
## slip: never over the piece or its button, kept on screen. While quiet says so,
## as it does through the arrival, whose slip is the only explanation on screen, it
## stays closed.

const GAP: float = 10.0
const MARGIN: float = 16.0
const PADDING: int = 20
## Marks a piece whose leaving the tree already hides the slip.
const WATCHED: StringName = &"detail_slip_watched"

## Returns true while the slip must stay closed; unset, it never must.
var quiet: Callable = Callable()
## The part of the screen whose buttons the slip keeps off: a sheet over the page, whose
## own buttons are the only ones that show; unset, the whole screen.
var within: Node = null
var _anchor: Control = null
var _above: bool = true
var _rule: String = ""


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = ScreenKit.LAYER_SLIP
	visible = false
	resized.connect(_place)


## Explains anchor: title over rule, above it or below it.
func show_for(anchor: Control, title: String, rule: String, above: bool = true) -> void:
	if quiet.is_valid() and bool(quiet.call()):
		hide_slip()
		return
	_anchor = anchor
	_above = above
	_rule = rule
	ScreenKit.clear(self)
	var content: Control = Keywords.slip(rule, title)
	add_child(content)
	# It only explains: a click goes through it to whatever lies under.
	for node: Node in [content] + content.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not anchor.has_meta(WATCHED):
		anchor.set_meta(WATCHED, true)
		anchor.tree_exiting.connect(hide_for.bind(anchor))
	visible = true
	reset_size()
	_place()


## Explains control, title over rule, while it is hovered or holds the focus.
func follow(control: Control, title: String, rule: String) -> void:
	control.mouse_entered.connect(show_for.bind(control, title, rule))
	control.focus_entered.connect(show_for.bind(control, title, rule))
	control.mouse_exited.connect(hide_for.bind(control))
	control.focus_exited.connect(hide_for.bind(control))


## Hides the slip if it is explaining anchor.
func hide_for(anchor: Control) -> void:
	if _anchor == anchor:
		hide_slip()


func hide_slip() -> void:
	_anchor = null
	_rule = ""
	visible = false


## What the slip explains now, for tests: its piece and its rule.
func anchor() -> Control:
	return _anchor


func shown_rule() -> String:
	return _rule if visible else ""


func _place() -> void:
	if _anchor == null or not is_instance_valid(_anchor) or not _anchor.is_inside_tree():
		return
	var screen: Rect2 = get_viewport_rect().grow(-MARGIN)
	var around: Rect2 = SlipPlacer.on_screen(_anchor)
	var side: int = SlipPlacer.ABOVE if _above else SlipPlacer.BELOW
	var root: Node = within if within != null else get_tree().root
	global_position = SlipPlacer.place(size, around, GAP, screen, root, self, side)
