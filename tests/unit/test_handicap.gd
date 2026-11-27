extends GdUnitTestSuite
## The Handicap (ADR 0043): each deal sets the year's count of the holder's cards aside face
## up, drawn at random on the deal stream, so the hand is short, the kitty stays three and
## every seat's count of the round drops them. The bots of every tier play such rounds with
## no illegal action and never count a set-aside card as unseen.

const HANDICAP: ModifierDef = preload("res://data/modifiers/bosses/the_handicap.tres")
const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD, BotConfig.Tier.EXPERT
]
const EXPERT_SAMPLES: int = 4
## The cards set aside in each Year from 1 to 7, from the data's numbers.
const COUNTS: Array[int] = [1, 1, 1, 2, 2, 2, 3]
## What deal stream 7 sets aside in Year 4, by card ID: the golden draw.
const GOLDEN_ASIDE: Array[int] = [5, 44]


func _deal(seed_value: int, year: int) -> DealResult:
	var stream: RandomStream = RandomStream.new(seed_value)
	var deal: DealResult = Dealer.deal(Deck.new().cards(), stream)
	var stack: ModifierStack = ModifierStack.new()
	stack.add(HANDICAP, 0)
	stack.run_on_deal(DealContext.new(Seats.NONE, deal, stream, year))
	return deal


func _ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	ids.sort()
	return ids


func test_the_count_grows_one_card_every_three_years() -> void:
	for year: int in COUNTS.size():
		assert_int(HandicapEffect.count_at(HANDICAP.parameters, year + 1)).is_equal(COUNTS[year])


func test_the_hand_is_short_the_kitty_whole_and_no_card_lost() -> void:
	for year: int in [1, 4, 7]:
		var deal: DealResult = _deal(7, year)
		var short: int = HandicapEffect.count_at(HANDICAP.parameters, year)
		assert_int(deal.hands[0].size()).is_equal(Dealer.HAND_SIZE - short)
		assert_int(deal.hands[1].size()).is_equal(Dealer.HAND_SIZE)
		assert_int(deal.hands[2].size()).is_equal(Dealer.HAND_SIZE)
		assert_int(deal.kitty.size()).is_equal(Dealer.KITTY_SIZE)
		assert_int(deal.set_aside.size()).is_equal(short)
		var every: Array[CardInstance] = deal.kitty + deal.set_aside
		for hand: Hand in deal.hands:
			every.append_array(hand.cards())
		var all_ids: Array[int] = []
		for slot: int in Deck.SIZE:
			all_ids.append(slot)
		assert_array(_ids(every)).is_equal(all_ids)


func test_the_draw_is_the_golden_one_and_never_reads_the_hand_order() -> void:
	assert_array(_ids(_deal(7, 4).set_aside)).is_equal(GOLDEN_ASIDE)
	# The same deal with its first hand held in reverse sets the same cards aside.
	var stream: RandomStream = RandomStream.new(7)
	var deal: DealResult = Dealer.deal(Deck.new().cards(), stream)
	var reversed: Hand = Hand.new()
	var cards: Array[CardInstance] = deal.hands[0].cards()
	cards.reverse()
	for card: CardInstance in cards:
		reversed.add(card)
	deal.hands[0] = reversed
	var stack: ModifierStack = ModifierStack.new()
	stack.add(HANDICAP, 0)
	stack.run_on_deal(DealContext.new(Seats.NONE, deal, stream, 4))
	assert_array(_ids(deal.set_aside)).is_equal(GOLDEN_ASIDE)


func test_every_seat_counts_the_round_without_the_cards_set_aside() -> void:
	var deal: DealResult = _deal(11, 7)
	var plain: PackedByteArray = Deck.new().rank_counts()
	for card: CardInstance in deal.set_aside:
		plain[card.base_rank()] -= 1
	assert_that(deal.deck_counts).is_equal(plain)
	var round_state: RoundState = RoundState.new(deal, 1, SeatRules.new(ModifierStack.new()))
	for seat: int in Seats.COUNT:
		var view: SeatView = round_state.view_for(seat)
		var unseen: PackedByteArray = UnseenCards.from_view(view)
		var total: int = 0
		for rank: int in Ranks.COUNT:
			total += unseen[rank]
		var others: int = 0
		for other: int in Seats.COUNT:
			if other != seat:
				others += view.public.remaining[other]
		# Every unseen card is in another hand: none of them is a card set aside.
		assert_int(total).override_failure_message("seat %d" % seat).is_equal(others)


func test_every_tier_plays_a_short_hand_legally() -> void:
	for tier: BotConfig.Tier in TIERS:
		for deal_index: int in 3:
			var seed_value: int = 700 + int(tier) * 11 + deal_index
			var deal: DealResult = _deal(seed_value, 7)
			var configs: Array[BotConfig] = []
			for seat: int in Seats.COUNT:
				configs.append(_config(tier, seed_value + seat))
			var table: SeatRules = SeatRules.new(ModifierStack.new())
			var result: SelfPlayResult = SelfPlay.play_round(deal, deal_index, configs, table)
			var name: String = "tier %d deal %d" % [tier, deal_index]
			assert_int(result.illegal_actions).override_failure_message(name).is_zero()
			assert_int(result.winner).override_failure_message(name).is_not_equal(Seats.NONE)


func _config(tier: BotConfig.Tier, seed_value: int) -> BotConfig:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
	if tier == BotConfig.Tier.EXPERT:
		weights = BotConfig.DEFAULT_WEIGHTS.duplicate()
		weights.expert_samples = EXPERT_SAMPLES
		weights.expert_min_samples = 2
	return BotConfig.new(weights, tier, seed_value)
