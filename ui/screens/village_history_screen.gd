class_name VillageHistoryScreen
extends Control
## Village history (P3B.9, ADR 0025): what each Quota of this run left behind, per
## villager, then the family's past generations from the profile, newest first, one plain
## line each on a sheet of aged paper. The page scrolls, and the scroll follows keyboard
## and gamepad focus from sheet to sheet.

const LINE_SIZE: int = 22
const RECORD_SIZE: int = 20
const RECORD_INK: Color = Color("2a2118")

var _scroll: ScrollContainer = ScrollContainer.new()
var _records: Array[AgedSheet] = []
var _back: Button


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	column.add_child(ScreenKit.header(tr("hist.eyebrow"), tr("hist.title"), ScreenKit.GOLD))
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines: PackedStringArray = history_lines(app)
	if lines.is_empty():
		lines.append(tr("hist.empty"))
	for text: String in lines:
		body.add_child(ScreenKit.label(text, LINE_SIZE, ScreenKit.STYLE.paper))
	body.add_child(_heading(tr("hist.past")))
	var past: PackedStringArray = HistoryView.generations(Saves.profile_service())
	if past.is_empty():
		past.append(tr("hist.no_generations"))
	for text: String in past:
		body.add_child(_record(text))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.add_child(body)
	column.add_child(_scroll)
	_back = ScreenKit.button(tr("hist.back"), CommonsTheme.PRIMARY)
	_back.pressed.connect(app.back)
	column.add_child(_back)
	ScreenKit.reveal(column)
	_back.grab_focus()


## The past generations' sheets, newest first, for tests.
func records() -> Array[AgedSheet]:
	return _records.duplicate()


func scroll() -> ScrollContainer:
	return _scroll


func back_button() -> Button:
	return _back


func _heading(text: String) -> Label:
	var heading: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	heading.add_theme_color_override("font_color", ScreenKit.GOLD)
	return heading


## One generation's line on its own aged sheet, which takes focus so the page scrolls.
func _record(text: String) -> AgedSheet:
	var sheet: AgedSheet = AgedSheet.new(0.0, _records.size())
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.accessibility_name = text
	var line: Label = ScreenKit.label(text, RECORD_SIZE, RECORD_INK)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.column().add_child(line)
	_records.append(sheet)
	return sheet


## One heading per Quota, then one line per villager it touched.
static func history_lines(app: DemoApp) -> PackedStringArray:
	var lines: PackedStringArray = []
	if not app.controller.has_run():
		return lines
	var state: RunState = app.controller.state_copy()
	for summary: SetSummary in state.summaries:
		if summary.counts.is_empty():
			continue
		var heading: String = TranslationServer.translate("hist.set")
		lines.append(heading.format({"number": summary.set_number + 1}))
		for family: String in summary.counts:
			lines.append(_row(app, state, summary, family))
	return lines


static func _row(app: DemoApp, state: RunState, summary: SetSummary, family: String) -> String:
	var seat: int = state.table.find(family)
	var fields: Dictionary = {
		"name": app.seat_name(seat) if seat > 0 else family,
		"fed": summary.count(family, SetSummary.Kind.FED),
		"bombed": summary.count(family, SetSummary.Kind.BOMBED),
		"denounced": summary.count(family, SetSummary.Kind.DENOUNCED),
		"betrayed": summary.count(family, SetSummary.Kind.BETRAYED),
	}
	return TranslationServer.translate("hist.row").format(fields)
