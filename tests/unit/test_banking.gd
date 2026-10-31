extends GdUnitTestSuite
## The Commons split is proportional and always sums to the pool.

const NEED_ROUNDS: int = 2000


func test_equal_needs_share_equally() -> void:
	assert_array(Array(Banking.split(90, PackedInt32Array([5, 5, 5])))).is_equal([30, 30, 30])


func test_a_zero_need_gets_nothing() -> void:
	assert_array(Array(Banking.split(100, PackedInt32Array([0, 1])))).is_equal([0, 100])


func test_no_need_at_all_shares_equally() -> void:
	assert_array(Array(Banking.split(10, PackedInt32Array([0, 0])))).is_equal([5, 5])


func test_an_extreme_need_takes_almost_everything() -> void:
	var shares: PackedInt32Array = Banking.split(1000, PackedInt32Array([1, 999999]))
	assert_int(shares[0]).is_equal(0)
	assert_int(shares[1]).is_equal(1000)


func test_a_caught_lie_recomputes_honestly() -> void:
	var lied: PackedInt32Array = Banking.split(100, PackedInt32Array([90, 10]))
	var honest: PackedInt32Array = Banking.split(100, PackedInt32Array([10, 10]))
	assert_array(Array(lied)).is_equal([90, 10])
	assert_array(Array(honest)).is_equal([50, 50])


func test_the_remainder_goes_to_the_neediest_then_seat_order() -> void:
	assert_array(Array(Banking.split(10, PackedInt32Array([1, 2])))).is_equal([3, 7])
	assert_array(Array(Banking.split(10, PackedInt32Array([1, 1, 1])))).is_equal([4, 3, 3])
	assert_array(Array(Banking.split(11, PackedInt32Array([1, 1, 1])))).is_equal([4, 4, 3])


func test_the_split_always_sums_to_the_pool() -> void:
	var stream: RandomStream = RandomStream.new(1907)
	for _round: int in NEED_ROUNDS:
		var needs: PackedInt32Array = PackedInt32Array()
		var pool: int = stream.next_int(0, 100000)
		for _seat: int in Seats.COUNT:
			needs.append(stream.next_int(0, 50))
		var total: int = 0
		for share: int in Banking.split(pool, needs):
			total += share
		assert_int(total).is_equal(pool)
