class_name PlotSwapSheet
extends Control
## The private-plot swap (ADR 0038), a sheet over the table at the foot of the screen,
## where the hand lies. It shows your hand and your plot side by side as real cards, so
## suit, marks and wild ribbons show, and the swaps left this round, always in view.
## Trade a hand card for a plot card by clicking one and then the other, or by dragging
## one onto the other; each traded pair is numbered, listed with its Undo, and can be
## taken back before Swap sends them. Keep hand sends none. The table opens it when the
## run waits on the swap, once its queue is empty, and nothing at the table plays while
## it is open: the run moves no seat until the swap is answered. It takes every key but
## Cancel, which opens the table's menu.

## The dim over the table, as light as the one-time tips', so the seats still show.
const DIM: Color = Color(0.05, 0.03, 0.02, 0.5)
const MARGIN: float = 24.0
const PADDING: int = 28
const SPACING: int = 12
const RULE_SIZE: int = 20
const COUNT_SIZE: int = 40
const SEAT_SIZE: int = 22

var _app: DemoApp
var _pool: CardPool
var _board: SwapBoard = SwapBoard.new()
var _paper: PanelContainer = PanelContainer.new()
var _count: Label = ScreenKit.label("", COUNT_SIZE)
var _seat: Label = ScreenKit.label("", SEAT_SIZE)
var _status: Label = ScreenKit.label("", RULE_SIZE)
var _pairs: VBoxContainer = VBoxContainer.new()
var _swap: Button = ScreenKit.button("", CommonsTheme.PRIMARY)
var _keep: Button = ScreenKit.button("", CommonsTheme.SECONDARY)
var _undo: Array[Button] = []
## True while the refusal just given should stay in view.
var _refused_now: bool = false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_paper.add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	_paper.theme = ScreenKit.ink_theme()
	add_child(_paper)
	_paper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_paper.offset_left = MARGIN
	_paper.offset_right = -MARGIN
	_paper.offset_bottom = -MARGIN
	_paper.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", SPACING)
	_paper.add_child(column)
	column.add_child(_header())
	var rule: Label = ScreenKit.label(tr("plot.rule"), RULE_SIZE)
	column.add_child(rule)
	column.add_child(_seat)
	column.add_child(_board)
	column.add_child(_footer())
	_board.changed.connect(_refresh)
	_board.refused.connect(_on_refused)
	_swap.text = tr("plot.swap")
	_swap.pressed.connect(_confirm)
	_keep.text = tr("plot.keep")
	_keep.pressed.connect(_decline)


func _header() -> Control:
	var titles: Control = ScreenKit.header(tr("plot.eyebrow"), tr("plot.title"))
	var headline: Label = titles.get_child(1) as Label
	headline.theme_type_variation = CommonsTheme.TITLE
	var counter: VBoxContainer = VBoxContainer.new()
	counter.add_theme_constant_override("separation", 0)
	var caption: Label = ScreenKit.eyebrow(tr("plot.left"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.add_child(caption)
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.add_child(_count)
	var row: HBoxContainer = ScreenKit.row([titles, counter])
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _footer() -> Control:
	_pairs.add_theme_constant_override("separation", 4)
	var notes: VBoxContainer = VBoxContainer.new()
	notes.add_theme_constant_override("separation", 4)
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_child(_pairs)
	notes.add_child(_status)
	var buttons: HBoxContainer = ScreenKit.row([_swap, _keep])
	buttons.size_flags_vertical = Control.SIZE_SHRINK_END
	return ScreenKit.row([notes, buttons])


func setup(app: DemoApp, pool: CardPool) -> void:
	_app = app
	_pool = pool


func is_open() -> bool:
	return visible


## The card board, and the buttons, for tests and the playtest.
func board() -> SwapBoard:
	return _board


func swap_button() -> Button:
	return _swap


func keep_button() -> Button:
	return _keep


func undo_buttons() -> Array[Button]:
	return _undo.duplicate()


## The paper the sheet is drawn on, for layout tests.
func paper() -> Control:
	return _paper


## Opens on the hand and plot the run holds now, when the run waits on the swap.
func open() -> void:
	var controller: RunController = _app.controller
	if visible or controller.awaiting() != RunController.AWAIT_SWAP:
		return
	var reader: KeptSeat = KeptSeat.of(controller.set_events())
	var names: Dictionary[int, String] = {0: tr("ledger.you")}
	for seat: int in [1, 2]:
		names[seat] = _app.seat_name(seat)
	_seat.text = reader.line(names) if reader.kept() else ""
	_seat.visible = reader.kept()
	_status.text = ""
	visible = true
	# Over everything at the table; the table's menu still comes to the front when opened.
	move_to_front()
	_board.show_cards(
		controller.table.player_cards(),
		controller.run.plot(),
		controller.table.swap_limit(),
		_pool,
		_app.hand,
		controller.table.wild_ranks()
	)
	_refresh()
	_board.grab_focus()
	var pieces: Array[Control] = [_paper]
	UiMotion.enter(pieces)
	# The first time the swap is offered, a one-time tooltip explains it (ADR 0026).
	TipSlip.offer(self, _app, ["tip.plot"] as Array[String])


func _refresh() -> void:
	var trade: PlotTrade = _board.trade
	_count.text = tr("plot.left.count").format({"left": trade.left(), "limit": trade.limit})
	_swap.disabled = trade.pairs() == 0
	if not _refused_now:
		_status.text = ""
	_refused_now = false
	_status.visible = not _status.text.is_empty()
	for child: Node in _pairs.get_children():
		_pairs.remove_child(child)
		child.queue_free()
	_undo.clear()
	if trade.pairs() == 0:
		_pairs.add_child(ScreenKit.label(tr("plot.how"), RULE_SIZE))
	for index: int in trade.pairs():
		var line: Label = ScreenKit.label(_pair_text(trade, index), RULE_SIZE)
		var undo: Button = ScreenKit.button(tr("plot.undo"), CommonsTheme.GHOST)
		undo.custom_minimum_size = Vector2.ZERO
		undo.pressed.connect(_board.undo.bind(index))
		_undo.append(undo)
		var row: HBoxContainer = ScreenKit.row([undo, line])
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pairs.add_child(row)
	_link_focus()
	# An Undo that was pressed has gone with its row: the focus goes back to the cards.
	if visible and get_viewport().gui_get_focus_owner() == null:
		_board.grab_focus()


## "1. 9 of Spades in, 3 of Hearts sits out", by the pair's number.
func _pair_text(trade: PlotTrade, index: int) -> String:
	var brought: String = CardName.of(_board.card_of(trade.plot_ids[index]))
	var set_aside: String = CardName.of(_board.card_of(trade.hand_ids[index]))
	var text: String = tr("plot.pair").format({"in": brought, "out": set_aside})
	return "%d. %s" % [index + 1, text]


## A pick past the round's swaps is refused where the count is: it says why, and pulses.
func _on_refused() -> void:
	_refused_now = true
	_status.text = tr("plot.none_left")
	UiMotion.pulse(_count)


## Focus stays on the sheet: the board above, the Undo buttons and the two buttons in a
## row under it.
func _link_focus() -> void:
	var row: Array[Control] = []
	for undo: Button in _undo:
		row.append(undo)
	row.append_array([_swap, _keep] as Array[Control])
	for index: int in row.size():
		var control: Control = row[index]
		var left: Control = row[maxi(0, index - 1)]
		var right: Control = row[mini(row.size() - 1, index + 1)]
		control.focus_neighbor_left = control.get_path_to(left)
		control.focus_neighbor_right = control.get_path_to(right)
		control.focus_neighbor_top = control.get_path_to(_board)
		control.focus_neighbor_bottom = control.get_path_to(control)
	var below: Control = _keep if _swap.disabled else _swap
	_board.focus_neighbor_bottom = _board.get_path_to(below)
	_board.focus_neighbor_top = _board.get_path_to(_board)
	_board.focus_neighbor_left = _board.get_path_to(_board)
	_board.focus_neighbor_right = _board.get_path_to(_board)


func _confirm() -> void:
	var trade: PlotTrade = _board.trade
	_close(trade.hand_ids.duplicate(), trade.plot_ids.duplicate())


func _decline() -> void:
	var none: Array[int] = []
	_close(none, none)


## Puts the cards back in the table's pool and answers the swap; the table plays on from
## the events the answer brings.
func _close(hand_ids: Array[int], plot_ids: Array[int]) -> void:
	visible = false
	_board.clear()
	if _app.controller.awaiting() == RunController.AWAIT_SWAP:
		_app.controller.swap(hand_ids, plot_ids)


## The sheet takes every key the table would act on, but Cancel, which opens its menu.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
