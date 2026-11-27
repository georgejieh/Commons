extends GdUnitTestSuite
## Bots of every tier on exchanged decks (ADR 0042): a rank at the most copies, a rank
## emptied, both, and both with a plot swap in the same round. No bot plays an illegal
## action, every round ends, and a seat counts unseen cards against the deck the table was
## dealt: the Expert's sampled worlds never hold more of a rank than that deck less what
## the seat has seen, and the player, who knows their own swap, never counts the card it
## set aside.

const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD, BotConfig.Tier.EXPERT
]
const DEALS: int = 3
const EXPERT_SAMPLES: int = 4
const SAMPLES: int = 6
const MOST: Array[int] = [Ranks.KING]
const EMPTY: Array[int] = [Ranks.THREE]
const NONE: Array[int] = []


func _config(tier: BotConfig.Tier, seed_value: int) -> BotConfig:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
	if tier == BotConfig.Tier.EXPERT:
		weights = BotConfig.DEFAULT_WEIGHTS.duplicate()
		weights.expert_samples = EXPERT_SAMPLES
		weights.expert_min_samples = 2
	return BotConfig.new(weights, tier, seed_value)


## A deck whose ranks in most hold eight copies and whose ranks in empty hold none, the
## room taken from and given to the 7s.
func _shaped(most: Array[int], empty: Array[int]) -> Deck:
	var deck: Deck = Deck.new()
	var spare: Array[int] = []
	for slot: int in Deck.SMALL_JOKER_ID:
		if deck.rank_of(slot) == Ranks.SEVEN or empty.has(deck.rank_of(slot)):
			spare.append(slot)
	for rank: int in most:
		while deck.rank_counts()[rank] < RunDefaults.PARAMS.deck_rank_most:
			deck.replace(spare.pop_back(), rank, deck.rank_counts()[rank] % Deck.SUITS)
	for slot: int in spare:
		if empty.has(deck.rank_of(slot)):
			deck.replace(slot, Ranks.SEVEN, slot % Deck.SUITS)
	return deck


func _shapes() -> Array[Deck]:
	return [_shaped(MOST, NONE), _shaped(NONE, EMPTY), _shaped(MOST, EMPTY)]


func test_the_shapes_are_what_they_say() -> void:
	var shapes: Array[Deck] = _shapes()
	assert_int(shapes[0].rank_counts()[Ranks.KING]).is_equal(8)
	assert_int(shapes[1].rank_counts()[Ranks.THREE]).is_zero()
	assert_int(shapes[2].rank_counts()[Ranks.KING]).is_equal(8)
	assert_int(shapes[2].rank_counts()[Ranks.THREE]).is_zero()
	for deck: Deck in shapes:
		var total: int = 0
		for count: int in deck.rank_counts():
			total += count
		assert_int(total).is_equal(Deck.SIZE)


func test_every_tier_plays_legally_on_every_shape() -> void:
	for shape: int in _shapes().size():
		var deck: Deck = _shapes()[shape]
		for tier: BotConfig.Tier in TIERS:
			for deal_index: int in DEALS:
				var seed_value: int = 900 + shape * 31 + int(tier) * 7 + deal_index
				var deal: DealResult = Dealer.deal(deck.cards(), RandomStream.new(seed_value))
				var configs: Array[BotConfig] = []
				for seat: int in Seats.COUNT:
					configs.append(_config(tier, seed_value + seat))
				var table: SeatRules = SeatRules.new(ModifierStack.new())
				var result: SelfPlayResult = SelfPlay.play_round(
					deal, deal_index % 3, configs, table
				)
				var name: String = "shape %d tier %d deal %d" % [shape, tier, deal_index]
				assert_int(result.illegal_actions).override_failure_message(name).is_zero()
				assert_int(result.winner).override_failure_message(name).is_not_equal(Seats.NONE)


func test_whole_sets_on_an_exchanged_deck_with_a_plot_swap_refuse_no_villager() -> void:
	for tier: BotConfig.Tier in TIERS:
		var state: RunState = RunState.new(1300 + int(tier))
		state.deck = _shaped(MOST, EMPTY)
		# Two more Kings in the plot: a swap brings a ninth or tenth into the round.
		for index: int in 2:
			state.inventory.plot.append(
				CardInstance.new(
					CardInstance.FIRST_PLOT_ID + index, Ranks.KING, index, CardInstance.Origin.PLOT
				)
			)
		var configs: Array[BotConfig] = [_config(BotConfig.Tier.MEDIUM, 1)]
		configs.append(_config(tier, 2))
		configs.append(_config(tier, 3))
		var loop: RunLoop = RunLoop.new(state, configs, SetConfig.new())
		loop.start_set()
		var script: RunScript = RunScript.new()
		var swaps: int = 0
		for _step: int in 900:
			if loop.awaiting() == RunLoop.Awaiting.PLAYER_SWAP:
				swaps += 1
			if not script.act(loop):
				break
		var over: Array[RunLoop.Awaiting] = [RunLoop.Awaiting.SET_OVER, RunLoop.Awaiting.RUN_OVER]
		assert_bool(over.has(loop.awaiting())).override_failure_message(str(tier)).is_true()
		assert_int(loop.refused_bot_actions).is_zero()
		assert_int(swaps).is_greater(0)


func test_a_seat_counts_the_dealt_deck_and_the_player_their_own_swap() -> void:
	var deck: Deck = _shaped(MOST, EMPTY)
	var deal: DealResult = Dealer.deal(deck.cards(), RandomStream.new(5))
	var round_state: RoundState = RoundState.new(deal, 0, SeatRules.new(ModifierStack.new()))
	for seat: int in Seats.COUNT:
		assert_that(round_state.view_for(seat).deck_counts).is_equal(deck.rank_counts())
	var out: CardInstance = round_state.view_for(0).own_cards[0]
	var plot_king: CardInstance = CardInstance.new(
		CardInstance.FIRST_PLOT_ID, Ranks.KING, 0, CardInstance.Origin.PLOT
	)
	round_state.exchange(0, [out.id()], [plot_king])
	var known: PackedByteArray = deck.rank_counts()
	known[out.base_rank()] -= 1
	known[Ranks.KING] += 1
	assert_that(round_state.view_for(0).deck_counts).is_equal(known)
	# The villagers cannot know what the player set aside or brought in.
	for seat: int in [1, 2]:
		assert_that(round_state.view_for(seat).deck_counts).is_equal(deck.rank_counts())
	var unseen: PackedByteArray = UnseenCards.from_view(round_state.view_for(0))
	var own: PackedByteArray = round_state.view_for(0).own_counts
	for rank: int in Ranks.COUNT:
		assert_int(unseen[rank]).is_equal(known[rank] - own[rank])


func test_the_experts_sampled_worlds_fit_the_dealt_deck() -> void:
	var deck: Deck = _shaped(MOST, EMPTY)
	var config: BotConfig = _config(BotConfig.Tier.EXPERT, 8)
	for seed_value: int in 6:
		var deal: DealResult = Dealer.deal(deck.cards(), RandomStream.new(70 + seed_value))
		var table: SeatRules = SeatRules.new(ModifierStack.new())
		var round_state: RoundState = RoundState.new(deal, 1, table)
		for seat: int in [1, 2, 0]:
			var view: SeatView = round_state.view_for(seat)
			var bot_table: BotTable = BotTable.of_seat(table, seat)
			var scorer: CandidateScorer = CandidateScorer.new(
				view.own_counts, bot_table, config.weights
			)
			var position: BotPosition = BotPosition.new(view, bot_table, config, scorer)
			for sample: int in SAMPLES:
				var hands: Array[PackedByteArray] = ExpertSearch.deal_unseen(position, sample)
				assert_int(hands.size()).is_equal(Seats.COUNT)
				for rank: int in Ranks.COUNT:
					var total: int = 0
					for hand: PackedByteArray in hands:
						total += hand[rank]
					assert_int(total).is_less_equal(deck.rank_counts()[rank])
