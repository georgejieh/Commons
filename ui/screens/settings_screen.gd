class_name SettingsScreen
extends Control
## Volumes, motion and the print pass on one sheet, and beside it the card back designs
## (ADR 0025), and under them the family's name with a way to change it between runs
## (ADR 0028). The two sheets stand as tall as each other, the name at the foot of its
## sheet. Changes apply at once and save on the way back. A new text size (ADR 0034)
## builds the screen again at once, with the focus on the size chosen. Controls opens the
## key bindings (ADR 0035) and Window the window's mode and size (WindowSheet), each as a
## screen of its own. Replay the arrival is on the title.

## The family name, and why it cannot change now, at Standard.
const NAME_SIZE: int = 30
const NOTE_SIZE: int = 20

## The family name, beside its Change button.
var family_line: Label
var _app: App = null
var _card_backs: CardBackRow
var _change: Button = null
var _sheets: HBoxContainer
var _scroll: ScrollContainer


func open(app: App) -> void:
	if _app == null:
		Settings.changed.connect(_on_setting)
	_app = app
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("settings.eyebrow"), tr("settings.title")))
	var backs: VBoxContainer = ScreenKit.card(Vector2(0, 0))
	_card_backs = CardBackRow.new(CardBacks.profile_runs())
	backs.add_child(_card_backs)
	# The shorter sheet is as tall as the taller, and what room that leaves on this one
	# lies between the card backs and the name, which stands at the sheet's foot.
	var room: Control = Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backs.add_child(room)
	backs.add_child(_family_name(app))
	var panel: Control = SettingsPanel.build(false)
	var sheet_row: HBoxContainer = ScreenKit.row([panel, ScreenKit.card_panel(backs)])
	sheet_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_sheets = sheet_row
	# The sheets are laid out to stand whole on the page at every text size; should they
	# ever stand taller, they scroll, follow the focus and fade at the cut, so Back and
	# the header stay on screen and the cut reads as more (ADR 0034).
	var scroller: ScrollContainer = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.follow_focus = true
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# As wide as the sheets, so its bar stands against them, not at the page's edge.
	scroller.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scroller.add_child(sheet_row)
	ScrollFade.over(scroller)
	_scroll = scroller
	column.add_child(scroller)
	var back: Button = ScreenKit.button(tr("settings.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(_leave)
	# The pages' tickets stand here with Back, where they are always whole.
	var row: Array[Control] = [back]
	row.append_array(SettingsPanel.pages(_open.bind("controls"), _open.bind("window")))
	column.add_child(ScreenKit.row(row))
	ScreenKit.reveal(column)
	back.grab_focus()


## Cancel (Escape, or B on a pad) goes back, as Back does.
func _unhandled_input(event: InputEvent) -> void:
	if ScreenKit.take_cancel(self, event):
		_leave()


## Back saves what changed and returns to the page before.
func _leave() -> void:
	Settings.save()
	_app.back()


func _open(screen_id: String) -> void:
	Settings.save()
	_app.show_screen(screen_id)


## A settings page no longer on screen does not build itself again.
func _on_setting(key: String) -> void:
	if key == TextSize.SETTING and is_inside_tree():
		_rebuild.call_deferred()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	ScreenKit.clear_page(self)
	_change = null
	open(_app)
	SettingsPanel.chosen_text_size(self).grab_focus()


## The two sheets, left to right, for tests.
func sheets() -> Array[Control]:
	var made: Array[Control] = []
	for sheet: Node in _sheets.get_children():
		made.append(sheet as Control)
	return made


## The scroll the sheets stand in, for tests.
func scroll() -> ScrollContainer:
	return _scroll


## The card back row, for tests.
func card_backs() -> CardBackRow:
	return _card_backs


## The family name's Change button, or null while a run stops it, and the line shown.
func change_button() -> Button:
	return _change


func name_line() -> String:
	return family_line.text


## The surname, then Change, or while a run is saved or the arrival plays, why not.
func _family_name(app: App) -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_child(ScreenKit.eyebrow(tr("settings.family_name")))
	family_line = ScreenKit.label(Surnames.of_profile(Saves.profile_service()), NAME_SIZE)
	# One line: a wrapping label beside a button is given a letter's width.
	family_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	var running: bool = app.has_saved_run() or app.arrival.is_running()
	if running:
		block.add_child(family_line)
		block.add_child(ScreenKit.label(tr("settings.name_locked"), NOTE_SIZE))
		return block
	_change = ScreenKit.button(tr("settings.change_name"), CommonsTheme.SECONDARY)
	_change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_change.pressed.connect(
		func() -> void:
			Settings.save()
			app.show_screen("surname")
	)
	block.add_child(ScreenKit.row([family_line, _change]))
	return block
