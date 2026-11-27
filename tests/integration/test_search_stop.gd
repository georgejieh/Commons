extends GdUnitTestSuite
## A sample still running when its stop expires is abandoned and counts as not
## finished, so an Expert decision has a ceiling whatever the machine (ADR 0030).

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _search_job() -> BotSearchJob:
	var round_state: RoundState = BotScript.round_after(["39TJQ", "4578", "6KA"], ["3"])
	var table: BotTable = BotTable.new(_rules, _map)
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	return Bot.search_job(round_state.view_for(1), round_state.legal_moves(), table, config)


func test_a_sample_whose_stop_expires_is_abandoned() -> void:
	var job: BotSearchJob = _search_job()
	var ticks: Array[int] = [0]
	var clock: Callable = func() -> int:
		ticks[0] += 1
		return ticks[0] - 1
	job.run_sample(0, BotBudget.new(3, clock))
	assert_int(job.finished_samples()).is_equal(0)
	job.run_sample(1, BotBudget.unlimited())
	assert_int(job.finished_samples()).is_equal(1)
	assert_object(job.best()).is_same(job.fallback)


func test_a_rollout_ends_at_once_when_its_stop_has_expired() -> void:
	var hands: Array[PackedByteArray] = [
		RankText.counts("34567"), RankText.counts("A"), RankText.counts("45")
	]
	var table: BotTable = BotTable.new(_rules, _map)
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
	var deck: PackedByteArray = Deck.new().rank_counts()
	var rollout: Rollout = Rollout.new(hands, 0, 0, null, Seats.NONE, 0, table, config, deck)
	var expired: BotBudget = BotBudget.new(1, func() -> int: return Time.get_ticks_usec() * 1000)
	OS.delay_msec(1)
	var steps: int = BotConfig.DEFAULT_WEIGHTS.search_step_limit
	assert_int(rollout.play_out(steps, expired)).is_equal(Seats.NONE)
	assert_int(rollout.play_out(steps)).is_not_equal(Seats.NONE)


## The deadline and the grace together stay under the Expert's 400 ms
## with room for one step.
func test_the_deadline_and_its_grace_leave_room_under_the_budget() -> void:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
	assert_int(weights.expert_grace_usec).is_greater(0)
	assert_int(weights.expert_deadline_usec + weights.expert_grace_usec).is_less_equal(370000)
