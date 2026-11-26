class_name CollectionScreen
extends Control
## The collection (ADR 0025): every Cadre, Campaign, Directive, Reform and envelope either
## shop sells, under one heading per kind, with a line at the top saying how many are
## open. An open item shows its name and rules, a Cadre its art too; a locked one is a
## blank aged sheet with only the line saying when it opens, and nothing in its text,
## tooltip or accessible name names it. The sections flow to the screen's width and
## scroll, and the scroll follows keyboard and gamepad focus from sheet to sheet. The
## whole page sits on one paper sheet, so the heading reads as the shops' do, and its
## text is ink on that paper, with no halo. A Cadre with no art yet shows the empty frame
## its picture will fill. The scroll is as wide as the whole cards that fit across, so
## its bar stands beside them, and it fades at a cut edge while more lies past it.

const ART_SIZE: Vector2 = Vector2(128, 168)
const CARD_WIDTH: float = 480.0
const RULES_WIDTH: float = 280.0
## Rules beside no art take the card's whole width, less its padding.
const WIDE_RULES: float = 420.0
const LOCKED_HEIGHT: float = 150.0
const SHEET_PADDING: int = 28
const GAP: int = 20
## The room kept between the last card and the scroll's bar.
const BAR_ROOM: int = 24
## The open line and a sheet's rules, at Standard.
const LINE_SIZE: int = 22
const RULE_SIZE: int = 20

var _entries: Array[Control] = []
var _scroll: ScrollContainer = ScrollContainer.new()
var _open_line: Label

var _app: DemoApp


func open(app: DemoApp) -> void:
	_app = app
	var view: CollectionView = CollectionView.of(Saves.profile_service())
	var page: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	var sheet: PanelContainer = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.theme = ScreenKit.ink_theme()
	page.add_child(sheet)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ScreenKit.STYLE.gap)
	sheet.add_child(column)
	column.add_child(ScreenKit.header(tr("coll.eyebrow"), tr("coll.title")))
	_open_line = ScreenKit.label(view.open_line(), LINE_SIZE)
	column.add_child(_open_line)
	var sections: VBoxContainer = VBoxContainer.new()
	sections.add_theme_constant_override("separation", 18)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var keys: Array[String] = view.section_keys()
	for section: int in keys.size():
		sections.add_child(_heading(tr(keys[section])))
		sections.add_child(_flow(view.sheets(section)))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.add_child(sections)
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ScrollFade.over(_scroll)
	column.add_child(_scroll)
	column.resized.connect(_fit_width.bind(column))
	var back: Button = ScreenKit.button(tr("coll.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()


## Cancel (Escape, or B on a pad) goes back, as Back does.
func _unhandled_input(event: InputEvent) -> void:
	if ScreenKit.take_cancel(self, event):
		_app.back()


## The scroll takes the width of as many whole cards as fit across the sheet, and the
## bar's room beside them.
func _fit_width(column: VBoxContainer) -> void:
	var bar: float = _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var room: float = column.size.x - bar - BAR_ROOM
	var across: int = maxi(1, floori((room + GAP) / (CARD_WIDTH + GAP)))
	var wide: float = across * CARD_WIDTH + (across - 1) * GAP + BAR_ROOM + bar
	if absf(_scroll.custom_minimum_size.x - wide) > 0.5:
		_scroll.custom_minimum_size.x = wide


## Every sheet in order, section by section, open and locked, for tests.
func entries() -> Array[Control]:
	return _entries.duplicate()


func scroll() -> ScrollContainer:
	return _scroll


## The line saying how many are open.
func open_line() -> String:
	return _open_line.text


func _heading(text: String) -> Label:
	return ScreenKit.styled(text, CommonsTheme.TITLE)


func _flow(sheets: Array[UnlockSheet]) -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", GAP)
	flow.add_theme_constant_override("v_separation", GAP)
	for sheet: UnlockSheet in sheets:
		var entry: Control = _entry(sheet) if sheet.open else _blank(sheet)
		flow.add_child(entry)
		_entries.append(entry)
	return flow


## A locked item: a blank sheet that takes focus and says only when it opens.
func _blank(sheet: UnlockSheet) -> Control:
	var size_wanted: Vector2 = Vector2(CARD_WIDTH, LOCKED_HEIGHT)
	return AgedSheet.blank(sheet.locked_line, size_wanted, _entries.size())


## One open item's card. It takes focus, so the arrows and the d-pad walk the sheets and
## the scroll follows; a faded gold ring shows where focus is.
func _entry(sheet: UnlockSheet) -> Control:
	var card: VBoxContainer = ScreenKit.card(Vector2(CARD_WIDTH, 0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var width: float = WIDE_RULES
	if not sheet.art_id.is_empty():
		row.add_child(_art(sheet.art_id))
		width = RULES_WIDTH
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name: Label = ScreenKit.styled("", CommonsTheme.TITLE)
	name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	name.custom_minimum_size = Vector2(width, 0)
	var title_size: int = TextSize.px(ScreenKit.STYLE.title_size)
	NameFit.apply(name, sheet.name, width, title_size, TextSize.least(NameFit.LEAST))
	words.add_child(name)
	var rules: Label = ScreenKit.label(sheet.text, RULE_SIZE)
	rules.custom_minimum_size = Vector2(width, 0)
	words.add_child(rules)
	row.add_child(words)
	card.add_child(row)
	var panel: Control = ScreenKit.card_panel(card)
	panel.focus_mode = Control.FOCUS_ALL
	panel.tooltip_text = Keywords.wrapped("%s\n%s" % [sheet.name, sheet.text])
	panel.accessibility_name = sheet.name
	panel.accessibility_description = sheet.text
	var ring: ReferenceRect = ReferenceRect.new()
	ring.editor_only = false
	ring.border_color = Color(BowlGrime.aged(ScreenKit.FOCUS_RING, BowlGrime.wear() * 0.5), 0.9)
	ring.border_width = 3.0
	ring.visible = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ring)
	panel.focus_entered.connect(ring.set_visible.bind(true))
	panel.focus_exited.connect(ring.set_visible.bind(false))
	UiMotion.hoverable(panel)
	return panel


## The Cadre's art, or the printed frame it will fill while it has none.
func _art(cadre_id: String) -> Control:
	if not ScreenKit.ART.has_cadre(cadre_id):
		return ArtFrame.new(ART_SIZE)
	var art: TextureRect = TextureRect.new()
	art.texture = ScreenKit.cadre_art(cadre_id)
	art.custom_minimum_size = ART_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return art
