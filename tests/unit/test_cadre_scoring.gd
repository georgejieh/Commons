extends GdUnitTestSuite
## ADR 0021's scoring Cadres, one golden scenario each through the real Scorer: the
## effect, its boundary, and who it reaches. A private Cadre changes only its holder's
## plays; a collective one changes every seat's. Also how Model, Red Banner, Poor
## Peasants' Association and Red Ink stack on one card, and where Zeal multipliers sit.

const HOLDER: int = 0
const OTHER: int = 1
const SPADE: int = 0
const HEART: int = 1
const CLUB: int = 2
const DIAMOND: int = 3


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("res://data/modifiers/%s.tres" % id)


func _stack(ids: Array[String]) -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in ids:
		stack.add(_def(id), HOLDER)
	return stack


func _card(rank: int, suit: int) -> CardInstance:
	return CardInstance.from_deck_id(rank * Deck.SUITS + suit)


func _pattern(cards: Array[CardInstance]) -> Pattern:
	var rules: RuleSet = RuleSet.default_rules()
	return CardSelection.classify_cards(cards, rules, Ranks.identity_map()).pattern


func _score(
	stack: ModifierStack, cards: Array[CardInstance], seat: int = HOLDER, facts: PlayFacts = null
) -> ScoreBreakdown:
	return Scorer.score_play(
		cards, _pattern(cards), 1, seat, false, stack, Scorer.DEFAULT_PARAMS, 0, facts
	)


func _bomb() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for suit: int in Deck.SUITS:
		cards.append(_card(Ranks.NINE, suit))
	return cards


func test_canteen_gives_every_seats_trios_their_zeal_and_nothing_else() -> void:
	var stack: ModifierStack = _stack(["canteen"])
	var trio: Array[CardInstance] = [
		_card(Ranks.FIVE, SPADE), _card(Ranks.FIVE, HEART), _card(Ranks.FIVE, CLUB)
	]
	var with_single: Array[CardInstance] = trio.duplicate()
	with_single.append(_card(Ranks.KING, SPADE))
	for seat: int in [HOLDER, OTHER]:
		assert_float(_score(stack, trio, seat).zeal).is_equal_approx(1.5, 0.0001)
		assert_float(_score(stack, with_single, seat).zeal).is_equal_approx(1.5, 0.0001)
	var pair: Array[CardInstance] = [_card(Ranks.FIVE, SPADE), _card(Ranks.FIVE, HEART)]
	assert_float(_score(stack, pair).zeal).is_equal(1.0)


func test_red_banner_adds_to_hearts_and_diamonds_for_everyone_and_not_jokers() -> void:
	var stack: ModifierStack = _stack(["red_banner"])
	for seat: int in [HOLDER, OTHER]:
		assert_float(_score(stack, [_card(Ranks.SEVEN, HEART)], seat).grain).is_equal(9.0)
		assert_float(_score(stack, [_card(Ranks.SEVEN, DIAMOND)], seat).grain).is_equal(9.0)
		assert_float(_score(stack, [_card(Ranks.SEVEN, SPADE)], seat).grain).is_equal(7.0)
	var joker: Array[CardInstance] = [CardInstance.from_deck_id(Deck.BIG_JOKER_ID)]
	assert_float(_score(stack, joker).grain).is_equal(17.0)


func test_poor_peasants_double_cards_printed_3_to_7_for_everyone() -> void:
	var stack: ModifierStack = _stack(["poor_peasants_association"])
	for seat: int in [HOLDER, OTHER]:
		assert_float(_score(stack, [_card(Ranks.THREE, SPADE)], seat).grain).is_equal(6.0)
		assert_float(_score(stack, [_card(Ranks.SEVEN, SPADE)], seat).grain).is_equal(14.0)
		assert_float(_score(stack, [_card(Ranks.EIGHT, SPADE)], seat).grain).is_equal(8.0)


## A kicker scores nothing whatever its rank: a Trio of 8s carrying a 3.
func test_poor_peasants_never_scores_a_kicker() -> void:
	var stack: ModifierStack = _stack(["poor_peasants_association", "red_banner"])
	var cards: Array[CardInstance] = [
		_card(Ranks.EIGHT, SPADE),
		_card(Ranks.EIGHT, CLUB),
		_card(Ranks.EIGHT, HEART),
		_card(Ranks.THREE, HEART),
	]
	assert_float(_score(stack, cards).grain).is_equal(8.0 * 3 + 2.0)


## One card under all four: Model doubles the printed 5 to 10 before any hook, the
## Association adds its own 10 again, Red Banner adds 2 and Red Ink 10. Flat Grain is
## never doubled, so the hooks' order does not matter: 10 + 10 + 2 + 10 = 32.
func test_model_poor_peasants_red_banner_and_red_ink_stack_in_any_order() -> void:
	var card: CardInstance = _card(Ranks.FIVE, HEART)
	CardModifiers.enhance(card, CardInstance.MODEL)
	CardModifiers.stamp(card, HOLDER)
	var orders: Array[Array] = [
		["poor_peasants_association", "red_banner", "red_ink"],
		["red_ink", "red_banner", "poor_peasants_association"],
		["red_banner", "red_ink", "poor_peasants_association"],
	]
	for order: Array in orders:
		var ids: Array[String] = []
		ids.assign(order)
		var breakdown: ScoreBreakdown = _score(_stack(ids), [card])
		assert_float(breakdown.grain).is_equal(32.0)
		# The breakdown's card step carries the whole card, so the steps add up.
		assert_float(breakdown.step_value(0)).is_equal(32.0)
	# Another seat scoring the same card gets the Model, the Association and the banner,
	# but not the stamp.
	var first: Array[String] = []
	first.assign(orders[0])
	var theirs: ScoreBreakdown = _score(_stack(first), [card], OTHER)
	assert_float(theirs.grain).is_equal(22.0)


func test_seed_grain_counts_met_quotas_and_feeds_every_seat() -> void:
	var stack: ModifierStack = _stack(["seed_grain"])
	var single: Array[CardInstance] = [_card(Ranks.SEVEN, SPADE)]
	assert_float(_score(stack, single).grain).is_equal(7.0)
	stack.run_set_end(SetContext.new(0, true))
	stack.run_set_end(SetContext.new(1, false))
	stack.run_set_end(SetContext.new(2, true))
	for seat: int in [HOLDER, OTHER]:
		assert_float(_score(stack, single, seat).grain).is_equal(7.0 + 6.0)
	var effect: ModifierEffect = stack.ordered_entries()[0].effect
	assert_int(effect.memo.value(SeedGrainEffect.MET)).is_equal(2)
	assert_bool(effect.memo.fired).is_true()


func test_show_trial_doubles_the_holders_bomb_zeal_and_charges_resentment() -> void:
	var stack: ModifierStack = _stack(["show_trial"])
	assert_float(_score(stack, _bomb()).zeal).is_equal(2.0)
	assert_float(_score(stack, _bomb(), OTHER).zeal).is_equal(1.0)
	assert_float(_score(stack, [_card(Ranks.NINE, SPADE)]).zeal).is_equal(1.0)
	var turn: TurnContext = TurnContext.new(HOLDER, OTHER, _pattern(_bomb()), 10, HOLDER)
	stack.run_turn_taken(turn)
	assert_int(turn.resentment).is_equal(3)
	var theirs: TurnContext = TurnContext.new(OTHER, HOLDER, _pattern(_bomb()), 10, HOLDER)
	stack.run_turn_taken(theirs)
	assert_int(theirs.resentment).is_equal(0)


func test_last_sheaf_triples_only_the_play_that_empties_the_holders_hand() -> void:
	var stack: ModifierStack = _stack(["last_sheaf"])
	var single: Array[CardInstance] = [_card(Ranks.SEVEN, SPADE)]
	var seats: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var grains: PackedFloat64Array = PackedFloat64Array([0, 0, 0])
	var out: PlayFacts = PlayFacts.new(OTHER, 0, seats, grains)
	var left: PlayFacts = PlayFacts.new(OTHER, 1, seats, grains)
	assert_float(_score(stack, single, HOLDER, out).zeal).is_equal(3.0)
	assert_float(_score(stack, single, HOLDER, left).zeal).is_equal(1.0)
	assert_float(_score(stack, single, OTHER, out).zeal).is_equal(1.0)


## Multipliers come after every flat Zeal: (1 + flat) × each multiplier. A Bomb that
## goes out under Show Trial and Last Sheaf, with Steel Target's 0.1 from one earlier
## bomb, scores (1 + 0.1) × 2 × 3 Zeal, and the tally's scale stays at 100%.
func test_zeal_multipliers_come_after_flat_zeal() -> void:
	var stack: ModifierStack = _stack(["steel_target", "show_trial", "last_sheaf"])
	stack.run_turn_taken(TurnContext.new(HOLDER, OTHER, _pattern(_bomb()), 12, HOLDER))
	var facts: PlayFacts = PlayFacts.new(
		OTHER, 0, PackedInt32Array([1, 0, 0]), PackedFloat64Array([0, 0, 0])
	)
	var breakdown: ScoreBreakdown = _score(stack, _bomb(), HOLDER, facts)
	assert_float(breakdown.zeal).is_equal_approx(6.6, 0.0001)
	var product: float = breakdown.grain * breakdown.rate * breakdown.zeal
	assert_float(breakdown.total).is_equal_approx(product, 0.0001)


func test_steel_target_counts_the_holders_bombs_into_later_zeal() -> void:
	var stack: ModifierStack = _stack(["steel_target"])
	var single: Array[CardInstance] = [_card(Ranks.SEVEN, SPADE)]
	assert_float(_score(stack, single).zeal).is_equal(1.0)
	var turn: TurnContext = TurnContext.new(HOLDER, OTHER, _pattern(_bomb()), 10, HOLDER)
	stack.run_turn_taken(turn)
	assert_int(turn.resentment).is_equal(2)
	var rocket: Array[CardInstance] = [
		CardInstance.from_deck_id(Deck.SMALL_JOKER_ID), CardInstance.from_deck_id(Deck.BIG_JOKER_ID)
	]
	stack.run_turn_taken(TurnContext.new(HOLDER, OTHER, _pattern(rocket), 8, HOLDER))
	# Another seat's bomb and the holder's pass count for nothing.
	stack.run_turn_taken(TurnContext.new(OTHER, OTHER, _pattern(_bomb()), 8, HOLDER))
	stack.run_turn_taken(TurnContext.new(HOLDER, OTHER, null, 8, HOLDER))
	assert_float(_score(stack, single).zeal).is_equal_approx(1.2, 0.0001)
	assert_float(_score(stack, single, OTHER).zeal).is_equal(1.0)


func test_stakhanovite_grows_from_long_straights_from_the_next_one_on() -> void:
	var stack: ModifierStack = _stack(["stakhanovite"])
	var seven: Array[CardInstance] = []
	for rank: int in range(Ranks.THREE, Ranks.NINE + 1):
		seven.append(_card(rank, SPADE))
	var six: Array[CardInstance] = seven.slice(0, 6)
	# Seven cards: two past five, at 0.5 each.
	assert_float(_score(stack, seven).zeal).is_equal_approx(2.0, 0.0001)
	stack.run_turn_taken(TurnContext.new(HOLDER, OTHER, _pattern(six), 11, HOLDER))
	assert_float(_score(stack, seven).zeal).is_equal_approx(2.0, 0.0001)
	stack.run_turn_taken(TurnContext.new(HOLDER, OTHER, _pattern(seven), 4, HOLDER))
	# Now 0.55 a card.
	assert_float(_score(stack, seven).zeal).is_equal_approx(2.1, 0.0001)
	assert_float(_score(stack, six).zeal).is_equal_approx(1.55, 0.0001)
	assert_float(_score(stack, seven, OTHER).zeal).is_equal(1.0)


func test_collective_farm_adds_the_teammates_last_grain_to_a_peasants_pair() -> void:
	var stack: ModifierStack = _stack(["collective_farm"])
	var pair: Array[CardInstance] = [_card(Ranks.SIX, SPADE), _card(Ranks.SIX, HEART)]
	var landlord: int = 2
	var played: PlayFacts = PlayFacts.new(
		landlord, 10, PackedInt32Array([2, 1, 3]), PackedFloat64Array([20, 31, 40])
	)
	# Seat 0's teammate is seat 1, whose last play scored 31; and the other way round.
	assert_float(_score(stack, pair, 0, played).grain).is_equal(12.0 + 31.0)
	assert_float(_score(stack, pair, 1, played).grain).is_equal(12.0 + 20.0)
	# The landlord has no teammate, and only a Pair gains.
	assert_float(_score(stack, pair, landlord, played).grain).is_equal(12.0)
	assert_float(_score(stack, [_card(Ranks.SIX, SPADE)], 0, played).grain).is_equal(6.0)
	# A teammate who has not played this round adds nothing.
	var quiet: PlayFacts = PlayFacts.new(
		landlord, 10, PackedInt32Array([2, 0, 3]), PackedFloat64Array([20, 0, 40])
	)
	assert_float(_score(stack, pair, 0, quiet).grain).is_equal(12.0)
