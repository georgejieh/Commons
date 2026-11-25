extends GdUnitTestSuite
## Only the allowed singletons are autoloads, and none of them holds run state.

const ALLOWED: Dictionary[String, String] = {
	"Settings": "res://game/autoload/settings.gd",
	"Strings": "res://game/autoload/strings.gd",
	"Saves": "res://game/autoload/saves.gd",
	"Audio": "res://game/autoload/audio.gd",
}
## Development add-ons that export presets exclude (ADR 0017).
const DEV_ONLY_PREFIX: String = "res://addons/godot_ai/"
## Types that carry a run. An autoload may not name or hold any of them.
const RUN_TYPES: Array[String] = [
	"RunState", "RunLoop", "RunController", "RoundState", "RunRecord", "SetLog", "Hand"
]


func test_autoload_list_matches_exactly() -> void:
	var found: Dictionary[String, String] = {}
	for property: Dictionary in ProjectSettings.get_property_list():
		var name: String = property["name"]
		if not name.begins_with("autoload/"):
			continue
		var path: String = str(ProjectSettings.get_setting(name)).trim_prefix("*")
		if path.begins_with(DEV_ONLY_PREFIX):
			continue
		found[name.trim_prefix("autoload/")] = path
	assert_dict(found).is_equal(ALLOWED)


func test_dev_only_autoloads_never_ship() -> void:
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var filter: String = DEV_ONLY_PREFIX.trim_prefix("res://") + "*"
	for line: String in presets.split("\n"):
		if line.begins_with("exclude_filter="):
			assert_str(line).contains(filter)


func test_no_autoload_names_a_run_type() -> void:
	var pattern: RegEx = RegEx.create_from_string("\\b(%s)\\b" % "|".join(RUN_TYPES))
	for path: String in ALLOWED.values():
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = line.get_slice("#", 0)
			(
				assert_object(pattern.search(code))
				. override_failure_message(path + ": " + line)
				. is_null()
			)


func test_no_autoload_holds_an_object_field() -> void:
	for path: String in ALLOWED.values():
		var script: GDScript = load(path)
		var node: Node = auto_free(script.new())
		for property: Dictionary in node.get_property_list():
			if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				continue
			var held: Variant = node.get(property["name"])
			if held is Object:
				# The music, voice, effects and ambience players hold audio, cues and line
				# plans, never run state; the key bindings hold keys.
				var allowed: bool = (
					held is SaveService
					or held is MusicPlayer
					or held is VoicePlayer
					or held is SfxPlayer
					or held is AmbiencePlayer
					or held is KeyBindings
				)
				(
					assert_bool(allowed)
					. override_failure_message(path + ": " + property["name"])
					. is_true()
				)


func test_settings_default_then_round_trip_through_the_file() -> void:
	var path: String = "user://test_settings.cfg"
	DirAccess.remove_absolute(path)
	var settings: SettingsStore = auto_free(SettingsStore.new())
	settings.load_from(path)
	assert_bool(settings.value("reduced_motion")).is_false()
	settings.set_value("reduced_motion", true)
	settings.set_value("music_volume", 0.25)
	assert_int(settings.save()).is_equal(OK)
	var reloaded: SettingsStore = auto_free(SettingsStore.new())
	reloaded.load_from(path)
	assert_bool(reloaded.value("reduced_motion")).is_true()
	assert_float(reloaded.value("music_volume")).is_equal(0.25)
	DirAccess.remove_absolute(path)


## Settings are written whole and renamed into place: a write that cannot be finished
## leaves the last file as it was.
func test_a_settings_write_that_cannot_finish_leaves_the_last_file() -> void:
	var folder: String = "user://test_settings_write/"
	var path: String = folder + "settings.cfg"
	DirAccess.make_dir_recursive_absolute(folder)
	var settings: SettingsStore = auto_free(SettingsStore.new())
	settings.load_from(path)
	settings.set_value("music_volume", 0.25)
	assert_int(settings.save()).is_equal(OK)
	var last: String = FileAccess.get_file_as_string(path)
	# A folder where the temporary file would go: the write cannot open it.
	DirAccess.make_dir_recursive_absolute(path + SaveService.TEMP_SUFFIX)
	settings.set_value("music_volume", 0.75)
	assert_int(settings.save()).is_not_equal(OK)
	assert_str(FileAccess.get_file_as_string(path)).is_equal(last)
	DirAccess.remove_absolute(path + SaveService.TEMP_SUFFIX)
	assert_int(settings.save()).is_equal(OK)
	assert_bool(FileAccess.file_exists(path + SaveService.TEMP_SUFFIX)).is_false()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)


func test_strings_count_with_the_one_form_when_the_table_has_it() -> void:
	var strings: StringTable = auto_free(StringTable.new())
	assert_str(strings.count("summary.paid", 1)).is_equal(tr("summary.paid.one"))
	assert_str(strings.count("summary.paid", 3)).is_equal(tr("summary.paid").format({"count": 3}))
	assert_str(strings.count("file.stamp.entries", 0)).contains("0")


func test_audio_adds_the_three_buses() -> void:
	var audio: AudioMixer = auto_free(AudioMixer.new())
	audio.ensure_buses()
	for bus: String in ["Music", "Effects", "Voice"]:
		assert_int(AudioServer.get_bus_index(bus)).is_not_equal(-1)


## A debug build takes another settings file from the environment, which is how the test
## run keeps a file of its own; a release build never does. Without one, the game keeps the
## player's file and a tool or test the sandbox's.
func test_settings_file_can_be_overridden_only_in_a_debug_build() -> void:
	var other: String = "user://other.cfg"
	var sandboxed: String = SavePaths.of(SettingsStore.PATH, false)
	for normal: bool in [true, false]:
		assert_str(SettingsStore.start_path(true, other, normal)).is_equal(other)
	assert_str(SettingsStore.start_path(true, "", true)).is_equal(SettingsStore.PATH)
	assert_str(SettingsStore.start_path(false, other, true)).is_equal(SettingsStore.PATH)
	assert_str(SettingsStore.start_path(true, "", false)).is_equal(sandboxed)
	assert_str(SettingsStore.start_path(false, other, false)).is_equal(sandboxed)
	assert_str(sandboxed).is_equal("user://tools/settings.cfg")


func test_the_test_run_uses_its_own_settings_file() -> void:
	(
		assert_str(OS.get_environment(SettingsStore.PATH_OVERRIDE))
		. override_failure_message("Run the tests with tools/test.sh, which sets COMMONS_SETTINGS.")
		. is_not_empty()
	)
