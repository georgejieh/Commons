extends GdUnitTestSuite
## Count keys round-trip, and distinct vectors never share a key.

const ITERATIONS: int = 100000
const SEED: int = 1103


func test_random_vectors_round_trip_without_collisions() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var vector_by_key: Dictionary[int, PackedByteArray] = {}
	var failures: int = 0
	for _i: int in ITERATIONS:
		var counts: PackedByteArray = _random_counts(rng)
		var key: int = CountKey.encode(counts)
		if CountKey.decode(key) != counts:
			failures += 1
		if vector_by_key.has(key) and vector_by_key[key] != counts:
			failures += 1
		vector_by_key[key] = counts
	assert_int(failures).is_equal(0)
	assert_int(vector_by_key.size()).is_greater(ITERATIONS - 10)


func test_full_vector_stays_positive_and_round_trips() -> void:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts.fill(CountKey.MAX_COUNT)
	assert_int(CountKey.encode(counts)).is_greater(0)
	assert_array(CountKey.decode(CountKey.encode(counts))).is_equal(counts)


func _random_counts(rng: RandomNumberGenerator) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for rank: int in Ranks.COUNT:
		counts[rank] = rng.randi_range(0, CountKey.MAX_COUNT)
	return counts
