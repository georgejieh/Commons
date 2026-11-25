class_name SettingsStore
extends Node
## The Settings autoload: the player's settings, loaded from and saved to one file in the
## user data folder. It holds preferences only, never run state.

signal changed(key: String)

const PATH: String = "user://settings.cfg"
## A debug build reads this environment variable for another file, so the test run keeps
## its own settings and never touches the player's (tools/test.sh sets it). The keys of
## the table actions (ADR 0035) live in the same file, in their own section, and are
## applied to the InputMap as the game starts, before any screen.
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
	"text_size",
	"table_pace",
	"show_hint",
	"window_mode",
	"window_size",
	"vsync",
]

## The keyboard bindings. They apply to the InputMap at once whenever they change.
var bindings: KeyBindings = KeyBindings.new()
var _values: Dictionary[String, Variant] = {}
var _path: String = PATH


func _ready() -> void:
	var normal: bool = SavePaths.normal_launch(get_tree())
	load_from(start_path(OS.is_debug_build(), OS.get_environment(PATH_OVERRIDE), normal))
	bindings.apply()


## The file settings start from: in a debug build the override when one is given, else
## the player's on a launch of the game, or the sandbox's for a tool or test (SavePaths).
static func start_path(debug: bool, override: String, normal: bool) -> String:
	if debug and not override.is_empty():
		return override
	return SavePaths.of(PATH, normal)


## Reads settings from path, falling back to the defaults for anything missing.
func load_from(path: String) -> void:
	_path = path
	var file: ConfigFile = ConfigFile.new()
	var loaded: bool = file.load(path) == OK
	for key: String in KEYS:
		var fallback: Variant = DEFAULTS.get(key)
		_values[key] = file.get_value(SECTION, key, fallback) if loaded else fallback
	bindings.read(file if loaded else ConfigFile.new())


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
	bindings.write(file)
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	return file.save(_path)


## From now on saves go to path; the values held stay as they are. The playtest tools
## use it, so what they set for a run never reaches the player's file.
func save_to(path: String) -> void:
	_path = path
