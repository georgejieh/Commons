extends GdUnitTestSuite
## ADR 0025: a family's warmth is the mirror of its pull, and a warm teammate's
## cooperation rises by warmth times loyal_cooperation, never past certain.

const MEMORY: MemoryParams = preload("res://data/villagers/memory.tres")
const FAR: String = "3456789TJQKA"
const SEEDS: int = 64


func test_warmth_mirrors_pull() -> void:
	var memory: VillageMemory = VillageMemory.new()
	var summary: SetSummary = SetSummary.new(0)
	summary.add("li", SetSummary.Kind.FED, 5)
	summary.add("chen", SetSummary.Kind.FED, 40)
	summary.add("gao", SetSummary.Kind.BOMBED, 2)
	memory.record(summary)
	assert_float(memory.warmth("li", MEMORY)).is_equal_approx(0.5, 0.0001)
	assert_float(memory.warmth("chen", MEMORY)).is_equal(1.0)
	assert_float(memory.warmth("gao", MEMORY)).is_equal(0.0)
	assert_float(memory.warmth("stranger", MEMORY)).is_equal(0.0)
	assert_float(memory.pull("li", MEMORY)).is_equal(0.0)


func test_loyalty_never_lifts_cooperation_past_its_maximum() -> void:
	var config: BotConfig = BotConfig.new()
	config.cooperation = 0.85
	config.loyalty = 0.3
	assert_float(config.team_cooperation()).is_equal(BotConfig.MAX_COOPERATION)
	config.cooperation = 0.5
	assert_float(config.team_cooperation()).is_equal_approx(0.8, 0.0001)
	config.loyalty = 0.0
	assert_float(config.team_cooperation()).is_equal(0.5)


## The same seeded position, the teammate's low single on the table and the landlord
## passed: a warm teammate leaves the trick to its partner more often, and never answers
## where a neutral one would have passed.
func test_a_warm_teammate_covers_where_a_neutral_one_answers() -> void:
	var seats: Array[String] = [FAR, "6KK", "4" + FAR.substr(1)]
	var plays: Array[String] = ["3", "", "4", ""]
	var neutral_passes: int = 0
	var warm_passes: int = 0
	for seed_value: int in SEEDS:
		var neutral: BotConfig = _config(seed_value, 0.0)
		var warm: BotConfig = _config(seed_value, MEMORY.loyal_cooperation)
		var neutral_play: BotPlay = BotScript.decide(seats, plays, 0, neutral)
		var warm_play: BotPlay = BotScript.decide(seats, plays, 0, warm)
		if neutral_play.is_pass():
			neutral_passes += 1
			assert_bool(warm_play.is_pass()).is_true()
		if warm_play.is_pass():
			warm_passes += 1
	assert_int(warm_passes).is_greater(neutral_passes)


func _config(seed_value: int, loyalty: float) -> BotConfig:
	var config: BotConfig = BotScript.policy_only()
	config.search_seed = seed_value
	config.cooperation = 0.4
	config.loyalty = loyalty
	return config
