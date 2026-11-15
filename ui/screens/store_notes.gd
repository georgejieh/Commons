class_name StoreNotes
extends RefCounted
## The notes a shop prints at the right of its heading, each on a slip of paper: the
## black market's warning of what every purchase there costs beyond coupons, and the
## state store's note of why its counter is short while rationing holds.

const NOTE_SIZE: int = 20
const PADDING: int = 10


static func warning(controller: RunController, width: float) -> Control:
	var note: KeywordText = KeywordText.new()
	note.add_theme_font_size_override("normal_font_size", NOTE_SIZE)
	note.add_theme_color_override("default_color", ScreenKit.INK)
	note.custom_minimum_size = Vector2(width, 0)
	var text: String = TranslationServer.translate("market.warning")
	note.set_rule(text.format({"rise": controller.purchase_resentment()}))
	return on_paper(note)


static func rationing(controller: RunController) -> Control:
	var slots: int = controller.store_stock().size()
	var text: String = Strings.count("store.rationed", slots).format(
		{"below": controller.rationing_lifts_below()}
	)
	var note: Label = ScreenKit.label(text, NOTE_SIZE)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.add_theme_color_override("font_color", ScreenKit.RED)
	return on_paper(note)


## The note on a slip of aged paper, which keeps to its own width at the right.
static func on_paper(note: Control) -> Control:
	var slip: PanelContainer = PanelContainer.new()
	slip.add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	slip.size_flags_horizontal = Control.SIZE_SHRINK_END
	slip.add_child(note)
	return slip
