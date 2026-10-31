extends GdUnitTestSuite
## Every project script compiles under the project's warning rules.

const BROKEN: String = "res://tests/fixtures/broken/"


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
	for warning: String in [
		"untyped_declaration", "unsafe_property_access", "unsafe_method_access", "unsafe_cast"
	]:
		var setting: String = "debug/gdscript/warnings/" + warning
		assert_int(ProjectSettings.get_setting(setting)).is_equal(2)


func _check_in_new_process(path: String) -> int:
	var arguments: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tools/check_script.gd",
		"--",
		path,
	]
	return OS.execute(OS.get_executable_path(), arguments)
