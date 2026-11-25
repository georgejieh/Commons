extends GdUnitTestSuite
## The table actions' keys (ADR 0035): the defaults are the project's, a change reaches
## the InputMap at once with the gamepad button kept, a key in use swaps, Escape and bare
## modifiers are refused, the defaults come back, and the settings file holds them, with
## each bad value falling back and a clash in the file sending every key home. Every
## commons_ action has a binding, a row and a string.

const PATH: String = "user://test_key_bindings.cfg"
const ACTION_PREFIX: String = "commons_"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	# A test's own bindings write the shared InputMap: the autoload's put it back.
	Settings.bindings.restore_defaults()


func _key_events(action: String) -> Array[InputEventKey]:
	var keys: Array[InputEventKey] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append(event as InputEventKey)
	return keys


func _pad_events(action: String) -> int:
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		count += 1 if event is InputEventJoypadButton else 0
	return count


func _key_press(key: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	return event


func test_the_defaults_are_the_project_keys() -> void:
	var bindings: KeyBindings = KeyBindings.new()
	var expected: Dictionary[String, Key] = {
		"commons_play": KEY_ENTER,
		"commons_pass": KEY_SPACE,
		"commons_hint": KEY_H,
		"commons_sort": KEY_S,
		"commons_rules": KEY_R,
		"commons_campaign": KEY_C,
		"commons_deck": KEY_D,
		"commons_select": KEY_UP,
		"commons_cursor_left": KEY_LEFT,
		"commons_cursor_right": KEY_RIGHT,
		"commons_sit_out": KEY_X,
	}
	for action: String in expected:
		assert_int(bindings.key(action)).override_failure_message(action).is_equal(expected[action])
	assert_bool(bindings.is_default()).is_true()
	for action: String in KeyBindings.ACTIONS:
		var keys: Array[InputEventKey] = _key_events(action)
		assert_int(keys.size()).is_equal(1)
		assert_int(keys[0].physical_keycode).is_equal(expected[action])


func test_a_change_moves_the_key_and_keeps_the_gamepad_button() -> void:
	var bindings: KeyBindings = KeyBindings.new()
	var pads: int = _pad_events("commons_hint")
	assert_int(pads).is_equal(1)
	assert_bool(bindings.bind("commons_hint", KEY_J)).is_true()
	assert_int(bindings.key("commons_hint")).is_equal(KEY_J)
	var keys: Array[InputEventKey] = _key_events("commons_hint")
	assert_int(keys.size()).is_equal(1)
	assert_int(keys[0].physical_keycode).is_equal(KEY_J)
	assert_int(_pad_events("commons_hint")).is_equal(pads)
	assert_bool(_key_press(KEY_J).is_action_pressed("commons_hint")).is_true()
	assert_bool(_key_press(KEY_H).is_action_pressed("commons_hint")).is_false()
	assert_bool(bindings.is_default()).is_false()


func test_a_key_in_use_swaps() -> void:
	var bindings: KeyBindings = KeyBindings.new()
	assert_bool(bindings.bind("commons_hint", KEY_S)).is_true()
	assert_int(bindings.key("commons_hint")).is_equal(KEY_S)
	assert_int(bindings.key("commons_sort")).is_equal(KEY_H)
	assert_bool(_key_press(KEY_H).is_action_pressed("commons_sort")).is_true()
	assert_bool(_key_press(KEY_S).is_action_pressed("commons_sort")).is_false()
	var seen: Dictionary[Key, bool] = {}
	for action: String in KeyBindings.ACTIONS:
		seen[bindings.key(action)] = true
	assert_int(seen.size()).is_equal(KeyBindings.ACTIONS.size())


func test_escape_and_bare_modifiers_are_refused() -> void:
	var bindings: KeyBindings = KeyBindings.new()
	for key: Key in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_NONE]:
		(
			assert_bool(bindings.bind("commons_play", key))
			. override_failure_message(str(key))
			. is_false()
		)
	assert_bool(bindings.bind("commons_play", (KEY_J | KEY_MASK_SHIFT) as Key)).is_false()
	assert_bool(bindings.is_default()).is_true()
	# Keys the menus also use are allowed, as the defaults use them.
	for key: Key in [KEY_ENTER, KEY_DOWN, KEY_TAB, KEY_F5]:
		assert_bool(KeyBindings.allowed(key)).override_failure_message(str(key)).is_true()


func test_restoring_the_defaults() -> void:
	var bindings: KeyBindings = KeyBindings.new()
	bindings.bind("commons_play", KEY_P)
	bindings.bind("commons_cursor_left", KEY_A)
	bindings.restore_defaults()
	assert_bool(bindings.is_default()).is_true()
	assert_int(_key_events("commons_play")[0].physical_keycode).is_equal(KEY_ENTER)
	assert_int(_key_events("commons_cursor_left")[0].physical_keycode).is_equal(KEY_LEFT)


func test_the_settings_file_round_trip() -> void:
	var store: SettingsStore = auto_free(SettingsStore.new())
	store.load_from(PATH)
	assert_bool(store.bindings.is_default()).is_true()
	store.bindings.bind("commons_rules", KEY_F1)
	store.bindings.bind("commons_hint", KEY_S)
	assert_int(store.save()).is_equal(OK)
	var file: ConfigFile = ConfigFile.new()
	assert_int(file.load(PATH)).is_equal(OK)
	assert_int(int(file.get_value(KeyBindings.SECTION, "commons_rules"))).is_equal(KEY_F1)
	var reloaded: SettingsStore = auto_free(SettingsStore.new())
	reloaded.load_from(PATH)
	assert_int(reloaded.bindings.key("commons_rules")).is_equal(KEY_F1)
	assert_int(reloaded.bindings.key("commons_hint")).is_equal(KEY_S)
	assert_int(reloaded.bindings.key("commons_sort")).is_equal(KEY_H)
	assert_int(reloaded.bindings.key("commons_play")).is_equal(KEY_ENTER)


## Missing, not a key, a string, Escape or a modifier: that action's default, the rest
## as written.
func test_each_bad_value_falls_back_to_its_default() -> void:
	var bad: Dictionary[String, Variant] = {
		"commons_pass": "Space",
		"commons_hint": 12345678,
		"commons_sort": KEY_ESCAPE,
		"commons_rules": KEY_SHIFT,
		"commons_select": -3,
	}
	var file: ConfigFile = ConfigFile.new()
	for action: String in bad:
		file.set_value(KeyBindings.SECTION, action, bad[action])
	file.set_value(KeyBindings.SECTION, "commons_play", int(KEY_P))
	# commons_campaign and the cursor keys are missing.
	var bindings: KeyBindings = KeyBindings.new()
	bindings.read(file)
	assert_int(bindings.key("commons_play")).is_equal(KEY_P)
	var defaults: Dictionary[String, Key] = KeyBindings.defaults()
	for action: String in KeyBindings.ACTIONS:
		if action != "commons_play":
			assert_int(bindings.key(action)).override_failure_message(action).is_equal(
				defaults[action]
			)


## Two actions on one key after the fallbacks: every key is the default.
func test_a_clash_in_the_file_sends_every_key_home() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value(KeyBindings.SECTION, "commons_play", int(KEY_P))
	file.set_value(KeyBindings.SECTION, "commons_rules", int(KEY_F2))
	file.set_value(KeyBindings.SECTION, "commons_hint", int(KEY_P))
	var bindings: KeyBindings = KeyBindings.new()
	bindings.read(file)
	assert_bool(bindings.is_default()).is_true()
	# A bad value that falls back onto a key another action took is a clash too.
	var fallen: ConfigFile = ConfigFile.new()
	fallen.set_value(KeyBindings.SECTION, "commons_play", int(KEY_H))
	fallen.set_value(KeyBindings.SECTION, "commons_hint", "nonsense")
	bindings.read(fallen)
	assert_bool(bindings.is_default()).is_true()


func test_a_missing_file_loads_the_defaults() -> void:
	var store: SettingsStore = auto_free(SettingsStore.new())
	store.load_from("user://no_such_settings_file.cfg")
	assert_bool(store.bindings.is_default()).is_true()


## Every commons_ action in the project has a key, a row on the page, a name and a pad
## button's name in the table.
func test_every_action_has_a_binding_a_row_and_a_string() -> void:
	var found: Array[String] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var name: String = property["name"]
		if name.begins_with("input/" + ACTION_PREFIX):
			found.append(name.trim_prefix("input/"))
	assert_array(found).contains_exactly_in_any_order(KeyBindings.ACTIONS)
	var page: ControlsPage = auto_free(ControlsPage.new())
	add_child(page)
	for action: String in found:
		assert_int(KeyBindings.default_key(action)).override_failure_message(action).is_not_equal(
			KEY_NONE
		)
		assert_object(page.ticket(action)).override_failure_message(action).is_not_null()
		var key: String = "controls.action." + action
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
		assert_str(ControlsPage.pad_name(action)).override_failure_message(action).is_not_empty()


func test_a_key_label_names_the_key() -> void:
	assert_str(KeyBindings.label(KEY_H)).is_equal("H")
	assert_str(KeyBindings.label(KEY_ENTER)).is_equal("Enter")
	assert_str(KeyBindings.label(KEY_SPACE)).is_equal("Space")
