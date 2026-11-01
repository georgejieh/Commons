extends GdUnitTestSuite
## The Expert search on real threads and a real clock.

## COMMONS_TIMING=1 holds the p99 to its limit. CI machines vary too much to enforce it.
const TIMING_FLAG: String = "COMMONS_TIMING"
## Under the limit by the length of a sample, which can't stop part way.
const DEADLINE_USEC: int = 300000
const P99_LIMIT_USEC: int = 400000
const SOON_USEC: int = 1
const LONG_USEC: int = 10000000

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: SeatRules = SeatRules.uniform(_rules, _map)
var _bot_table: BotTable = BotTable.new(_rules, _map)
var _expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)


func _times_for_game(deal_seed: int) -> PackedInt64Array:
	var deal: DealResult = SelfPlay.deal_from_seed(deal_seed)
	var round_state: RoundState = RoundState.new(deal, 0, _table)
	var times: PackedInt64Array = PackedInt64Array()
	while not round_state.is_over():
		var seat: int = round_state.seat_to_act()
		var legal: Array[Pattern] = round_state.legal_moves()
		var started: int = Time.get_ticks_usec()
		var play: BotPlay = ExpertRunner.new().decide(
			round_state.view_for(seat), legal, _bot_table, _expert, DEADLINE_USEC
		)
		times.append(Time.get_ticks_usec() - started)
		var action: RoundAction = RoundAction.new(seat)
		if not play.is_pass():
			action = round_state.action_for(play.pattern)
		assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
	return times


func test_p99_stays_under_the_limit() -> void:
	var times: PackedInt64Array = PackedInt64Array()
	for deal_seed: int in LongRun.sample(3, 40):
		times.append_array(_times_for_game(deal_seed))
	times.sort()
	@warning_ignore("integer_division")
	var p99: int = times[times.size() * 99 / 100]
	print("expert on threads: %d decisions, p99 %d usec" % [times.size(), p99])
	if OS.get_environment(TIMING_FLAG) == "1":
		assert_int(p99).is_less(P99_LIMIT_USEC)


func test_a_passed_deadline_leaves_the_hard_decision() -> void:
	var round_state: RoundState = BotScript.round_after(["39TJQ", "4578", "6KA"], ["3"])
	var view: SeatView = round_state.view_for(1)
	var legal: Array[Pattern] = round_state.legal_moves()
	var play: BotPlay = ExpertRunner.new().decide(view, legal, _bot_table, _expert, SOON_USEC)
	assert_int(play.rationale).is_not_equal(BotRationale.Code.SEARCHED)


func test_a_runner_searches_again_after_a_missed_deadline() -> void:
	var round_state: RoundState = BotScript.round_after(["39TJQ", "4578", "6KA"], ["3"])
	var view: SeatView = round_state.view_for(1)
	var legal: Array[Pattern] = round_state.legal_moves()
	var runner: ExpertRunner = ExpertRunner.new()
	runner.decide(view, legal, _bot_table, _expert, SOON_USEC)
	var play: BotPlay = runner.decide(view, legal, _bot_table, _expert, LONG_USEC)
	assert_int(play.rationale).is_equal(BotRationale.Code.SEARCHED)
