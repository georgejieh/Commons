class_name VillageHistoryScreen
extends Control
## Village history (ADR 0025): what each Quota of the run in progress left
## behind, one plain line per family it touched, then the family's past generations from
## the profile, newest first, one line each on a sheet of aged paper. The whole page sits
## on one paper sheet across the page, as the collection does, in dark ink with no halo
## and a red heading. The scroll sits inside the sheet and follows keyboard and gamepad
## focus from sheet to sheet. With no run in progress there is no "This run" section.
## While the family's file holds an entry its page follows, as the state keeps it: one
## line an entry, oldest first, and that the file is kept (ADR 0022).

const LINE_SIZE: int = 22
const RECORD_SIZE: int = 20
const RECORD_INK: Color = Color("2a2118")
const SHEET_PADDING: int = 28
## The file's sheet keeps stains of its own, apart from the generations' sheets.
const FILE_SHEET: int = 97

var _scroll: ScrollContainer = ScrollContainer.new()
var _sheet: PanelContainer = PanelContainer.new()
var _records: Array[AgedSheet] = []
var _run_lines: Array[Label] = []
var _file_lines: Array[Label] = []
var _back: Button

var _app: App


func open(app: App) -> void:
	_app = app
	var page: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	_sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING))
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Text on the paper is ink, so the backdrop's paper halo is taken off it.
	_sheet.theme = ScreenKit.ink_theme()
	page.add_child(_sheet)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ScreenKit.STYLE.gap)
	_sheet.add_child(column)
	column.add_child(ScreenKit.header("", tr("hist.eyebrow")))
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if app.controller.has_run():
		body.add_child(_heading(tr("hist.title")))
		var lines: PackedStringArray = history_lines(app)
		if lines.is_empty():
			lines.append(tr("hist.empty"))
		for text: String in lines:
			var line: Label = ScreenKit.label(text, LINE_SIZE, ScreenKit.INK)
			body.add_child(line)
			_run_lines.append(line)
	body.add_child(_heading(tr("hist.past")))
	var past: PackedStringArray = HistoryView.generations(Saves.profile_service())
	if past.is_empty():
		past.append(tr("hist.no_generations"))
	for text: String in past:
		body.add_child(_record(text))
	var filed: PackedStringArray = HistoryView.file_lines(Saves.profile_service())
	if not filed.is_empty():
		body.add_child(_heading(tr("hist.file")))
		body.add_child(_file_page(filed))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.add_child(body)
	column.add_child(_scroll)
	_back = ScreenKit.button(tr("hist.back"), CommonsTheme.PRIMARY)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(app.back)
	column.add_child(_back)
	ScreenKit.reveal(column)
	_back.grab_focus()


## Cancel (Escape, or B on a pad) goes back, as Back does.
func _unhandled_input(event: InputEvent) -> void:
	if ScreenKit.take_cancel(self, event):
		_app.back()


## The past generations' sheets, newest first, for tests.
func records() -> Array[AgedSheet]:
	return _records.duplicate()


## The run in progress's lines, empty when there is no run, for tests.
func run_lines() -> PackedStringArray:
	var texts: PackedStringArray = []
	for line: Label in _run_lines:
		texts.append(line.text)
	return texts


## The family's file's page, its kept line last, empty while the file is. For tests.
func file_lines() -> PackedStringArray:
	var texts: PackedStringArray = []
	for line: Label in _file_lines:
		texts.append(line.text)
	return texts


func scroll() -> ScrollContainer:
	return _scroll


## The paper sheet everything on the page sits on.
func sheet() -> PanelContainer:
	return _sheet


func back_button() -> Button:
	return _back


func _heading(text: String) -> Label:
	var heading: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	heading.add_theme_color_override("font_color", ScreenKit.RED)
	return heading


## One generation's line on its own aged sheet, which takes focus so the page scrolls.
func _record(text: String) -> AgedSheet:
	var record: AgedSheet = AgedSheet.new(0.0, _records.size())
	record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record.accessibility_name = text
	var line: Label = ScreenKit.label(text, RECORD_SIZE, RECORD_INK)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record.column().add_child(line)
	_records.append(record)
	return record


## The family's file on one aged sheet, which takes focus so the page scrolls to it: a
## line an entry, then that the file is kept.
func _file_page(entries: PackedStringArray) -> AgedSheet:
	var page: AgedSheet = AgedSheet.new(0.0, FILE_SHEET)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.append(tr("hist.file.kept"))
	page.accessibility_name = " ".join(entries)
	for text: String in entries:
		var line: Label = ScreenKit.label(text, RECORD_SIZE, RECORD_INK)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.column().add_child(line)
		_file_lines.append(line)
	return page


## The run's Quotas as a record, one line per family each Quota touched.
static func history_lines(app: App) -> PackedStringArray:
	if not app.controller.has_run():
		return PackedStringArray()
	var table: Array[String] = app.controller.run.table()
	var name_of: Callable = func(family: String) -> String:
		var seat: int = table.find(family)
		if seat > 0:
			return app.seat_name(seat)
		var key: String = app.controller.seats.family_name_key(family)
		if key.is_empty():
			return family
		return TranslationServer.translate(key)
	return app.controller.seats.history_lines(name_of)
