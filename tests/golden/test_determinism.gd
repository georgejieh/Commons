extends GdUnitTestSuite
## The same seed and inputs produce the same log, now and against the committed golden.

const GOLDEN_PATH: String = "res://tests/golden/determinism.golden"


func test_two_runs_produce_identical_logs() -> void:
	var first: PackedStringArray = DeterminismLog.build()
	var second: PackedStringArray = DeterminismLog.build()
	assert_bool(first == second).is_true()


func test_log_matches_the_golden_file() -> void:
	var text: String = "\n".join(DeterminismLog.build()) + "\n"
	assert_str(GoldenFile.text(GOLDEN_PATH, text)).is_equal(text)
