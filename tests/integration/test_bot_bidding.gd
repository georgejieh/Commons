extends GdUnitTestSuite
## Bid points, thresholds and the overall bid rate.

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: BotTable = BotTable.new(_rules, _map)
var _weights: BotWeights = BotConfig.DEFAULT_WEIGHTS


func _points(text: String) -> float:
	return BidPolicy.hand_points(RankText.counts(text), _table, _weights)


func test_points_count_each_part() -> void:
	var counts: PackedByteArray = RankText.counts("sb2A3333")
	var no_shape: BotWeights = _weights.duplicate()
	no_shape.shape_points = 0.0
	var points: float = BidPolicy.hand_points(counts, _table, no_shape)
	assert_float(points).is_equal(4.0 + 3.0 + 2.0 + 1.0 + 5.0 + 7.0)


func test_a_better_shape_earns_more() -> void:
	assert_float(_points("3456789TJQKA")).is_greater(_points("33557799JJKK"))


func test_the_last_bidder_lowers_the_bar_by_a_tenth() -> void:
	var bar: float = BidPolicy.threshold(false, false, _weights)
	assert_float(BidPolicy.threshold(false, true, _weights)).is_equal_approx(bar * 0.9, 0.001)
	var grab: float = BidPolicy.threshold(true, false, _weights)
	assert_float(BidPolicy.threshold(true, true, _weights)).is_equal_approx(grab * 0.9, 0.001)
	assert_float(grab).is_greater(bar)


func test_a_strong_hand_claims_and_a_weak_hand_passes() -> void:
	var strong: PackedByteArray = RankText.counts("sb22AA3456789TJQK")
	var weak: PackedByteArray = RankText.counts("33446688TTQQKK579")
	var budget: BotBudget = BotBudget.unlimited()
	var config: BotConfig = BotConfig.new()
	assert_bool(Bot.decide_bid(strong, false, false, _table, config, budget)).is_true()
	assert_bool(Bot.decide_bid(weak, false, false, _table, config, budget)).is_false()


func test_the_bid_rate_stays_in_its_band() -> void:
	var deals: int = LongRun.sample(500, 10000)
	var claimed: int = 0
	var configs: Array[BotConfig] = [BotConfig.new(), BotConfig.new(), BotConfig.new()]
	for deal_seed: int in deals:
		var deal: DealResult = SelfPlay.deal_from_seed(deal_seed)
		if SelfPlay.bid_round(deal, configs, _table, deal_seed % Seats.COUNT).landlord() != -1:
			claimed += 1
	var rate: float = float(claimed) / deals
	print("bid rate %.4f over %d deals" % [rate, deals])
	assert_float(rate).is_between(_weights.bid_rate_low, _weights.bid_rate_high)
