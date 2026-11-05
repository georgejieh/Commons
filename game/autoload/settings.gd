class_name SettingsStore
extends Node
## The Settings autoload: the player's settings, loaded from and saved to one file in the
## user data folder. It holds preferences only, never run state.

signal changed(key: String)

const PATH: String = "user://settings.cfg"
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
]

var _values: Dictionary[String, Variant] = {}
var _path: String = PATH


func _ready() -> void:
	load_from(PATH)


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
