class_name RunSetupScreen
extends Control
## Run setup (ADR 0025). For a full run, on one sheet of aged paper: the player's name
## and the generation this run will be (ADR 0028), what the last generation left, the
## households as papers to pick (a locked one is a blank sheet saying when it opens), the
## stakes as tickets to pick with the rules the chosen one plays under (its own and every
## lower stake's), a locked one saying how it opens, then Start and Back. The stake row
## stands as wide as the household row. It opens on Poor Peasants and the highest
## unlocked stake every time. Keyboard and gamepad reach everything, and the sheet
## scrolls with focus and fades at the cut where the screen is short. Where the page has
## room to spare, the household papers stand taller into most of it, and the rules,
## beside the stake heading, keep room for the longest any open stake plays under, so
## picking a stake moves nothing.
## With --demo it keeps its simple form and starts the demo.

const PAGE_MARGIN: int = 40
const SHEET_PADDING: int = 26
const PAPER_MIN: Vector2 = Vector2(220, 210)
const NAME_SIZE: int = 26
const RULES_SIZE: int = 20
const LINE_SIZE: int = 22
## Where the page has room to spare, the household papers stand this many times as tall
## as the room left under the rules.
const PAPERS_SHARE: float = 6.0
## The gap between the page's rows at each text size: closer at the larger sizes, so the
## stake row stands whole on the page at every size.
const ROW_GAPS: Array[int] = [20, 14, 10]
## The least width the rules beside the stake heading take, so they wrap as lines and
## not as a column of words.
const RULES_WIDTH: float = 960.0

var _app: DemoApp
var _view: SetupView
var _household: String = ""
var _stake: int = 0
## Chosen as the page opens, so the name it shows is the one the run started with Start
## will use.
var _seed: int = 0
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
	_seed = int(Time.get_unix_time_from_system())
	_view = SetupView.of(Saves.profile_service(), _seed)
	_household = _view.default_household()
	_stake = _view.top_stake
	_rules = ScreenKit.label("", RULES_SIZE)
	_scroll = ScrollContainer.new()
	var page: VBoxContainer = _page()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAPS[TextSize.level()])
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var values: Dictionary[String, Variant] = {
		"name": _view.player_name, "number": _view.generation
	}
	column.add_child(ScreenKit.header(tr("setup.eyebrow"), tr("setup.named").format(values)))
	if not _view.inherited.is_empty():
		column.add_child(ScreenKit.label(_view.inherited, LINE_SIZE))
	column.add_child(_heading(tr("setup.household")))
	var households: HBoxContainer = _household_row()
	households.size_flags_vertical = Control.SIZE_EXPAND_FILL
	households.size_flags_stretch_ratio = PAPERS_SHARE
	column.add_child(households)
	# The rules the picked stake plays under stand beside its heading, above the tickets,
	# so the stake row and its rules stand whole together at every text size.
	var stake_heading: HBoxContainer = ScreenKit.row([_heading(tr("setup.stake")), _rules], 28)
	_rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rules.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(stake_heading)
	column.add_child(_stake_row())
	var foot: Control = Control.new()
	foot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.add_child(column)
	ScrollFade.over(_scroll)
	page.add_child(_scroll)
	_reserve_rules()
	_start = ScreenKit.button(tr("setup.start"), CommonsTheme.PRIMARY)
	_start.pressed.connect(_begin)
	_back = ScreenKit.button(tr("setup.back"), CommonsTheme.GHOST)
	_back.pressed.connect(app.back)
	page.add_child(ScreenKit.row([_start, _back]))
	_wire_focus()
	_show_choice()
	ScreenKit.reveal(page)
	_start.grab_focus()


## Cancel (Escape, or B on a pad) goes back, as Back does.
func _unhandled_input(event: InputEvent) -> void:
	if ScreenKit.take_cancel(self, event):
		_app.back()


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


## The seed Start will begin the run with, and the name the page gives the player.
func run_seed() -> int:
	return _seed


func player_name() -> String:
	return _view.player_name if _view != null else ""


func _page() -> VBoxContainer:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ScreenKit.cover(ScreenKit.ART.title_night))
	var margin: MarginContainer = ScreenKit.margins(PAGE_MARGIN, PAGE_MARGIN)
	add_child(margin)
	var sheet: PanelContainer = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING))
	margin.add_child(sheet)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", ScreenKit.STYLE.gap)
	sheet.add_child(page)
	return page


## Keeps room under the tickets for the most lines of rules an open stake plays under.
func _reserve_rules() -> void:
	var most: int = 1
	for sheet: UnlockSheet in _view.stakes:
		if sheet.open:
			most = maxi(most, _view.stake_rules(sheet.index).size())
	var between: int = _rules.get_theme_constant("line_spacing")
	var tall: float = most * _rules.get_line_height() + (most - 1) * between
	_rules.custom_minimum_size = Vector2(RULES_WIDTH, tall)


func _heading(text: String) -> Label:
	var heading: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	row.add_theme_constant_override("separation", 14)
	for sheet: UnlockSheet in _view.stakes:
		var words: String = sheet.name if sheet.open else sheet.locked_line
		# Past the next stake the view names none, so as not to name a stake not yet
		# reached: each of those opens with a win at the one before it.
		if words.is_empty():
			words = tr("unlock.win_before")
		var ticket: StakeTicket = StakeTicket.new(sheet.index, sheet.open, words)
		ticket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if _app.new_run(_seed, true, _household, _stake):
		_app.show_screen("set_intro", true)


## The demo's page: one ticket for the base stake, and Start begins the demo.
func _open_demo(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	sheet.add_child(ScreenKit.header(tr("setup.eyebrow"), tr("setup.title")))
	var base: Button = ScreenKit.button(tr("setup.stake_base"), CommonsTheme.SECONDARY)
	base.toggle_mode = true
	base.button_pressed = true
	sheet.add_child(base)
	sheet.add_child(ScreenKit.label(tr("setup.stake_base_text"), LINE_SIZE))
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
