extends GdUnitTestSuite
## One test per personality parameter: the direction of its effect, over seeded games.

var _table: SeatRules = SeatRules.uniform(RuleSet.default_rules(), Ranks.identity_map())
var _bot_table: BotTable = BotTable.new(RuleSet.default_rules(), Ranks.identity_map())


func _games() -> int:
	return LongRun.sample(120, 1000)


func _medium(level_setter: Callable, level: Personality.Level) -> BotConfig:
	var personality: Personality = Personality.new()
	personality.tier = BotConfig.Tier.MEDIUM
	personality.bomb_aggression = Personality.Level.MID
	personality.cooperation = Personality.Level.MID
	personality.honesty = Personality.Level.MID
	personality.ambition = Personality.Level.MID
	personality.grudge = Personality.Level.MID
	level_setter.call(personality, level)
	return BotConfig.from_personality(personality, 77)


func _set_bombs(personality: Personality, level: Personality.Level) -> void:
	personality.bomb_aggression = level


func _set_cooperation(personality: Personality, level: Personality.Level) -> void:
	personality.cooperation = level


func _set_honesty(personality: Personality, level: Personality.Level) -> void:
	personality.honesty = level


func _set_ambition(personality: Personality, level: Personality.Level) -> void:
	personality.ambition = level


func _set_grudge(personality: Personality, level: Personality.Level) -> void:
	personality.grudge = level


## Plays seat 1 and 2 as config, against a plain Medium landlord.
func _peasant_results(config: BotConfig) -> Array[SelfPlayResult]:
	var landlord: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
	var seats: Array[BotConfig] = [landlord, config, config]
	var results: Array[SelfPlayResult] = []
	for deal_seed: int in _games():
		var deal: DealResult = SelfPlay.deal_from_seed(deal_seed)
		results.append(SelfPlay.play_round(deal, 0, seats, _table))
	return results


func _bombs_by_peasants(config: BotConfig) -> int:
	var bombs: int = 0
	for result: SelfPlayResult in _peasant_results(config):
		bombs += result.bombs[1] + result.bombs[2]
	return bombs


func _plays_over_teammate(config: BotConfig) -> int:
	var plays: int = 0
	for result: SelfPlayResult in _peasant_results(config):
		plays += result.answers[1 * Seats.COUNT + 2] + result.answers[2 * Seats.COUNT + 1]
	return plays


func _plays_over_hated_seat(config: BotConfig) -> int:
	var seats: Array[BotConfig] = [config, BotConfig.new(), BotConfig.new()]
	seats[1].tier = BotConfig.Tier.MEDIUM
	seats[2].tier = BotConfig.Tier.MEDIUM
	config.memory = PackedFloat32Array([0.0, 1.0, 0.0])
	var plays: int = 0
	for deal_seed: int in _games():
		var deal: DealResult = SelfPlay.deal_from_seed(deal_seed)
		plays += SelfPlay.play_round(deal, 0, seats, _table).answers[1]
	return plays


func _claims(config: BotConfig) -> int:
	var claims: int = 0
	var budget: BotBudget = BotBudget.unlimited()
	for deal_seed: int in _games():
		var counts: PackedByteArray = SelfPlay.deal_from_seed(deal_seed).hands[0].counts()
		if Bot.decide_bid(counts, false, false, _bot_table, config, budget):
			claims += 1
	return claims


func _lies(config: BotConfig) -> int:
	var lies: int = 0
	var stream: RandomStream = RandomStream.new(2110)
	var budget: BotBudget = BotBudget.unlimited()
	for _split: int in _games():
		if Bot.declare_need(10, config, stream, budget) != 10:
			lies += 1
	return lies


func test_bomb_aggression_raises_bombs() -> void:
	var low: int = _bombs_by_peasants(_medium(_set_bombs, Personality.Level.LOW))
	var high: int = _bombs_by_peasants(_medium(_set_bombs, Personality.Level.HIGH))
	print("peasant bombs low %d high %d" % [low, high])
	assert_int(high).is_greater(low)


func test_cooperation_lowers_plays_over_a_teammate() -> void:
	var low: int = _plays_over_teammate(_medium(_set_cooperation, Personality.Level.LOW))
	var high: int = _plays_over_teammate(_medium(_set_cooperation, Personality.Level.HIGH))
	print("over teammate low %d high %d" % [low, high])
	assert_int(low).is_greater(high)


func test_honesty_lowers_lies() -> void:
	var low: int = _lies(_medium(_set_honesty, Personality.Level.LOW))
	var high: int = _lies(_medium(_set_honesty, Personality.Level.HIGH))
	assert_int(low).is_greater(high)
	assert_int(high).is_equal(0)


func test_honesty_shrinks_a_lie() -> void:
	var low: BotConfig = _medium(_set_honesty, Personality.Level.LOW)
	var mid: BotConfig = _medium(_set_honesty, Personality.Level.MID)
	low.honesty = 0.0
	mid.honesty = 0.0
	var budget: BotBudget = BotBudget.unlimited()
	var stream: RandomStream = RandomStream.new(2112)
	var low_need: int = Bot.declare_need(10, low, stream, budget)
	assert_int(low_need).is_greater(Bot.declare_need(10, mid, stream, budget))


func test_a_lie_only_ever_inflates_need() -> void:
	var stream: RandomStream = RandomStream.new(2111)
	var config: BotConfig = _medium(_set_honesty, Personality.Level.LOW)
	for _split: int in 200:
		var budget: BotBudget = BotBudget.unlimited()
		assert_int(Bot.declare_need(0, config, stream, budget)).is_greater_equal(0)
		assert_int(Bot.declare_need(10, config, stream, budget)).is_greater_equal(10)


func test_ambition_raises_claims() -> void:
	var low: int = _claims(_medium(_set_ambition, Personality.Level.LOW))
	var high: int = _claims(_medium(_set_ambition, Personality.Level.HIGH))
	print("claims low %d high %d" % [low, high])
	assert_int(high).is_greater(low)


func test_grudge_raises_plays_over_a_remembered_seat() -> void:
	var low: int = _plays_over_hated_seat(_medium(_set_grudge, Personality.Level.LOW))
	var high: int = _plays_over_hated_seat(_medium(_set_grudge, Personality.Level.HIGH))
	print("over hated seat low %d high %d" % [low, high])
	assert_int(high).is_greater(low)
