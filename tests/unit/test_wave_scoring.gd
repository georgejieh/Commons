extends GdUnitTestSuite
## ADR 0032's scoring Cadres, one golden scenario each through the real Scorer: the
## effect, its boundary, and who it reaches. A collective Cadre changes every seat's
## plays; a private one changes only its holder's.

const HOLDER: int = 0
const OTHER: int = 1
const SPADE: int = 0
const HEART: int = 1
const CLUB: int = 2
const DIAMOND: int = 3


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("res://data/modifiers/%s.tres" % id)


func _stack(ids: Array[String], memo: CadreMemo = null) -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in ids:
		stack.add(_def(id), HOLDER, memo)
	return stack


func _card(rank: int, suit: int) -> CardInstance:
	if rank == Ranks.SMALL_JOKER:
		return CardInstance.from_deck_id(Deck.SMALL_JOKER_ID)
	if rank == Ranks.BIG_JOKER:
		return CardInstance.from_deck_id(Deck.BIG_JOKER_ID)
	return CardInstance.from_deck_id(rank * Deck.SUITS + suit)


func _cards(ranks: Array[int]) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	var used: Dictionary[int, int] = {}
	for rank: int in ranks:
		var suit: int = used.get(rank, 0)
		used[rank] = suit + 1
		cards.append(_card(rank, suit))
	return cards


func _pattern(cards: Array[CardInstance]) -> Pattern:
	var rules: RuleSet = RuleSet.default_rules()
	return CardSelection.classify_cards(cards, rules, Ranks.identity_map()).pattern


func _score(
	stack: ModifierStack,
	cards: Array[CardInstance],
	seat: int = HOLDER,
	landlord: bool = false,
	year: int = 0
) -> ScoreBreakdown:
	var facts: PlayFacts = PlayFacts.new(
		Seats.NONE, -1, PackedInt32Array(), PackedFloat64Array(), year
	)
	return Scorer.score_play(
		cards, _pattern(cards), 1, seat, landlord, stack, Scorer.DEFAULT_PARAMS, 0, facts
	)


func test_night_school_gives_every_seats_singles_and_pairs_half_a_zeal() -> void:
	var stack: ModifierStack = _stack(["night_school"])
	for seat: int in [HOLDER, OTHER]:
		assert_float(_score(stack, _cards([Ranks.SEVEN]), seat).zeal).is_equal(1.5)
		assert_float(_score(stack, _cards([Ranks.SEVEN, Ranks.SEVEN]), seat).zeal).is_equal(1.5)
	var trio: Array[CardInstance] = _cards([Ranks.SEVEN, Ranks.SEVEN, Ranks.SEVEN])
	assert_float(_score(stack, trio).zeal).is_equal(1.0)


func test_iron_and_coal_adds_to_spades_and_clubs_for_everyone_and_not_jokers() -> void:
	var stack: ModifierStack = _stack(["iron_and_coal"])
	for seat: int in [HOLDER, OTHER]:
		assert_float(_score(stack, [_card(Ranks.SEVEN, SPADE)], seat).grain).is_equal(9.0)
		assert_float(_score(stack, [_card(Ranks.SEVEN, CLUB)], seat).grain).is_equal(9.0)
		assert_float(_score(stack, [_card(Ranks.SEVEN, HEART)], seat).grain).is_equal(7.0)
		assert_float(_score(stack, [_card(Ranks.SEVEN, DIAMOND)], seat).grain).is_equal(7.0)
	var joker: Array[CardInstance] = [CardInstance.from_deck_id(Deck.SMALL_JOKER_ID)]
	assert_float(_score(stack, joker).grain).is_equal(16.0)


## J is printed 11 and A 14: each gains 4. A 10 and a 2 sit outside the range.
func test_advanced_cooperative_adds_to_cards_printed_jack_to_ace() -> void:
	var stack: ModifierStack = _stack(["advanced_cooperative"])
	for seat: int in [HOLDER, OTHER]:
		assert_float(_score(stack, _cards([Ranks.JACK]), seat).grain).is_equal(15.0)
		assert_float(_score(stack, _cards([Ranks.ACE]), seat).grain).is_equal(18.0)
		assert_float(_score(stack, _cards([Ranks.TEN]), seat).grain).is_equal(10.0)
		assert_float(_score(stack, _cards([Ranks.TWO]), seat).grain).is_equal(15.0)
	# A Pair of Queens: 12 + 4 twice.
	assert_float(_score(stack, _cards([Ranks.QUEEN, Ranks.QUEEN])).grain).is_equal(32.0)


func test_tractor_station_gives_every_airplane_a_zeal_and_nothing_else() -> void:
	var stack: ModifierStack = _stack(["tractor_station"])
	var plane: Array[int] = [Ranks.SEVEN, Ranks.SEVEN, Ranks.SEVEN, Ranks.EIGHT, Ranks.EIGHT]
	plane.append(Ranks.EIGHT)
	var singles: Array[int] = plane.duplicate()
	singles.append_array([Ranks.THREE, Ranks.FOUR])
	var pairs: Array[int] = plane.duplicate()
	pairs.append_array([Ranks.THREE, Ranks.THREE, Ranks.FOUR, Ranks.FOUR])
	for seat: int in [HOLDER, OTHER]:
		for ranks: Array[int] in [plane, singles, pairs]:
			assert_float(_score(stack, _cards(ranks), seat).zeal).is_equal(2.0)
	var trio: Array[CardInstance] = _cards([Ranks.SEVEN, Ranks.SEVEN, Ranks.SEVEN])
	assert_float(_score(stack, trio).zeal).is_equal(1.0)


func test_five_year_plan_counts_the_year_in_play_for_every_seat() -> void:
	var stack: ModifierStack = _stack(["five_year_plan"])
	var single: Array[CardInstance] = _cards([Ranks.SEVEN])
	var expected: Dictionary[int, float] = {0: 1.0, 1: 1.1, 3: 1.3, 8: 1.8}
	for year: int in expected:
		for seat: int in [HOLDER, OTHER]:
			var zeal: float = _score(stack, single, seat, seat == OTHER, year).zeal
			assert_float(zeal).override_failure_message(str(year)).is_equal_approx(
				expected[year], 0.0001
			)


func test_loudspeaker_raises_the_holders_twos_and_jokers_played_as_singles() -> void:
	var stack: ModifierStack = _stack(["loudspeaker"])
	assert_float(_score(stack, _cards([Ranks.TWO])).zeal).is_equal(3.0)
	assert_float(_score(stack, _cards([Ranks.SMALL_JOKER])).zeal).is_equal(3.0)
	assert_float(_score(stack, _cards([Ranks.BIG_JOKER])).zeal).is_equal(3.0)
	assert_float(_score(stack, _cards([Ranks.ACE])).zeal).is_equal(1.0)
	assert_float(_score(stack, _cards([Ranks.TWO, Ranks.TWO])).zeal).is_equal(1.0)
	var rocket: Array[CardInstance] = _cards([Ranks.SMALL_JOKER, Ranks.BIG_JOKER])
	assert_float(_score(stack, rocket).zeal).is_equal(1.0)
	assert_float(_score(stack, _cards([Ranks.TWO]), OTHER).zeal).is_equal(1.0)


## A Model 5 is printed 5: Model alone makes it 10, Prize Exhibit 15, for the holder only.
func test_prize_exhibit_triples_the_holders_model_cards() -> void:
	var stack: ModifierStack = _stack(["prize_exhibit"])
	var model: CardInstance = _card(Ranks.FIVE, HEART)
	CardModifiers.enhance(model, CardInstance.MODEL)
	assert_float(_score(stack, [model]).grain).is_equal(15.0)
	assert_float(_score(stack, [model], OTHER).grain).is_equal(10.0)
	assert_float(_score(stack, [_card(Ranks.FIVE, SPADE)]).grain).is_equal(5.0)
	# Flat Grain from another Cadre is never tripled: 15 + 2.
	var banner: ModifierStack = _stack(["prize_exhibit", "red_banner"])
	assert_float(_score(banner, [model]).grain).is_equal(17.0)


func test_forged_seal_waives_only_the_holders_stamped_resentment() -> void:
	var stack: ModifierStack = _stack(["forged_seal"])
	var single: Array[CardInstance] = _cards([Ranks.SEVEN])
	assert_bool(_score(stack, single).stamps_resented).is_false()
	assert_bool(_score(stack, single, OTHER).stamps_resented).is_true()
	assert_bool(_score(ModifierStack.new(), single).stamps_resented).is_true()
	# It changes no number.
	assert_float(_score(stack, single).total).is_equal(_score(ModifierStack.new(), single).total)


func _out(seat: int, landlord: int, cards_left: int, pattern: Pattern) -> TurnContext:
	return TurnContext.new(seat, landlord, pattern, cards_left, HOLDER)


## Each round the holder wins as landlord is 0.2 Zeal on later landlord plays, and 2
## Resentment; a peasant's win, a pass, a play that leaves cards and a villager's win
## count for nothing.
func test_rent_book_grows_with_rounds_won_as_landlord() -> void:
	var memo: CadreMemo = CadreMemo.new()
	var stack: ModifierStack = _stack(["rent_book"], memo)
	var single: Array[CardInstance] = _cards([Ranks.SEVEN])
	var played: Pattern = _pattern(single)
	assert_float(_score(stack, single, HOLDER, true).zeal).is_equal(1.0)
	var none: Array[TurnContext] = [
		_out(HOLDER, OTHER, 0, played),
		_out(HOLDER, HOLDER, 3, played),
		_out(HOLDER, HOLDER, 0, null),
		_out(OTHER, OTHER, 0, played),
	]
	for turn: TurnContext in none:
		stack.run_turn_taken(turn)
		assert_int(turn.resentment).is_equal(0)
	assert_int(memo.value(RentBookEffect.WINS)).is_equal(0)
	for _round: int in 2:
		var won: TurnContext = _out(HOLDER, HOLDER, 0, played)
		stack.run_turn_taken(won)
		assert_int(won.resentment).is_equal(2)
	assert_int(memo.value(RentBookEffect.WINS)).is_equal(2)
	assert_bool(memo.fired).is_true()
	assert_float(_score(stack, single, HOLDER, true).zeal).is_equal_approx(1.4, 0.0001)
	assert_float(_score(stack, single, HOLDER, false).zeal).is_equal(1.0)
	assert_float(_score(stack, single, OTHER, true).zeal).is_equal(1.0)
	var effect: ModifierEffect = stack.ordered_entries()[0].effect
	assert_int(effect.state_values()["wins"]).is_equal(2)
