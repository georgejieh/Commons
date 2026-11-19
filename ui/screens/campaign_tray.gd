class_name CampaignTray
extends Control
## The player's held Campaigns as leaflets in a small tray (ADR 0021), at the table and in
## both shops. Clicking a usable leaflet arms it: one that asks for cards then takes the
## hand's selection, and Use spends it; one that asks for none waits for Use to confirm.
## Cancel, or arming nothing, leaves no state behind. Keyboard and gamepad step a cursor
## through the leaflets with commons_campaign, arm with commons_play and cancel with
## commons_pass or ui_cancel. Every use goes through the run controller. The tray has a
## place for every Campaign the player can hold, and grows when a Reform raises that.

## Armed, cursor or prompt changed, so the screen can update its prompt line.
signal changed
## A Campaign was used: the run accepted it and its events are on their way.
signal used(slot: int, campaign_id: String)

const GAP: float = 14.0
## Room for the head over a compact row, and over full-size leaflets, whose armed one
## lifts by CampaignLeaflet.LIFT and must stay clear of the head.
const HEAD: float = 26.0
const HEAD_FULL: float = 36.0
const BUTTON: Vector2 = Vector2(118, 44)

## Off while the table is acting events out, so nothing is armed mid-moment.
var enabled: bool = true
## The hand's selection, for a Campaign that asks for cards. None in the shops.
var selection: Callable = Callable()
## Use and Cancel stand beside the leaflets rather than under them, where a shop's
## shelf has more width than height. Set before setup().
var side_buttons: bool = false
## Smaller leaflets, for a shop's shelf. Set before setup().
var compact: bool = false
## Leaflets stack in a column with Use and Cancel beside the top one, for the table's
## left edge, which has more height than width. Set before setup().
var vertical: bool = false
## Faint places for the Campaigns that could still be held, so a shop shows the room
## left. The table shows only what is held. Set before setup().
var show_empty: bool = true

var use: Button = ScreenKit.button("", CommonsTheme.PRIMARY)
var cancel: Button = ScreenKit.button("", CommonsTheme.SECONDARY)

var _controller: RunController
var _head: Label = ScreenKit.eyebrow("")
var _leaflets: Array[CampaignLeaflet] = []
var _armed: int = -1
var _cursor: int = -1
var _refusal: String = ""


func _init() -> void:
	for button: Button in [use, cancel]:
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = BUTTON
		button.add_theme_font_size_override("font_size", TextSize.px(20))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.text = tr("campaign.tray").to_upper()
	ScreenKit.paper_outline(_head)
	add_child(_head)
	for button: Button in [use, cancel]:
		add_child(button)
	use.text = tr("campaign.use")
	cancel.text = tr("campaign.cancel")
	use.pressed.connect(use_armed)
	cancel.pressed.connect(disarm)


func setup(controller: RunController) -> void:
	_controller = controller
	refresh()


## A place for every Campaign the player can hold. Leaflets are only ever added: the
## limit rises with a Reform and never falls.
func _grow() -> void:
	while _leaflets.size() < _controller.campaign_slots():
		var leaflet: CampaignLeaflet = CampaignLeaflet.new()
		leaflet.set_compact(compact)
		leaflet.chosen.connect(_on_chosen)
		add_child(leaflet)
		_leaflets.append(leaflet)
		custom_minimum_size = tray_size(_leaflets.size(), side_buttons, compact, vertical)
		size = custom_minimum_size


## The tray's size for a number of slots: the head, a row of leaflets, the buttons. A
## vertical tray is its column alone; its buttons stand to its right.
static func tray_size(
	slots: int, beside: bool = false, small: bool = false, column: bool = false
) -> Vector2:
	var leaf: Vector2 = CampaignLeaflet.leaf_size(small)
	var head: float = HEAD if small else HEAD_FULL
	if column:
		return Vector2(leaf.x, head + slots * leaf.y + (slots - 1) * GAP)
	var wide: float = slots * leaf.x + (slots - 1) * GAP
	if beside:
		return Vector2(wide + GAP + BUTTON.x, head + leaf.y)
	return Vector2(maxf(wide, BUTTON.x * 2.0 + GAP), head + leaf.y + GAP + BUTTON.y)


## Shows what is held now, dims each leaflet that cannot be used with its reason, and
## drops an armed one the run no longer holds.
func refresh() -> void:
	_grow()
	var held: Array[String] = _controller.held_campaigns()
	for slot: int in _leaflets.size():
		var leaflet: CampaignLeaflet = _leaflets[slot]
		leaflet.position = _place(slot)
		leaflet.size = _leaf()
		leaflet.visible = slot < held.size()
		if not leaflet.visible:
			continue
		var held_id: String = held[slot]
		leaflet.show_campaign(
			slot,
			held_id,
			_controller.campaign_name(held_id),
			_controller.campaign_text(held_id),
			_controller.is_private_campaign(held_id)
		)
		var refusal: int = _controller.campaign_reason(slot)
		var why: String = ""
		if refusal != RunController.CAMPAIGN_OK:
			why = tr(RunController.campaign_reason_key(refusal))
		leaflet.set_reason(refusal, why)
	if _armed >= held.size() or (_armed >= 0 and _leaflets[_armed].reason != 0):
		_armed = -1
	_cursor = mini(_cursor, held.size() - 1)
	_show_marks()
	queue_redraw()


## How many leaflet places the tray has.
func campaign_count() -> int:
	return _leaflets.size()


func armed_slot() -> int:
	return _armed


func cursor_slot() -> int:
	return _cursor


func leaflet(slot: int) -> CampaignLeaflet:
	return _leaflets[slot]


## Where a slot's leaflet sits on screen, its middle.
func slot_center(slot: int) -> Vector2:
	return global_position + _place(slot) + _leaf() / 2.0


## What the prompt line should say: the armed Campaign's ask, why Use was refused, or
## nothing while none is armed.
func prompt() -> String:
	if _armed < 0:
		return ""
	if not _refusal.is_empty():
		return _refusal
	return _controller.campaign_prompt(_held_id(_armed))


## Arms a usable leaflet. Arming the armed one again disarms it.
func arm(slot: int) -> void:
	if not enabled or slot < 0 or slot >= _leaflets.size() or not _leaflets[slot].visible:
		return
	if _leaflets[slot].reason != 0:
		return
	_armed = -1 if _armed == slot else slot
	_refusal = ""
	_show_marks()


func disarm() -> void:
	if _armed < 0 and _refusal.is_empty():
		return
	_armed = -1
	_refusal = ""
	_show_marks()


## Spends the armed Campaign on the hand's selection, when it asks for cards.
func use_armed() -> void:
	if not enabled or _armed < 0:
		return
	var slot: int = _armed
	var held_id: String = _held_id(slot)
	var ids: Array[int] = []
	if _controller.campaign_cards(held_id).y > 0 and selection.is_valid():
		ids.assign(selection.call())
	var refusal: int = _controller.campaign_reason(slot, ids, true)
	if refusal != RunController.CAMPAIGN_OK:
		_refusal = tr(RunController.campaign_reason_key(refusal))
		changed.emit()
		return
	_armed = -1
	_refusal = ""
	if _controller.campaign(slot, ids) == RunController.OK:
		used.emit(slot, held_id)
	refresh()
	changed.emit()


## Keyboard and gamepad: true when the tray used the event.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("commons_campaign"):
		_step_cursor()
		return true
	if _armed >= 0 and event.is_action_pressed("commons_play"):
		use_armed()
		return true
	if _cursor >= 0 and _armed < 0 and event.is_action_pressed("commons_play"):
		arm(_cursor)
		return true
	var back: bool = event.is_action_pressed("commons_pass") or event.is_action_pressed("ui_cancel")
	if back and (_armed >= 0 or _cursor >= 0):
		if _armed >= 0:
			disarm()
		else:
			_cursor = -1
			_show_marks()
		return true
	return false


## The cursor visits each held leaflet in turn, then leaves the tray.
func _step_cursor() -> void:
	var held: int = _controller.held_campaigns().size()
	_cursor = _cursor + 1 if _cursor + 1 < held else -1
	_show_marks()


func _on_chosen(slot: int) -> void:
	_cursor = -1
	arm(slot)


func _held_id(slot: int) -> String:
	return _controller.held_campaigns()[slot]


func _place(slot: int) -> Vector2:
	if vertical:
		return Vector2(0, _head_height() + slot * (_leaf().y + GAP))
	return Vector2(slot * (_leaf().x + GAP), _head_height())


func _head_height() -> float:
	return HEAD if compact else HEAD_FULL


func _leaf() -> Vector2:
	return CampaignLeaflet.leaf_size(compact)


func _show_marks() -> void:
	for slot: int in _leaflets.size():
		var lift: float = CampaignLeaflet.LIFT if slot == _armed else 0.0
		_leaflets[slot].set_armed(slot == _armed)
		# A leaflet in a column lifts out sideways, toward its buttons.
		_leaflets[slot].position = (
			_place(slot) + (Vector2(lift, 0) if vertical else Vector2(0, -lift))
		)
		_leaflets[slot].set_cursor(slot == _cursor)
	var row: float = _head_height() + _leaf().y + GAP
	use.position = Vector2(0, row)
	cancel.position = Vector2(BUTTON.x + GAP, row)
	if side_buttons:
		var column: float = _place(_leaflets.size()).x
		use.position = Vector2(column, _head_height())
		cancel.position = Vector2(column, _head_height() + BUTTON.y + GAP)
	if vertical:
		var beside: float = _leaf().x + GAP + CampaignLeaflet.LIFT
		use.position = Vector2(beside, _head_height())
		cancel.position = Vector2(beside, _head_height() + BUTTON.y + GAP)
	for button: Button in [use, cancel]:
		button.visible = _armed >= 0
		# Sized once in the tree, where the button's own minimum is known.
		if button.is_inside_tree():
			button.reset_size()
	changed.emit()


func _draw() -> void:
	if not show_empty:
		return
	var worn: float = BowlGrime.wear()
	var held: int = 0 if _controller == null else _controller.held_campaigns().size()
	for slot: int in range(held, _leaflets.size()):
		CampaignPaper.empty_place(self, Rect2(_place(slot), _leaf()), worn, slot)
