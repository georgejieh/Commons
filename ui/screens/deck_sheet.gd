class_name DeckSheet
extends Control
## The deck sheet (ADR 0041): a sheet over the page that shows the communal deck, all 54
## cards as real faces with their marks, a rank to a group in rank order, and the private
## plot's cards after them, with a legend of the marks the run holds. It opens from both
## shops and the table. A hover or the cursor names a card's marks in the slip beside it.
## While open it keeps the focus and every key; Cancel closes it.

signal closed

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
var _board: DeckBoard = DeckBoard.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _paper: PanelContainer = PanelContainer.new()
var _eyebrow: Label = ScreenKit.eyebrow("")
var _title: Label = ScreenKit.styled("", CommonsTheme.TITLE)
var _legend: HBoxContainer = HBoxContainer.new()
var _status: Label = ScreenKit.label("", RULE_SIZE)
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
	column.add_child(ScreenKit.row([_status, _back]))
	_back.text = tr("deck.close")
	_back.pressed.connect(close)
	_board.cursor_moved.connect(_on_cursor)
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


func back_button() -> Button:
	return _back


func paper() -> Control:
	return _paper


func slip() -> DetailSlip:
	return _slip


func status_text() -> String:
	return _status.text


## Opens on the deck as the run holds it now.
func open_deck() -> void:
	visible = true
	move_to_front()
	_eyebrow.text = tr("deck.eyebrow")
	_title.text = tr("deck.title")
	_status.text = tr("deck.how")
	var state: RunState = _controller.state_copy()
	_board.show_cards(_controller.deck_cards(), state.inventory.plot, _room())
	_show_legend(state)
	_link_focus()
	_board.grab_focus()
	UiMotion.enter([_paper] as Array[Control])


func close() -> void:
	if not visible:
		return
	visible = false
	_slip.hide_slip()
	_board.clear()
	closed.emit()


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


## The focus stays on the sheet: the cards above, the button under them.
func _link_focus() -> void:
	for side: String in ["left", "right", "bottom"]:
		_back.set("focus_neighbor_" + side, _back.get_path_to(_back))
	_back.focus_neighbor_top = _back.get_path_to(_board)
	_back.focus_next = _back.get_path_to(_board)
	_back.focus_previous = _back.get_path_to(_board)
	_board.focus_neighbor_bottom = _board.get_path_to(_back)
	for side: String in ["top", "left", "right"]:
		_board.set("focus_neighbor_" + side, _board.get_path_to(_board))
	_board.focus_next = _board.get_path_to(_back)
	_board.focus_previous = _board.get_path_to(_back)


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
