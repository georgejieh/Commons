class_name PlotSwapScreen
extends Control
## The private-plot swap (P3B.9): your hand beside your plot. Swapping needs plot cards,
## which P4.8 brings; until then Keep hand is the only choice.


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.notice_wall)
	sheet.add_child(ScreenKit.header(tr("plot.eyebrow"), tr("plot.title")))
	sheet.add_child(ScreenKit.eyebrow(tr("plot.hand")))
	sheet.add_child(ScreenKit.label(cards_text(controller.player_cards()), 24))
	sheet.add_child(ScreenKit.eyebrow(tr("plot.plot")))
	var plot: Array[CardInstance] = state.inventory.plot
	var plot_text: String = tr("plot.empty") if plot.is_empty() else cards_text(plot)
	sheet.add_child(ScreenKit.label(plot_text, 24))
	var keep: Button = ScreenKit.button(tr("plot.keep"), CommonsTheme.PRIMARY)
	keep.pressed.connect(
		func() -> void:
			if controller.awaiting() == RunController.AWAIT_SWAP:
				controller.swap([], [])
			if not app.back():
				app.show_screen(app.table_id(), true)
	)
	sheet.add_child(keep)
	ScreenKit.reveal(sheet)
	keep.grab_focus()


static func cards_text(cards: Array[CardInstance]) -> String:
	var glyphs: PackedStringArray = []
	for card: CardInstance in cards:
		glyphs.append(TranslationServer.translate(CardView.RANK_KEYS[card.base_rank()]))
	return " ".join(glyphs)
