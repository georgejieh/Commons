extends GdUnitTestSuite
## tools/perf_budget.gd, run headless with tiny samples in its own process: it writes a
## report with every headless row, and every windowed row marked NOT MEASURED even when
## asked for, since there is no window. It exits 1 exactly when a measured row missed.

const REPORT: String = "user://test_perf_budget/report.md"
const HEADLESS_ROWS: Array[String] = [
	"Hand classification",
	"Legal moves, 20-card hand",
	"Bot decision, Easy",
	"Bot decision, Medium",
	"Bot decision, Hard",
	"Bot decision, Expert",
	"Save file size",
	"Save time",
	"Load time",
	"Resume time",
	"Static memory, run loaded (headless)",
	"Resident memory, run loaded (headless)",
]
const WINDOWED_ROWS: Array[String] = [
	"Startup to title",
	"Frame time during play",
	"Nodes made during a round",
	"Resident memory, table open",
]
const TINY: PackedStringArray = [
	"--hands",
	"100",
	"--movegen-hands",
	"20",
	"--bot-deals",
	"1",
	"--expert-deals",
	"1",
	"--save-sets",
	"1",
	"--save-reps",
	"2",
]


func after_test() -> void:
	DirAccess.remove_absolute(REPORT)


func _run(extra: PackedStringArray) -> int:
	var arguments: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tools/perf_budget.gd",
		"--",
	]
	arguments.append_array(TINY)
	arguments.append_array(extra)
	arguments.append_array(["--out", REPORT])
	return OS.execute(OS.get_executable_path(), arguments)


func _row(text: String, row_name: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("| %s |" % row_name):
			return line
	return ""


func test_the_headless_report_has_every_row_and_the_exit_code_follows_the_misses() -> void:
	var code: int = _run(PackedStringArray(["--windowed-rows"]))
	var text: String = FileAccess.get_file_as_string(REPORT)
	assert_str(text).contains("# Performance budget")
	assert_str(text).contains("- Godot: ")
	for row_name: String in HEADLESS_ROWS:
		var line: String = _row(text, row_name)
		assert_str(line).override_failure_message("no row %s" % row_name).is_not_empty()
		assert_str(line).override_failure_message(line).not_contains("NOT MEASURED")
	for row_name: String in WINDOWED_ROWS:
		assert_str(_row(text, row_name)).contains("| NOT MEASURED |")
		assert_str(_row(text, row_name)).contains("needs a window")
	var missed: bool = text.contains("| MISS |")
	assert_int(code).is_equal(1 if missed else 0)
