extends GdUnitTestSuite
## ADR 0032's Double-Share Plough: a Pair Run of 2 pairs is a hand for its holder's seat
## while it is in force, and for no other seat (ADR 0039) and never otherwise. The
## classifier reads it, the move generator offers it, and every bot tier plays it legally.

const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD, BotConfig.Tier.EXPERT
]
const GAMES: int = 40
const SEARCHED_GAMES: int = 2


func _plough() -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ResourceLoader.load("res://data/modifiers/double_share_plough.tres"), 0)
	return SeatRules.new(stack)


func _plain() -> SeatRules:
	return SeatRules.new(ModifierStack.new())


func _is_short_run(pattern: Pattern) -> bool:
	return pattern.type == Pattern.Type.PAIR_CHAIN and pattern.chain_length == 2


func _mask(counts: PackedByteArray) -> int:
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			mask |= 1 << rank
	return mask


func test_the_classifier_and_move_generator_read_two_pairs_only_under_the_plough() -> void:
	var counts: PackedByteArray = RankText.counts("3344")
	for table: SeatRules in [_plough(), _plain()]:
		var ploughs: bool = table.rules_for(0).min_pair_chain_length() == 2
		for seat: int in Seats.COUNT:
			var ploughed: bool = ploughs and seat == 0
			assert_int(table.rules_for(seat).min_pair_chain_length()).is_equal(2 if ploughed else 3)
			var seat_rules: RuleSet = table.rules_for(seat)
			var read: Classification = Classifier.classify(counts, seat_rules, Ranks.identity_map())
			assert_bool(read.is_valid()).is_equal(ploughed)
			if ploughed:
				assert_bool(_is_short_run(read.pattern)).is_true()
			var moves: Array[Pattern] = MoveGenerator.generate(
				RankText.counts("33445566"), _mask(counts), null, seat_rules, Ranks.identity_map()
			)
			assert_bool(moves.any(_is_short_run)).is_equal(ploughed)
	# Three pairs still read as they always did, and a 2-pair run is answered by a higher
	# 2-pair run, never by a longer one.
	var rules: RuleSet = _plough().rules_for(0)
	var three: Classification = Classifier.classify(
		RankText.counts("334455"), rules, Ranks.identity_map()
	)
	assert_int(three.pattern.chain_length).is_equal(3)
	var low: Pattern = Classifier.classify(counts, rules, Ranks.identity_map()).pattern
	var held: PackedByteArray = RankText.counts("556677")
	var answers: Array[Pattern] = MoveGenerator.generate(
		held, _mask(held), low, rules, Ranks.identity_map()
	)
	for answer: Pattern in answers:
		assert_int(answer.chain_length).is_equal(2)
	assert_int(answers.size()).is_equal(2)


## The landlord holds 3 3 4 4 and leads: going out in one play is a 2-pair run, which
## every tier takes; without the plough each plays something legal and smaller.
func test_every_tier_leads_a_two_pair_run_to_go_out() -> void:
	for tier: BotConfig.Tier in TIERS:
		var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier)
		for table: SeatRules in [_plough(), _plain()]:
			var deal: DealResult = RoundScript.stacked_deal(["3344", "9", "T"], "")
			var round_state: RoundState = RoundState.new(deal, 0, table)
			var legal: Array[Pattern] = round_state.legal_moves()
			var play: BotPlay = Bot.decide_play(
				round_state.view_for(0),
				legal,
				BotTable.new(table.rules_for(0), table.map_for(0)),
				config,
				BotBudget.unlimited()
			)
			assert_bool(SelfPlay.is_offered(play, legal)).is_true()
			var ploughed: bool = table.rules_for(0).min_pair_chain_length() == 2
			var case: String = "%s %s" % [tier, ploughed]
			assert_bool(_is_short_run(play.pattern)).override_failure_message(case).is_equal(
				ploughed
			)


func _played(history: Array[PublicPlay]) -> int:
	return (
		history.filter(func(entry: PublicPlay) -> bool: return _is_short_run(entry.pattern)).size()
	)


func _games(tier: BotConfig.Tier, table: SeatRules, games: int) -> Vector2i:
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier)
	var seats: Array[BotConfig] = [config, config, config]
	var illegal: int = 0
	var short_runs: int = 0
	for game_seed: int in games:
		var deal: DealResult = SelfPlay.deal_from_seed(7700 + game_seed)
		var result: SelfPlayResult = SelfPlay.play_round(
			deal, game_seed % Seats.COUNT, seats, table
		)
		illegal += result.illegal_actions
		short_runs += _played(result.history)
	return Vector2i(illegal, short_runs)


## Whole rounds: no tier makes an illegal action with the plough or without it, 2-pair
## runs are played under it, and none ever without it.
func test_every_tier_plays_whole_rounds_legally_under_the_plough() -> void:
	var ploughed_runs: int = 0
	for tier: BotConfig.Tier in TIERS:
		var games: int = SEARCHED_GAMES if tier == BotConfig.Tier.EXPERT else GAMES
		var with_plough: Vector2i = _games(tier, _plough(), games)
		var without: Vector2i = _games(tier, _plain(), games)
		assert_int(with_plough.x).override_failure_message(str(tier)).is_equal(0)
		assert_int(without.x).override_failure_message(str(tier)).is_equal(0)
		assert_int(without.y).override_failure_message(str(tier)).is_equal(0)
		ploughed_runs += with_plough.y
	assert_int(ploughed_runs).is_greater(0)
