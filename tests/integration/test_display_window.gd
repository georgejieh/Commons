extends GdUnitTestSuite
## The window's mode, size and vertical sync (DisplayWindow): on the settings sheet, put
## on the window as the display starts and as each changes, and a new mode or size kept
## only when the player says so, else put back, on the sheet too, and saved. A test, like
## any run under a script, never touches the window.

const KEYS: Array[String] = [DisplayWindow.MODE, DisplayWindow.SIZE, DisplayWindow.VSYNC]
const BORDERLESS: int = 1
const EXCLUSIVE: int = 2

static var _save_path: String = TestFolder.of("test_display_window") + "run.json"

## Each call the display made to the window, as [mode, size, vsync].
var _calls: Array[Array] = []
var _host: Control


func before_test() -> void:
	_calls.clear()
	for key: String in KEYS:
		Settings.set_value(key, SettingsStore.DEFAULTS.get(key))
	_host = auto_free(Control.new())
	add_child(_host)


func after_test() -> void:
	for key: String in KEYS:
		Settings.set_value(key, SettingsStore.DEFAULTS.get(key))


func _record(mode: Window.Mode, size: Vector2i, vsync: bool) -> void:
	_calls.append([mode, size, vsync])


func _display() -> DisplayWindow:
	var display: DisplayWindow = DisplayWindow.new(_host, _record)
	_host.add_child(display)
	return display


func _app() -> App:
	Saves.use_run_path(_save_path)
	var app: App = AppKit.make(self)
	return app


func _last() -> Array:
	return _calls.back()


func test_a_new_player_gets_borderless_full_screen_with_sync() -> void:
	assert_int(SettingsStore.DEFAULTS.window_mode).is_equal(BORDERLESS)
	assert_bool(SettingsStore.DEFAULTS.vsync).is_true()
	var size: Vector2i = SettingsStore.DEFAULTS.window_sizes[SettingsStore.DEFAULTS.window_size]
	assert_object(size).is_equal(Vector2i(1920, 1080))
	_display()
	assert_array(_calls).is_equal([[Window.MODE_FULLSCREEN, size, true]])


func test_the_app_under_a_script_never_touches_the_window() -> void:
	var app: App = _app()
	var displays: Array[DisplayWindow] = []
	for child: Node in app.get_children():
		if child is DisplayWindow:
			displays.append(child as DisplayWindow)
	assert_int(displays.size()).is_equal(1)
	var display: DisplayWindow = displays[0]
	var mode: Window.Mode = get_window().mode
	Settings.set_value(DisplayWindow.MODE, EXCLUSIVE)
	await await_idle_frame()
	assert_object(display.notice()).is_null()
	assert_int(get_window().mode).is_equal(mode)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func test_vertical_sync_changes_at_once_with_no_question() -> void:
	var display: DisplayWindow = _display()
	Settings.set_value(DisplayWindow.VSYNC, false)
	assert_bool(_last()[2]).is_false()
	assert_object(display.notice()).is_null()


func test_a_new_mode_stands_once_kept() -> void:
	var display: DisplayWindow = _display()
	Settings.set_value(DisplayWindow.MODE, EXCLUSIVE)
	assert_int(_last()[0]).is_equal(Window.MODE_EXCLUSIVE_FULLSCREEN)
	var notice: SessionNotice = display.notice()
	assert_object(notice).is_not_null()
	await await_idle_frame()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(notice.buttons()[0])
	notice.buttons()[0].pressed.emit()
	assert_object(display.notice()).is_null()
	assert_int(int(Settings.value(DisplayWindow.MODE))).is_equal(EXCLUSIVE)
	assert_bool(display.revert_timer.is_stopped()).is_true()
	# Kept, it is the one a later change goes back to.
	Settings.set_value(DisplayWindow.MODE, DisplayWindow.WINDOWED)
	display.notice().buttons()[1].pressed.emit()
	assert_int(int(Settings.value(DisplayWindow.MODE))).is_equal(EXCLUSIVE)
	assert_int(_last()[0]).is_equal(Window.MODE_EXCLUSIVE_FULLSCREEN)


## Unkept, by the clock, Change back or Escape, the old mode returns to the window, the
## settings and the file.
func test_a_new_mode_unkept_goes_back_and_is_saved() -> void:
	for way: String in ["clock", "button", "escape"]:
		_calls.clear()
		var display: DisplayWindow = _display()
		Settings.set_value(DisplayWindow.MODE, EXCLUSIVE)
		await await_idle_frame()
		match way:
			"clock":
				display.revert_timer.timeout.emit()
			"button":
				display.notice().buttons()[1].pressed.emit()
			"escape":
				var escape: InputEventAction = InputEventAction.new()
				escape.action = "ui_cancel"
				escape.pressed = true
				Input.parse_input_event(escape)
				Input.flush_buffered_events()
				await await_idle_frame()
		assert_object(display.notice()).override_failure_message(way).is_null()
		assert_int(int(Settings.value(DisplayWindow.MODE))).is_equal(BORDERLESS)
		assert_int(_last()[0]).override_failure_message(way).is_equal(Window.MODE_FULLSCREEN)
		var file: ConfigFile = ConfigFile.new()
		(
			assert_int(
				file.load(
					SettingsStore.start_path(
						OS.is_debug_build(), OS.get_environment(SettingsStore.PATH_OVERRIDE), false
					)
				)
			)
			. is_equal(OK)
		)
		var saved: int = file.get_value(SettingsStore.SECTION, DisplayWindow.MODE)
		assert_int(saved).override_failure_message(way).is_equal(BORDERLESS)
		display.free()


func test_the_clock_is_data() -> void:
	var display: DisplayWindow = _display()
	var timer: Timer = display.revert_timer
	assert_float(timer.wait_time).is_equal(float(SettingsStore.DEFAULTS.display_check_seconds))


## A size asks only for a window: in full screen it is kept for later, and nothing moves.
func test_a_size_asks_only_for_a_window() -> void:
	var display: DisplayWindow = _display()
	Settings.set_value(DisplayWindow.SIZE, 0)
	assert_object(display.notice()).is_null()
	Settings.set_value(DisplayWindow.MODE, DisplayWindow.WINDOWED)
	display.notice().buttons()[0].pressed.emit()
	assert_object(_last()[1]).is_equal(SettingsStore.DEFAULTS.window_sizes[0])
	Settings.set_value(DisplayWindow.SIZE, 1)
	assert_object(display.notice()).is_not_null()
	assert_object(_last()[1]).is_equal(SettingsStore.DEFAULTS.window_sizes[1])
	display.notice().buttons()[1].pressed.emit()
	assert_int(int(Settings.value(DisplayWindow.SIZE))).is_equal(0)


## Only the sizes a screen has room for are offered, and the smallest always is.
func test_the_sizes_offered_fit_the_screen() -> void:
	var all: int = SettingsStore.DEFAULTS.window_sizes.size()
	assert_int(DisplayWindow.offered(Vector2i.ZERO).size()).is_equal(all)
	assert_array(DisplayWindow.offered(Vector2i(1920, 1040))).is_equal([0, 1])
	assert_array(DisplayWindow.offered(Vector2i(1280, 760))).is_equal([0])
	assert_array(DisplayWindow.offered(Vector2i(800, 600))).is_equal([0])
	Settings.set_value(DisplayWindow.SIZE, 3)
	assert_int(DisplayWindow.size_chosen(Vector2i(1920, 1040))).is_equal(1)
	assert_int(DisplayWindow.size_chosen(Vector2i.ZERO)).is_equal(3)


## The sheet offers the three modes and the sizes; the sizes can be picked only for a
## window, and the ticks follow a mode that goes back.
func test_the_sheet_offers_the_window() -> void:
	var display: DisplayWindow = _display()
	var sheet: Control = auto_free(WindowSheet.build())
	add_child(sheet)
	await await_idle_frame()
	var windowed: CheckBox = sheet.find_child(WindowSheet.MODE_BOX % 0, true, false)
	var borderless: CheckBox = sheet.find_child(WindowSheet.MODE_BOX % 1, true, false)
	var small: CheckBox = sheet.find_child(WindowSheet.SIZE_BOX % 0, true, false)
	assert_str(windowed.text).is_equal(tr("settings.window_mode.windowed"))
	assert_str(small.text).is_equal("1280 × 720")
	assert_bool(borderless.button_pressed).is_true()
	assert_bool(small.disabled).is_true()
	windowed.button_pressed = true
	assert_int(int(Settings.value(DisplayWindow.MODE))).is_equal(DisplayWindow.WINDOWED)
	assert_bool(small.disabled).is_false()
	display.notice().buttons()[1].pressed.emit()
	assert_bool(borderless.button_pressed).is_true()
	assert_bool(windowed.button_pressed).is_false()
	assert_bool(small.disabled).is_true()
	var sync: CheckBox = _box_named(sheet, tr("settings.vsync"))
	assert_bool(sync.button_pressed).is_true()


func _box_named(root: Node, text: String) -> CheckBox:
	for node: Node in root.find_children("*", "CheckBox", true, false):
		if (node as CheckBox).text == text:
			return node as CheckBox
	return null


## The Window page stands whole and unclipped at both screens and every text size, as a
## screen from the settings and as a page of the table's menu, and Back on it saves and
## goes back.
func test_the_window_page_stands_whole_at_every_size() -> void:
	var was: Vector2i = get_tree().root.size
	var app: App = _app()
	app.new_run(4301)
	for level: int in TextSize.count():
		for screen_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 800)]:
			Settings.set_value(TextSize.SETTING, level)
			get_tree().root.size = screen_size
			var where: String = "text size %d at %s" % [level, screen_size]
			var screen: WindowScreen = app.show_screen(ScreenId.WINDOW, true)
			await await_idle_frame()
			await await_idle_frame()
			_assert_whole(screen, where + " screen")
			var table: TableScreen = app.show_screen(ScreenId.TABLE, true)
			await await_idle_frame()
			table.hud.menu.pressed.emit()
			var pause: PauseMenu = table.pause
			TestInput.press(self, pause.main, tr("pause.settings"))
			SettingsPanel.window_button(pause).pressed.emit()
			await await_idle_frame()
			await await_idle_frame()
			var page: Control = pause.window
			assert_bool(page.visible).override_failure_message(where).is_true()
			_assert_whole(page, where + " menu")
			pause.visible = false
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = was
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _assert_whole(root: Control, where: String) -> void:
	var view: Rect2 = root.get_viewport_rect().grow(1.5)
	for node: Node in root.find_children("*", "CheckBox", true, false):
		var rect: Rect2 = (node as Control).get_global_rect()
		assert_bool(view.encloses(rect)).override_failure_message("%s %s" % [where, rect]).is_true()
	var problems: PackedStringArray = []
	ClipCheck.check(root, where, problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
