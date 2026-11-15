class_name StoreNotes
extends RefCounted
## The notes a shop prints under its heading: the black market's warning of what every
## purchase there costs beyond coupons, and the state store's note of why its counter
## is short while rationing holds.


static func warning(controller: RunController, width: float) -> Control:
	var note: KeywordText = KeywordText.new()
	note.add_theme_font_size_override("normal_font_size", 24)
	note.add_theme_color_override("default_color", ScreenKit.STYLE.paper_bright)
	note.custom_minimum_size = Vector2(width, 0)
	var text: String = TranslationServer.translate("market.warning")
	note.set_rule(text.format({"rise": controller.purchase_resentment()}))
	return note


static func rationing(controller: RunController) -> Label:
	var slots: int = controller.store_stock().size()
	var text: String = Strings.count("store.rationed", slots).format(
		{"below": controller.rationing_lifts_below()}
	)
	var note: Label = ScreenKit.label(text, 22)
	note.add_theme_color_override("font_color", ScreenKit.RED)
	return note
