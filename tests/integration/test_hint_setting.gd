extends GdUnitTestSuite
## The Hint can be turned off (the owner's playtest of 2026-11-24): a setting on the
## sheet, on by default. Off, the table shows no Hint button, its key does nothing, the
## button's press does nothing, and the Controls page leaves its row out; turned on again
## at an open table, the button is back at once.

const SEED: int = 3
const WAIT_FRAMES: int = 600

var _app: DemoApp


func before_test() -> void:
	AppKit.fresh_saves(self)
	Settings.set_value(HintSetting.SETTING, true)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(HintSetting.SETTING, true)
	Saves.run_service().delete()


## The table, played on until the run waits on the player's play.
func _table_at_play() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var player: EventPlayer = table.player
	for _frame: int in WAIT_FRAMES:
		var awaiting: int = _app.controller.awaiting()
		if awaiting == RunController.AWAIT_PLAY and player.is_idle():
			break
		if awaiting == RunController.AWAIT_BID:
			_app.controller.bid(true)
		table.skip_events()
		await await_idle_frame()
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_PLAY)
	_app.hand.clear()
	return table


func test_the_hint_is_on_by_default_and_on_the_sheet() -> void:
	assert_bool(SettingsStore.DEFAULTS.show_hint).is_true()
	assert_bool(SettingsStore.KEYS.has(HintSetting.SETTING)).is_true()
	var sheet: Control = auto_free(SettingsPanel.build())
	add_child(sheet)
	await await_idle_frame()
	var toggle: CheckBox = null
	for node: Node in sheet.find_children("*", "CheckBox", true, false):
		if (node as CheckBox).text == tr("settings.show_hint"):
			toggle = node as CheckBox
	assert_object(toggle).is_not_null()
	assert_bool(toggle.button_pressed).is_true()
	toggle.button_pressed = false
	assert_bool(HintSetting.shown()).is_false()


func test_with_the_hint_on_its_key_lights_a_play() -> void:
	var table: TableScreen = await _table_at_play()
	assert_bool(table.actions.hint.is_visible_in_tree()).is_true()
	await TestInput.tap_key(self, Settings.bindings.key(KeyBindings.HINT))
	var hinted: bool = not _app.hand.selected_ids().is_empty()
	var passing: bool = table.actions.reading.text == tr("hand.hint.pass")
	assert_bool(hinted or passing).is_true()


func test_with_the_hint_off_neither_button_nor_key_does_anything() -> void:
	var table: TableScreen = await _table_at_play()
	Settings.set_value(HintSetting.SETTING, false)
	await await_idle_frame()
	var hint: Button = table.actions.hint
	assert_bool(hint.is_visible_in_tree()).is_false()
	var reading: String = table.actions.reading.text
	await TestInput.tap_key(self, Settings.bindings.key(KeyBindings.HINT))
	hint.pressed.emit()
	await await_idle_frame()
	assert_array(_app.hand.selected_ids()).is_empty()
	assert_str(table.actions.reading.text).is_equal(reading)
	# Turned on again at the open table, the button is back at once.
	Settings.set_value(HintSetting.SETTING, true)
	assert_bool(hint.is_visible_in_tree()).is_true()


func test_the_controls_page_leaves_the_hint_out_while_it_is_off() -> void:
	Settings.set_value(HintSetting.SETTING, false)
	var screen: ControlsScreen = _app.show_screen("controls", true)
	await await_idle_frame()
	await await_idle_frame()
	var page: ControlsPage = screen.page()
	assert_bool(page.ticket(KeyBindings.HINT).is_visible_in_tree()).is_false()
	var labels: Array[String] = []
	for node: Node in page.find_children("*", "Label", true, false):
		if (node as Label).is_visible_in_tree():
			labels.append((node as Label).text)
	assert_array(labels).not_contains([tr("controls.action.commons_hint")])
	# The focus runs past where the row was.
	var play: Button = page.ticket("commons_play")
	var pass_ticket: Button = page.ticket("commons_pass")
	var below_pass: Button = pass_ticket.get_node(pass_ticket.focus_neighbor_bottom) as Button
	assert_object(below_pass).is_same(page.ticket("commons_sort"))
	assert_bool(play.is_visible_in_tree()).is_true()
	Settings.set_value(HintSetting.SETTING, true)
	page.visible = false
	page.visible = true
	await await_idle_frame()
	assert_bool(page.ticket(KeyBindings.HINT).is_visible_in_tree()).is_true()
