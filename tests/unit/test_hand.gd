extends GdUnitTestSuite
## Incremental counts and bitmask always match a recount from the instances.

const ITERATIONS: int = 10000
const SEED: int = 1102


func test_counts_and_mask_match_a_recount_after_random_operations() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var hand: Hand = Hand.new()
	var outside: Array[CardInstance] = _all_cards()
	var mismatches: int = 0
	for _i: int in ITERATIONS:
		var adding: bool = (
			hand.size() == 0 or (rng.randi_range(0, 1) == 0 and not outside.is_empty())
		)
		if adding:
			var index: int = rng.randi_range(0, outside.size() - 1)
			if not hand.add(outside[index]):
				mismatches += 1
			outside[index] = outside[-1]
			outside.resize(outside.size() - 1)
		else:
			var held: Array[CardInstance] = hand.cards()
			var chosen: CardInstance = held[rng.randi_range(0, held.size() - 1)]
			var removed: CardInstance = hand.remove(chosen.id())
			if removed != chosen:
				mismatches += 1
			outside.append(removed)
		if not _matches_recount(hand):
			mismatches += 1
	assert_int(mismatches).is_equal(0)


func test_removing_an_absent_card_changes_nothing() -> void:
	var hand: Hand = Hand.new()
	hand.add(CardInstance.from_deck_id(0))
	assert_object(hand.remove(1)).is_null()
	assert_int(hand.size()).is_equal(1)
	assert_bool(_matches_recount(hand)).is_true()


func test_adding_the_same_card_twice_is_rejected() -> void:
	var hand: Hand = Hand.new()
	var card: CardInstance = CardInstance.from_deck_id(0)
	assert_bool(hand.add(card)).is_true()
	assert_bool(hand.add(card)).is_false()
	assert_int(hand.count_of(Ranks.THREE)).is_equal(1)


func test_mask_keeps_a_rank_until_its_last_copy_leaves() -> void:
	var hand: Hand = Hand.new()
	hand.add(CardInstance.from_deck_id(0))
	hand.add(CardInstance.from_deck_id(1))
	hand.remove(0)
	assert_int(hand.rank_mask()).is_equal(1)
	hand.remove(1)
	assert_int(hand.rank_mask()).is_equal(0)


func test_counts_are_a_copy_callers_cannot_change() -> void:
	var hand: Hand = Hand.new()
	hand.add(CardInstance.from_deck_id(0))
	var counts: PackedByteArray = hand.counts()
	counts[Ranks.THREE] = 9
	assert_int(hand.count_of(Ranks.THREE)).is_equal(1)


func _all_cards() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(id))
	return cards


func _matches_recount(hand: Hand) -> bool:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	var mask: int = 0
	for card: CardInstance in hand.cards():
		counts[card.base_rank()] += 1
		mask |= 1 << card.base_rank()
	return counts == hand.counts() and mask == hand.rank_mask()
