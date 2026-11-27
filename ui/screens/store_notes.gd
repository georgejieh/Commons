class_name StoreNotes
extends RefCounted
## The notes a shop prints at the right of its heading, on the same sheet as the Reforms
## in force: the black market's warning of what every purchase there costs beyond
## coupons, and the state store's note of why its counter is short while rationing holds.
## Anything else a shop says on its own goes on a slip of paper through on_paper().

## The font size of the notes a shop prints, at Standard.
const NOTE_SIZE: int = 20
## Clear of the paper's printed border, so no rule crosses a line of the note.
const PADDING: int = 22
## The warning's width at the right of the black market's heading.
const NOTE_WIDTH: float = 640.0


## The black market's note of what each purchase there costs beyond coupons, in Resentment.
static func warning(controller: RunController) -> Control:
	var note: KeywordText = KeywordText.new()
	note.add_theme_font_size_override("normal_font_size", TextSize.px(NOTE_SIZE))
	note.add_theme_color_override("default_color", ScreenKit.INK)
	note.custom_minimum_size = Vector2(NOTE_WIDTH, 0)
	var text: String = TranslationServer.translate("market.warning")
	note.set_rule(text.format({"rise": controller.figures.purchase_resentment()}))
	return note


## The state store's note, in red on one line, of why its counter is short while rationing holds.
static func rationing(controller: RunController) -> Control:
	var slots: int = controller.store.store_stock().size()
	var text: String = Strings.count("store.rationed", slots).format(
		{"below": controller.figures.rationing_lifts_below()}
	)
	var note: Label = ScreenKit.label(text, NOTE_SIZE)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.add_theme_color_override("font_color", ScreenKit.RED)
	return note


## The state store's note of the Cadres Short Supply keeps off its counter (ADR 0023).
static func short_supply(controller: RunController) -> Control:
	var text: String = Strings.count("store.short_supply", controller.store.short_supply())
	var note: Label = ScreenKit.label(text, NOTE_SIZE)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.add_theme_color_override("font_color", ScreenKit.RED)
	return note


## The note on a slip of aged paper, which keeps to its own width at the right.
static func on_paper(note: Control) -> Control:
	var slip: PanelContainer = PanelContainer.new()
	slip.add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	slip.size_flags_horizontal = Control.SIZE_SHRINK_END
	slip.add_child(note)
	return slip


## The black market's Resentment count under its name, in red: count is the label the
## screen rolls.
static func resentment_box(count: Label) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_child(ScreenKit.eyebrow(TranslationServer.translate("keyword.resentment.name")))
	count.add_theme_color_override("font_color", ScreenKit.RED)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(count)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	return box


## A rolling count's text: the nearest whole number.
static func whole(value: float) -> String:
	return str(roundi(value))


## Rolls the black market's Resentment count from shown to the run's, pulsing as it
## rises, or writes "None reported" while it is not shown as it is, with no pulse (ADR
## 0022). Returns the value the count now shows.
static func count_resentment(count: Label, shown: float, state: RunView) -> float:
	if not ShownFigures.is_true(state, RunCorrections.RESENTMENT):
		count.text = ShownFigures.none_reported()
		return shown
	UiMotion.count(count, shown, state.resentment(), whole)
	if state.resentment() > shown:
		UiMotion.pulse(count)
	return state.resentment()


## The page's eyebrow and title, the black market's or the state store's.
static func heading(market: bool) -> Control:
	var eyebrow: String = "market.eyebrow" if market else "store.eyebrow"
	var title: String = "market.title" if market else "store.title"
	return ScreenKit.header(
		TranslationServer.translate(eyebrow), TranslationServer.translate(title)
	)


## Your coupons over the household's true figures, at the foot of the heading.
static func balance(coupons: Label, books: SmallLedger) -> VBoxContainer:
	var made: VBoxContainer = VBoxContainer.new()
	made.add_child(ScreenKit.eyebrow(TranslationServer.translate("store.balance")))
	coupons.add_theme_color_override("font_color", ScreenKit.COUPON)
	coupons.autowrap_mode = TextServer.AUTOWRAP_OFF
	made.add_child(coupons)
	made.add_child(books)
	made.size_flags_vertical = Control.SIZE_SHRINK_END
	return made


## The notes at the right of the heading, over the Reforms in force on strip: the black
## market's warning, or the state store's rationing and short supply while they hold.
static func beside(controller: RunController, market: bool, strip: ReformStrip) -> VBoxContainer:
	var notes: VBoxContainer = VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.alignment = BoxContainer.ALIGNMENT_END
	notes.add_theme_constant_override("separation", 8)
	if market:
		strip.add_note(warning(controller))
	else:
		if controller.figures.is_rationed():
			strip.add_note(rationing(controller))
		if controller.store.short_supply() > 0:
			strip.add_note(short_supply(controller))
	notes.add_child(strip)
	return notes


## Coupons as a shop shows them: ample at the stage past the last (ADR 0022).
static func coupon_text(value: float) -> String:
	return ShownFigures.coupons(roundi(value), "store.coupons")


## A sheet of paper holding content near its top, padded inside its printed border.
static func sheet(content: Control, padding: int) -> PanelContainer:
	var made: PanelContainer = PanelContainer.new()
	made.add_theme_stylebox_override("panel", ScreenKit.paper_style(padding))
	made.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	made.add_child(content)
	return made
