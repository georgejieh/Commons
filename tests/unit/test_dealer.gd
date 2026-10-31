extends GdUnitTestSuite
## Deals are complete and unbiased, and configured biases hit their targets.

const DEALS: int = 100000
const SEED: int = 1107
const DESTINATIONS: int = 4
## Chi-square critical value at the 1% level for 53 × 3 = 159 degrees of freedom.
const CHI_SQUARE_CRITICAL: float = 203.4
const BIAS_TOLERANCE: float = 0.02


func test_deal_gives_17_to_each_seat_and_3_to_the_kitty() -> void:
	var result: DealResult = Dealer.deal(_deck(), _stream())
	var seen: Dictionary[int, bool] = {}
	for hand: Hand in result.hands:
		assert_int(hand.size()).is_equal(17)
		for card: CardInstance in hand.cards():
			seen[card.id] = true
	assert_int(result.kitty.size()).is_equal(3)
	for card: CardInstance in result.kitty:
		seen[card.id] = true
	assert_int(seen.size()).is_equal(54)


func test_deal_leaves_the_input_order_alone() -> void:
	var deck: Array[CardInstance] = _deck()
	Dealer.deal(deck, _stream())
	assert_int(deck[0].id).is_equal(0)
	assert_int(deck[53].id).is_equal(53)


func test_unbiased_deals_pass_chi_square_at_the_one_percent_level() -> void:
	var deck: Array[CardInstance] = _deck()
	var stream: RandomStream = _stream()
	var counts: PackedInt32Array = []
	counts.resize(Deck.SIZE * DESTINATIONS)
	for _i: int in DEALS:
		var order: Array[CardInstance] = Dealer.arrange(deck, stream)
		for index: int in Deck.SIZE:
			counts[order[index].id * DESTINATIONS + _destination(index)] += 1

	var statistic: float = _chi_square(counts)
	print(
		"Chi-square over %d deals: %.2f (critical %.1f)" % [DEALS, statistic, CHI_SQUARE_CRITICAL]
	)
	assert_float(statistic).is_less(CHI_SQUARE_CRITICAL)


func test_bias_doubles_the_chance_of_a_four_copy_rank() -> void:
	_assert_bias_hits_target(Ranks.ACE, 0, 2.0)


func test_bias_doubles_the_chance_of_a_single_joker_for_another_seat() -> void:
	_assert_bias_hits_target(Ranks.BIG_JOKER, 2, 2.0)


func test_bias_never_creates_or_loses_a_card() -> void:
	var biases: Array[DealBias] = [DealBias.new(1, Ranks.TWO, 3.0)]
	var stream: RandomStream = _stream()
	for _i: int in 1000:
		var seen: Dictionary[int, bool] = {}
		for card: CardInstance in Dealer.arrange(_deck(), stream, biases):
			seen[card.id] = true
		assert_int(seen.size()).is_equal(Deck.SIZE)


func test_multiplier_of_one_changes_no_cards() -> void:
	var biases: Array[DealBias] = [DealBias.new(0, Ranks.ACE, 1.0)]
	var plain: Array[CardInstance] = Dealer.arrange(_deck(), _stream())
	var biased: Array[CardInstance] = Dealer.arrange(_deck(), _stream(), biases)
	for index: int in Deck.SIZE:
		assert_int(biased[index].id).is_equal(plain[index].id)


func _assert_bias_hits_target(rank: int, seat: int, multiplier: float) -> void:
	var deck: Array[CardInstance] = _deck()
	var stream: RandomStream = _stream()
	var biases: Array[DealBias] = [DealBias.new(seat, rank, multiplier)]
	var copies: int = 0
	var landed: int = 0
	for _i: int in DEALS:
		var order: Array[CardInstance] = Dealer.arrange(deck, stream, biases)
		for index: int in Deck.SIZE:
			if order[index].base_rank == rank:
				copies += 1
				if _destination(index) == seat:
					landed += 1

	var rate: float = float(landed) / copies
	var target: float = multiplier * Dealer.HAND_SIZE / Deck.SIZE
	print("Bias rank %d seat %d: %.4f (target %.4f)" % [rank, seat, rate, target])
	assert_float(rate).is_between(target - BIAS_TOLERANCE, target + BIAS_TOLERANCE)


func _chi_square(counts: PackedInt32Array) -> float:
	var statistic: float = 0.0
	for card: int in Deck.SIZE:
		for destination: int in DESTINATIONS:
			var size: int = Dealer.KITTY_SIZE if destination == 3 else Dealer.HAND_SIZE
			var expected: float = float(DEALS) * size / Deck.SIZE
			var difference: float = counts[card * DESTINATIONS + destination] - expected
			statistic += difference * difference / expected
	return statistic


## Seats 0 to 2, or 3 for the kitty.
func _destination(index: int) -> int:
	return mini(index / Dealer.HAND_SIZE, 3)


func _deck() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(id))
	return cards


func _stream() -> RandomStream:
	return RandomStreams.new(SEED).stream(RandomStreams.DEAL)
