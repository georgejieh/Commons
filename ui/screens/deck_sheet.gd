class_name DeckSheet
extends Control
## The deck sheet (ADR 0041): a sheet over the page that shows the communal deck, all 54
## cards as real faces with their marks, a rank to a group in rank order, and the private
## plot's cards after them, with a legend of the marks the run holds. It opens read-only
## from both shops and the table, and in choosing mode from a shop's desk, where the
## player picks one deck card, reads what will change on it, the mark it would replace
## included, and confirms or backs out. A hover or the cursor names a card's marks in the
## slip beside it. While open it keeps the focus and every key; Cancel closes it.

signal closed
## The desk marked the card: the page shows what the desk did.
signal marked(card_id: int)

const DIM: Color = Color(0.05, 0.03, 0.02, 0.6)
const MARGIN: float = 24.0
const PADDING: int = 28
const SPACING: int = 10
const RULE_SIZE: int = 20
const LEGEND_SIZE: int = 18
## The stamp that marks a card as the player's, beside the enhancements in the legend.
const STAMP: String = "stamp"
const PLAYER: int = 0

var _controller: RunController = null
var _desk: DeskView = null
var _market: bool = false
var _board: DeckBoard = DeckBoard.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _paper: PanelContainer = PanelContainer.new()
var _eyebrow: Label = ScreenKit.eyebrow("")
var _title: Label = ScreenKit.styled("", CommonsTheme.TITLE)
var _legend: HBoxContainer = HBoxContainer.new()
var _status: Label = ScreenKit.label("", RULE_SIZE)
var _confirm: Button = ScreenKit.button("", CommonsTheme.PRIMARY)
var _back: Button = ScreenKit.button("", CommonsTheme.SECONDARY)
var _slip: DetailSlip = DetailSlip.new()


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
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top"]:
		_paper.set("offset_" + side, MARGIN)
	for side: String in ["right", "bottom"]:
		_paper.set("offset_" + side, -MARGIN)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", SPACING)
	_paper.add_child(column)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(_eyebrow)
	titles.add_child(_title)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legend.add_theme_constant_override("separation", 18)
	_legend.size_flags_vertical = Control.SIZE_SHRINK_END
	column.add_child(ScreenKit.row([titles, _legend]))
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_board)
	column.add_child(_scroll)
	ScrollFade.over(_scroll)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buttons: HBoxContainer = ScreenKit.row([_confirm, _back])
	column.add_child(ScreenKit.row([_status, buttons]))
	_back.pressed.connect(close)
	_confirm.pressed.connect(_on_confirm)
	_board.cursor_moved.connect(_on_cursor)
	_board.picked_card.connect(_on_picked)
	add_child(_slip)
	resized.connect(_fit)


func setup(controller: RunController) -> void:
	_controller = controller
	_board.prepare()


func is_open() -> bool:
	return visible


## The parts, for tests and the playtest.
func board() -> DeckBoard:
	return _board


func confirm_button() -> Button:
	return _confirm


func back_button() -> Button:
	return _back


func paper() -> Control:
	return _paper


func slip() -> DetailSlip:
	return _slip


func status_text() -> String:
	return _status.text


## Opens read-only on the deck as the run holds it now.
func open_deck() -> void:
	_desk = null
	_eyebrow.text = tr("deck.eyebrow")
	_title.text = tr("deck.title")
	_open(false)


## Opens on the deck for the player to pick a card for desk to mark: the state store's,
## or with market the black market's.
func open_desk(desk: DeskView, market: bool) -> void:
	_desk = desk
	_market = market
	_eyebrow.text = tr("deck.desk.market" if market else "deck.desk.store")
	if desk.stamps():
		_title.text = tr("deck.desk.stamp_title")
	else:
		_title.text = tr("deck.desk.title").format({"mark": _mark_name(desk.offer())})
	_open(true)


func close() -> void:
	if not visible:
		return
	visible = false
	_slip.hide_slip()
	_board.clear()
	closed.emit()


func _open(choosing: bool) -> void:
	visible = true
	move_to_front()
	_board.picking = choosing
	_confirm.visible = choosing
	_back.text = tr("deck.back" if choosing else "deck.close")
	var state: RunState = _controller.state_copy()
	_board.show_cards(_controller.deck_cards(), state.inventory.plot, _room())
	_show_legend(state)
	_show_choice()
	_link_focus()
	_board.grab_focus()
	UiMotion.enter([_paper] as Array[Control])


## The room the cards may take: the paper's inside, less the heading and the buttons.
func _room() -> Vector2:
	var inside: Vector2 = get_viewport_rect().size - Vector2.ONE * (MARGIN + PADDING) * 2.0
	var header: float = (
		_title.get_combined_minimum_size().y + _eyebrow.get_combined_minimum_size().y
	)
	var footer: float = _back.get_combined_minimum_size().y
	return Vector2(inside.x - 12.0, inside.y - header - footer - SPACING * 2.0)


func _fit() -> void:
	if visible:
		_board.lay_out(_room())


## One entry for each mark the deck or the plot holds now: its drawn mark, its name and
## how many cards carry it.
func _show_legend(state: RunState) -> void:
	for child: Node in _legend.get_children():
		_legend.remove_child(child)
		child.queue_free()
	var counts: Dictionary[String, int] = {}
	var cards: Array[CardInstance] = _controller.deck_cards()
	cards.append_array(state.inventory.plot)
	for card: CardInstance in cards:
		if card.owner_stamp() == PLAYER:
			counts[STAMP] = counts.get(STAMP, 0) + 1
		if CardMark.draws(card.enhancement_id()):
			counts[card.enhancement_id()] = counts.get(card.enhancement_id(), 0) + 1
	if counts.is_empty():
		_legend.add_child(ScreenKit.label(tr("deck.legend.none"), LEGEND_SIZE))
		return
	for mark: String in [STAMP] + CardInstance.ENHANCEMENTS:
		if counts.has(mark):
			_legend.add_child(_legend_entry(mark, counts[mark]))


func _legend_entry(mark: String, count: int) -> Control:
	var kind: CardMark.Kind = CardMark.Kind.STAMP if mark == STAMP else CardMark.KINDS[mark]
	var drawn: CardMark = CardMark.new(kind)
	drawn.visible = true
	var words: String = tr("deck.legend.entry").format({"mark": _mark_name(mark), "count": count})
	var entry: HBoxContainer = ScreenKit.row([drawn, ScreenKit.label(words, LEGEND_SIZE)], 6)
	entry.tooltip_text = Keywords.wrapped(Keywords.meaning(mark))
	return entry


static func _mark_name(mark: String) -> String:
	return TranslationServer.translate("keyword.%s.name" % mark)


## The marks a card carries, in words whose keywords the slip explains.
static func marks_text(card: CardInstance) -> String:
	var names: PackedStringArray = []
	if CardMark.draws(card.enhancement_id()):
		names.append(_mark_name(card.enhancement_id()))
	if card.owner_stamp() == PLAYER:
		names.append(_mark_name(STAMP))
	if names.is_empty():
		return TranslationServer.translate("deck.marks.none")
	return TranslationServer.translate("deck.marks").format({"marks": ", ".join(names)})


func _on_cursor(card_id: int) -> void:
	var view: CardView = _board.view_of(card_id)
	var card: CardInstance = _board.card_of(card_id)
	if view == null or card == null:
		return
	var title: String = PlotSwapSheet.card_name(card)
	if _board.is_plot(card_id):
		title = tr("deck.plot_card").format({"card": title})
	_slip.show_for(view, title, marks_text(card))


func _on_picked(_card_id: int) -> void:
	_show_choice()
	_link_focus()


## What the desk would do to the picked card, or why it cannot, and the confirm ticket.
func _show_choice() -> void:
	if _desk == null:
		_status.text = tr("deck.how")
		return
	var price: int = _desk.price()
	var key: String = "deck.desk.stamp" if _desk.stamps() else "deck.desk.mark"
	_confirm.text = tr(key).format({"price": price})
	var picked: int = _board.picked
	if picked == DeckBoard.NONE:
		_status.text = tr("deck.desk.how")
		_confirm.disabled = true
		return
	var refusal: String = _desk.refusal(picked)
	_confirm.disabled = not refusal.is_empty()
	_status.text = _change_text(_board.card_of(picked), refusal, price)


func _change_text(card: CardInstance, refusal: String, price: int) -> String:
	var values: Dictionary[String, Variant] = {
		"card": PlotSwapSheet.card_name(card),
		"mark": _mark_name(_desk.offer()),
		"old": _mark_name(card.enhancement_id()),
		"price": price,
	}
	if not refusal.is_empty():
		return tr(refusal).format(values)
	if _desk.stamps():
		return tr("deck.change.stamp").format(values)
	if CardMark.draws(card.enhancement_id()):
		return tr("deck.change.replace").format(values)
	return tr("deck.change.mark").format(values)


func _on_confirm() -> void:
	var picked: int = _board.picked
	if _desk == null or picked == DeckBoard.NONE:
		return
	if _controller.mark_card(picked, _market) != RunController.OK:
		_show_choice()
		return
	close()
	marked.emit(picked)


## The focus stays on the sheet: the cards above, the buttons in a row under them.
func _link_focus() -> void:
	var row: Array[Control] = [_back]
	if _confirm.visible and not _confirm.disabled:
		row.push_front(_confirm)
	for index: int in row.size():
		var control: Control = row[index]
		control.focus_neighbor_left = control.get_path_to(row[maxi(0, index - 1)])
		control.focus_neighbor_right = control.get_path_to(row[mini(row.size() - 1, index + 1)])
		control.focus_neighbor_top = control.get_path_to(_board)
		control.focus_neighbor_bottom = control.get_path_to(control)
	_board.focus_neighbor_bottom = _board.get_path_to(row[0])
	for side: String in ["top", "left", "right"]:
		_board.set("focus_neighbor_" + side, _board.get_path_to(_board))
	_confirm.focus_next = _confirm.get_path_to(_back)
	_back.focus_next = _back.get_path_to(_board)
	_board.focus_next = _board.get_path_to(row[0])


## Cancel closes the sheet; every other key stays with it.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
