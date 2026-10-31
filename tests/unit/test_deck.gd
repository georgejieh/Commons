extends GdUnitTestSuite
## The base deck's IDs, rank counts and suits.


func test_deck_has_54_unique_ids() -> void:
	var seen: Dictionary[int, bool] = {}
	for id: int in Deck.generate():
		seen[id] = true
	assert_int(Deck.generate().size()).is_equal(54)
	assert_int(seen.size()).is_equal(54)
	assert_bool(seen.has(0) and seen.has(53)).is_true()


func test_four_per_rank_and_one_of_each_joker() -> void:
	var counts: PackedInt32Array = []
	counts.resize(Ranks.COUNT)
	for id: int in Deck.generate():
		counts[Deck.rank_of(id)] += 1
	for rank: int in Ranks.SMALL_JOKER:
		assert_int(counts[rank]).is_equal(4)
	assert_int(counts[Ranks.SMALL_JOKER]).is_equal(1)
	assert_int(counts[Ranks.BIG_JOKER]).is_equal(1)


func test_id_encodes_rank_times_four_plus_suit() -> void:
	for id: int in Deck.SMALL_JOKER_ID:
		assert_int(Deck.rank_of(id) * 4 + Deck.suit_of(id)).is_equal(id)


func test_jokers_have_no_suit() -> void:
	assert_int(Deck.suit_of(Deck.SMALL_JOKER_ID)).is_equal(Deck.NO_SUIT)
	assert_int(Deck.suit_of(Deck.BIG_JOKER_ID)).is_equal(Deck.NO_SUIT)
