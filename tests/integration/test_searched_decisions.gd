extends GdUnitTestSuite
## ADR 0030: a searching villager's plays are written to the run record, a resume replays
## them without asking the searcher, a written play that no longer fits fails the resume,
## an older save replays with the unlimited search, and only the live game searches.

const SEED: int = 3007
## Player turns played before a save is taken, and after it.
const TURNS: int = 12
const DIR: String = "user://test_searched/"

## Searcher calls, and those that played something other than the policy's play.
var _calls: int = 0
var _overturned: int = 0


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_calls = 0
	_overturned = 0


func after_test() -> void:
	SaveService.for_run(DIR + "run.json").delete()


## Seat 1 is Expert, sampling the fewest deals a search may decide on.
func _configs() -> Array[BotConfig]:
	var fast: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
	fast.expert_samples = fast.expert_min_samples
	return [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.new(fast, BotConfig.Tier.EXPERT, SEED),
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD),
	]


## A searcher that plays the first legal move the policy would not, so a replay that
## searched again would not land where the run did.
func _overturn(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig
) -> BotPlay:
	_calls += 1
	var policy: Pattern = Bot.search_job(view, legal, table, config).fallback.pattern
	for move: Pattern in legal:
		if not move.equals(policy):
			_overturned += 1
			return BotPlay.new(move, BotRationale.Code.SEARCHED)
	return BotPlay.new(policy, BotRationale.Code.SEARCHED)


func _loop(searcher: Callable, turns: int) -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), _configs(), SetConfig.new())
	loop.decisions.searcher = searcher
	loop.start_set()
	_act(loop, turns)
	return loop


func _act(loop: RunLoop, turns: int) -> void:
	var script: RunScript = RunScript.new()
	for _turn: int in turns:
		if not script.act(loop):
			return


## The record as a load reads it back: written as JSON, migrated and validated.
func _through_disk(data: Dictionary, version: int = SaveService.SCHEMA_VERSION) -> Dictionary:
	var file: FileAccess = FileAccess.open(DIR + "run.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": version, "data": data}))
	file.close()
	var loaded: SaveLoad = SaveService.for_run(DIR + "run.json").load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	return loaded.data


func _resume(data: Dictionary, searcher: Callable = Callable()) -> RunLoop:
	return RunRecord.resume(
		data,
		_configs(),
		SetConfig.new(),
		RunLoop.DEFAULT_PARAMS,
		RunLoop.DEFAULT_POOL.debuffs,
		RunLoop.DEFAULT_METERS,
		searcher
	)


func _text(data: Dictionary) -> String:
	return JSON.stringify(data, "", true)


func test_a_searched_run_writes_its_decisions_and_a_resume_replays_them() -> void:
	var loop: RunLoop = _loop(_overturn, TURNS)
	var made: int = _calls
	assert_int(made).is_greater(0)
	assert_int(_overturned).is_greater(0)
	var saved: Dictionary = _through_disk(loop.record.to_dict())
	assert_bool(saved[RunRecord.WRITTEN_KEY]).is_true()
	var written: Array = saved["decisions"]
	assert_int(written.size()).is_greater_equal(made)
	_calls = 0
	var resumed: RunLoop = _resume(saved, _overturn)
	assert_object(resumed).is_not_null()
	assert_int(_calls).is_equal(0)
	assert_int(resumed.awaiting()).is_equal(loop.awaiting())
	assert_str(_text(resumed.state.to_dict())).is_equal(_text(loop.state.to_dict()))
	# The replayed decisions stay in the new record, so a later save still holds them.
	assert_str(_text(resumed.record.to_dict())).is_equal(_text(loop.record.to_dict()))
	_act(resumed, TURNS)
	assert_int(_calls).is_greater(0)
	_act(loop, TURNS)
	assert_str(_text(resumed.state.to_dict())).is_equal(_text(loop.state.to_dict()))


func test_a_written_decision_that_no_longer_fits_fails_the_resume() -> void:
	var saved: Dictionary = _through_disk(_loop(_overturn, TURNS).record.to_dict())
	assert_object(_resume(saved)).is_not_null()
	var other_seat: Dictionary = saved.duplicate(true)
	other_seat["decisions"][0]["seat"] = 2
	var illegal: Dictionary = saved.duplicate(true)
	illegal["decisions"][0]["cards"] = [9999]
	# Emptied, the list ends long before the last command is replayed.
	var short: Dictionary = saved.duplicate(true)
	var fewer: Array = short["decisions"]
	fewer.clear()
	var left_over: Dictionary = saved.duplicate(true)
	var more: Array = left_over["decisions"]
	var last: Dictionary = more[-1]
	more.append(last.duplicate(true))
	var tampered: Dictionary = {
		"another seat": other_seat,
		"illegal cards": illegal,
		"runs out": short,
		"left over": left_over
	}
	for name: String in tampered:
		# Each keeps the shape a save may have: the replay refuses it, not the validator.
		assert_bool(RunRecord.is_valid(tampered[name])).override_failure_message(name).is_true()
		assert_object(_resume(tampered[name])).override_failure_message(name).is_null()


## The game saves at every state move, and one inside a command comes before the
## villagers that command sets playing. Such a save holds none of their plays, and the
## resume decides them then, with the searcher, landing where the run did.
func test_a_save_written_inside_its_last_command_goes_on_live() -> void:
	var loop: RunLoop = _loop(_overturn, TURNS)
	var script: RunScript = RunScript.new()
	var before: int = loop.record.decisions.size()
	var commands: int = loop.record.commands.size()
	var asked: int = 0
	for _turn: int in 40:
		before = loop.record.decisions.size()
		commands = loop.record.commands.size()
		asked = _calls
		assert_bool(script.act(loop)).is_true()
		asked = _calls - asked
		if asked > 0 and loop.record.commands.size() == commands + 1:
			break
	assert_int(asked).is_greater(0)
	var saved: Dictionary = _through_disk(loop.record.to_dict())
	var written: Array = saved["decisions"]
	written.resize(before)
	assert_bool(RunRecord.is_valid(saved)).is_true()
	_calls = 0
	var resumed: RunLoop = _resume(saved, _overturn)
	assert_object(resumed).is_not_null()
	assert_int(_calls).is_equal(asked)
	assert_int(resumed.awaiting()).is_equal(loop.awaiting())
	assert_str(_text(resumed.state.to_dict())).is_equal(_text(loop.state.to_dict()))
	assert_str(_text(resumed.record.to_dict())).is_equal(_text(loop.record.to_dict()))


func test_written_decisions_of_the_wrong_shape_are_a_damaged_save() -> void:
	var record: RunRecord = RunRecord.new()
	record.mark(RunState.new(SEED))
	var empty: Array[int] = []
	record.decide(1, [5, 6])
	record.decide(2, empty)
	assert_bool(RunRecord.is_valid(record.to_dict())).is_true()
	var wrong: Array = [
		["decisions", {}],
		["decisions", [{"seat": 0, "cards": []}]],
		["decisions", [{"seat": 3, "cards": []}]],
		["decisions", [{"seat": 1.5, "cards": []}]],
		["decisions", [{"seat": "1", "cards": []}]],
		["decisions", [{"seat": 1, "cards": {}}]],
		["decisions", [{"seat": 1, "cards": [-1]}]],
		["decisions", [{"seat": 1, "cards": [2.5]}]],
		["decisions", [{"seat": 1}]],
		["decisions", [{"seat": 1, "cards": [], "pattern": 2}]],
		["decisions", [7]],
		[RunRecord.WRITTEN_KEY, "yes"],
		[RunRecord.WRITTEN_KEY, false],
	]
	for change: Array in wrong:
		var data: Dictionary = record.to_dict()
		data[change[0]] = change[1]
		assert_bool(RunRecord.is_valid(data)).override_failure_message(str(change)).is_false()
	var unmarked: Dictionary = record.to_dict()
	unmarked.erase(RunRecord.WRITTEN_KEY)
	assert_bool(RunRecord.is_valid(unmarked)).is_false()
	var none_written: Dictionary = RunRecord.migrate_from_12(record.to_dict())
	assert_bool(RunRecord.is_valid(none_written)).is_true()


## A schema 12 save with an Expert seat replays with the unlimited search, as it was made,
## and the resumed record writes every decision from there.
func test_a_schema_12_save_replays_with_the_unlimited_search() -> void:
	assert_int(SaveService.SCHEMA_VERSION).is_greater_equal(13)
	var loop: RunLoop = _loop(Callable(), TURNS)
	assert_int(loop.record.decisions.size()).is_greater(0)
	var old: Dictionary = loop.record.to_dict()
	old.erase("decisions")
	old.erase(RunRecord.WRITTEN_KEY)
	var migrated: Dictionary = _through_disk(old, 12)
	assert_bool(migrated[RunRecord.WRITTEN_KEY]).is_false()
	assert_array(migrated["decisions"]).is_empty()
	var resumed: RunLoop = _resume(migrated, _overturn)
	assert_object(resumed).is_not_null()
	assert_int(_calls).is_equal(0)
	assert_str(_text(resumed.state.to_dict())).is_equal(_text(loop.state.to_dict()))
	assert_str(_text(resumed.record.to_dict())).is_equal(_text(loop.record.to_dict()))


func test_a_run_without_a_searching_seat_writes_no_decisions() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	assert_array(loop.record.decisions).is_empty()


func test_a_scripted_or_unsearching_seat_is_never_searched() -> void:
	var expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	assert_bool(SearchedDecisions.searches(expert)).is_true()
	for tier: int in [BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD]:
		var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier as BotConfig.Tier)
		assert_bool(SearchedDecisions.searches(config)).is_false()
	# The arrival scripts every villager seat, an Expert one too.
	var configs: Array[BotConfig] = _configs()
	RunTutorial.new(RunTutorial.SCRIPT, configs)
	assert_bool(configs[1].searches()).is_true()
	assert_bool(SearchedDecisions.searches(configs[1])).is_false()


## A searching seat decides with the weights a tool hands in, and gets its own back.
func test_a_searching_seat_decides_with_the_weights_handed_in() -> void:
	var rules: RuleSet = RuleSet.default_rules()
	var deal: DealResult = SelfPlay.deal_from_seed(SEED)
	var round_state: RoundState = RoundState.new(
		deal, 0, SeatRules.uniform(rules, Ranks.identity_map())
	)
	var decisions: SearchedDecisions = SearchedDecisions.new(RunRecord.new())
	decisions.weights = BalanceDriver.sampling(12)
	var seen: Array[int] = []
	decisions.searcher = func(
		_view: SeatView, legal: Array[Pattern], _table: BotTable, config: BotConfig
	) -> BotPlay:
		seen.append(config.weights.expert_samples)
		return BotPlay.new(legal[0], BotRationale.Code.SEARCHED)
	var expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	var seat: int = round_state.seat_to_act()
	decisions.decide(
		round_state.view_for(seat),
		round_state.legal_moves(),
		BotTable.new(rules, Ranks.identity_map()),
		expert
	)
	assert_array(seen).contains_exactly([12])
	assert_object(expert.weights).is_same(BotConfig.DEFAULT_WEIGHTS)
	assert_int(BotConfig.DEFAULT_WEIGHTS.expert_samples).is_equal(48)


func test_the_live_game_searches_and_the_harness_does_not() -> void:
	var live: RunController = auto_free(RunController.new())
	live.start_run(SEED, RunScript.bots(), SetConfig.new())
	var live_loop: RunLoop = live.get("_loop")
	assert_bool(live_loop.decisions.searcher.is_valid()).is_true()
	var driver: BalanceDriver = BalanceDriver.new(BalanceDriver.strategy_named("collective"))
	var harness: RunController = auto_free(driver.new_controller())
	harness.start_run(SEED, RunScript.bots(), SetConfig.new())
	var harness_loop: RunLoop = harness.get("_loop")
	assert_bool(harness_loop.decisions.searcher.is_valid()).is_false()
