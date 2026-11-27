extends GdUnitTestSuite
## Every project script compiles under the project's warning rules.

const BROKEN: String = "res://tests/fixtures/broken/"
## The engine warnings project.godot makes errors, so a script that trips one does not load.
const ERRORS: Array[String] = [
	"untyped_declaration",
	"unsafe_property_access",
	"unsafe_method_access",
	"unsafe_cast",
	"unused_variable",
	"unused_local_constant",
	"unused_private_class_variable",
	"unused_parameter",
	"unused_signal",
	"unreachable_code",
	"unreachable_pattern",
	"standalone_expression",
	"standalone_ternary",
	"assert_always_true",
	"assert_always_false",
	"unassigned_variable",
	"enum_variable_without_default",
	"redundant_await",
	"integer_division",
	"narrowing_conversion",
	"static_called_on_instance",
]


func test_all_project_scripts_compile() -> void:
	var scripts: PackedStringArray = ScriptCheck.scripts_under("res://")
	assert_array(scripts).contains(["res://tools/script_check.gd"])

	var failures: PackedStringArray = []
	for path: String in scripts:
		if not ScriptCheck.compiles(path):
			failures.append(path)
	assert_array(failures).is_empty()


func test_valid_script_passes_the_gate() -> void:
	assert_int(_check_in_new_process("res://tools/script_check.gd")).is_equal(0)


func test_type_error_is_caught() -> void:
	assert_int(_check_in_new_process(BROKEN + "type_error.gd")).is_equal(1)


func test_untyped_variable_is_caught() -> void:
	assert_int(_check_in_new_process(BROKEN + "untyped.gd")).is_equal(1)


func test_warning_settings_stay_errors() -> void:
	for warning: String in ERRORS:
		var setting: String = "debug/gdscript/warnings/" + warning
		(
			assert_int(ProjectSettings.get_setting(setting))
			. override_failure_message("%s is no longer an error" % setting)
			. is_equal(2)
		)


func test_add_ons_are_the_only_folder_spared_warnings() -> void:
	var rules: Dictionary = ProjectSettings.get_setting("debug/gdscript/warnings/directory_rules")
	assert_dict(rules).is_equal({"res://addons": 0})


func _check_in_new_process(path: String) -> int:
	var arguments: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tools/check_script.gd",
		"--",
		"--check",
		path,
	]
	# OS.execute has no time limit of its own: tools/test.sh bounds the whole run.
	return OS.execute(OS.get_executable_path(), arguments)
