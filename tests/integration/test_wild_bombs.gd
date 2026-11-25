extends GdUnitTestSuite
## Industrialization (ADR 0029, rule 6): five or more cards read as one rank are a bomb
## for the player's seat alone (ADR 0039), through the private plot's fifth copy and
## through wild cards, a bigger bomb beats a smaller one and the Rocket beats both, and
## each card past the fourth adds its Zeal. With it not held nothing changes. The golden
## numbers are five Nines' score.

const SEED: int = 7301
## Five Nines as a bomb under Industrialization, the fifth from the plot: Grain, Rate, Zeal
## and total.
const GOLDEN_BIG_BOMB: Array[float] = [45.0, 32.0, 2.0, 2880.0]
## Plot IDs for the copies of a rank past the deck's four.
const PLOT_ID: int = 900


func _loop(seed_value: int, reforms: Array[String]) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.reforms.assign(reforms)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


func _rules(reforms: Array[String], wild: Array[int]) -> SeatRules:
	var state: RunState = RunState.new(SEED)
	state.reforms.assign(reforms)
	var stack: ModifierStack = ModifierStack.new()
	for rule: ActiveModifier in RunReforms.table_rules(state, RunLoop.PLAYER):
		stack.add_entry(rule)
	var table: SeatRules = SeatRules.new(stack)
	table.set_wild_ranks(wild)
	table.refresh()
	return table


func _has_bomb(readings: Array[Pattern], cards: int) -> bool:
	return readings.any(
		func(reading: Pattern) -> bool:
			return reading.type == Pattern.Type.BOMB and reading.card_count == cards
	)


## Sevens wild for every seat here, as a test or the tournament makes them, so only the
## Reform's reach differs between seats.
func test_industrialization_makes_five_of_a_rank_a_bomb_for_the_player_alone() -> void:
	var sevens: Array[int] = [Ranks.SEVEN]
	var big: SeatRules = _rules(["industrialization"], sevens)
	var plain: SeatRules = _rules([], sevens)
	var map: PackedByteArray = Ranks.identity_map()
	for seat: int in Seats.COUNT:
		var holds: bool = seat == RunLoop.PLAYER
		assert_bool(big.rules_for(seat).five_plus_is_bomb()).is_equal(holds)
		assert_bool(plain.rules_for(seat).five_plus_is_bomb()).is_false()
		# Through the private plot: five natural Nines.
		var natural: Classification = Classifier.classify(
			RankText.counts("99999"), big.rules_for(seat), map
		)
		assert_bool(natural.is_valid()).is_equal(holds)
		if holds:
			assert_int(natural.pattern.type).is_equal(Pattern.Type.BOMB)
		(
			assert_bool(
				Classifier.classify(RankText.counts("99999"), plain.rules_for(seat), map).is_valid()
			)
			. is_false()
		)
		# Through wild cards: four Nines and a wild Seven.
		var counts: PackedByteArray = RankText.counts("99997")
		assert_bool(_has_bomb(Readings.of(counts, big.rules_for(seat), map), 5)).is_equal(holds)
		assert_bool(_has_bomb(Readings.of(counts, plain.rules_for(seat), map), 5)).is_false()


func test_industrialization_ranks_a_bigger_bomb_above_a_smaller_one() -> void:
	var rules: RuleSet = _rules(["industrialization"], []).rules_for(0)
	var map: PackedByteArray = Ranks.identity_map()
	var five_threes: Pattern = Classifier.classify(RankText.counts("33333"), rules, map).pattern
	var four_twos: Pattern = Classifier.classify(RankText.counts("2222"), rules, map).pattern
	var rocket: Pattern = Classifier.classify(RankText.counts("sb"), rules, map).pattern
	assert_bool(PlayComparator.beats(five_threes, four_twos, rules)).is_true()
	assert_bool(PlayComparator.beats(four_twos, five_threes, rules)).is_false()
	assert_bool(PlayComparator.beats(rocket, five_threes, rules)).is_true()


func test_industrialization_adds_zeal_for_each_card_past_the_fourth() -> void:
	var table: SeatRules = _rules(["industrialization"], [])
	var stack: ModifierStack = table.get("_stack")
	var rules: RuleSet = table.rules_for(0)
	for seat: int in Seats.COUNT:
		for text: String in ["9999", "99999", "999999"]:
			var cards: Array[CardInstance] = _nines(text.length())
			var pattern: Pattern = (
				Classifier.classify(RankText.counts(text), rules, Ranks.identity_map()).pattern
			)
			var score: ScoreBreakdown = Scorer.score_play(cards, pattern, 1, seat, false, stack)
			assert_float(score.zeal).is_equal_approx(1.0 + (text.length() - 4), 0.0001)
			if text == "99999":
				var shown: Array[float] = [score.grain, score.rate, score.zeal, score.total]
				assert_array(shown).is_equal(GOLDEN_BIG_BOMB)
	# With none held a bomb's Zeal is the plain one.
	var bare: SeatRules = _rules([], [])
	var four: Array[CardInstance] = RoundScript.stacked_deal(["9999"], "").hands[0].cards()
	var bomb: Pattern = (
		Classifier
		. classify(RankText.counts("9999"), bare.rules_for(0), Ranks.identity_map())
		. pattern
	)
	var plain: ScoreBreakdown = Scorer.score_play(four, bomb, 1, 0, false, bare.get("_stack"))
	assert_float(plain.zeal).is_equal_approx(1.0, 0.0001)


## count Nines: the deck's four, then copies from the private plot.
func _nines(count: int) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for index: int in count:
		var suit: int = index % Deck.SUITS
		if index < Deck.SUITS:
			cards.append(Deck.new().card(Ranks.NINE * Deck.SUITS + suit))
		else:
			cards.append(
				CardInstance.new(PLOT_ID + index, Ranks.NINE, suit, CardInstance.Origin.PLOT)
			)
	return cards


func test_industrialization_holds_at_the_table_for_the_player_alone() -> void:
	var loop: RunLoop = _loop(SEED, ["industrialization"])
	var bare: RunLoop = _loop(SEED, [])
	for seat: int in Seats.COUNT:
		var holds: bool = seat == RunLoop.PLAYER
		assert_bool(loop.seat_table(seat).rules.five_plus_is_bomb()).is_equal(holds)
		assert_bool(bare.seat_table(seat).rules.five_plus_is_bomb()).is_false()
	# It is a rule about bombs: no rank is made wild by it.
	assert_array(loop.state.wild_ranks).is_empty()
