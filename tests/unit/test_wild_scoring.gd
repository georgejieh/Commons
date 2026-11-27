extends GdUnitTestSuite
## Scoring under wild ranks (ADR 0029, rule 7): Grain from the printed cards, body and
## kicker by the reading's placement, Rate from the reading, and the effects' rulings.

const HIDDEN_RESERVES: ModifierDef = preload("res://data/modifiers/hidden_reserves.tres")
const REQUISITION: ModifierDef = preload("res://data/modifiers/bosses/requisition.tres")

var _map: PackedByteArray = Ranks.identity_map()
var _sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)
var _params: ScoreParams = Scorer.DEFAULT_PARAMS


## The lowest unused deck cards for the text.
func _cards(text: String) -> Array[CardInstance]:
	return RoundScript.stacked_deal([text] as Array[String], "").hands[0].cards()


func _reading(cards: Array[CardInstance], type: Pattern.Type) -> Pattern:
	for reading: Pattern in CardSelection.readings(cards, _sevens, _map):
		if reading.type == type:
			return reading
	return null


func _score(cards: Array[CardInstance], pattern: Pattern, stack: ModifierStack) -> ScoreBreakdown:
	return Scorer.score_play(cards, pattern, 1, 0, true, stack, _params)


func _grain(rank: int) -> float:
	return float(_params.card_grain[rank])


func test_grain_comes_from_the_printed_cards() -> void:
	var cards: Array[CardInstance] = _cards("QQ7")
	var trio: Pattern = _reading(cards, Pattern.Type.TRIO)
	assert_int(trio.main_rank).is_equal(Ranks.QUEEN)
	var breakdown: ScoreBreakdown = _score(cards, trio, ModifierStack.new())
	assert_float(breakdown.grain).is_equal(_grain(Ranks.QUEEN) * 2 + _grain(Ranks.SEVEN))


func test_the_reading_places_each_card_as_body_or_kicker() -> void:
	var cards: Array[CardInstance] = _cards("9997")
	var bomb: Pattern = _reading(cards, Pattern.Type.BOMB)
	var trio: Pattern = _reading(cards, Pattern.Type.TRIO_SINGLE)
	var as_bomb: ScoreBreakdown = _score(cards, bomb, ModifierStack.new())
	var as_trio: ScoreBreakdown = _score(cards, trio, ModifierStack.new())
	assert_float(as_bomb.grain).is_equal(_grain(Ranks.NINE) * 3 + _grain(Ranks.SEVEN))
	assert_float(as_trio.grain).is_equal(_grain(Ranks.NINE) * 3)
	assert_float(as_bomb.rate).is_equal(float(_params.rate_for(Pattern.Type.BOMB, 1)))
	assert_float(as_trio.rate).is_equal(float(_params.rate_for(Pattern.Type.TRIO_SINGLE, 1)))


func test_wild_cards_fill_the_body_before_the_kickers() -> void:
	var two: RuleSet = WildReference.rules([Ranks.SEVEN, Ranks.JACK] as Array[int], false)
	var cards: Array[CardInstance] = _cards("3457J")
	var straight: Pattern = Readings.of(CardSelection.printed_counts(cards), two, _map)[0]
	assert_int(straight.type).is_equal(Pattern.Type.STRAIGHT)
	var stands: PackedByteArray = PlayPlacement.stands_for(cards, straight)
	assert_array(Array(stands)).is_equal(
		[Ranks.THREE, Ranks.FOUR, Ranks.FIVE, Ranks.SEVEN, Ranks.SIX]
	)
	# Three 9s with a single read as a queen: the wild seven is the kicker, as a seven.
	var trio_cards: Array[CardInstance] = _cards("99977")
	var queen_pair: Pattern = Pattern.new(
		Pattern.Type.TRIO_PAIR, Ranks.NINE, 1, 5, PackedByteArray([9, 9]), Ranks.NINE
	)
	var checked: Pattern = Readings.checked(
		queen_pair, CardSelection.printed_counts(trio_cards), _sevens, _map
	)
	var placed: PackedByteArray = PlayPlacement.stands_for(trio_cards, checked)
	assert_int(placed.count(Ranks.QUEEN)).is_equal(2)
	assert_int(placed.count(Ranks.NINE)).is_equal(3)


func test_hidden_reserves_scores_the_kickers_own_cards() -> void:
	var cards: Array[CardInstance] = _cards("9997")
	var queen_kicker: Pattern = Readings.checked(
		Pattern.new(
			Pattern.Type.TRIO_SINGLE, Ranks.NINE, 1, 4, PackedByteArray([Ranks.QUEEN]), Ranks.NINE
		),
		CardSelection.printed_counts(cards),
		_sevens,
		_map
	)
	var stack: ModifierStack = ModifierStack.new()
	stack.add(HIDDEN_RESERVES, 0)
	var breakdown: ScoreBreakdown = _score(cards, queen_kicker, stack)
	assert_float(breakdown.grain).is_equal(_grain(Ranks.NINE) * 3 + _grain(Ranks.SEVEN))


func test_a_soft_bomb_is_a_bomb_for_requisition() -> void:
	var cards: Array[CardInstance] = _cards("9997")
	var bomb: Pattern = _reading(cards, Pattern.Type.BOMB)
	assert_int(bomb.stand_ins()).is_equal(1)
	var stack: ModifierStack = ModifierStack.new()
	stack.add(REQUISITION, 0)
	assert_float(_score(cards, bomb, stack).total).is_equal(0.0)


func test_resentment_counts_a_stamped_card_by_its_placement() -> void:
	var cards: Array[CardInstance] = _cards("9997")
	var trio: Pattern = _reading(cards, Pattern.Type.TRIO_SINGLE)
	var bomb: Pattern = _reading(cards, Pattern.Type.BOMB)
	var seven: Array[CardInstance] = cards.filter(
		func(card: CardInstance) -> bool: return card.base_rank() == Ranks.SEVEN
	)
	CardModifiers.stamp(seven[0], 0)
	assert_int(Resentment.stamped(cards, 0, trio)).is_equal(0)
	assert_int(Resentment.stamped(cards, 0, bomb)).is_equal(1)
