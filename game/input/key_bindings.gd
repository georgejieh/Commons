class_name KeyBindings
extends RefCounted
## The keyboard keys of the eleven table actions (ADR 0035). Each action has one bare key,
## held as a physical keycode so it sits in the same place on any layout. The defaults
## are the keys the project's input settings give; the bindings in use replace only the
## key event of each action in the InputMap, so its gamepad button stays. A key already
## in use swaps, so no action is ever left without a key and no key does two things.
## Escape and the modifier keys alone are never bound. The Settings autoload holds one,
## loads and saves it with the settings file under its own section, and applies it.

## The actions whose keys can change, in the order the Controls page lists them.
const ACTIONS: Array[String] = [
	"commons_play",
	"commons_pass",
	"commons_hint",
	"commons_sort",
	"commons_rules",
	"commons_campaign",
	"commons_deck",
	"commons_select",
	"commons_cursor_left",
	"commons_cursor_right",
	"commons_sit_out",
]
## The section of the settings file the bindings live in.
const SECTION: String = "keys"
## Keys that cancel a capture or only change another key, never bound.
const REFUSED: Array[Key] = [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var _keys: Dictionary[String, Key] = {}


func _init() -> void:
	_keys = defaults()


## Each action's key as the project's input settings give it.
static func defaults() -> Dictionary[String, Key]:
	var keys: Dictionary[String, Key] = {}
	for action: String in ACTIONS:
		keys[action] = default_key(action)
	return keys


## The physical key of the action's first key event in the project's input settings.
static func default_key(action: String) -> Key:
	var setting: Dictionary = ProjectSettings.get_setting("input/" + action, {})
	var events: Array = setting.get("events", [])
	for event: InputEvent in events:
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key_of(key)
	return KEY_NONE


## True for a key an action may have: a real key, bare, not Escape nor a modifier.
static func allowed(key: int) -> bool:
	if key <= 0 or key & KEY_MODIFIER_MASK != 0 or REFUSED.has(key):
		return false
	return OS.find_keycode_from_string(OS.get_keycode_string(key)) == key


## The key an event names: its physical key, or its key where it has none.
static func key_of(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


## The name printed on a key in the player's layout. A display server that cannot say,
## as a headless one cannot, gives the key's own name.
static func label(key: Key) -> String:
	var printed: Key = KEY_NONE
	if DisplayServer.get_name() != "headless":
		printed = DisplayServer.keyboard_get_label_from_physical(key)
	var text: String = OS.get_keycode_string(printed) if printed != KEY_NONE else ""
	return text if not text.is_empty() else OS.get_keycode_string(key)


func key(action: String) -> Key:
	assert(_keys.has(action), "Unknown action")
	return _keys[action]


## The action bound to key, or "" when none is.
func action_on(key: Key) -> String:
	for action: String in ACTIONS:
		if _keys[action] == key:
			return action
	return ""


## Binds key to action and applies it. An action that had the key takes the one action
## had. False, and nothing changes, for a key no action may have.
func bind(action: String, key: Key) -> bool:
	assert(_keys.has(action), "Unknown action")
	if not allowed(key):
		return false
	var other: String = action_on(key)
	if not other.is_empty():
		_keys[other] = _keys[action]
	_keys[action] = key
	apply()
	return true


func restore_defaults() -> void:
	_keys = defaults()
	apply()


func is_default() -> bool:
	return _keys == defaults()


## Reads the bindings from file. A value that is missing, not a key, Escape or a
## modifier falls back to that action's default; if two actions then share a key, every
## binding is the default.
func read(file: ConfigFile) -> void:
	var read_keys: Dictionary[String, Key] = defaults()
	for action: String in ACTIONS:
		if not file.has_section_key(SECTION, action):
			continue
		var value: Variant = file.get_value(SECTION, action)
		if value is int and allowed(value):
			read_keys[action] = value
	var seen: Dictionary[Key, bool] = {}
	for action: String in ACTIONS:
		seen[read_keys[action]] = true
	_keys = read_keys if seen.size() == ACTIONS.size() else defaults()


func write(file: ConfigFile) -> void:
	for action: String in ACTIONS:
		file.set_value(SECTION, action, int(_keys[action]))


## Puts each action's key in the InputMap in place of its key event, leaving its gamepad
## button and anything else it has.
func apply() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var bound: InputEventKey = InputEventKey.new()
		bound.physical_keycode = _keys[action]
		InputMap.action_add_event(action, bound)
