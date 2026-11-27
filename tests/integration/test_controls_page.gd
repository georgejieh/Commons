extends GdUnitTestSuite
## The Controls page (ADR 0035), at the title and in the pause menu, driven through the
## engine's input path as a player's keys are: the Enter that presses a ticket is never
## taken as its new key, the next key is; Escape and the gamepad's B cancel the asking
## and then back out; a bare modifier is refused; Restore defaults puts every key back;
## the focus is never lost; and no set of bindings can lock the page in or out.

const SEED: int = 4301
## Bindings on the keys the menus use, as hostile as the rules allow.
const HOSTILE: Dictionary[String, Key] = {
	"commons_play": KEY_ENTER,
	"commons_pass": KEY_KP_ENTER,
	"commons_select": KEY_DOWN,
	"commons_cursor_left": KEY_UP,
	"commons_cursor_right": KEY_TAB,
	"commons_rules": KEY_SPACE,
	"commons_hint": KEY_LEFT,
	"commons_sort": KEY_RIGHT,
	"commons_campaign": KEY_BACKSPACE,
}

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	Settings.bindings.restore_defaults()
	Settings.save()
	Saves.run_service().delete()


func _key(key: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	return event


## A key pressed and let go, a frame apart, through the root viewport.
func _tap(key: Key) -> void:
	get_tree().root.push_input(_key(key, true))
	await await_idle_frame()
	get_tree().root.push_input(_key(key, false))
	await await_idle_frame()


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_tree().root.push_input(event)
		await await_idle_frame()


func _focus() -> Control:
	return get_tree().root.gui_get_focus_owner()


func _assert_focus_in(page: Control) -> void:
	var focus: Control = _focus()
	var inside: bool = focus != null and page.is_ancestor_of(focus)
	assert_bool(inside).override_failure_message("focus on %s" % focus).is_true()


## The title's settings, then its Controls ticket pressed with Enter.
func _open_from_title() -> ControlsPage:
	_app.show_screen("title", true)
	var settings: SettingsScreen = _app.show_screen("settings")
	await await_idle_frame()
	SettingsPanel.controls_button(settings).grab_focus()
	await _tap(KEY_ENTER)
	assert_str(_app.switcher.current_id()).is_equal("controls")
	var screen: ControlsScreen = _app.switcher.current()
	return screen.page()


func test_settings_opens_the_page_with_the_focus_on_the_first_key() -> void:
	var page: ControlsPage = await _open_from_title()
	assert_object(_focus()).is_same(page.ticket(KeyBindings.ACTIONS[0]))
	for action: String in KeyBindings.ACTIONS:
		var shown: String = KeyBindings.label(Settings.bindings.key(action))
		assert_str(page.ticket(action).text).is_equal(shown)


func test_the_enter_that_presses_a_ticket_is_not_its_new_key() -> void:
	var page: ControlsPage = await _open_from_title()
	var ticket: Button = page.ticket("commons_hint")
	ticket.grab_focus()
	await _tap(KEY_ENTER)
	assert_str(page.capturing()).is_equal("commons_hint")
	assert_str(ticket.text).is_equal(tr("controls.press"))
	assert_int(Settings.bindings.key("commons_hint")).is_equal(KEY_H)
	await _tap(KEY_J)
	assert_str(page.capturing()).is_empty()
	assert_int(Settings.bindings.key("commons_hint")).is_equal(KEY_J)
	assert_str(ticket.text).is_equal("J")
	assert_object(_focus()).is_same(ticket)
	# Saved at once.
	var file: ConfigFile = ConfigFile.new()
	file.load(OS.get_environment(SettingsStore.PATH_OVERRIDE))
	assert_int(int(file.get_value(KeyBindings.SECTION, "commons_hint", 0))).is_equal(KEY_J)


## A ticket that answers on the press, not the release: the press that opened the asking
## comes in the same frame and is let go by.
func test_a_press_in_the_frame_the_asking_began_is_let_go_by() -> void:
	var page: ControlsPage = await _open_from_title()
	page.capture("commons_play")
	get_tree().root.push_input(_key(KEY_SPACE, true))
	assert_str(page.capturing()).is_equal("commons_play")
	assert_int(Settings.bindings.key("commons_play")).is_equal(KEY_ENTER)
	await await_idle_frame()
	get_tree().root.push_input(_key(KEY_SPACE, false))
	await await_idle_frame()
	await _tap(KEY_P)
	assert_int(Settings.bindings.key("commons_play")).is_equal(KEY_P)


func test_escape_cancels_the_asking_then_backs_out() -> void:
	var page: ControlsPage = await _open_from_title()
	var ticket: Button = page.ticket("commons_sort")
	ticket.grab_focus()
	await _tap(KEY_ENTER)
	assert_str(page.capturing()).is_equal("commons_sort")
	await _tap(KEY_ESCAPE)
	assert_str(page.capturing()).is_empty()
	assert_str(_app.switcher.current_id()).is_equal("controls")
	assert_int(Settings.bindings.key("commons_sort")).is_equal(KEY_S)
	assert_str(ticket.text).is_equal("S")
	assert_object(_focus()).is_same(ticket)
	await _tap(KEY_ESCAPE)
	assert_str(_app.switcher.current_id()).is_equal("settings")


func test_the_gamepad_cancels_and_a_bare_modifier_is_refused() -> void:
	var page: ControlsPage = await _open_from_title()
	page.ticket("commons_rules").grab_focus()
	await _tap(KEY_ENTER)
	await _tap(KEY_SHIFT)
	await _tap(KEY_CTRL)
	assert_str(page.capturing()).is_equal("commons_rules")
	# Arrow keys are taken by the asking, so the focus stays put.
	await _tap(KEY_DOWN)
	assert_int(Settings.bindings.key("commons_rules")).is_equal(KEY_DOWN)
	_assert_focus_in(page)
	page.ticket("commons_rules").grab_focus()
	await _tap(KEY_ENTER)
	await _pad(JOY_BUTTON_B)
	assert_str(page.capturing()).is_empty()
	assert_str(_app.switcher.current_id()).is_equal("controls")
	await _pad(JOY_BUTTON_B)
	assert_str(_app.switcher.current_id()).is_equal("settings")


func test_a_clash_swaps_and_restore_puts_every_key_back() -> void:
	var page: ControlsPage = await _open_from_title()
	page.ticket("commons_hint").grab_focus()
	await _tap(KEY_ENTER)
	await _tap(KEY_S)
	assert_str(page.ticket("commons_hint").text).is_equal("S")
	assert_str(page.ticket("commons_sort").text).is_equal("H")
	page.restore_button().grab_focus()
	await _tap(KEY_ENTER)
	for action: String in KeyBindings.ACTIONS:
		assert_int(Settings.bindings.key(action)).is_equal(KeyBindings.default_key(action))
	assert_str(page.ticket("commons_hint").text).is_equal("H")
	assert_object(_focus()).is_same(page.restore_button())


## Down runs from the first ticket through every key, Restore defaults and Back, and up
## runs back; the focus never leaves the page.
func test_the_focus_runs_down_the_page_and_never_leaves_it() -> void:
	var page: ControlsPage = await _open_from_title()
	var order: Array[Control] = []
	for action: String in KeyBindings.ACTIONS:
		order.append(page.ticket(action))
	order.append_array([page.restore_button(), page.back_button()])
	for index: int in order.size():
		assert_object(_focus()).override_failure_message(str(index)).is_same(order[index])
		await _tap(KEY_DOWN)
	assert_object(_focus()).is_same(page.back_button())
	for key: Key in [KEY_LEFT, KEY_RIGHT]:
		await _tap(key)
		assert_object(_focus()).is_same(page.back_button())
	for _step: int in order.size():
		await _tap(KEY_UP)
	assert_object(_focus()).is_same(order[0])


## Every action on a key the menus use: the title still reaches the page with Enter and
## leaves it with Escape, and so does the table's menu.
func test_no_binding_set_locks_the_page() -> void:
	for action: String in HOSTILE:
		Settings.bindings.bind(action, HOSTILE[action])
	for action: String in HOSTILE:
		assert_int(Settings.bindings.key(action)).is_equal(HOSTILE[action])
	var page: ControlsPage = await _open_from_title()
	_assert_focus_in(page)
	for action: String in HOSTILE:
		if HOSTILE[action] != KEY_ENTER:
			await _tap(HOSTILE[action])
		_assert_focus_in(page)
		assert_str(_app.switcher.current_id()).is_equal("controls")
	await _tap(KEY_ESCAPE)
	assert_str(_app.switcher.current_id()).is_equal("settings")
	_app.new_run(SEED)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.skip_events()
	await _tap(KEY_ESCAPE)
	var pause: PauseMenu = table.pause
	assert_bool(pause.visible).is_true()
	var settings: Button = _button_in(pause, tr("pause.settings"))
	settings.grab_focus()
	await _tap(KEY_ENTER)
	_assert_focus_in(pause)
	SettingsPanel.controls_button(pause).grab_focus()
	await _tap(KEY_ENTER)
	var controls: ControlsPage = pause.controls_page()
	assert_bool(controls.is_visible_in_tree()).is_true()
	_assert_focus_in(controls)
	await _tap(KEY_ESCAPE)
	assert_bool(controls.is_visible_in_tree()).is_false()
	assert_object(_focus()).is_same(SettingsPanel.controls_button(pause))
	await _tap(KEY_ESCAPE)
	assert_bool(pause.visible).is_false()


func _button_in(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	return null
