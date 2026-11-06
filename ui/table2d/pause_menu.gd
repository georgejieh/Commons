class_name PauseMenu
extends Control
## The in-game menu, opened with the Menu button or Escape: resume, change settings, go
## back to the title, or quit. The run saves after every move, so leaving loses
## nothing; Continue on the title picks up at the same moment.

signal resumed
signal to_title
signal quit_game
signal dossier
signal last_round

const DIM: Color = Color(0.05, 0.03, 0.02, 0.78)

var _main: VBoxContainer
var _settings: VBoxContainer
var _resume: Button


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
	stack.add_child(_main)
	stack.add_child(_settings)
	visible = false


func open() -> void:
	visible = true
	move_to_front()
	_show_page(_main)
	_resume.grab_focus()


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
	sheet.add_child(_wide(tr("pause.settings"), CommonsTheme.SECONDARY, _show_page.bind(null)))
	sheet.add_child(_wide(tr("pause.to_title"), CommonsTheme.GHOST, _leave.bind(to_title)))
	sheet.add_child(_wide(tr("pause.quit"), CommonsTheme.GHOST, _leave.bind(quit_game)))
	sheet.add_child(ScreenKit.styled(tr("pause.saved"), CommonsTheme.CAPTION))
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(ScreenKit.card_panel(sheet))
	return wrapper


func _settings_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	page.add_child(SettingsPanel.build())
	page.add_child(_wide(tr("settings.back"), CommonsTheme.PRIMARY, _show_page.bind(_main)))
	return page


## Shows one page; null means the settings page.
func _show_page(page: VBoxContainer) -> void:
	var settings: bool = page == null
	_main.visible = not settings
	_settings.visible = settings
	UiMotion.enter([_settings if settings else _main] as Array[Control])


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
		close()
		get_viewport().set_input_as_handled()
