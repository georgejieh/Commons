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
