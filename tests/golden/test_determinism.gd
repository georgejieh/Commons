extends GdUnitTestSuite
## The same seed and inputs produce the same log, now and against the committed golden.
## Set UPDATE_GOLDEN=1 to rewrite the golden file after an intended change.

const GOLDEN_PATH: String = "res://tests/golden/determinism.golden"


func test_two_runs_produce_identical_logs() -> void:
	var first: PackedStringArray = DeterminismLog.build()
	var second: PackedStringArray = DeterminismLog.build()
	assert_bool(first == second).is_true()


func test_log_matches_the_golden_file() -> void:
	var text: String = "\n".join(DeterminismLog.build()) + "\n"
	if OS.get_environment("UPDATE_GOLDEN") == "1":
		var file: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	var golden: String = FileAccess.get_file_as_string(GOLDEN_PATH)
	assert_str(golden.replace("\r", "")).is_equal(text)
