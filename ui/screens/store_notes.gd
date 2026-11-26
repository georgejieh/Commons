class_name StoreNotes
extends RefCounted
## The notes a shop prints at the right of its heading, on the same sheet as the Reforms
## in force: the black market's warning of what every purchase there costs beyond
## coupons, and the state store's note of why its counter is short while rationing holds.
## Anything else a shop says on its own goes on a slip of paper through on_paper().

const NOTE_SIZE: int = 20
## Clear of the paper's printed border, so no rule crosses a line of the note.
const PADDING: int = 22


static func warning(controller: RunController, width: float) -> Control:
	var note: KeywordText = KeywordText.new()
	note.add_theme_font_size_override("normal_font_size", TextSize.px(NOTE_SIZE))
	note.add_theme_color_override("default_color", ScreenKit.INK)
	note.custom_minimum_size = Vector2(width, 0)
	var text: String = TranslationServer.translate("market.warning")
	note.set_rule(text.format({"rise": controller.figures.purchase_resentment()}))
	return note


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
static func count_resentment(count: Label, shown: float, state: RunState) -> float:
	if not ShownFigures.is_true(state, RunCorrections.RESENTMENT):
		count.text = ShownFigures.none_reported()
		return shown
	UiMotion.count(count, shown, state.resentment, whole)
	if state.resentment > shown:
		UiMotion.pulse(count)
	return state.resentment
