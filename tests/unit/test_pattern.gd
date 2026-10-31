extends GdUnitTestSuite
## Equal patterns compare and hash equal, and keys order plays of one shape.


func _trio_single(main: int, kicker: int, effective: int = main) -> Pattern:
	return Pattern.new(Pattern.Type.TRIO_SINGLE, main, 1, 4, PackedByteArray([kicker]), effective)


func _airplane(type: Pattern.Type) -> Pattern:
	var kickers: PackedByteArray = PackedByteArray([Ranks.NINE, Ranks.NINE])
	return Pattern.new(type, Ranks.THREE, 2, 8, kickers, Ranks.THREE)


func test_equal_patterns_compare_and_hash_equal() -> void:
	var first: Pattern = _trio_single(Ranks.FIVE, Ranks.NINE)
	var second: Pattern = _trio_single(Ranks.FIVE, Ranks.NINE)
	assert_bool(first.equals(second)).is_true()
	assert_int(first.key).is_equal(second.key)
	assert_int(first.identity()).is_equal(second.identity())


func test_kickers_change_identity_but_not_the_key() -> void:
	var first: Pattern = _trio_single(Ranks.FIVE, Ranks.NINE)
	var second: Pattern = _trio_single(Ranks.FIVE, Ranks.TEN)
	assert_bool(first.equals(second)).is_false()
	assert_int(first.key).is_equal(second.key)


func test_type_changes_identity_when_the_cards_match() -> void:
	var pairs: Pattern = _airplane(Pattern.Type.AIRPLANE_PAIRS)
	var singles: Pattern = _airplane(Pattern.Type.AIRPLANE_SINGLES)
	assert_int(pairs.identity()).is_not_equal(singles.identity())


func test_key_orders_one_shape_by_main_rank() -> void:
	for rank: int in range(Ranks.THREE, Ranks.TWO):
		var lower: Pattern = _trio_single(rank, Ranks.BIG_JOKER)
		var higher: Pattern = _trio_single(rank + 1, Ranks.THREE)
		assert_int(lower.shape()).is_equal(higher.shape())
		assert_bool(higher.key > lower.key).is_true()


func test_key_uses_the_effective_rank() -> void:
	var promoted: Pattern = _trio_single(Ranks.THREE, Ranks.NINE, Ranks.TWO)
	var plain: Pattern = _trio_single(Ranks.ACE, Ranks.NINE)
	assert_int(promoted.main_rank).is_equal(Ranks.THREE)
	assert_bool(promoted.key > plain.key).is_true()


func test_different_lengths_are_different_shapes() -> void:
	var none: PackedByteArray = PackedByteArray()
	var short: Pattern = Pattern.new(Pattern.Type.STRAIGHT, Ranks.THREE, 5, 5, none, Ranks.THREE)
	var long: Pattern = Pattern.new(Pattern.Type.STRAIGHT, Ranks.THREE, 6, 6, none, Ranks.THREE)
	assert_int(short.shape()).is_not_equal(long.shape())


func test_counts_reproduce_each_part_of_a_play() -> void:
	var kickers: PackedByteArray = PackedByteArray(
		[Ranks.THREE, Ranks.THREE, Ranks.NINE, Ranks.NINE]
	)
	var pattern: Pattern = Pattern.new(
		Pattern.Type.AIRPLANE_PAIRS, Ranks.FIVE, 2, 10, kickers, Ranks.FIVE
	)
	var counts: PackedByteArray = pattern.counts()
	assert_int(counts[Ranks.FIVE]).is_equal(3)
	assert_int(counts[Ranks.SIX]).is_equal(3)
	assert_int(counts[Ranks.THREE]).is_equal(2)
	assert_int(counts[Ranks.NINE]).is_equal(2)


func test_a_pass_has_no_cards() -> void:
	var counts: PackedByteArray = Pattern.pass_play().counts()
	assert_int(Array(counts).max()).is_equal(0)
