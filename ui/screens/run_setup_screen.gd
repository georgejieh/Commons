class_name RunSetupScreen
extends Control
## Run setup (ADR 0025). For a full run, on one sheet of aged paper: the generation this
## run will be, what the last generation left, the households as papers to pick (a locked
## one is a blank sheet saying when it opens), the unlocked stakes as tickets to pick with
## the rules the chosen one plays under (its own and every lower stake's), then Start and
## Back. It opens on Poor Peasants and the highest unlocked stake every time. Keyboard and
## gamepad reach everything, and the sheet scrolls with focus where the screen is short.
## With --demo it keeps its simple form and starts the demo.

const PAGE_MARGIN: int = 40
const SHEET_PADDING: int = 26
const PAPER_MIN: Vector2 = Vector2(220, 210)
const NAME_SIZE: int = 26
const RULES_SIZE: int = 20
const LINE_SIZE: int = 22

var _app: DemoApp
var _view: SetupView
var _household: String = ""
var _stake: int = 0
var _papers: Array[AgedSheet] = []
var _tickets: Array[StakeTicket] = []
## Made only for a full run's page, so the demo's leaves nothing outside the tree.
var _rules: Label
var _scroll: ScrollContainer
var _start: Button
var _back: Button


func open(app: DemoApp) -> void:
	_app = app
	if app.demo:
		_open_demo(app)
		return
	_view = SetupView.of(Saves.profile_service())
	_household = _view.default_household()
	_stake = _view.top_stake
	_rules = ScreenKit.label("", RULES_SIZE)
	_scroll = ScrollContainer.new()
	var page: VBoxContainer = _page()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ScreenKit.STYLE.gap + 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var generation: String = tr("setup.generation").format({"number": _view.generation})
	column.add_child(ScreenKit.header(tr("setup.eyebrow"), generation))
	if not _view.inherited.is_empty():
		column.add_child(ScreenKit.label(_view.inherited, LINE_SIZE))
	column.add_child(_heading(tr("setup.household")))
	column.add_child(_household_row())
	column.add_child(_heading(tr("setup.stake")))
	column.add_child(_stake_row())
	column.add_child(_rules)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.add_child(column)
	page.add_child(_scroll)
	_start = ScreenKit.button(tr("setup.start"), CommonsTheme.PRIMARY)
	_start.pressed.connect(_begin)
	_back = ScreenKit.button(tr("setup.back"), CommonsTheme.GHOST)
	_back.pressed.connect(app.back)
	page.add_child(ScreenKit.row([_start, _back]))
	_wire_focus()
	_show_choice()
	ScreenKit.reveal(page)
	_start.grab_focus()


## The household papers and stake tickets in order, and the chosen ones, for tests and
## the playtest.
func papers() -> Array[AgedSheet]:
	return _papers.duplicate()


func tickets() -> Array[StakeTicket]:
	return _tickets.duplicate()


func household() -> String:
	return _household


func stake() -> int:
	return _stake


func rules_text() -> String:
	return _rules.text


func scroll() -> ScrollContainer:
	return _scroll


func start_button() -> Button:
	return _start


func _page() -> VBoxContainer:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ScreenKit.cover(ScreenKit.ART.title_night))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAGE_MARGIN)
	add_child(margin)
	var sheet: PanelContainer = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING))
	margin.add_child(sheet)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", ScreenKit.STYLE.gap)
	sheet.add_child(page)
	return page


func _heading(text: String) -> Label:
	var heading: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	ScreenKit.paper_outline(heading)
	return heading


func _household_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for sheet: UnlockSheet in _view.households:
		var paper: AgedSheet = _household_paper(sheet)
		paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(paper)
		_papers.append(paper)
	return row


## An open household's paper, picked with a click or accept, or a locked one's blank.
func _household_paper(sheet: UnlockSheet) -> AgedSheet:
	if not sheet.open:
		return AgedSheet.blank(sheet.locked_line, PAPER_MIN, sheet.index)
	var paper: AgedSheet = AgedSheet.new(PAPER_MIN.x, sheet.index)
	paper.custom_minimum_size = PAPER_MIN
	paper.choosable = true
	paper.accessibility_name = sheet.name
	paper.accessibility_description = sheet.text
	var name: Label = ScreenKit.label(sheet.name, NAME_SIZE)
	name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	paper.column().add_child(name)
	paper.column().add_child(ScreenKit.label(sheet.text, RULES_SIZE))
	paper.chosen.connect(_pick_household.bind(sheet.id))
	return paper


func _stake_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for sheet: UnlockSheet in _view.stakes:
		var words: String = sheet.name if sheet.open else sheet.locked_line
		var ticket: StakeTicket = StakeTicket.new(sheet.index, sheet.open, words)
		if sheet.open:
			ticket.pressed.connect(_pick_stake.bind(sheet.index))
		row.add_child(ticket)
		_tickets.append(ticket)
	return row


## Down from the papers to the tickets, then to Start; up the same way.
func _wire_focus() -> void:
	for paper: AgedSheet in _papers:
		paper.focus_neighbor_bottom = paper.get_path_to(_tickets[0])
	for ticket: StakeTicket in _tickets:
		ticket.focus_neighbor_top = ticket.get_path_to(_papers[0])
		ticket.focus_neighbor_bottom = ticket.get_path_to(_start)


func _pick_household(household_id: String) -> void:
	_household = household_id
	_show_choice()


func _pick_stake(stake_number: int) -> void:
	_stake = stake_number
	_show_choice()


func _show_choice() -> void:
	for index: int in _papers.size():
		_papers[index].selected = _view.households[index].id == _household
	for ticket: StakeTicket in _tickets:
		ticket.picked = ticket.stake == _stake
	# Up from Start and Back lands on the stake picked.
	for button: Button in [_start, _back]:
		button.focus_neighbor_top = button.get_path_to(_tickets[_stake])
	_rules.text = "\n".join(_view.stake_rules(_stake))


func _begin() -> void:
	if _app.new_run(int(Time.get_unix_time_from_system()), true, _household, _stake):
		_app.show_screen("set_intro", true)


## The demo's page: one ticket for the base stake, and Start begins the demo.
func _open_demo(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	sheet.add_child(ScreenKit.header(tr("setup.eyebrow"), tr("setup.title")))
	var base: Button = ScreenKit.button(tr("setup.stake_base"), CommonsTheme.SECONDARY)
	base.toggle_mode = true
	base.button_pressed = true
	sheet.add_child(base)
	sheet.add_child(ScreenKit.label(tr("setup.stake_base_text"), 22))
	sheet.add_child(ScreenKit.styled(tr("setup.locked"), CommonsTheme.CAPTION))
	_start = ScreenKit.button(tr("setup.start"), CommonsTheme.PRIMARY)
	_start.pressed.connect(
		func() -> void:
			app.new_run(int(Time.get_unix_time_from_system()))
			app.show_screen("set_intro", true)
	)
	_back = ScreenKit.button(tr("setup.back"), CommonsTheme.GHOST)
	_back.pressed.connect(app.back)
	sheet.add_child(ScreenKit.row([_start, _back]))
	ScreenKit.reveal(sheet)
	_start.grab_focus()
