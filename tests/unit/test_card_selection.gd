extends GdUnitTestSuite
## Selection is deterministic and reproduces the pattern exactly.

const SEED: int = 1602
const ROUNDS: int = 500

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _hand_of(deck_ids: Array[int]) -> Hand:
	var hand: Hand = Hand.new()
	for deck_id: int in deck_ids:
		hand.add(CardInstance.from_deck_id(deck_id))
	return hand


func _dealt_hand(seed_value: int) -> Hand:
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	return Dealer.deal(cards, RandomStream.new(seed_value)).hands[0]


func _ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	return ids


func test_every_move_of_random_hands_reproduces_its_pattern() -> void:
	for round_index: int in ROUNDS:
		var hand: Hand = _dealt_hand(SEED + round_index)
		var moves: Array[Pattern] = MoveGenerator.generate(
			hand.counts(), hand.rank_mask(), null, _rules, _map
		)
		for move: Pattern in moves:
			var chosen: Array[CardInstance] = CardSelection.pick(hand, move)
			assert_int(chosen.size()).is_equal(move.card_count)
			var read: Classification = CardSelection.classify_cards(chosen, _rules, _map)
			assert_int(read.pattern.identity()).is_equal(move.identity())


func test_selection_is_deterministic_whatever_the_hand_order() -> void:
	var first: Hand = _hand_of([0, 1, 2, 3, 4])
	var second: Hand = _hand_of([4, 3, 2, 1, 0])
	var pair: Pattern = Classifier.classify(RankText.counts("33"), _rules, _map).pattern
	assert_array(_ids(CardSelection.pick(first, pair))).is_equal([0, 1])
	assert_array(_ids(CardSelection.pick(second, pair))).is_equal([0, 1])


func test_plain_cards_go_before_valuable_ones() -> void:
	var hand: Hand = _hand_of([0, 1, 2, 3])
	hand.cards()[0].set_enhancement("gold")
	hand.cards()[1].set_owner_stamp(0)
	hand.cards()[2].set_seal("red")
	var single: Pattern = Classifier.classify(RankText.counts("3"), _rules, _map).pattern
	assert_array(_ids(CardSelection.pick(hand, single))).is_equal([3])
	var pair: Pattern = Classifier.classify(RankText.counts("33"), _rules, _map).pattern
	assert_array(_ids(CardSelection.pick(hand, pair))).is_equal([3, 0])


func test_a_hand_that_lacks_the_cards_gets_nothing() -> void:
	var hand: Hand = _hand_of([0])
	var pair: Pattern = Classifier.classify(RankText.counts("33"), _rules, _map).pattern
	assert_int(CardSelection.pick(hand, pair).size()).is_equal(0)


func test_a_player_selection_goes_through_the_classifier() -> void:
	var bad: Array[CardInstance] = [CardInstance.from_deck_id(0), CardInstance.from_deck_id(4)]
	var result: Classification = CardSelection.classify_cards(bad, _rules, _map)
	assert_bool(result.is_valid()).is_false()
