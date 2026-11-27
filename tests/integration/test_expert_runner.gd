extends GdUnitTestSuite
## The Expert search on real threads and a real clock.

## Under the limit by the length of a sample, which can't stop part way.
const DEADLINE_USEC: int = 300000
const SOON_USEC: int = 1
## Shorter than a full search of an opening hand on any machine.
const MID_RUN_USEC: int = 10000
const LONG_USEC: int = 10000000

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: SeatRules = SeatRules.uniform(_rules, _map)
var _bot_table: BotTable = BotTable.new(_rules, _map)
var _expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)


## Plays a whole game of Expert decisions and returns how many it made.
func _decisions_in_game(deal_seed: int) -> int:
	var deal: DealResult = SelfPlay.deal_from_seed(deal_seed)
	var round_state: RoundState = RoundState.new(deal, 0, _table)
	var decisions: int = 0
	while not round_state.is_over():
		var seat: int = round_state.seat_to_act()
		var legal: Array[Pattern] = round_state.legal_moves()
		var play: BotPlay = ExpertRunner.new().decide(
			round_state.view_for(seat), legal, _bot_table, _expert, DEADLINE_USEC
		)
		decisions += 1
		var action: RoundAction = RoundAction.new(seat)
		if not play.is_pass():
			action = round_state.action_for(play.pattern)
		assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
	return decisions


## Whole games played by Expert on threads at its real deadline make only legal plays.
## The deadline's p99 is measured by tools/perf_budget.gd, where time is measured.
func test_expert_on_threads_plays_whole_games() -> void:
	var decisions: int = 0
	for deal_seed: int in LongRun.sample(3, 40):
		decisions += _decisions_in_game(deal_seed)
	assert_int(decisions).is_greater(0)


func test_a_passed_deadline_leaves_the_hard_decision() -> void:
	var round_state: RoundState = BotScript.round_after(["39TJQ", "4578", "6KA"], ["3"])
	var view: SeatView = round_state.view_for(1)
	var legal: Array[Pattern] = round_state.legal_moves()
	var play: BotPlay = ExpertRunner.new().decide(view, legal, _bot_table, _expert, SOON_USEC)
	assert_int(play.rationale).is_not_equal(BotRationale.Code.SEARCHED)


func test_a_deadline_mid_run_skips_the_samples_not_started() -> void:
	var round_state: RoundState = RoundState.new(SelfPlay.deal_from_seed(1), 0, _table)
	var legal: Array[Pattern] = round_state.legal_moves()
	var runner: ExpertRunner = ExpertRunner.new()
	runner.decide(round_state.view_for(0), legal, _bot_table, _expert, MID_RUN_USEC)
	assert_int(runner.finished_samples()).is_less(_expert.search_samples())


func test_a_runner_searches_again_after_a_missed_deadline() -> void:
	var round_state: RoundState = BotScript.round_after(["39TJQ", "4578", "6KA"], ["3"])
	var view: SeatView = round_state.view_for(1)
	var legal: Array[Pattern] = round_state.legal_moves()
	var runner: ExpertRunner = ExpertRunner.new()
	runner.decide(view, legal, _bot_table, _expert, SOON_USEC)
	var play: BotPlay = runner.decide(view, legal, _bot_table, _expert, LONG_USEC)
	assert_int(play.rationale).is_equal(BotRationale.Code.SEARCHED)
