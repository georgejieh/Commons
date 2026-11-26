class_name PauseMenu
extends Control
## The in-game menu, opened with the Menu button or Escape: resume, change settings, go
## back to the title, abandon the run, or quit. The run saves after every move, so leaving
## loses nothing; Continue on the title picks up at the same moment. Abandoning asks
## first, with the focus on keeping the run, and clears its save (ADR 0025). A new text
## size (ADR 0034) shows on the menu at once, and the screen under it is built again when
## the menu closes. The settings page opens the Controls page (ADR 0035) and the Window
## page (WindowSheet), whose Back and Escape come back to the settings.

signal resumed
## The player chose to go back to the title.
signal title_chosen
## The player chose to quit the game.
signal quit_chosen
## The player chose to read the dossier.
signal dossier_chosen
## The player chose to see the last round's summary.
signal last_round_chosen
## The player confirmed abandoning the run.
signal abandoned
## At the table, the player asked for the deck sheet (ADR 0041).
signal deck_chosen

const DIM: Color = Color(0.05, 0.03, 0.02, 0.78)

## The table's own menu: its settings sheet says a new text size reaches the table at
## the next deal (ADR 0034). Set before the menu enters the tree.
var at_table: bool = false
var _app: DemoApp = null
var _stack: VBoxContainer = VBoxContainer.new()
## The text size the pages were built at, and the one the menu opened at.
var _built_size: int = -1
var _opened_size: int = -1
var _main: VBoxContainer
var _settings: VBoxContainer
var _confirm: VBoxContainer
var _controls: ControlsPage
var _window: VBoxContainer
var _resume: Button
var _keep: Button
var _abandon: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(_stack)
	_build_pages()
	visible = false
	Settings.changed.connect(_on_setting)


## Builds the five pages at the text size chosen now.
func _build_pages() -> void:
	for page: Node in _stack.get_children():
		_stack.remove_child(page)
		page.queue_free()
	_built_size = TextSize.level()
	_main = _menu()
	_settings = _settings_page()
	_confirm = _confirm_page()
	_controls = ControlsPage.new(true)
	_controls.left.connect(_back_to_settings.bind(SettingsPanel.controls_button(_settings)))
	_window = _window_page()
	_stack.add_child(_main)
	_stack.add_child(_settings)
	_stack.add_child(_confirm)
	_stack.add_child(_controls)
	_stack.add_child(_window)


## A new text size rebuilds the pages at once, still on the settings page, with the focus
## on the size just chosen.
func _on_setting(key: String) -> void:
	if key == TextSize.SETTING and visible:
		_rebuild_on_settings.call_deferred()


func _rebuild_on_settings() -> void:
	if _built_size == TextSize.level():
		return
	_build_pages()
	_show_page(_settings)
	SettingsPanel.chosen_text_size(_settings).grab_focus()


## Sends the menu's ways out to the app's screens.
func wire(app: DemoApp) -> void:
	_app = app
	title_chosen.connect(func() -> void: app.show_screen("title", true))
	quit_chosen.connect(func() -> void: app.get_tree().quit())
	dossier_chosen.connect(func() -> void: app.show_screen("dossier"))
	last_round_chosen.connect(func() -> void: app.show_screen("round_summary"))
	abandoned.connect(app.leave_run)


func open() -> void:
	if _built_size != TextSize.level():
		_build_pages()
	_opened_size = TextSize.level()
	visible = true
	move_to_front()
	_show_page(_main)


func close() -> void:
	Settings.save()
	visible = false
	resumed.emit()
	if _app != null and _opened_size != TextSize.level():
		_opened_size = TextSize.level()
		SettingsPanel.rebuild_screen(_app)


func _menu() -> VBoxContainer:
	var sheet: VBoxContainer = SheetPad.column(ScreenKit.card(Vector2(460, 0)))
	sheet.add_theme_constant_override("separation", 14)
	sheet.add_child(ScreenKit.header(tr("pause.eyebrow"), tr("pause.title"), ScreenKit.INK))
	_resume = _wide(tr("pause.resume"), CommonsTheme.PRIMARY, close)
	sheet.add_child(_resume)
	if at_table:
		sheet.add_child(_wide(tr("deck.open"), CommonsTheme.SECONDARY, _leave.bind(deck_chosen)))
	sheet.add_child(_wide(tr("dossier.open"), CommonsTheme.SECONDARY, _leave.bind(dossier_chosen)))
	sheet.add_child(
		_wide(tr("pause.last_round"), CommonsTheme.SECONDARY, _leave.bind(last_round_chosen))
	)
	var settings: Callable = func() -> void: _show_page(_settings)
	sheet.add_child(_wide(tr("pause.settings"), CommonsTheme.SECONDARY, settings))
	sheet.add_child(_wide(tr("pause.to_title"), CommonsTheme.GHOST, _leave.bind(title_chosen)))
	var ask: Callable = func() -> void: _show_page(_confirm)
	sheet.add_child(_wide(tr("menu.abandon"), CommonsTheme.GHOST, ask))
	sheet.add_child(_wide(tr("pause.quit"), CommonsTheme.GHOST, _leave.bind(quit_chosen)))
	sheet.add_child(ScreenKit.styled(tr("pause.saved"), CommonsTheme.CAPTION))
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(ScreenKit.card_panel(sheet))
	return wrapper


func _settings_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	var controls: Callable = func() -> void: _show_page(_controls)
	var window: Callable = func() -> void: _show_page(_window)
	page.add_child(SettingsPanel.build(at_table, controls, window))
	var back: Callable = func() -> void: _show_page(_main)
	page.add_child(_wide(tr("settings.back"), CommonsTheme.PRIMARY, back))
	return page


func _window_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	page.add_child(WindowSheet.build())
	var back: Callable = _back_to_settings.bind(SettingsPanel.window_button(_settings))
	page.add_child(_wide(tr("settings.back"), CommonsTheme.PRIMARY, back))
	return page


## Asks before abandoning the run, under a title of its own, on the menu's padding. Keep
## playing has the focus, so a stray press of accept keeps the run.
func _confirm_page() -> VBoxContainer:
	var sheet: VBoxContainer = SheetPad.column(ScreenKit.card(Vector2(460, 0)))
	sheet.add_theme_constant_override("separation", 14)
	sheet.add_child(ScreenKit.header(tr("pause.eyebrow"), tr("menu.abandon"), ScreenKit.INK))
	sheet.add_child(ScreenKit.label(tr("menu.abandon.confirm"), 24, ScreenKit.INK))
	_keep = _wide(tr("menu.abandon.no"), CommonsTheme.PRIMARY, close)
	sheet.add_child(_keep)
	_abandon = _wide(tr("menu.abandon.yes"), CommonsTheme.GHOST, _leave.bind(abandoned))
	sheet.add_child(_abandon)
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(ScreenKit.card_panel(sheet))
	return wrapper


## Shows one page, with the focus on its first way out.
func _show_page(page: VBoxContainer) -> void:
	for each: VBoxContainer in [_main, _settings, _confirm, _controls, _window]:
		each.visible = each == page
	UiMotion.enter([page] as Array[Control])
	if page == _main:
		_resume.grab_focus()
	elif page == _confirm:
		_keep.grab_focus()
	elif page == _controls:
		_controls.focus_first()
	elif page == _window:
		WindowSheet.chosen_mode(_window).grab_focus()
	else:
		# The settings sheet's first control, so a keyboard or gamepad can reach Controls.
		var first: Control = _settings.find_next_valid_focus()
		if first != null:
			first.grab_focus()


## From the Controls or Window page back to the settings, with the focus on the ticket
## that opened it.
func _back_to_settings(ticket: Button) -> void:
	_show_page(_settings)
	ticket.grab_focus()


## The Controls page, for tests and the playtest.
func controls_page() -> ControlsPage:
	return _controls


## True while the menu asks whether to abandon the run.
func is_confirming() -> bool:
	return visible and _confirm.visible


## The confirm page's two buttons, for tests and the playtest.
func keep_button() -> Button:
	return _keep


func abandon_button() -> Button:
	return _abandon


func _leave(where: Signal) -> void:
	Settings.save()
	visible = false
	where.emit()


func _wide(text: String, kind: String, action: Callable) -> Button:
	var made: Button = ScreenKit.button(text, kind)
	made.size_flags_horizontal = Control.SIZE_FILL
	made.pressed.connect(action)
	return made


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		# Cancel on the question goes back to the menu, not past it.
		if _confirm.visible:
			_show_page(_main)
		elif _window.visible:
			_back_to_settings(SettingsPanel.window_button(_settings))
		else:
			close()
		get_viewport().set_input_as_handled()
