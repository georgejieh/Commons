extends GdUnitTestSuite
## Bots read each seat's own rules and rank map, so no modifier set makes them act illegally.

const MODIFIERS: Array[String] = [
	"promotion_of_the_masses", "criticism_meeting", "inverted_order", "cultural_revolution"
]
const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD
]
const SEARCHED_GAMES: int = 3


func _random_table(stream: RandomStream) -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	for name: String in MODIFIERS:
		if stream.next_int(0, 1) == 1:
			var path: String = "res://data/modifiers/%s.tres" % name
			stack.add(ResourceLoader.load(path), stream.next_int(0, Seats.COUNT - 1))
	return SeatRules.new(stack)


func _random_seats(stream: RandomStream) -> Array[BotConfig]:
	var seats: Array[BotConfig] = []
	for _seat: int in Seats.COUNT:
		var tier: BotConfig.Tier = TIERS[stream.next_int(0, TIERS.size() - 1)]
		seats.append(BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier))
	return seats


func _assert_clean(game_seed: int, seats: Array[BotConfig]) -> void:
	var stream: RandomStream = RandomStream.new(game_seed)
	var table: SeatRules = _random_table(stream)
	var deal: DealResult = SelfPlay.deal_from_seed(game_seed)
	var landlord: int = stream.next_int(0, Seats.COUNT - 1)
	var result: SelfPlayResult = SelfPlay.play_round(deal, landlord, seats, table)
	assert_int(result.illegal_actions).is_equal(0)
	assert_bool(result.winner != Seats.NONE).is_true()


func test_random_modifier_sets_produce_no_illegal_action() -> void:
	for game_seed: int in LongRun.sample(60, 10000):
		_assert_clean(game_seed, _random_seats(RandomStream.new(game_seed + 1)))


func test_searching_bots_stay_legal_under_modifiers() -> void:
	var expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	for game_seed: int in SEARCHED_GAMES:
		_assert_clean(game_seed, [expert, expert, expert])


func test_a_bot_answers_by_its_seats_rank_map() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ResourceLoader.load("res://data/modifiers/promotion_of_the_masses.tres"), 0)
	var table: SeatRules = SeatRules.new(stack)
	var deal: DealResult = RoundScript.stacked_deal(["29", "3", "4"], "")
	var round_state: RoundState = RoundState.new(deal, 0, table)
	var two: Classification = Classifier.classify(
		RankText.counts("2"), table.rules_for(0), table.map_for(0)
	)
	round_state.apply(round_state.action_for(two.pattern))
	var seat: int = round_state.seat_to_act()
	var play: BotPlay = Bot.decide_play(
		round_state.view_for(seat),
		round_state.legal_moves(),
		BotTable.new(table.rules_for(seat), table.map_for(seat)),
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotBudget.unlimited()
	)
	assert_str(BotScript.text_of(play)).is_equal("3")
