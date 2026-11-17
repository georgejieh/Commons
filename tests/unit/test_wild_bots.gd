extends GdUnitTestSuite
## Every bot tier plays wild rounds (ADR 0029) with no illegal action, and the planning
## tiers use a wild card to finish a straight or a bomb.

const SEED: int = 2931
const DEALS: int = 6
const EXPERT_DEALS: int = 1
const EXPERT_SAMPLES: int = 12

var _map: PackedByteArray = Ranks.identity_map()


func _config(tier: BotConfig.Tier) -> BotConfig:
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier)
	if tier == BotConfig.Tier.EXPERT:
		var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
		weights.expert_samples = EXPERT_SAMPLES
		config = BotConfig.new(weights, tier)
	return config


func test_every_tier_plays_wild_rounds_legally() -> void:
	var illegal: int = 0
	var played: int = 0
	var tiers: Array[BotConfig.Tier] = [
		BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD, BotConfig.Tier.EXPERT
	]
	for tier: BotConfig.Tier in tiers:
		var deals: int = EXPERT_DEALS if tier == BotConfig.Tier.EXPERT else DEALS
		for wild: int in [1, 2]:
			for deal: int in deals:
				var game_seed: int = SEED + deal
				var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
				params.wild_ranks = TournamentRun.wild_ranks_for(game_seed, wild)
				params.five_plus_is_bomb = wild == 2
				var table: SeatRules = SeatRules.uniform(RuleSet.new(params), _map)
				var config: BotConfig = _config(tier)
				var configs: Array[BotConfig] = [config, config, config]
				var result: SelfPlayResult = SelfPlay.play_round(
					SelfPlay.deal_from_seed(game_seed), deal % Seats.COUNT, configs, table
				)
				illegal += result.illegal_actions
				played += 1 if result.winner != Seats.NONE else 0
	assert_int(illegal).is_equal(0)
	assert_int(played).is_equal(2 * (3 * DEALS + EXPERT_DEALS))


## One decomposer scores many hands in a search and remembers them. With two wild ranks,
## hands that differ only in which wild rank they hold must not share a memory.
func test_the_memo_tells_two_wild_ranks_apart() -> void:
	var wild: Array[int] = [Ranks.SEVEN, Ranks.KING]
	var rules: RuleSet = WildReference.rules(wild, false)
	var reused: HandDecomposer = HandDecomposer.new(rules, _map, 100000)
	for hand: String in ["7", "K", "3457", "345K", "99K", "997", "77", "KK", "7K"]:
		var fresh: HandDecomposer = HandDecomposer.new(rules, _map, 100000)
		var expected: int = fresh.score(RankText.counts(hand))
		assert_int(reused.score(RankText.counts(hand))).override_failure_message(hand).is_equal(
			expected
		)


func test_a_wild_card_completes_a_planned_straight() -> void:
	var jacks: RuleSet = WildReference.rules([Ranks.JACK] as Array[int], false)
	var search: HandDecomposer = HandDecomposer.new(jacks, _map, 100000)
	var groups: Array[Pattern] = search.decompose(RankText.counts("3456J99")).groups
	var types: Array[int] = []
	for group: Pattern in groups:
		types.append(group.type)
	assert_int(groups.size()).is_equal(2)
	assert_array(types).contains([Pattern.Type.STRAIGHT, Pattern.Type.PAIR])
	var round_state: RoundState = RoundState.new(
		RoundScript.stacked_deal(["3456J99", "8888", "TTTT"] as Array[String], ""),
		0,
		SeatRules.uniform(jacks, _map)
	)
	var play: BotPlay = Bot.decide_play(
		round_state.view_for(0),
		round_state.legal_moves(),
		BotTable.new(jacks, _map),
		_config(BotConfig.Tier.MEDIUM),
		BotBudget.unlimited()
	)
	assert_int(play.pattern.type).is_equal(Pattern.Type.STRAIGHT)
	assert_int(play.pattern.spent_counts()[Ranks.JACK]).is_equal(1)
	assert_int(round_state.apply(round_state.action_for(play.pattern))).is_equal(
		RoundState.Reason.OK
	)


func test_a_wild_card_completes_a_bomb_to_stop_an_opponent() -> void:
	var sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)
	var round_state: RoundState = RoundState.new(
		RoundScript.stacked_deal(["24", "88873", "55"] as Array[String], ""),
		0,
		SeatRules.uniform(sevens, _map)
	)
	var two: Array[int] = []
	for card: CardInstance in round_state.view_for(0).own_cards:
		if card.base_rank() == Ranks.TWO:
			two.append(card.id())
	assert_int(round_state.apply(RoundAction.new(0, two))).is_equal(RoundState.Reason.OK)
	var play: BotPlay = Bot.decide_play(
		round_state.view_for(1),
		round_state.legal_moves(),
		BotTable.new(sevens, _map),
		_config(BotConfig.Tier.HARD),
		BotBudget.unlimited()
	)
	assert_int(play.pattern.type).is_equal(Pattern.Type.BOMB)
	assert_int(play.pattern.main_rank).is_equal(Ranks.EIGHT)
	assert_int(play.pattern.stand_ins()).is_equal(1)


func test_hard_counts_a_wild_answer_as_possible() -> void:
	var sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)
	var unseen: PackedByteArray = RankText.counts("A7")
	var pair: Pattern = Readings.of(RankText.counts("KK"), sevens, _map)[0]
	var groups: Array[Pattern] = [pair]
	var counted: Controls = Controls.new(groups, unseen, 10, BotTable.new(sevens, _map))
	assert_bool(counted.flags[0]).is_false()
	var plain: Controls = Controls.new(
		groups, RankText.counts("A8"), 10, BotTable.new(RuleSet.default_rules(), _map)
	)
	assert_bool(plain.flags[0]).is_true()
	var bombs: Controls = Controls.new(
		groups, RankText.counts("9997"), 10, BotTable.new(sevens, _map)
	)
	assert_bool(bombs.bomb_possible).is_true()
