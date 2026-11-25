class_name DisplayWindow
extends Node
## Puts the game's window in the mode, size and vertical sync the player chose: once as
## the app starts, before the launch gate can show its notice, and again whenever one of
## them changes. The canvas is a fixed 1920x1080 stretched to the window, so the size
## only means something for a window; in full screen the window is the screen.
##
## A new mode or size could leave a window the player cannot see or reach, such as
## exclusive full screen on a screen that cannot show it, so it stands only once kept: a
## notice asks, and unless Keep is chosen within display_check_seconds the mode and size
## before it come back and are saved. Vertical sync cannot hide the window and needs no
## asking.
##
## Only a launch of the game itself, on a real display, drives the window. A tool, the
## playtest and the test run each run the tree under a script of their own, and a headless
## run has no window: there the settings change and nothing else does.

const PARAMS: SettingsParams = SettingsStore.DEFAULTS
## The window modes by the setting's value: a window, borderless full screen and exclusive
## full screen.
const MODES: Array[Window.Mode] = [
	Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN
]
const WINDOWED: int = 0
const MODE: String = "window_mode"
const SIZE: String = "window_size"
const VSYNC: String = "vsync"

var _host: Control
var _window: Callable
## The mode and size the player has kept, which a new one unkept goes back to.
var _kept_mode: int = 0
var _kept_size: int = 0
var _notice: SessionNotice = null
## What had the focus when the notice came, which has it again once the notice goes.
var _focus: Control = null
var _timer: Timer = Timer.new()
var _restoring: bool = false


## window is called with a Window.Mode, a size and whether to sync, to put the window so;
## with none, the window is never touched. The notice stands over host.
func _init(host: Control, window: Callable) -> void:
	_host = host
	_window = window


## The display for the app: one that drives its window on a launch of the game itself
## with a display, and one that touches nothing otherwise.
static func for_app(app: Control) -> DisplayWindow:
	if not LaunchGate.guards(app) or DisplayServer.get_name() == "headless":
		return DisplayWindow.new(app, Callable())
	return DisplayWindow.new(app, DisplayWindow.drive.bind(app.get_window()))


## Puts window in mode, at size when it is a window, centred on its screen.
static func drive(mode: Window.Mode, size: Vector2i, vsync: bool, window: Window) -> void:
	var sync: DisplayServer.VSyncMode = (
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	DisplayServer.window_set_vsync_mode(sync, window.get_window_id())
	window.mode = mode
	if mode == Window.MODE_WINDOWED:
		window.size = size
		window.move_to_center()


## The room a window has on the screen the game is on, or zero with no display.
static func usable_screen() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	var screen: int = DisplayServer.window_get_current_screen()
	return DisplayServer.screen_get_usable_rect(screen).size


## The window sizes offered, by their index in window_sizes: those the screen has room
## for, and always the smallest. With no screen known, all of them.
static func offered(usable: Vector2i) -> Array[int]:
	var made: Array[int] = [0]
	for index: int in range(1, PARAMS.window_sizes.size()):
		var size: Vector2i = PARAMS.window_sizes[index]
		if usable == Vector2i.ZERO or (size.x <= usable.x and size.y <= usable.y):
			made.append(index)
	return made


## The mode chosen, held inside MODES.
static func mode_chosen() -> int:
	return clampi(int(Settings.value(MODE)), 0, MODES.size() - 1)


## The window size chosen, by index: the largest offered at or under the one saved.
static func size_chosen(usable: Vector2i) -> int:
	var chosen: int = int(Settings.value(SIZE))
	var held: int = 0
	for index: int in offered(usable):
		if index <= chosen:
			held = index
	return held


func _ready() -> void:
	_timer.one_shot = true
	_timer.wait_time = PARAMS.display_check_seconds
	_timer.timeout.connect(_restore)
	add_child(_timer)
	_kept_mode = mode_chosen()
	_kept_size = size_chosen(usable_screen())
	if _window.is_valid():
		_apply()
		Settings.changed.connect(_on_setting)


## The notice asking whether to keep a new mode or size, while it shows, or null.
func notice() -> SessionNotice:
	return _notice


func _on_setting(key: String) -> void:
	if _restoring or not [MODE, SIZE, VSYNC].has(key):
		return
	var mode: int = mode_chosen()
	var size: int = size_chosen(usable_screen())
	var moved: bool = mode != _kept_mode or (mode == WINDOWED and size != _kept_size)
	_apply()
	if moved and _notice == null:
		_focus = _host.get_viewport().gui_get_focus_owner()
		_notice = SessionNotice.display_check(PARAMS.display_check_seconds, _keep, _restore)
		_host.add_child(_notice)
		_timer.start()
	elif not moved:
		_kept_size = size


func _keep() -> void:
	_kept_mode = mode_chosen()
	_kept_size = size_chosen(usable_screen())
	_close()


## The mode and size kept before come back, on the sheet too, and are saved, so a window
## the player could not see is never the one the game starts in.
func _restore() -> void:
	_restoring = true
	Settings.set_value(MODE, _kept_mode)
	Settings.set_value(SIZE, _kept_size)
	_restoring = false
	_apply()
	Settings.save()
	_close()


func _close() -> void:
	_timer.stop()
	if _notice != null:
		_notice.close()
		_notice = null
	if is_instance_valid(_focus) and _focus.is_visible_in_tree():
		_focus.grab_focus()
	_focus = null


func _apply() -> void:
	var size: Vector2i = PARAMS.window_sizes[size_chosen(usable_screen())]
	_window.call(MODES[mode_chosen()], size, bool(Settings.value(VSYNC)))
