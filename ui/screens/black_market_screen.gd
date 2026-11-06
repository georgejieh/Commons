class_name BlackMarketScreen
extends Control
## The black market (P3B.9): private goods at a price that raises Resentment. It has
## no stock until P4.10 brings private items, so it shows an empty counter.


func open(app: DemoApp) -> void:
	var state: RunState = app.controller.state_copy()
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.store)
	sheet.add_child(ScreenKit.header(tr("market.eyebrow"), tr("market.title")))
	sheet.add_child(ScreenKit.label(Strings.count("table.coupons", state.coupons), 26))
	sheet.add_child(ScreenKit.label(tr("market.empty"), 24))
	var back: Button = ScreenKit.button(tr("market.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	sheet.add_child(back)
	ScreenKit.reveal(sheet)
	back.grab_focus()
