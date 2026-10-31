extends GdUnitTestSuite
## The layer check catches every form of randomness outside the stream service.

const FIXTURES: String = "res://tests/fixtures/layers/"


func test_card_setters_outside_the_service_fail() -> void:
	assert_str(_report("bad_card_setter")).contains("card setter outside CardModifiers")


func test_every_global_random_function_fails() -> void:
	var report: String = _report("bad_random_global")
	for random_name: String in ["randi", "randf", "randi_range", "randf_range", "randfn"]:
		assert_str(report).contains("global random use: %s\n" % random_name)
	for random_name: String in ["randomize", "rand_from_seed"]:
		assert_str(report).contains("global random use: %s\n" % random_name)
	assert_str(report).contains("global random use: seed(")


func test_array_shuffle_fails() -> void:
	assert_str(_report("bad_random_shuffle")).contains("global random use: shuffle")


func test_array_pick_random_fails() -> void:
	assert_str(_report("bad_random_pick")).contains("global random use: pick_random")


func test_engine_generator_outside_service_fails() -> void:
	assert_str(_report("bad_random_generator")).contains("engine generator")


func test_callable_references_fail() -> void:
	var report: String = _report("bad_random_reference")
	assert_str(report).contains("global random use: randi")
	assert_str(report).contains("global random use: shuffle")


func test_name_in_a_string_fails() -> void:
	assert_str(_report("bad_random_string")).contains("by name: shuffle")


func test_stream_private_generator_fails() -> void:
	assert_str(_report("bad_random_private")).contains("global random use: _rng")


func test_crypto_fails() -> void:
	assert_str(_report("bad_crypto")).contains("forbidden name: Crypto")


func test_translation_call_fails() -> void:
	assert_str(_report("bad_translate")).contains("forbidden name: tr")


func _report(folder: String) -> String:
	return "\n".join(LayerCheck.scan(FIXTURES + folder)) + "\n"
