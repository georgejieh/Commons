extends GdUnitTestSuite
## The plain deck's slots, rank counts and suits, and a deck changed slot by slot.


func test_a_plain_deck_has_four_of_each_rank_and_one_of_each_joker() -> void:
	var counts: PackedByteArray = Deck.new().rank_counts()
	for rank: int in Ranks.SMALL_JOKER:
		assert_int(counts[rank]).is_equal(4)
	assert_int(counts[Ranks.SMALL_JOKER]).is_equal(1)
	assert_int(counts[Ranks.BIG_JOKER]).is_equal(1)


func test_a_plain_slot_holds_rank_times_four_plus_suit() -> void:
	var deck: Deck = Deck.new()
	for slot: int in Deck.SMALL_JOKER_ID:
		assert_int(deck.rank_of(slot) * Deck.SUITS + deck.suit_of(slot)).is_equal(slot)


func test_jokers_have_no_suit() -> void:
	var deck: Deck = Deck.new()
	assert_int(deck.suit_of(Deck.SMALL_JOKER_ID)).is_equal(Deck.NO_SUIT)
	assert_int(deck.suit_of(Deck.BIG_JOKER_ID)).is_equal(Deck.NO_SUIT)


func test_every_slot_makes_its_own_unmarked_deck_card() -> void:
	var deck: Deck = Deck.new()
	deck.replace(0, Ranks.KING, 2)
	var cards: Array[CardInstance] = deck.cards()
	assert_int(cards.size()).is_equal(Deck.SIZE)
	for slot: int in Deck.SIZE:
		assert_int(cards[slot].id()).is_equal(slot)
		assert_int(cards[slot].base_rank()).is_equal(deck.rank_of(slot))
		assert_int(cards[slot].suit()).is_equal(deck.suit_of(slot))
		assert_int(cards[slot].origin()).is_equal(CardInstance.Origin.DECK)
		assert_str(cards[slot].enhancement_id()).is_equal(CardInstance.NO_ID)


func test_a_replaced_slot_changes_its_card_and_the_counts_only() -> void:
	var deck: Deck = Deck.new()
	deck.replace(0, Ranks.KING, 2)
	var counts: PackedByteArray = deck.rank_counts()
	assert_int(counts[Ranks.THREE]).is_equal(3)
	assert_int(counts[Ranks.KING]).is_equal(5)
	assert_int(deck.rank_of(0)).is_equal(Ranks.KING)
	assert_int(deck.suit_of(0)).is_equal(2)
	assert_array(deck.changed_slots()).is_equal([0])
	assert_int(Deck.new().rank_of(0)).is_equal(Ranks.THREE)


func test_a_deck_saves_only_its_changed_slots_and_loads_through_json() -> void:
	assert_dict(Deck.new().to_dict()).is_empty()
	var deck: Deck = Deck.new()
	deck.replace(7, Ranks.TWO, 0)
	deck.replace(40, Ranks.THREE, 3)
	var saved: Variant = JSON.parse_string(JSON.stringify(deck.to_dict()))
	assert_bool(Deck.is_valid(saved)).is_true()
	var loaded: Deck = Deck.from_dict(saved)
	assert_array(loaded.changed_slots()).is_equal([7, 40])
	for slot: int in Deck.SIZE:
		assert_int(loaded.rank_of(slot)).is_equal(deck.rank_of(slot))
		assert_int(loaded.suit_of(slot)).is_equal(deck.suit_of(slot))


func test_a_saved_deck_of_the_wrong_shape_is_refused() -> void:
	assert_bool(Deck.is_valid({})).is_true()
	assert_bool(Deck.is_valid([])).is_false()
	assert_bool(Deck.is_valid({"x": [1, 1]})).is_false()
	# The jokers' slots never change.
	assert_bool(Deck.is_valid({"52": [1, 1]})).is_false()
	assert_bool(Deck.is_valid({"3": [Ranks.SMALL_JOKER, 0]})).is_false()
	assert_bool(Deck.is_valid({"3": [1, Deck.SUITS]})).is_false()
	assert_bool(Deck.is_valid({"3": [1]})).is_false()
	assert_bool(Deck.is_valid({"3": ["1", 1]})).is_false()
