extends GdUnitTestSuite
## Bots read each seat's own rules and rank map, so no modifier set makes them act illegally.

const MODIFIERS: Array[String] = [
	"promotion_of_the_masses",
	"criticism_meeting",
	"inverted_order",
	"cultural_revolution",
	"shock_brigade",
	"double_share_plough",
]
## The Cadres that change what one seat may play or what its cards beat (ADR 0039).
const SEAT_CADRES: Array[String] = [
	"promotion_of_the_masses", "cultural_revolution", "shock_brigade", "double_share_plough"
]
const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD
]
const SEARCHED_GAMES: int = 3
const HELD_GAMES: int = 12
## Rank-moving Cadres held two at a time by seat 0, in both slot orders (ADR 0039).
const RANK_PAIRS: Array[Array] = [
	["rehabilitation", "promotion_of_the_masses"],
	["promotion_of_the_masses", "rehabilitation"],
	["class_label", "promotion_of_the_masses"],
	["rehabilitation", "class_label"],
]
const PAIR_GAMES: int = 4
## Cultural Revolution, then Rehabilitation on the 4, then Inverted Order: after a bomb the
## 4 climbs past the turned-over 3 and is turned over again.
const CLIMB: Array[String] = ["cultural_revolution", "rehabilitation", "inverted_order"]
## What the player buys that changes play, held by seat 0 alone (ADR 0039): wild
## ranks (Mass Line, Model Worker), Industrialization, and each with a
## rank Cadre and a rule Cadre. Each row: the wild ranks, the Reforms, the Cadres.
const HOUSEHOLD: Array[Array] = [
	[[Ranks.SEVEN], [], []],
	[[Ranks.SEVEN, Ranks.QUEEN], [], []],
	[[], ["industrialization"], []],
	[[Ranks.SEVEN], ["industrialization"], []],
	[[Ranks.SEVEN, Ranks.QUEEN], ["industrialization"], ["promotion_of_the_masses"]],
	[[Ranks.SEVEN], [], ["shock_brigade"]],
	[[Ranks.NINE], ["industrialization"], ["shock_brigade", "promotion_of_the_masses"]],
]
const HOUSEHOLD_GAMES: int = 5


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


## Each Cadre held by seat 0 alone, as the player holds it, with every tier at every seat
## and Expert in one game each: no bot makes an illegal action against the seat that
## plays by other rules, or while holding them.
func test_no_bot_acts_illegally_while_one_seat_holds_a_cadre() -> void:
	var expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	for name: String in SEAT_CADRES:
		var stack: ModifierStack = ModifierStack.new()
		stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % name), 0)
		var table: SeatRules = SeatRules.new(stack)
		for game: int in HELD_GAMES + 1:
			var seats: Array[BotConfig] = [expert, expert, expert]
			if game < HELD_GAMES:
				seats = _random_seats(RandomStream.new(game + 31))
			var deal: DealResult = SelfPlay.deal_from_seed(4100 + game)
			var result: SelfPlayResult = SelfPlay.play_round(deal, game % Seats.COUNT, seats, table)
			var label: String = "%s game %d" % [name, game]
			assert_int(result.illegal_actions).override_failure_message(label).is_equal(0)
			assert_bool(result.winner != Seats.NONE).override_failure_message(label).is_true()


func test_a_bot_answers_by_its_seats_rank_map() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ResourceLoader.load("res://data/modifiers/promotion_of_the_masses.tres"), 1)
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


## Two rank-moving Cadres held together, Rehabilitation's pick already at the 2: no bot
## makes an illegal action against the holder or while holding them.
func test_no_bot_acts_illegally_while_one_seat_holds_two_rank_cadres() -> void:
	for pair: Array in RANK_PAIRS:
		var stack: ModifierStack = ModifierStack.new()
		for name: String in pair:
			var memo: CadreMemo = CadreMemo.new()
			memo.put(CadreMemo.RANK, Ranks.ACE)
			stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % name), 0, memo)
		var table: SeatRules = SeatRules.new(stack)
		for game: int in PAIR_GAMES:
			var seats: Array[BotConfig] = _random_seats(RandomStream.new(game + 57))
			var deal: DealResult = SelfPlay.deal_from_seed(4300 + game)
			var result: SelfPlayResult = SelfPlay.play_round(deal, game % Seats.COUNT, seats, table)
			var label: String = "%s game %d" % [pair, game]
			assert_int(result.illegal_actions).override_failure_message(label).is_equal(0)
			assert_bool(result.winner != Seats.NONE).override_failure_message(label).is_true()


func test_no_bot_acts_illegally_while_the_holder_turns_a_climbed_rank_over() -> void:
	var stack: ModifierStack = ModifierStack.new()
	for name: String in CLIMB:
		var memo: CadreMemo = CadreMemo.new()
		memo.put(CadreMemo.RANK, Ranks.FOUR)
		stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % name), 0, memo)
	var table: SeatRules = SeatRules.new(stack)
	for game: int in PAIR_GAMES * 2:
		var seats: Array[BotConfig] = _random_seats(RandomStream.new(game + 71))
		var deal: DealResult = SelfPlay.deal_from_seed(4400 + game)
		var result: SelfPlayResult = SelfPlay.play_round(deal, game % Seats.COUNT, seats, table)
		var label: String = "climb game %d" % game
		assert_int(result.illegal_actions).override_failure_message(label).is_equal(0)
		assert_bool(result.winner != Seats.NONE).override_failure_message(label).is_true()


func _household_table(row: Array) -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	for name: String in row[2]:
		stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % name), 0)
	var state: RunState = RunState.new(1)
	state.reforms.assign(row[1])
	for rule: ActiveModifier in RunReforms.table_rules(state, 0):
		stack.add_entry(rule)
	var table: SeatRules = SeatRules.new(stack)
	var wild: Array[int] = []
	wild.assign(row[0])
	table.set_wild_ranks(wild, 0)
	return table


## The player's wild ranks and bigger bombs held by seat 0 alone, with every tier at every
## seat and Expert in one game each: no bot makes an illegal action against them, and none
## while holding them.
func test_no_bot_acts_illegally_against_the_players_wild_ranks_and_big_bombs() -> void:
	var expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	for row: Array in HOUSEHOLD:
		var table: SeatRules = _household_table(row)
		for game: int in HOUSEHOLD_GAMES + 1:
			var seats: Array[BotConfig] = [expert, expert, expert]
			if game < HOUSEHOLD_GAMES:
				seats = _random_seats(RandomStream.new(game + 91))
			var deal: DealResult = SelfPlay.deal_from_seed(4500 + game)
			var result: SelfPlayResult = SelfPlay.play_round(deal, game % Seats.COUNT, seats, table)
			var label: String = "%s game %d" % [row, game]
			assert_int(result.illegal_actions).override_failure_message(label).is_equal(0)
			assert_bool(result.winner != Seats.NONE).override_failure_message(label).is_true()
