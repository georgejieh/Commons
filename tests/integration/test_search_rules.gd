extends GdUnitTestSuite
## What a search must respect: the trick as it stands, and the policy's gates.

const FAR: String = "JQKA2"

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: BotTable = BotTable.new(_rules, _map)


func _config(tier: BotConfig.Tier) -> BotConfig:
	return BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier)


func _pattern(text: String) -> Pattern:
	return Classifier.classify(RankText.counts(text), _rules, _map).pattern


func _position(round_state: RoundState, config: BotConfig) -> BotPosition:
	var view: SeatView = round_state.view_for(round_state.seat_to_act())
	var scorer: CandidateScorer = CandidateScorer.new(view.own_counts, _table, config.weights)
	return BotPosition.new(view, _table, config, scorer)


func test_a_pass_is_always_a_candidate() -> void:
	var round_state: RoundState = BotScript.round_after(["3" + FAR, "6" + FAR, "789TQ"], ["3", "6"])
	var config: BotConfig = _config(BotConfig.Tier.HARD)
	config.cooperation = 0.0
	var position: BotPosition = _position(round_state, config)
	var legal: Array[Pattern] = round_state.legal_moves()
	var policy: BotPlay = BotPlay.new(legal[0])
	var has_pass: bool = false
	for move: Pattern in ExpertSearch.top_candidates(position, legal, policy):
		has_pass = has_pass or move.type == Pattern.Type.PASS
	assert_bool(has_pass).is_true()


func test_the_policy_play_is_always_a_candidate() -> void:
	var round_state: RoundState = BotScript.round_after(["3" + FAR, "789TQ", "4567"], ["3"])
	var position: BotPosition = _position(round_state, _config(BotConfig.Tier.HARD))
	var legal: Array[Pattern] = round_state.legal_moves()
	var policy: BotPlay = BotPlay.new(legal[legal.size() - 1])
	var top: Array[Pattern] = ExpertSearch.top_candidates(position, legal, policy)
	assert_bool(top[0].equals(policy.pattern)).is_true()


func test_a_search_keeps_off_a_teammates_winning_card() -> void:
	var seats: Array[String] = ["3" + FAR, "A" + FAR, "2KK"]
	var play: BotPlay = BotScript.decide(seats, ["3", "A"], 0, _config(BotConfig.Tier.EXPERT))
	assert_bool(play.is_pass()).is_true()


func test_a_search_never_bombs_a_teammate() -> void:
	var config: BotConfig = _config(BotConfig.Tier.EXPERT)
	config.cooperation = 0.0
	var round_state: RoundState = BotScript.round_after(["5" + FAR, "9TJ", "33334"], ["5", "9"])
	var legal: Array[Pattern] = round_state.legal_moves()
	var position: BotPosition = _position(round_state, config)
	var policy: BotPlay = FollowPolicy.choose(position, legal)
	assert_str(BotScript.text_of(policy)).is_not_equal("3333")
	for move: Pattern in ExpertSearch.top_candidates(position, legal, policy):
		assert_bool(FollowPolicy.is_bomb(move)).is_false()


func test_a_rollout_remembers_a_pass_already_made() -> void:
	var hands: Array[PackedByteArray] = [
		RankText.counts("34567"), RankText.counts("A"), RankText.counts("45")
	]
	var rollout: Rollout = Rollout.new(
		hands, 0, 2, _pattern("9"), 0, 1, _table, _config(BotConfig.Tier.MEDIUM)
	)
	rollout.step(Pattern.pass_play())
	assert_int(rollout.play_out(BotConfig.DEFAULT_WEIGHTS.search_step_limit)).is_equal(0)


func test_passes_on_the_table_count_back_to_the_play() -> void:
	var round_state: RoundState = BotScript.round_after(["9" + FAR, "A", "45"], ["9", ""])
	assert_int(_position(round_state, _config(BotConfig.Tier.HARD)).passes_on_table()).is_equal(1)


func test_a_move_nobody_offered_is_not_legal() -> void:
	var legal: Array[Pattern] = [_pattern("9")]
	assert_bool(SelfPlay.is_offered(BotPlay.new(_pattern("9")), legal)).is_true()
	assert_bool(SelfPlay.is_offered(BotPlay.new(_pattern("2")), legal)).is_false()
	assert_bool(SelfPlay.is_offered(BotPlay.new(Pattern.pass_play()), legal)).is_true()


func test_scores_follow_the_rank_map() -> void:
	var reversed: PackedByteArray = Ranks.identity_map()
	ReversedRanks.reverse(reversed)
	var table: BotTable = BotTable.new(_rules, reversed)
	var counts: PackedByteArray = RankText.counts("39K")
	var scorer: CandidateScorer = CandidateScorer.new(counts, table, BotConfig.DEFAULT_WEIGHTS)
	var king: Pattern = Classifier.classify(RankText.counts("K"), _rules, reversed).pattern
	var three: Pattern = Classifier.classify(RankText.counts("3"), _rules, reversed).pattern
	assert_float(scorer.score_play(king)).is_greater(scorer.score_play(three))


func test_a_five_card_bomb_keeps_all_its_cards() -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
	params.five_plus_is_bomb = true
	var rules: RuleSet = RuleSet.new(params)
	var decomposer: HandDecomposer = HandDecomposer.new(rules, _map, 1000)
	var cards: int = 0
	for group: Pattern in decomposer.decompose(RankText.counts("333334")).groups:
		cards += group.card_count
	assert_int(cards).is_equal(6)
