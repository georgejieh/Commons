extends GdUnitTestSuite
## What each tier does, and its strength in small samples. tools/tournament.gd measures
## the 2,000-game bar (ADR 0010).

const CLEAR_MARGIN: float = 0.55

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: SeatRules = SeatRules.uniform(_rules, _map)


func _config(tier: BotConfig.Tier) -> BotConfig:
	return BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier)


func _rate(high: BotConfig, low: BotConfig, deals: int) -> float:
	var wins: int = 0
	for deal_seed: int in deals:
		wins += SelfPlay.play_duplicate(SelfPlay.deal_from_seed(deal_seed), high, low, _table)
	return float(wins) / (deals * 2)


func test_easy_answers_with_the_lowest_play() -> void:
	var play: BotPlay = BotScript.decide(
		["9TJQKA", "8TK2", "567"], ["9"], 0, _config(BotConfig.Tier.EASY)
	)
	assert_str(BotScript.text_of(play)).is_equal("T")


func test_easy_beats_its_own_teammate() -> void:
	var seats: Array[String] = ["3456789TJ", "4567", "589T"]
	var play: BotPlay = BotScript.decide(seats, ["3", "4"], 0, _config(BotConfig.Tier.EASY))
	assert_str(BotScript.text_of(play)).is_equal("5")


func test_easy_keeps_bombs_until_an_opponent_is_close() -> void:
	var seats: Array[String] = ["9456789TJQ", "33335", "678"]
	var easy: BotConfig = _config(BotConfig.Tier.EASY)
	assert_bool(BotScript.decide(seats, ["9"], 0, easy).is_pass()).is_true()
	var close: BotPlay = BotScript.decide(["98", "33335", "678"], ["9"], 0, easy)
	assert_str(BotScript.text_of(close)).is_equal("3333")


func test_medium_passes_on_its_teammate() -> void:
	var seats: Array[String] = ["3456789TJ", "4567", "589T"]
	var medium: BotConfig = _config(BotConfig.Tier.MEDIUM)
	assert_bool(BotScript.decide(seats, ["3", "4"], 0, medium).is_pass()).is_true()


func test_medium_has_no_seat_role() -> void:
	var seats: Array[String] = ["5789TJQKA", "3456789", "6Q99KK"]
	var play: BotPlay = BotScript.decide(seats, ["5", ""], 0, _config(BotConfig.Tier.MEDIUM))
	assert_str(BotScript.text_of(play)).is_equal("6")


func test_only_expert_searches() -> void:
	assert_bool(ExpertSearch.applies(_config(BotConfig.Tier.EASY))).is_false()
	assert_bool(ExpertSearch.applies(_config(BotConfig.Tier.MEDIUM))).is_false()
	assert_bool(ExpertSearch.applies(_config(BotConfig.Tier.HARD))).is_false()
	assert_bool(ExpertSearch.applies(_config(BotConfig.Tier.EXPERT))).is_true()


func test_a_search_keeps_to_legal_moves_and_can_pass() -> void:
	var round_state: RoundState = BotScript.round_after(["39TJ", "458", "67"], ["3"])
	var legal: Array[Pattern] = round_state.legal_moves()
	var table: BotTable = BotTable.new(_rules, _map)
	var play: BotPlay = Bot.decide_play(
		round_state.view_for(1), legal, table, _config(BotConfig.Tier.EXPERT), BotBudget.unlimited()
	)
	var found: bool = play.is_pass()
	for move: Pattern in legal:
		found = found or move.equals(play.pattern)
	assert_bool(found).is_true()


func test_a_search_is_repeatable() -> void:
	var seats: Array[String] = ["39TJQ", "4578", "6KA"]
	var expert: BotConfig = _config(BotConfig.Tier.EXPERT)
	var first: String = BotScript.text_of(BotScript.decide(seats, ["3"], 0, expert))
	assert_str(BotScript.text_of(BotScript.decide(seats, ["3"], 0, expert))).is_equal(first)


func test_an_expired_budget_falls_back_to_the_hard_decision() -> void:
	var round_state: RoundState = BotScript.round_after(["39TJQ", "4578", "6KA"], ["3"])
	var table: BotTable = BotTable.new(_rules, _map)
	var view: SeatView = round_state.view_for(1)
	var legal: Array[Pattern] = round_state.legal_moves()
	var job: BotSearchJob = Bot.search_job(view, legal, table, _config(BotConfig.Tier.EXPERT))
	var clock: Callable = func() -> int: return Time.get_ticks_usec() * 1000
	var budget: BotBudget = BotBudget.new(1, clock)
	OS.delay_msec(1)
	assert_object(ExpertSearch.run(job, budget)).is_same(job.fallback)


func _search_job(weights: BotWeights) -> BotSearchJob:
	var round_state: RoundState = BotScript.round_after(["39TJQ", "4578", "6KA"], ["3"])
	var table: BotTable = BotTable.new(_rules, _map)
	var config: BotConfig = BotConfig.new(weights, BotConfig.Tier.EXPERT)
	return Bot.search_job(round_state.view_for(1), round_state.legal_moves(), table, config)


func test_a_rival_short_of_the_margin_leaves_the_policy_play() -> void:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
	weights.expert_margin = 2.0
	var job: BotSearchJob = _search_job(weights)
	assert_object(ExpertSearch.run(job, BotBudget.unlimited())).is_same(job.fallback)


func test_a_rival_past_the_margin_overturns_the_policy_play() -> void:
	var job: BotSearchJob = _search_job(BotConfig.DEFAULT_WEIGHTS)
	var play: BotPlay = ExpertSearch.run(job, BotBudget.unlimited())
	assert_bool(job.fallback.is_pass()).is_false()
	assert_bool(play.is_pass()).is_true()
	assert_int(play.rationale).is_equal(BotRationale.Code.SEARCHED)


func test_the_margin_rounds_up_and_needs_a_lead() -> void:
	assert_bool(BotSearchJob.clears_margin(5, 48, 0.125)).is_false()
	assert_bool(BotSearchJob.clears_margin(6, 48, 0.125)).is_true()
	assert_bool(BotSearchJob.clears_margin(1, 12, 0.125)).is_false()
	assert_bool(BotSearchJob.clears_margin(2, 12, 0.125)).is_true()
	assert_bool(BotSearchJob.clears_margin(1, 9, 0.125)).is_false()
	assert_bool(BotSearchJob.clears_margin(2, 9, 0.125)).is_true()
	assert_bool(BotSearchJob.clears_margin(0, 48, 0.0)).is_false()


func test_a_deadline_stops_the_samples_and_decides_on_those_finished() -> void:
	var job: BotSearchJob = _search_job(BotConfig.DEFAULT_WEIGHTS)
	var ticks: Array[int] = [0]
	var clock: Callable = func() -> int:
		ticks[0] += 1
		return ticks[0] - 1
	var budget: BotBudget = BotBudget.new(BotConfig.DEFAULT_WEIGHTS.expert_min_samples + 1, clock)
	ExpertSearch.run(job, budget)
	assert_int(job.finished_samples()).is_equal(BotConfig.DEFAULT_WEIGHTS.expert_min_samples)


func test_the_default_samples_can_reach_the_minimum() -> void:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
	assert_int(weights.expert_samples).is_greater_equal(weights.expert_min_samples)


func test_too_few_finished_samples_leave_the_policy_play() -> void:
	var job: BotSearchJob = _search_job(BotConfig.DEFAULT_WEIGHTS)
	for sample: int in BotConfig.DEFAULT_WEIGHTS.expert_min_samples - 1:
		job.run_sample(sample)
	assert_object(job.best()).is_same(job.fallback)


func test_enough_finished_samples_decide_at_a_deadline() -> void:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
	weights.expert_margin = 0.0
	var job: BotSearchJob = _search_job(weights)
	for sample: int in weights.expert_min_samples:
		job.run_sample(sample)
	assert_int(job.best().rationale).is_equal(BotRationale.Code.SEARCHED)


func test_the_unseen_deal_fits_every_hand_and_keeps_the_kitty_with_the_landlord() -> void:
	var deal: DealResult = RoundScript.stacked_deal(["3456", "789", "TJQ"], "KA2")
	var round_state: RoundState = RoundState.new(deal, 0, _table)
	var view: SeatView = round_state.view_for(1)
	var config: BotConfig = _config(BotConfig.Tier.EXPERT)
	var table: BotTable = BotTable.new(_rules, _map)
	var scorer: CandidateScorer = CandidateScorer.new(view.own_counts, table, config.weights)
	var position: BotPosition = BotPosition.new(view, table, config, scorer)
	var hands: Array[PackedByteArray] = ExpertSearch.deal_unseen(position, 0)
	assert_int(hands[0][Ranks.KING]).is_equal(1)
	assert_int(hands[0][Ranks.ACE]).is_equal(1)
	assert_int(hands[0][Ranks.TWO]).is_equal(1)
	var size: int = 0
	for rank: int in Ranks.COUNT:
		size += hands[0][rank]
	assert_int(size).is_equal(view.public.remaining[0])


func test_medium_beats_easy_in_a_small_sample() -> void:
	var rate: float = _rate(_config(BotConfig.Tier.MEDIUM), _config(BotConfig.Tier.EASY), 40)
	assert_float(rate).is_greater(CLEAR_MARGIN)
