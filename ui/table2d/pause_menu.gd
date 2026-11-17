class_name PauseMenu
extends Control
## The in-game menu, opened with the Menu button or Escape: resume, change settings, go
## back to the title, abandon the run, or quit. The run saves after every move, so leaving
## loses nothing; Continue on the title picks up at the same moment. Abandoning asks
## first, with the focus on keeping the run, and clears its save (ADR 0025).

signal resumed
signal to_title
signal quit_game
signal dossier
signal last_round
signal abandon

const DIM: Color = Color(0.05, 0.03, 0.02, 0.78)

var _main: VBoxContainer
var _settings: VBoxContainer
var _confirm: VBoxContainer
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
	var stack: VBoxContainer = VBoxContainer.new()
	center.add_child(stack)
	_main = _menu()
	_settings = _settings_page()
	_confirm = _confirm_page()
	stack.add_child(_main)
	stack.add_child(_settings)
	stack.add_child(_confirm)
	visible = false


## Sends the menu's ways out to the app's screens.
func wire(app: DemoApp) -> void:
	to_title.connect(func() -> void: app.show_screen("title", true))
	quit_game.connect(func() -> void: app.get_tree().quit())
	dossier.connect(func() -> void: app.show_screen("dossier"))
	last_round.connect(func() -> void: app.show_screen("round_summary"))
	abandon.connect(app.leave_run)


func open() -> void:
	visible = true
	move_to_front()
	_show_page(_main)


func close() -> void:
	Settings.save()
	visible = false
	resumed.emit()


func _menu() -> VBoxContainer:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(460, 0))
	sheet.add_theme_constant_override("separation", 14)
	sheet.add_child(ScreenKit.header(tr("pause.eyebrow"), tr("pause.title"), ScreenKit.INK))
	_resume = _wide(tr("pause.resume"), CommonsTheme.PRIMARY, close)
	sheet.add_child(_resume)
	sheet.add_child(_wide(tr("dossier.open"), CommonsTheme.SECONDARY, _leave.bind(dossier)))
	sheet.add_child(_wide(tr("pause.last_round"), CommonsTheme.SECONDARY, _leave.bind(last_round)))
	var settings: Callable = func() -> void: _show_page(_settings)
	sheet.add_child(_wide(tr("pause.settings"), CommonsTheme.SECONDARY, settings))
	sheet.add_child(_wide(tr("pause.to_title"), CommonsTheme.GHOST, _leave.bind(to_title)))
	var ask: Callable = func() -> void: _show_page(_confirm)
	sheet.add_child(_wide(tr("menu.abandon"), CommonsTheme.GHOST, ask))
	sheet.add_child(_wide(tr("pause.quit"), CommonsTheme.GHOST, _leave.bind(quit_game)))
	sheet.add_child(ScreenKit.styled(tr("pause.saved"), CommonsTheme.CAPTION))
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(ScreenKit.card_panel(sheet))
	return wrapper


func _settings_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	page.add_child(SettingsPanel.build())
	var back: Callable = func() -> void: _show_page(_main)
	page.add_child(_wide(tr("settings.back"), CommonsTheme.PRIMARY, back))
	return page


## Asks before abandoning the run. Keep playing has the focus, so a stray press of
## accept keeps the run.
func _confirm_page() -> VBoxContainer:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(460, 0))
	sheet.add_theme_constant_override("separation", 14)
	sheet.add_child(ScreenKit.label(tr("menu.abandon.confirm"), 24, ScreenKit.INK))
	_keep = _wide(tr("menu.abandon.no"), CommonsTheme.PRIMARY, close)
	sheet.add_child(_keep)
	_abandon = _wide(tr("menu.abandon.yes"), CommonsTheme.GHOST, _leave.bind(abandon))
	sheet.add_child(_abandon)
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(ScreenKit.card_panel(sheet))
	return wrapper


## Shows one page, with the focus on its first way out.
func _show_page(page: VBoxContainer) -> void:
	for each: VBoxContainer in [_main, _settings, _confirm]:
		each.visible = each == page
	UiMotion.enter([page] as Array[Control])
	if page == _main:
		_resume.grab_focus()
	elif page == _confirm:
		_keep.grab_focus()


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
		else:
			close()
		get_viewport().set_input_as_handled()
