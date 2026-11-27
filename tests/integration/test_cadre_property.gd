extends GdUnitTestSuite
## A property over many seeds (ADR 0021): the player holds a random set of the 24 Cadres,
## the collective ones reaching every seat, with random picked ranks, Years held, counts
## and stamped cards, while villagers of every tier play whole Sets. No villager makes an
## illegal action (the loop asserts on one, which fails the test), every round finishes,
## and every score is finite and never negative.

const SEEDS: int = 24
const HELD: int = 5
const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD, BotConfig.Tier.EXPERT
]
const STEP_LIMIT: int = 900
const EXPERT_SAMPLES: int = 4
const STAMPS: int = 12


func _configs(seed_value: int) -> Array[BotConfig]:
	var configs: Array[BotConfig] = [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
	]
	for seat: int in [1, 2]:
		var tier: BotConfig.Tier = TIERS[(seed_value + seat * 3) % TIERS.size()]
		var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
		if tier == BotConfig.Tier.EXPERT:
			weights = BotConfig.DEFAULT_WEIGHTS.duplicate()
			weights.expert_samples = EXPERT_SAMPLES
			weights.expert_min_samples = 2
		configs.append(BotConfig.new(weights, tier))
	return configs


## A random hand of Cadres with random run state, and some deck cards stamped.
func _stock(state: RunState, stream: RandomStream) -> void:
	var pool: Array[ModifierDef] = RunLoop.all_cadres()
	while state.inventory.cadres.size() < HELD:
		var pick: ModifierDef = pool[stream.next_int(0, pool.size() - 1)]
		if state.inventory.cadres.has(pick.id):
			continue
		state.inventory.cadres.append(pick.id)
		var memo: CadreMemo = state.cadre_memos.entry(pick.id)
		memo.put(CadreMemo.RANK, stream.next_int(Ranks.THREE, Ranks.TWO))
		memo.put(CadreMemo.YEARS, stream.next_int(0, 8))
		for key: String in ["bombs", "met", "long_straights", "passed"]:
			memo.put(key, stream.next_int(0, 6))
	for _stamp: int in STAMPS:
		state.card_marks.stamps[stream.next_int(0, Deck.SIZE - 1)] = RunLoop.PLAYER


func test_random_cadres_keep_every_round_legal_whole_and_scored_sanely() -> void:
	var tiers_seen: Dictionary[int, bool] = {}
	var held_seen: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var configs: Array[BotConfig] = _configs(seed_value)
		tiers_seen[configs[1].tier] = true
		tiers_seen[configs[2].tier] = true
		var state: RunState = RunState.new(seed_value + 700)
		_stock(state, RandomStream.new(seed_value))
		for cadre_id: String in state.inventory.cadres:
			held_seen[cadre_id] = true
		var loop: RunLoop = RunLoop.new(state, configs, SetConfig.new())
		loop.start_set()
		_play_set(loop)
	assert_int(tiers_seen.size()).is_equal(TIERS.size())
	assert_int(held_seen.size()).is_greater(18)


func _play_set(loop: RunLoop) -> void:
	var script: RunScript = RunScript.new()
	var scores: Array[float] = []
	for _step: int in STEP_LIMIT:
		_collect(loop, scores)
		if not script.act(loop):
			break
	_collect(loop, scores)
	var over: Array[RunLoop.Awaiting] = [RunLoop.Awaiting.SET_OVER, RunLoop.Awaiting.RUN_OVER]
	assert_bool(over.has(loop.awaiting())).override_failure_message("stuck").is_true()
	assert_int(scores.size()).is_greater(0)
	for score: float in scores:
		(
			assert_bool(is_finite(score) and score >= 0.0)
			. override_failure_message(str(score))
			. is_true()
		)


func _collect(loop: RunLoop, scores: Array[float]) -> void:
	scores.clear()
	for event: RunEvent in loop.events():
		var scored: bool = event.type == RunEvent.Type.PLAY_SCORED
		if scored or event.type == RunEvent.Type.ROUND_SCORED:
			scores.append(event.amount)
			if scored:
				scores.append(event.grain)
				scores.append(event.zeal)
