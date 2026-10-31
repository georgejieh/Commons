extends GdUnitTestSuite
## The layer check catches every form of randomness outside the stream service.

const FIXTURES: String = "res://tests/fixtures/layers/"


func test_global_random_call_fails() -> void:
	_assert_flagged("bad_random_global", "global random call")


func test_array_shuffle_fails() -> void:
	_assert_flagged("bad_random_shuffle", "global random call")


func test_array_pick_random_fails() -> void:
	_assert_flagged("bad_random_pick", "global random call")


func test_engine_generator_outside_service_fails() -> void:
	_assert_flagged("bad_random_generator", "engine generator")


func _assert_flagged(folder: String, reason: String) -> void:
	var report: String = "\n".join(LayerCheck.scan(FIXTURES + folder))
	assert_str(report).contains(reason)
