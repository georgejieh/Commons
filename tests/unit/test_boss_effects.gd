extends GdUnitTestSuite
## P4.7: each official's twist, checked through the modifier stack the run uses.

const REQUISITION: ModifierDef = preload("res://data/modifiers/bosses/requisition.tres")
const GREAT_LEAP: ModifierDef = preload("res://data/modifiers/bosses/great_leap.tres")
const STRUGGLE: ModifierDef = preload("res://data/modifiers/bosses/struggle_session.tres")


func _score(text: String, stack: ModifierStack) -> float:
	var rules: RuleSet = RuleSet.default_rules()
	var pattern: Pattern = (
		Classifier.classify(RankText.counts(text), rules, Ranks.identity_map()).pattern
	)
	var cards: Array[CardInstance] = RoundScript.stacked_deal([text], "").hands[0].cards()
	return Scorer.score_play(cards, pattern, 1, 0, false, stack).total


func _stack(definition: ModifierDef) -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(definition, 0)
	return stack


func test_requisition_zeroes_bombs_and_rockets_only() -> void:
	var stack: ModifierStack = _stack(REQUISITION)
	assert_float(_score("9999", stack)).is_equal(0.0)
	assert_float(_score("sb", stack)).is_equal(0.0)
	assert_float(_score("99", stack)).is_equal(_score("99", ModifierStack.new()))


func test_great_leap_adds_zeal_and_doubles_the_quota() -> void:
	# A pair of 9s: 18 Grain × 3 Rate, with 1 + 0.5 Zeal under the boss.
	assert_float(_score("99", ModifierStack.new())).is_equal(54.0)
	assert_float(_score("99", _stack(GREAT_LEAP))).is_equal(81.0)
	var state: RunState = RunState.new(1)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var plain: float = loop.target()
	state.boss_id = GREAT_LEAP.id
	assert_float(loop.target()).is_equal_approx(plain * 2.0, 1e-6)


func test_struggle_session_swaps_the_highest_card_into_the_kitty() -> void:
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	var deal: DealResult = Dealer.deal(cards, RandomStream.new(7))
	var highest: int = 0
	for card: CardInstance in deal.hands[0].cards():
		highest = maxi(highest, card.base_rank())
	var lowest: int = 99
	for card: CardInstance in deal.kitty:
		lowest = mini(lowest, card.base_rank())
	_stack(STRUGGLE).run_on_deal(DealContext.new(Seats.NONE, deal))
	var after_high: int = 0
	var total: int = deal.kitty.size()
	for hand: Hand in deal.hands:
		total += hand.size()
	for card: CardInstance in deal.hands[0].cards():
		after_high = maxi(after_high, card.base_rank())
	assert_int(total).is_equal(54)
	assert_int(deal.hands[0].size()).is_equal(17)
	(
		assert_bool(
			deal.kitty.any(func(card: CardInstance) -> bool: return card.base_rank() == highest)
		)
		. is_true()
	)
	(
		assert_bool(
			deal.hands[0].cards().any(
				func(card: CardInstance) -> bool: return card.base_rank() == lowest
			)
		)
		. is_true()
	)
	assert_int(after_high).is_less_equal(highest)
