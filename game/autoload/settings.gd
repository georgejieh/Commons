class_name SettingsStore
extends Node
## The Settings autoload: the player's settings, loaded from and saved to one file in the
## user data folder. It holds preferences only, never run state.

signal changed(key: String)

const PATH: String = "user://settings.cfg"
## A debug build reads this environment variable for another file, so the test run keeps
## its own settings and never touches the player's (tools/test.sh sets it).
const PATH_OVERRIDE: String = "COMMONS_SETTINGS"
const SECTION: String = "settings"
const DEFAULTS: SettingsParams = preload("res://data/settings/default_settings.tres")
const KEYS: Array[String] = [
	"music_volume",
	"effects_volume",
	"voice_volume",
	"reduced_motion",
	"post_process",
	"horror_intensity",
	"no_flash",
	"content_note_seen",
	"card_back",
]

var _values: Dictionary[String, Variant] = {}
var _path: String = PATH


func _ready() -> void:
	load_from(start_path(OS.is_debug_build(), OS.get_environment(PATH_OVERRIDE)))


## The file settings start from: the player's, or in a debug build the override when one
## is given.
static func start_path(debug: bool, override: String) -> String:
	return override if debug and not override.is_empty() else PATH


## Reads settings from path, falling back to the defaults for anything missing.
func load_from(path: String) -> void:
	_path = path
	var file: ConfigFile = ConfigFile.new()
	var loaded: bool = file.load(path) == OK
	for key: String in KEYS:
		var fallback: Variant = DEFAULTS.get(key)
		_values[key] = file.get_value(SECTION, key, fallback) if loaded else fallback


func value(key: String) -> Variant:
	assert(KEYS.has(key), "Unknown setting")
	return _values[key]


func set_value(key: String, new_value: Variant) -> void:
	assert(KEYS.has(key), "Unknown setting")
	_values[key] = new_value
	changed.emit(key)


func save() -> Error:
	var file: ConfigFile = ConfigFile.new()
	for key: String in KEYS:
		file.set_value(SECTION, key, _values[key])
	return file.save(_path)
