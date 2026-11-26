class_name KeyBindings
extends RefCounted
## The keyboard keys of the eleven table actions (ADR 0035). Each action has one bare key,
## held as a physical keycode so it sits in the same place on any layout. The defaults
## are the keys the project's input settings give; the bindings in use replace only the
## key event of each action in the InputMap, so its gamepad button stays. A key already
## in use swaps, so no action is ever left without a key and no key does two things.
## Escape and the modifier keys alone are never bound. The Settings autoload holds one,
## loads and saves it with the settings file under its own section, and applies it.

## Plays the selected cards, or calls for the landlord seat.
const PLAY: String = "commons_play"
## Passes the turn, or declines the seat.
const PASS: String = "commons_pass"
## Offers a play.
const HINT: String = "commons_hint"
## Changes how the hand is sorted.
const SORT: String = "commons_sort"
## Opens the rules of the round.
const RULES: String = "commons_rules"
## Opens the Campaign tray.
const CAMPAIGN: String = "commons_campaign"
## Opens the deck.
const DECK: String = "commons_deck"
## Selects the card under the cursor.
const SELECT: String = "commons_select"
## Moves the cursor left along the hand.
const CURSOR_LEFT: String = "commons_cursor_left"
## Moves the cursor right along the hand.
const CURSOR_RIGHT: String = "commons_cursor_right"
## Sits out a trick the player cannot answer.
const SIT_OUT: String = "commons_sit_out"
## The actions that step a board's cursor, the engine's arrows and the table's own: the
## direction is the end of each name.
const CURSOR_STEPS: Array[String] = ["ui_left", CURSOR_LEFT, "ui_right", CURSOR_RIGHT]
## The actions whose keys can change, in the order the Controls page lists them.
const ACTIONS: Array[String] = [
	PLAY,
	PASS,
	HINT,
	SORT,
	RULES,
	CAMPAIGN,
	DECK,
	SELECT,
	CURSOR_LEFT,
	CURSOR_RIGHT,
	SIT_OUT,
]
## The section of the settings file the bindings live in.
const SECTION: String = "keys"
## Keys that cancel a capture or only change another key, never bound.
const REFUSED: Array[Key] = [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var _keys: Dictionary[String, Key] = {}


## Each action's key as the project's input settings give it.
## Which way an event steps a board's cursor along its cards: -1 left, 1 right, or 0 for
## an event that is no step.
static func cursor_step(event: InputEvent) -> int:
	for action: String in CURSOR_STEPS:
		if event.is_action_pressed(action, true):
			return -1 if action.ends_with("left") else 1
	return 0


## True for a press that picks what a board's cursor is on: accept, or the select key.
static func is_pick(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or event.is_action_pressed(SELECT)


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


func _init() -> void:
	_keys = defaults()


## The key bound to action.
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
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var bound: InputEventKey = InputEventKey.new()
		bound.physical_keycode = _keys[action]
		InputMap.action_add_event(action, bound)
