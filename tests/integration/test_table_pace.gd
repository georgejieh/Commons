extends GdUnitTestSuite
## The table's pace is the player's to set (P5.2a): Slow gives every step of the table
## longer, Fast less, Standard is as it was, and a change takes hold at once at a table
## already open, with the beat before a villager's play scaled to match.

const SEED: int = 3
const SLOW: int = 0
const STANDARD: int = 1
const FAST: int = 2

var _app: DemoApp


func before_test() -> void:
	AppKit.fresh_saves(self)
	Settings.set_value("table_pace", STANDARD)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value("table_pace", STANDARD)
	Saves.run_service().delete()


func test_standard_is_the_default_and_the_step_as_it_was() -> void:
	assert_int(SettingsStore.DEFAULTS.table_pace).is_equal(STANDARD)
	var presets: MotionPresets = UiMotion.PRESETS
	assert_float(presets.pace_scales[STANDARD]).is_equal(1.0)
	assert_float(_app.motion_step()).is_equal_approx(presets.event_step, 0.0001)


func test_slow_is_longer_and_fast_is_shorter() -> void:
	var presets: MotionPresets = UiMotion.PRESETS
	Settings.set_value("table_pace", SLOW)
	var slow: float = _app.motion_step()
	Settings.set_value("table_pace", FAST)
	var fast: float = _app.motion_step()
	assert_float(slow).is_equal_approx(presets.event_step * presets.pace_scales[SLOW], 0.0001)
	assert_float(fast).is_equal_approx(presets.event_step * presets.pace_scales[FAST], 0.0001)
	assert_float(slow).is_greater(presets.event_step)
	assert_float(fast).is_less(presets.event_step)
	# A value from a damaged file is held inside the scales, never past them.
	Settings.set_value("table_pace", 9)
	assert_float(_app.motion_step()).is_equal_approx(fast, 0.0001)


func test_the_settings_sheet_offers_the_three_paces() -> void:
	var sheet: Control = auto_free(SettingsPanel.build())
	add_child(sheet)
	await await_idle_frame()
	assert_int(SettingsPanel.PACES.size()).is_equal(UiMotion.PRESETS.pace_scales.size())
	var standard: CheckBox = sheet.find_child(SettingsPanel.PACE_BOX % STANDARD, true, false)
	var slow: CheckBox = sheet.find_child(SettingsPanel.PACE_BOX % SLOW, true, false)
	assert_bool(standard.button_pressed).is_true()
	assert_str(slow.text).is_equal(tr("settings.table_pace.slow"))
	slow.button_pressed = true
	assert_int(int(Settings.value("table_pace"))).is_equal(SLOW)
	assert_bool(standard.button_pressed).is_false()


func test_a_change_takes_hold_at_an_open_table() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var player: EventPlayer = table.player
	var presets: MotionPresets = UiMotion.PRESETS
	assert_float(player.step).is_equal_approx(presets.event_step, 0.0001)
	var wind: float = player.wind
	Settings.set_value("table_pace", SLOW)
	assert_float(player.step).is_equal_approx(
		presets.event_step * presets.pace_scales[SLOW], 0.0001
	)
	assert_float(player.wind).is_equal_approx(wind * presets.pace_scales[SLOW], 0.0001)
	assert_float(player.play_wait).is_equal_approx(
		presets.fly_time * presets.pace_scales[SLOW], 0.0001
	)
