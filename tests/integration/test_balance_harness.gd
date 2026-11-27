extends GdUnitTestSuite
## ADR 0027's balance harness: each strategy plays full runs to their end with every
## command accepted, a seed plays the same twice, and each strategy's own choices happen
## in a real run. The seeds are ones whose runs end early at the base stake, so the
## suite stays quick: a run seated with an Expert family takes minutes.

## Seeds whose runs are short for every strategy, the shortest first.
const SEEDS: Array[int] = [16, 2]
const STAKE: int = 0

var _runs: Dictionary[String, Array] = {}
var _errors: BalanceErrors


func before() -> void:
	_errors = BalanceErrors.new()
	OS.add_logger(_errors)
	for strategy: String in BalanceDriver.STRATEGIES:
		var played: Array[BalanceResult] = []
		for seed_value: int in SEEDS:
			played.append(_play(strategy, seed_value))
		_runs[strategy] = played


func after() -> void:
	OS.remove_logger(_errors)


func _play(strategy: String, seed_value: int) -> BalanceResult:
	var driver: BalanceDriver = BalanceDriver.new(
		BalanceDriver.strategy_named(strategy), STAKE, _errors
	)
	return driver.play(seed_value)


func _each(strategy: String) -> Array[BalanceResult]:
	var played: Array[BalanceResult] = []
	played.assign(_runs[strategy])
	return played


func test_every_strategy_plays_its_runs_to_their_end() -> void:
	for strategy: String in BalanceDriver.STRATEGIES:
		for run: BalanceResult in _each(strategy):
			var case: String = "%s seed %d" % [strategy, run.seed_value]
			assert_str(run.failure).override_failure_message(case + ": " + run.failure).is_empty()
			assert_str(run.outcome).override_failure_message(case).is_not_empty()
			assert_int(run.quotas_played).override_failure_message(case).is_greater(0)
			var columns: int = BalanceResult.HEADER.split(",").size()
			assert_int(run.csv().split(",").size()).override_failure_message(case).is_equal(columns)


func test_a_seed_plays_the_same_twice() -> void:
	var first: BalanceResult = _each("collective")[0]
	var again: BalanceResult = _play("collective", first.seed_value)
	assert_str(again.csv(false)).is_equal(first.csv(false))
	var rows: PackedStringArray = first.ledger.csv(first.seed_value, first.strategy)
	assert_array(again.ledger.csv(again.seed_value, again.strategy)).is_equal(rows)


func test_collective_never_calls_and_never_buys_privately() -> void:
	for run: BalanceResult in _each("collective"):
		assert_int(run.calls + run.grabs).is_equal(0)
		assert_int(run.landlord_rounds).is_equal(0)
		assert_int(run.market_buys).is_equal(0)
		assert_int(run.market_resentment).is_equal(0)
		assert_int(run.swapped_cards).is_equal(0)
		assert_int(run.max_need).is_less_equal(RunDefaults.PARAMS.base_need)


func test_every_strategy_issues_directives() -> void:
	for strategy: String in BalanceDriver.STRATEGIES:
		var issued: int = 0
		for run: BalanceResult in _each(strategy):
			issued += run.directive_buys
		assert_int(issued).override_failure_message(strategy).is_greater(0)


## A row per Quota played to its end, each against the target the run started it with,
## met as the run itself said.
func test_each_quota_played_has_its_row() -> void:
	for strategy: String in BalanceDriver.STRATEGIES:
		for run: BalanceResult in _each(strategy):
			var case: String = "%s seed %d" % [strategy, run.seed_value]
			var rows: Array[BalanceQuota] = run.ledger.quotas
			assert_int(rows.size()).override_failure_message(case).is_equal(run.quotas_played)
			var started: Array[RunEvent] = run.ledger.events.filter(
				func(event: RunEvent) -> bool: return event.type == RunEvent.Type.SET_STARTED
			)
			var ended: Array[RunEvent] = run.ledger.events.filter(
				func(event: RunEvent) -> bool: return event.type == RunEvent.Type.SET_ENDED
			)
			assert_int(ended.size()).is_equal(rows.size())
			for at: int in rows.size():
				var row: BalanceQuota = rows[at]
				assert_int(row.index).override_failure_message(case).is_equal(at + 1)
				assert_float(row.target).is_equal_approx(started[at].amount, 0.001)
				assert_bool(row.met).override_failure_message(case).is_equal(ended[at].value == 1)
				assert_float(row.progress).is_equal_approx(ended[at].amount, 0.001)
				assert_int(row.rounds).is_greater(0)
				var columns: int = BalanceQuota.HEADER.split(",").size()
				assert_int(row.csv(run.seed_value, strategy).split(",").size()).is_equal(columns)
			var lines: PackedStringArray = run.ledger.csv(run.seed_value, strategy)
			assert_int(lines.size()).is_equal(rows.size())


func test_lowered_expert_samples_play_the_same_twice_and_leave_the_game_alone() -> void:
	var first: BalanceResult = _sampled(SEEDS[0])
	var again: BalanceResult = _sampled(SEEDS[0])
	assert_str(again.csv(false)).is_equal(first.csv(false))
	var rows: PackedStringArray = first.ledger.csv(first.seed_value, first.strategy)
	assert_array(again.ledger.csv(again.seed_value, again.strategy)).is_equal(rows)
	assert_int(BotConfig.DEFAULT_WEIGHTS.expert_samples).is_equal(48)
	assert_int(BotConfig.DEFAULT_WEIGHTS.expert_min_samples).is_equal(12)


func _sampled(seed_value: int) -> BalanceResult:
	var driver: BalanceDriver = BalanceDriver.new(
		BalanceDriver.strategy_named("collective"), STAKE, _errors
	)
	driver.search_weights = BalanceDriver.sampling(12)
	return driver.play(seed_value)


func test_private_enters_the_market_and_over_claims() -> void:
	var market_buys: int = 0
	for run: BalanceResult in _each("private"):
		market_buys += run.market_buys
		assert_int(run.store_buys).is_equal(0)
		assert_int(run.deck_spent).is_equal(0)
		assert_int(run.max_need).is_equal(RunStarter.DEMO_RUN.need_cap)
		assert_int(run.market_resentment).is_greater(0)
	assert_int(market_buys).is_greater(0)


func test_mixed_keeps_coupons_back_and_stops_at_the_limit() -> void:
	var store_buys: int = 0
	for run: BalanceResult in _each("mixed"):
		# A Directive is issued from everything held; the floor is for what follows it.
		store_buys += run.store_buys + run.directive_buys
		assert_int(run.grabs).is_equal(0)
		if run.store_buys > 0:
			assert_int(run.store_floor).is_greater_equal(BalanceDriver.PARAMS.kept_back)
		assert_int(run.market_buys_over_limit).is_equal(0)
		assert_int(run.market_buys_per_visit).is_less_equal(1)
	assert_int(store_buys).is_greater(0)
