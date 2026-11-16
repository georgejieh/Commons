class_name SurnameScreen
extends Control
## The family's name (ADR 0028), on one sheet: a field that keeps 1 to 12 Latin letters,
## the first capitalised and the rest lowered, the 24 common surnames as tickets, Random,
## which picks one of them, and Confirm. It opens with the field focused and a surname
## already in it, so one press of Confirm (or Enter) finishes it. A village family's
## surname is refused in words. On a first launch it comes after the content note and
## hands the surname to the arrival, which writes it with the profile's first save; from
## Settings it writes the profile and goes back. Keyboard, gamepad and mouse all work: a
## gamepad player can finish with the tickets, Random and Confirm alone.

const COLUMNS: int = 8
const FIELD_SIZE: int = 40
const FIELD_WIDTH: float = 420.0
const NOTE_SIZE: int = 22
const NOTE_INK: Color = Color("9e2a1d")

var _app: DemoApp
## True when the page changes a profile's surname from Settings.
var _renaming: bool = false
var _field: LineEdit = LineEdit.new()
var _note: Label
var _tickets: Array[SurnameTicket] = []
var _random: Button
var _confirm: Button
## Random picks from a seed taken when the page opens, moved on with each press.
var _seed: int = 0


func open(app: DemoApp) -> void:
	_app = app
	_renaming = not app.arrival.first_launch
	_seed = int(Time.get_ticks_usec())
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	sheet.add_child(ScreenKit.header(tr("surname.eyebrow"), tr("surname.title")))
	_field.max_length = Surnames.LONGEST
	_field.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_field.add_theme_font_size_override("font_size", FIELD_SIZE)
	_field.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_field.text_changed.connect(_on_typed)
	_field.text_submitted.connect(func(_text: String) -> void: confirm())
	sheet.add_child(_field)
	_note = ScreenKit.label("", NOTE_SIZE, NOTE_INK)
	sheet.add_child(_note)
	sheet.add_child(_ticket_grid())
	_random = ScreenKit.button(tr("surname.random"), CommonsTheme.SECONDARY)
	_random.pressed.connect(func() -> void: _put(Surnames.pick(_next_seed())))
	_confirm = ScreenKit.button(tr("surname.confirm"), CommonsTheme.PRIMARY)
	_confirm.pressed.connect(confirm)
	sheet.add_child(ScreenKit.row([_confirm, _random]))
	_wire_focus()
	var first: String = Surnames.of_profile(Saves.profile_service())
	_put(first if _renaming else Surnames.pick(_next_seed()))
	ScreenKit.reveal(sheet)
	_field.grab_focus()
	_field.caret_column = _field.text.length()


## Takes the surname in the field, or says why not.
func confirm() -> void:
	var surname: String = _field.text
	var why: String = Surnames.refusal(surname)
	_note.text = why
	if not why.is_empty():
		return
	if _renaming:
		Surnames.change(Saves.profile_service(), surname)
		_app.back()
		return
	_app.arrival.surname = surname
	_app.show_screen(_app.arrival.next_screen(), true)


## The field, the tickets and the buttons, for tests and the playtest.
func field() -> LineEdit:
	return _field


func tickets() -> Array[SurnameTicket]:
	return _tickets.duplicate()


func random_button() -> Button:
	return _random


func confirm_button() -> Button:
	return _confirm


## The line saying why a surname was refused, or "".
func note() -> String:
	return _note.text


func _ticket_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	var offered: Array[String] = Surnames.offered()
	for index: int in offered.size():
		var ticket: SurnameTicket = SurnameTicket.new(offered[index], index)
		ticket.pressed.connect(_put.bind(offered[index]))
		grid.add_child(ticket)
		_tickets.append(ticket)
	return grid


## Down from the field to the first row of tickets, and from the last row to Confirm;
## up the same way.
func _wire_focus() -> void:
	_field.focus_neighbor_bottom = _field.get_path_to(_tickets[0])
	for index: int in _tickets.size():
		var ticket: SurnameTicket = _tickets[index]
		if index < COLUMNS:
			ticket.focus_neighbor_top = ticket.get_path_to(_field)
		if index >= _tickets.size() - COLUMNS:
			ticket.focus_neighbor_bottom = ticket.get_path_to(_confirm)
	for button: Button in [_confirm, _random]:
		button.focus_neighbor_top = button.get_path_to(_tickets[_tickets.size() - COLUMNS])


## Puts a surname in the field, as typed or picked.
func _put(surname: String) -> void:
	_field.text = surname
	_field.caret_column = surname.length()
	_on_typed(surname)


## Keeps only what the field accepts, and marks the ticket it matches.
func _on_typed(typed: String) -> void:
	var kept: String = Surnames.clean(typed)
	if kept != typed:
		var caret: int = mini(_field.caret_column, kept.length())
		_field.text = kept
		_field.caret_column = caret
	_note.text = ""
	for ticket: SurnameTicket in _tickets:
		ticket.picked = ticket.surname == kept


func _next_seed() -> int:
	_seed += 1
	return _seed
