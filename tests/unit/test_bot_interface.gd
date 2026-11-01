extends GdUnitTestSuite
## The bot interface, its budget, and what it keeps out of release builds.

const SCANNED_FOLDERS: PackedStringArray = ["res://core/", "res://game/", "res://ui/"]
const EXPORT_PRESETS: String = "res://export_presets.cfg"
const BOT_FOLDER: String = "res://core/bots/"
## Everything in core/bots/ except the interface and what callers must pass or read.
const PUBLIC_FILES: PackedStringArray = [
	"bot.gd",
	"bot_budget.gd",
	"bot_config.gd",
	"bot_play.gd",
	"bot_rationale.gd",
	"bot_search_job.gd",
	"bot_table.gd"
]

var _now: int = 0


func _clock() -> int:
	return _now


func _script_files(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "gd":
			found.append(folder.path_join(file))
	for child: String in DirAccess.get_directories_at(folder):
		found.append_array(_script_files(folder.path_join(child)))
	return found


func _private_bot_classes() -> PackedStringArray:
	var names: PackedStringArray = []
	for path: String in _script_files(BOT_FOLDER):
		if path.get_file() in PUBLIC_FILES:
			continue
		var script: GDScript = load(path)
		names.append(script.get_global_name())
	return names


func test_a_budget_expires_on_its_clock() -> void:
	var budget: BotBudget = BotBudget.new(100, _clock)
	assert_bool(budget.is_expired()).is_false()
	_now = 99
	assert_bool(budget.is_expired()).is_false()
	_now = 100
	assert_bool(budget.is_expired()).is_true()


func test_a_budget_with_no_clock_never_expires() -> void:
	assert_bool(BotBudget.new(1).is_expired()).is_false()
	assert_bool(BotBudget.unlimited().is_expired()).is_false()


func test_only_the_interface_is_used_outside_the_bots_folder() -> void:
	var private_names: PackedStringArray = _private_bot_classes()
	for folder: String in SCANNED_FOLDERS:
		for path: String in _script_files(folder):
			if path.begins_with(BOT_FOLDER):
				continue
			var text: String = FileAccess.get_file_as_string(path)
			for name: String in private_names:
				(
					assert_bool(text.contains(name))
					. override_failure_message("%s reaches %s" % [path, name])
					. is_false()
				)


func test_every_rationale_code_has_debug_text() -> void:
	for code: int in BotRationale.Code.values():
		assert_bool(BotRationaleText.TEXT.has(code)).is_true()


func test_exports_leave_out_the_rationale_text() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_int(presets.load(EXPORT_PRESETS)).is_equal(OK)
	for section: String in presets.get_sections():
		if section.ends_with(".options"):
			continue
		var filter: String = presets.get_value(section, "exclude_filter")
		assert_bool(filter.split(",").has("tools/*")).is_true()
