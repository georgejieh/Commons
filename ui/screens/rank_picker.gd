class_name RankPicker
extends PanelContainer
## The strip that asks for a rank before a Cadre that needs one is bought (ADR 0021):
## a one-line prompt, thirteen worn rank tickets from 3 up to 2, and Cancel, beside the
## card it asks about, over a scrim that dims the page and takes its clicks. The card
## stays above the dim, whole and readable. Choosing a ticket hands the rank to the
## purchase waiting on it. Keyboard and gamepad move along the tickets, and back or
## Cancel closes it with nothing bought.

## The ranks offered: 3 up to 2. Jokers are never a pick.
const FIRST: int = Ranks.THREE
const LAST: int = Ranks.TWO
## One padding on every side inside the paper's printed border, which ends 17 px in, and
## the room between prompt, tickets and Cancel.
const PADDING: int = 32
const SPACING: int = 16
## Between the card asked about and the strip, and the strip and the screen's edge.
const GAP: float = 14.0
const MARGIN: float = 16.0

var _prompt: Label = ScreenKit.label("", 24)
var _chips: Array[RankChip] = []
var _cancel: Button = ScreenKit.button("", CommonsTheme.GHOST)
var _then: Callable = Callable()
## Made the first time the strip opens, and kept on the page from then on.
var _scrim: Scrim = null
## What had focus before the strip opened, to give it back.
var _was_focused: Control = null
## The card asked about, lifted over the scrim while the strip is open, and its own depth.
var _card: Control = null
var _card_z: int = 0


func _ready() -> void:
	visible = false
	z_index = ScreenKit.LAYER_OVER
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	# One line: a wrapping prompt is measured at no width, which makes the strip tall.
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", SPACING)
	column.add_child(_prompt)
	var strip: HBoxContainer = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	for rank: int in range(FIRST, LAST + 1):
		var chip: RankChip = RankChip.new(rank, tr(Ranks.label_key(rank)))
		chip.pressed.connect(_choose.bind(rank))
		strip.add_child(chip)
		_chips.append(chip)
	# A focused ticket rises by its lift, so the strip keeps that much room above it.
	var room: MarginContainer = MarginContainer.new()
	room.add_theme_constant_override("margin_top", ceili(RankChip.LIFT))
	room.add_child(strip)
	column.add_child(room)
	_cancel.text = tr("store.pick_cancel")
	_cancel.pressed.connect(close)
	_cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_cancel)
	add_child(column)
	_trap_focus()


## Opens beside the card it asks about, asking for the rank then waits on.
func ask(prompt: String, about: Control, then: Callable) -> void:
	_prompt.text = prompt
	_then = then
	_was_focused = get_viewport().gui_get_focus_owner()
	visible = true
	_cover()
	_lift(about)
	reset_size()
	global_position = spot(size, about.get_global_rect(), get_viewport_rect().grow(-MARGIN))
	_chips[0].grab_focus()
	var pieces: Array[Control] = [self]
	UiMotion.enter(pieces)


func is_open() -> bool:
	return visible


## The dim behind the strip, for tests.
func scrim() -> Scrim:
	return _scrim


## The rank tickets in order, for tests and the playtest.
func chips() -> Array[RankChip]:
	return _chips.duplicate()


## Closes with nothing chosen.
func close() -> void:
	visible = false
	_lift(null)
	if _scrim != null:
		_scrim.visible = false
	_then = Callable()
	if (
		_was_focused != null
		and is_instance_valid(_was_focused)
		and _was_focused.is_visible_in_tree()
	):
		_was_focused.grab_focus()


func _choose(rank: int) -> void:
	var then: Callable = _then
	close()
	if then.is_valid():
		then.call(rank)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## The scrim stands just under the strip, beside it in the page, over everything else.
## A sibling, not a child: a child covering the screen would take the strip's own clicks.
func _cover() -> void:
	if _scrim == null:
		_scrim = Scrim.new()
		get_parent().add_child(_scrim)
	get_parent().move_child(_scrim, get_index())
	_scrim.z_index = z_index
	_scrim.visible = true


## Where a strip of size stands on screen beside card: below it, above it, then right
## and left of it, centred on it along the other side; centred on the screen when none
## keeps clear of it.
static func spot(strip: Vector2, card: Rect2, screen: Rect2) -> Vector2:
	var middle: Vector2 = card.get_center() - strip / 2.0
	var tries: Array[Vector2] = [
		Vector2(middle.x, card.end.y + GAP),
		Vector2(middle.x, card.position.y - GAP - strip.y),
		Vector2(card.end.x + GAP, middle.y),
		Vector2(card.position.x - GAP - strip.x, middle.y),
	]
	var room: Rect2 = Rect2(screen.position, (screen.size - strip).max(Vector2.ZERO))
	for at: Vector2 in tries:
		var placed: Vector2 = at.clamp(room.position, room.end)
		if not Rect2(placed, strip).intersects(card) and screen.encloses(Rect2(placed, strip)):
			return placed
	return (screen.get_center() - strip / 2.0).clamp(room.position, room.end)


## Lifts card over the scrim, and sets the last one lifted back down.
func _lift(card: Control) -> void:
	if _card != null and is_instance_valid(_card):
		_card.z_index = _card_z
	_card = card
	if card != null:
		_card_z = card.z_index
		card.z_index = z_index + 1


## Up and down stay on the strip: the tickets lead down to Cancel and Cancel back up.
func _trap_focus() -> void:
	for chip: RankChip in _chips:
		chip.focus_neighbor_top = chip.get_path_to(chip)
		chip.focus_neighbor_bottom = chip.get_path_to(_cancel)
	_chips[0].focus_neighbor_left = _chips[0].get_path_to(_chips[0])
	_chips[-1].focus_neighbor_right = _chips[-1].get_path_to(_chips[-1])
	_cancel.focus_neighbor_top = _cancel.get_path_to(_chips[0])
	_cancel.focus_neighbor_bottom = _cancel.get_path_to(_cancel)
	_cancel.focus_neighbor_left = _cancel.get_path_to(_chips[-1])
	_cancel.focus_neighbor_right = _cancel.get_path_to(_cancel)
