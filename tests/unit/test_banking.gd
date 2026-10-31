extends GdUnitTestSuite
## The Commons split is proportional and always sums to the pool.

const NEED_ROUNDS: int = 2000


func test_the_split_holds_at_the_largest_pool() -> void:
	var pool: int = Banking.MAX_POOL
	var needs: Array[PackedInt64Array] = [
		PackedInt64Array([1, 1]),
		PackedInt64Array([3, 1, 2]),
		PackedInt64Array([Banking.MAX_NEED, 1, Banking.MAX_NEED]),
	]
	for need: PackedInt64Array in needs:
		var total: int = 0
		for share: int in Banking.split(pool, need):
			assert_bool(share >= 0).is_true()
			total += share
		assert_int(total).is_equal(pool)


func test_declared_needs_clamp() -> void:
	assert_array(Array(Banking.split(100, PackedInt64Array([-1, 3])))).is_equal([0, 100])


func test_scores_become_whole_pool_units() -> void:
	assert_int(Banking.to_pool_units(256.5)).is_equal(256)
	assert_int(Banking.to_pool_units(-14.0)).is_equal(0)
	assert_int(Banking.to_pool_units(Scorer.MAX_SCORE)).is_equal(Banking.MAX_POOL)
	assert_int(Banking.to_pool_units(NAN)).is_equal(Banking.MAX_POOL)


func test_equal_needs_share_equally() -> void:
	assert_array(Array(Banking.split(90, PackedInt64Array([5, 5, 5])))).is_equal([30, 30, 30])


func test_a_zero_need_gets_nothing() -> void:
	assert_array(Array(Banking.split(100, PackedInt64Array([0, 1])))).is_equal([0, 100])


func test_no_need_at_all_shares_equally() -> void:
	assert_array(Array(Banking.split(10, PackedInt64Array([0, 0])))).is_equal([5, 5])


func test_an_extreme_need_takes_almost_everything() -> void:
	var shares: PackedInt64Array = Banking.split(1000, PackedInt64Array([1, 999999]))
	assert_int(shares[0]).is_equal(0)
	assert_int(shares[1]).is_equal(1000)


func test_a_caught_lie_recomputes_honestly() -> void:
	var lied: PackedInt64Array = Banking.split(100, PackedInt64Array([90, 10]))
	var honest: PackedInt64Array = Banking.split(100, PackedInt64Array([10, 10]))
	assert_array(Array(lied)).is_equal([90, 10])
	assert_array(Array(honest)).is_equal([50, 50])


func test_the_remainder_goes_to_the_neediest_then_seat_order() -> void:
	assert_array(Array(Banking.split(10, PackedInt64Array([1, 2])))).is_equal([3, 7])
	assert_array(Array(Banking.split(10, PackedInt64Array([1, 1, 1])))).is_equal([4, 3, 3])
	assert_array(Array(Banking.split(11, PackedInt64Array([1, 1, 1])))).is_equal([4, 4, 3])


func test_the_split_always_sums_to_the_pool() -> void:
	var stream: RandomStream = RandomStream.new(1907)
	for _round: int in NEED_ROUNDS:
		var needs: PackedInt64Array = PackedInt64Array()
		var pool: int = stream.next_int(0, 100000)
		for _seat: int in Seats.COUNT:
			needs.append(stream.next_int(0, 50))
		var total: int = 0
		for share: int in Banking.split(pool, needs):
			total += share
		assert_int(total).is_equal(pool)
