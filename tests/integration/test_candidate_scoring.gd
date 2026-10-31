extends GdUnitTestSuite
## Candidate scoring, and that its weights matter in play.

const BAD_WEIGHTS: BotWeights = preload("res://tests/fixtures/bots/bad_weights.tres")
const BETTER_THAN_EVEN: float = 0.55

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: BotTable = BotTable.new(_rules, _map)


func _scorer(text: String) -> CandidateScorer:
	return CandidateScorer.new(RankText.counts(text), _table, BotConfig.DEFAULT_WEIGHTS)


func _pattern(text: String) -> Pattern:
	return Classifier.classify(RankText.counts(text), _rules, _map).pattern


func test_weights_load_from_data() -> void:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
	assert_float(weights.round_penalty).is_equal(7.0)
	assert_int(weights.type_bonus.size()).is_equal(Pattern.Type.size())
	assert_int(weights.memo_cap).is_equal(50000)


func test_going_out_outscores_everything() -> void:
	var scorer: CandidateScorer = _scorer("33")
	assert_float(scorer.score_play(_pattern("33"))).is_equal(1000.0)
	assert_float(scorer.score_play(_pattern("3"))).is_less(1000.0)


func test_breaking_a_straight_scores_below_playing_it_whole() -> void:
	var scorer: CandidateScorer = _scorer("345679")
	assert_float(scorer.score_play(_pattern("34567"))).is_greater(scorer.score_play(_pattern("5")))


func test_passing_costs_one_more_round() -> void:
	var scorer: CandidateScorer = _scorer("3334")
	var played: float = scorer.score_play(_pattern("3334"))
	assert_float(played).is_equal(1000.0)
	var after_four: float = scorer.score_play(_pattern("4"))
	assert_float(scorer.score_pass()).is_less(after_four + 8.0)


func test_bad_weights_lower_the_win_rate() -> void:
	var table: SeatRules = SeatRules.uniform(_rules, _map)
	var good: BotConfig = BotConfig.new()
	var bad: BotConfig = BotConfig.new(BAD_WEIGHTS)
	var deals: int = LongRun.sample(40, 400)
	var wins: int = 0
	for deal_seed: int in deals:
		wins += SelfPlay.play_duplicate(SelfPlay.deal_from_seed(deal_seed), good, bad, table)
	var rate: float = float(wins) / (deals * 2)
	print("good weights beat bad weights %.3f over %d deals" % [rate, deals])
	assert_float(rate).is_greater(BETTER_THAN_EVEN)
