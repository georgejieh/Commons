extends GdUnitTestSuite
## Streams are stable, independent and resume exactly from saved state.

const SEED: int = 2026
const DRAWS: int = 200
## Above 2^53, so a JSON number could not hold it.
const UNSAFE_JSON_SEED: int = 9007199254740993


func test_stable_hash_matches_published_fnv1a_vectors() -> void:
	assert_int(RandomStreams.stable_hash("".to_utf8_buffer())).is_equal(-3750763034362895579)
	assert_int(RandomStreams.stable_hash("a".to_utf8_buffer())).is_equal(-5808556873153909620)


func test_each_stream_gets_a_distinct_seed() -> void:
	var seeds: Dictionary[int, bool] = {}
	for stream_name: String in RandomStreams.NAMES:
		seeds[RandomStreams.derive_seed(SEED, stream_name)] = true
	assert_int(seeds.size()).is_equal(RandomStreams.NAMES.size())


func test_streams_are_independent() -> void:
	var quiet: RandomStreams = RandomStreams.new(SEED)
	var busy: RandomStreams = RandomStreams.new(SEED)
	for _i: int in DRAWS:
		busy.stream(RandomStreams.SHOP).next_float()
	assert_bool(_draws(busy, RandomStreams.DEAL) == _draws(quiet, RandomStreams.DEAL)).is_true()


func test_different_run_seeds_give_different_draws() -> void:
	var first: PackedInt32Array = _draws(RandomStreams.new(SEED), RandomStreams.DEAL)
	var second: PackedInt32Array = _draws(RandomStreams.new(SEED + 1), RandomStreams.DEAL)
	assert_bool(first == second).is_false()


func test_saved_state_resumes_every_stream_through_json() -> void:
	var original: RandomStreams = RandomStreams.new(UNSAFE_JSON_SEED)
	for stream_name: String in RandomStreams.NAMES:
		_draws(original, stream_name)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	var restored: RandomStreams = RandomStreams.from_dict(saved)
	for stream_name: String in RandomStreams.NAMES:
		assert_bool(_draws(restored, stream_name) == _draws(original, stream_name)).is_true()
	assert_str(JSON.stringify(restored.to_dict())).is_equal(JSON.stringify(original.to_dict()))


func _draws(streams: RandomStreams, stream_name: String) -> PackedInt32Array:
	var values: PackedInt32Array = []
	for _i: int in DRAWS:
		values.append(streams.stream(stream_name).next_int(0, 1000000))
	return values
