class_name DeckSheet
extends Control
## The deck sheet (ADR 0041): a sheet over the page that shows the communal deck, all 54
## cards as real faces with their marks, a rank to a group in rank order, and the private
## plot's cards after them, with a legend of the marks the run holds. Each group's name
## gives its count where an exchange made it differ from a plain deck's, and the slip
## over a card the state store put in the deck names the card it replaced (ADR 0042). It
## opens read-only from both shops and the table, and in choosing mode for a DeckChoice,
## a shop's desk or an exchange, where the player picks one deck card, reads what will
## happen to it, and confirms or backs out. A hover or the cursor names a card's marks in
## the slip beside it. While open it keeps the focus and every key; Cancel closes it.

## Sent each time the sheet closes, whichever way it was closed.
signal closed
## The choice was made on the card: the page shows what it did.
signal chosen(card_id: int)

## The scene the card coming into the deck is shown with, the same face the table draws.
const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")

## The veil over the page behind the sheet.
const DIM: Color = Color(0.05, 0.03, 0.02, 0.6)
## The gap between the sheet's paper and the screen's edge, in pixels.
const MARGIN: float = 24.0
## The padding inside the sheet's paper, in pixels.
const PADDING: int = 28
## The gap between the parts of the sheet's column, in pixels.
const SPACING: int = 10
## The size of the status line, at Standard text.
const RULE_SIZE: int = 20
## The size of the legend's entries, at Standard text.
const LEGEND_SIZE: int = 18
## The stamp that marks a card as the player's, beside the enhancements in the legend.
const STAMP: String = "stamp"

## The key to the marks on the cards.
var legend: HBoxContainer = HBoxContainer.new()
## The scroll the deck's cards stand in.
var scroll: ScrollContainer = ScrollContainer.new()
## The sheet's heading.
var title_label: Label = ScreenKit.styled("", CommonsTheme.TITLE)
var _controller: RunController = null
var _choice: DeckChoice = null
var _board: DeckBoard = DeckBoard.new()
var _paper: PanelContainer = PanelContainer.new()
var _eyebrow: Label = ScreenKit.eyebrow("")
var _status: Label = ScreenKit.label("", RULE_SIZE)
var _confirm: Button = ScreenKit.button("", CommonsTheme.PRIMARY)
var _back: Button = ScreenKit.button("", CommonsTheme.SECONDARY)
var _slip: DetailSlip = DetailSlip.new()
## The card coming into the deck, beside the heading, while an exchange is chosen.
var _incoming: CardView = null


func _ready() -> void:
	visible = false
	z_index = ScreenKit.LAYER_SHEET
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(Scrim.new(DIM))
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
	titles.add_child(title_label)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_theme_constant_override("separation", 18)
	legend.size_flags_vertical = Control.SIZE_SHRINK_END
	_incoming = CARD_SCENE.instantiate()
	_incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incoming.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_child(ScreenKit.row([_incoming, titles, legend]))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_board)
	column.add_child(scroll)
	ScrollFade.over(scroll)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buttons: HBoxContainer = ScreenKit.row([_confirm, _back])
	column.add_child(ScreenKit.row([_status, buttons]))
	_back.pressed.connect(close)
	_confirm.pressed.connect(_on_confirm)
	_board.cursor_moved.connect(_on_cursor)
	_board.picked_card.connect(_on_picked)
	add_child(_slip)
	# The sheet covers the page, so its slip keeps off the sheet's buttons and names alone.
	_slip.within = self
	resized.connect(_fit)


## Gives the sheet the run controller it reads the deck from, and prepares the card board.
func setup(controller: RunController) -> void:
	_controller = controller
	_board.prepare()


## True while the sheet is showing; it keeps the focus and every key until it closes.
func is_open() -> bool:
	return visible


## The card board, for tests and the playtest.
func board() -> DeckBoard:
	return _board


## The ticket that confirms the choice, for tests and the playtest.
func confirm_button() -> Button:
	return _confirm


## The Back button, for tests and the playtest.
func back_button() -> Button:
	return _back


## The sheet's paper, for tests and the playtest.
func paper() -> Control:
	return _paper


## The slip beside the sheet that names the card under the cursor, for tests and the playtest.
func slip() -> DetailSlip:
	return _slip


## The line beside the buttons, saying what picking the card does or why it cannot, for tests.
func status_text() -> String:
	return _status.text


## The card shown coming into the deck, for tests and the playtest.
func incoming_view() -> CardView:
	return _incoming


## Opens read-only on the deck as the run holds it now.
func open_deck() -> void:
	_choice = null
	_eyebrow.text = tr("deck.eyebrow")
	title_label.text = tr("deck.title")
	_open(false)


## Opens on the deck for the player to pick a card for choice: a desk's mark, or the card
## an exchange takes out.
func open_choice(choice: DeckChoice) -> void:
	_choice = choice
	_eyebrow.text = choice.eyebrow()
	title_label.text = choice.title()
	_open(true)


## Closes the sheet, puts the slip away, clears the board and sends closed.
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
	var coming: CardInstance = null if _choice == null else _choice.incoming()
	_incoming.visible = coming != null
	if coming != null:
		_incoming.bind(coming)
	var deck: Array[CardInstance] = _controller.store.deck_cards()
	var plot: Array[CardInstance] = _controller.run.plot()
	_board.show_cards(deck, plot, _room())
	deck.append_array(plot)
	_show_legend(deck)
	_show_choice()
	_link_focus()
	_board.grab_focus()
	UiMotion.enter([_paper] as Array[Control])


## The room the cards may take: the paper's inside, less the heading and the buttons.
func _room() -> Vector2:
	var inside: Vector2 = get_viewport_rect().size - Vector2.ONE * (MARGIN + PADDING) * 2.0
	var header: float = (
		title_label.get_combined_minimum_size().y + _eyebrow.get_combined_minimum_size().y
	)
	if _incoming.visible:
		header = maxf(header, _incoming.get_combined_minimum_size().y)
	var footer: float = _back.get_combined_minimum_size().y
	return Vector2(inside.x - 12.0, inside.y - header - footer - SPACING * 2.0)


func _fit() -> void:
	if visible:
		_board.lay_out(_room())


## One entry for each mark the deck or the plot holds now: its drawn mark, its name and
## how many cards carry it.
func _show_legend(cards: Array[CardInstance]) -> void:
	ScreenKit.clear(legend)
	var counts: Dictionary[String, int] = {}
	for card: CardInstance in cards:
		if card.owner_stamp() == Seats.PLAYER:
			counts[STAMP] = counts.get(STAMP, 0) + 1
		if CardMark.draws(card.enhancement_id()):
			counts[card.enhancement_id()] = counts.get(card.enhancement_id(), 0) + 1
	if counts.is_empty():
		legend.add_child(ScreenKit.label(tr("deck.legend.none"), LEGEND_SIZE))
		return
	for mark: String in [STAMP] + CardInstance.ENHANCEMENTS:
		if counts.has(mark):
			legend.add_child(_legend_entry(mark, counts[mark]))


func _legend_entry(mark: String, count: int) -> Control:
	var kind: CardMark.Kind = CardMark.Kind.STAMP if mark == STAMP else CardMark.KINDS[mark]
	var drawn: CardMark = CardMark.new(kind)
	drawn.visible = true
	var words: String = tr("deck.legend.entry").format({"mark": mark_name(mark), "count": count})
	var entry: HBoxContainer = ScreenKit.row([drawn, ScreenKit.label(words, LEGEND_SIZE)], 6)
	entry.tooltip_text = Keywords.wrapped(Keywords.meaning(mark))
	return entry


## The name of a mark by its id, as the legend and the slips say it.
static func mark_name(mark: String) -> String:
	return TranslationServer.translate("keyword.%s.name" % mark)


## The marks a card carries, by name: its enhancement's, then the player's stamp.
static func marks(card: CardInstance) -> PackedStringArray:
	var names: PackedStringArray = []
	if CardMark.draws(card.enhancement_id()):
		names.append(mark_name(card.enhancement_id()))
	if card.owner_stamp() == Seats.PLAYER:
		names.append(mark_name(STAMP))
	return names


## The marks a card carries, in words whose keywords the slip explains.
static func marks_text(card: CardInstance) -> String:
	var names: PackedStringArray = marks(card)
	if names.is_empty():
		return TranslationServer.translate("deck.marks.none")
	return TranslationServer.translate("deck.marks").format({"marks": ", ".join(names)})


func _on_cursor(card_id: int) -> void:
	var view: CardView = _board.view_of(card_id)
	var card: CardInstance = _board.card_of(card_id)
	if view == null or card == null:
		return
	var title: String = CardName.of(card)
	var rule: String = marks_text(card)
	if _board.is_plot(card_id):
		title = tr("deck.plot_card").format({"card": title})
	elif _controller.store.replaced(card_id) != null:
		var plain: String = CardName.of(_controller.store.replaced(card_id))
		rule = tr("deck.exchanged").format({"marks": rule, "card": plain})
	_slip.show_for(view, title, rule)


func _on_picked(_card_id: int) -> void:
	_show_choice()
	_link_focus()


## What the choice would do to the picked card, or why it cannot, and the confirm ticket.
## Read-only, how many cards the state store has exchanged.
func _show_choice() -> void:
	if _choice == null:
		var changed: int = _controller.store.exchanged_count()
		_status.text = tr("deck.how")
		if changed > 0:
			_status.text += " " + tr("deck.exchanges").format({"count": changed})
		return
	_confirm.text = _choice.confirm_text()
	var picked: int = _board.picked
	if picked == DeckBoard.NONE:
		_status.text = _choice.how()
		_confirm.disabled = true
		return
	var card: CardInstance = _board.card_of(picked)
	var refusal: String = _choice.refusal(card)
	_confirm.disabled = not refusal.is_empty()
	_status.text = refusal if not refusal.is_empty() else _choice.change(card)


func _on_confirm() -> void:
	var picked: int = _board.picked
	if _choice == null or picked == DeckBoard.NONE:
		return
	if not _choice.commit(_controller, picked):
		_show_choice()
		return
	# Told before closed, so whatever waits on the choice knows it was made.
	chosen.emit(picked)
	close()


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
	elif (
		event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion
	):
		get_viewport().set_input_as_handled()
