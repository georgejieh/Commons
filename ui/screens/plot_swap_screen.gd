class_name PlotSwapScreen
extends Control
## The private-plot swap (P4.8): your hand, kitty included when you are landlord, beside
## your plot. Pick as many hand cards as plot cards, up to the round's swap limit, and
## swap them one for one, or keep your hand.

var _controller: RunController
var _hand_picks: Array[int] = []
var _plot_picks: Array[int] = []
var _swap: Button = ScreenKit.button("", CommonsTheme.PRIMARY)


func open(app: DemoApp) -> void:
	_controller = app.controller
	_hand_picks.clear()
	_plot_picks.clear()
	var state: RunState = _controller.state_copy()
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.notice_wall)
	sheet.add_child(ScreenKit.header(tr("plot.eyebrow"), tr("plot.title")))
	var swapping: bool = _controller.awaiting() == RunController.AWAIT_SWAP
	if swapping:
		var limit: String = Strings.count("plot.limit", _controller.swap_limit())
		sheet.add_child(ScreenKit.label(limit, 22))
	sheet.add_child(ScreenKit.eyebrow(tr("plot.hand")))
	sheet.add_child(_cards_row(_controller.player_cards(), _hand_picks, swapping))
	sheet.add_child(ScreenKit.eyebrow(tr("plot.plot")))
	var plot: Array[CardInstance] = state.inventory.plot
	if plot.is_empty():
		sheet.add_child(ScreenKit.label(tr("plot.empty"), 24))
	else:
		sheet.add_child(_cards_row(plot, _plot_picks, swapping))
	var keep: Button = ScreenKit.button(tr("plot.keep"), CommonsTheme.SECONDARY)
	var none: Array[int] = []
	keep.pressed.connect(func() -> void: _leave(app, none, none))
	_swap.text = tr("plot.swap")
	_swap.pressed.connect(func() -> void: _leave(app, _hand_picks, _plot_picks))
	_swap.visible = swapping
	_refresh()
	sheet.add_child(ScreenKit.row([_swap, keep]))
	ScreenKit.reveal(sheet)
	keep.grab_focus()


## One toggle per card while a swap is waiting, so a pick is a pressed button; plain
## text otherwise.
func _cards_row(cards: Array[CardInstance], picks: Array[int], active: bool) -> Control:
	if not active:
		return ScreenKit.label(cards_text(cards), 24)
	var flow: HFlowContainer = HFlowContainer.new()
	for card: CardInstance in cards:
		var toggle: Button = ScreenKit.button(cards_text([card]), CommonsTheme.GHOST)
		toggle.toggle_mode = true
		var card_id: int = card.id()
		toggle.toggled.connect(
			func(on: bool) -> void:
				if on:
					picks.append(card_id)
				else:
					picks.erase(card_id)
				_refresh()
		)
		flow.add_child(toggle)
	return flow


func _refresh() -> void:
	var count: int = _hand_picks.size()
	var even: bool = count > 0 and count == _plot_picks.size()
	_swap.disabled = not even or count > _controller.swap_limit()


func _leave(app: DemoApp, hand_ids: Array[int], plot_ids: Array[int]) -> void:
	if _controller.awaiting() == RunController.AWAIT_SWAP:
		_controller.swap(hand_ids, plot_ids)
	if not app.back():
		app.show_screen(app.table_id(), true)


static func cards_text(cards: Array[CardInstance]) -> String:
	var glyphs: PackedStringArray = []
	for card: CardInstance in cards:
		glyphs.append(TranslationServer.translate(CardView.RANK_KEYS[card.base_rank()]))
	return " ".join(glyphs)
