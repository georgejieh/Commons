extends GdUnitTestSuite
## The enhancements a deck card may carry (ADR 0041), scored through the real Scorer: a
## Sheaf card adds flat Grain, a Pennant card gives its play Zeal, a Surplus card is listed
## for the loop to pay. Each scores the same for the player and a villager, alone, under a
## held Cadre and at a Directive's level, and each shows as a step of its own in the trail.

const PLAYER: int = 0
const VILLAGER: int = 1
const SPADE: int = 0
const HEART: int = 1
const CLUB: int = 2
const PARAMS: ScoreParams = preload("res://data/scoring/default_scoring.tres")


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("res://data/modifiers/%s.tres" % id)


func _card(rank: int, suit: int, enhancement: String = CardInstance.NO_ID) -> CardInstance:
	var card: CardInstance = Deck.new().card(rank * Deck.SUITS + suit)
	if enhancement != CardInstance.NO_ID:
		CardModifiers.enhance(card, enhancement)
	return card


func _score(
	cards: Array[CardInstance], seat: int, held: Array[String] = [], level: int = 1
) -> ScoreBreakdown:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in held:
		stack.add(_def(id), PLAYER)
	var pattern: Pattern = (
		CardSelection.classify_cards(cards, RuleSet.default_rules(), Ranks.identity_map()).pattern
	)
	return Scorer.score_play(cards, pattern, level, seat, false, stack, PARAMS, 0, null, true)


func _rate(type: Pattern.Type, level: int = 1) -> float:
	return PARAMS.rate_for(type, level)


## The numbers these goldens were written against, so a change to the data shows here.
func test_the_marks_numbers_are_the_datas() -> void:
	assert_int(PARAMS.sheaf_grain).is_equal(10)
	assert_float(PARAMS.pennant_zeal).is_equal_approx(0.2, 0.0001)
	assert_int(PARAMS.surplus_coupons).is_equal(1)
	assert_int(PARAMS.surplus_round_most).is_equal(2)


## A Sheaf 3 scores its printed 3 and 10 more, 13, for anyone; Model on the same 3 only
## doubles it to 6.
func test_a_sheaf_card_adds_flat_grain_for_whoever_scores_it() -> void:
	var sheaf: Array[CardInstance] = [_card(Ranks.THREE, SPADE, CardInstance.SHEAF)]
	var model: Array[CardInstance] = [_card(Ranks.THREE, SPADE, CardInstance.MODEL)]
	for seat: int in [PLAYER, VILLAGER]:
		var scored: ScoreBreakdown = _score(sheaf, seat)
		assert_float(scored.grain).is_equal(13.0)
		assert_float(scored.total).is_equal(13.0 * _rate(Pattern.Type.SINGLE))
		assert_float(_score(model, seat).grain).is_equal(6.0)


## Red Banner's flat +2 on a heart lands on top of the Sheaf's 10 for its holder alone,
## and a Directive's level raises the Rate the whole Grain is multiplied by.
func test_a_sheaf_stacks_with_a_cadre_and_a_level() -> void:
	var cards: Array[CardInstance] = [
		_card(Ranks.FIVE, HEART, CardInstance.SHEAF), _card(Ranks.FIVE, SPADE)
	]
	var held: Array[String] = ["red_banner"]
	var player: ScoreBreakdown = _score(cards, PLAYER, held, 3)
	assert_float(player.grain).is_equal(5.0 + 10.0 + 2.0 + 5.0)
	assert_float(player.total).is_equal(22.0 * _rate(Pattern.Type.PAIR, 3))
	var villager: ScoreBreakdown = _score(cards, VILLAGER, held, 3)
	assert_float(villager.grain).is_equal(20.0)
	assert_float(villager.total).is_equal(20.0 * _rate(Pattern.Type.PAIR, 3))


## Each scored Pennant card gives its play +0.2 Zeal, for anyone: one makes 1.2, two 1.4.
func test_each_pennant_card_gives_its_play_zeal() -> void:
	var one: Array[CardInstance] = [
		_card(Ranks.NINE, SPADE, CardInstance.PENNANT), _card(Ranks.NINE, HEART)
	]
	var two: Array[CardInstance] = [
		_card(Ranks.NINE, SPADE, CardInstance.PENNANT),
		_card(Ranks.NINE, HEART, CardInstance.PENNANT),
	]
	for seat: int in [PLAYER, VILLAGER]:
		var scored: ScoreBreakdown = _score(one, seat)
		assert_float(scored.zeal).is_equal_approx(1.2, 0.0001)
		assert_float(scored.grain).is_equal(18.0)
		assert_float(scored.total).is_equal_approx(18.0 * _rate(Pattern.Type.PAIR) * 1.2, 0.001)
		assert_float(_score(two, seat).zeal).is_equal_approx(1.4, 0.0001)


## A kicker scores nothing, so a Pennant card played as one gives no Zeal.
func test_a_pennant_kicker_gives_no_zeal() -> void:
	var cards: Array[CardInstance] = [
		_card(Ranks.SEVEN, SPADE),
		_card(Ranks.SEVEN, HEART),
		_card(Ranks.SEVEN, CLUB),
		_card(Ranks.KING, SPADE, CardInstance.PENNANT),
	]
	assert_float(_score(cards, PLAYER).zeal).is_equal(1.0)


## Canteen's +0.5 on a trio adds to the Pennant's +0.2 for the holder, 1.7; a villager has
## the Pennant's alone, 1.2. A level changes the Rate, not the Zeal.
func test_a_pennant_stacks_with_a_cadre_and_a_level() -> void:
	var trio: Array[CardInstance] = [
		_card(Ranks.SIX, SPADE, CardInstance.PENNANT),
		_card(Ranks.SIX, HEART),
		_card(Ranks.SIX, CLUB),
	]
	var held: Array[String] = ["canteen"]
	var player: ScoreBreakdown = _score(trio, PLAYER, held, 2)
	assert_float(player.zeal).is_equal_approx(1.7, 0.0001)
	var rate: float = _rate(Pattern.Type.TRIO, 2)
	assert_float(player.total).is_equal_approx(18.0 * rate * 1.7, 0.001)
	var villager: ScoreBreakdown = _score(trio, VILLAGER, held, 2)
	assert_float(villager.zeal).is_equal_approx(1.2, 0.0001)
	assert_float(villager.total).is_equal_approx(18.0 * rate * 1.2, 0.001)


## A Surplus card scores as a plain card and is listed for the loop to pay, for any seat;
## the loop pays the player's alone (SurplusPay).
func test_a_surplus_card_scores_plain_and_is_listed() -> void:
	var surplus: CardInstance = _card(Ranks.TEN, SPADE, CardInstance.SURPLUS)
	var cards: Array[CardInstance] = [surplus, _card(Ranks.TEN, HEART)]
	for seat: int in [PLAYER, VILLAGER]:
		var scored: ScoreBreakdown = _score(cards, seat, ["red_banner"], 2)
		var expected: float = 20.0 + (2.0 if seat == PLAYER else 0.0)
		assert_float(scored.grain).is_equal(expected)
		assert_float(scored.zeal).is_equal(1.0)
		assert_array(scored.surplus_cards).is_equal([surplus.id()])
	var kicker: Array[CardInstance] = [
		_card(Ranks.FOUR, SPADE), _card(Ranks.FOUR, HEART), _card(Ranks.FOUR, CLUB), surplus
	]
	assert_array(_score(kicker, PLAYER).surplus_cards).is_empty()


## Each mark is a step of its own on its card: the Sheaf's Grain, the Pennant's Zeal.
## Applied in order, the steps land on the play's figures.
func test_each_mark_is_a_step_on_its_card() -> void:
	var sheaf: CardInstance = _card(Ranks.EIGHT, SPADE, CardInstance.SHEAF)
	var pennant: CardInstance = _card(Ranks.EIGHT, HEART, CardInstance.PENNANT)
	var scored: ScoreBreakdown = _score([sheaf, pennant], PLAYER, ["red_banner"])
	var marks: Array[ScoreStep] = []
	for step: ScoreStep in scored.trail:
		if step.source == ScoreStep.Source.MARK:
			marks.append(step)
	assert_int(marks.size()).is_equal(2)
	assert_str(marks[0].source_id).is_equal(CardInstance.SHEAF)
	assert_int(marks[0].card_id).is_equal(sheaf.id())
	assert_int(marks[0].figure).is_equal(ScoreStep.Figure.GRAIN)
	assert_float(marks[0].value).is_equal(10.0)
	assert_str(marks[1].source_id).is_equal(CardInstance.PENNANT)
	assert_int(marks[1].card_id).is_equal(pennant.id())
	assert_int(marks[1].figure).is_equal(ScoreStep.Figure.ZEAL)
	assert_float(marks[1].after).is_equal_approx(1.2, 0.0001)
	var last: Dictionary[int, float] = {}
	for step: ScoreStep in scored.trail:
		last[step.figure] = step.after
	assert_float(last[ScoreStep.Figure.GRAIN]).is_equal(scored.grain)
	assert_float(last[ScoreStep.Figure.ZEAL]).is_equal_approx(scored.zeal, 0.0001)


## Two Pennant cards and Canteen: the hook's Zeal is its own +0.5 after the marks' 0.4.
func test_a_hooks_zeal_step_follows_the_marks() -> void:
	var trio: Array[CardInstance] = [
		_card(Ranks.SIX, SPADE, CardInstance.PENNANT),
		_card(Ranks.SIX, HEART, CardInstance.PENNANT),
		_card(Ranks.SIX, CLUB),
	]
	var scored: ScoreBreakdown = _score(trio, PLAYER, ["canteen"])
	var hook: ScoreStep = scored.trail[-1]
	assert_str(hook.source_id).is_equal("canteen")
	assert_float(hook.before).is_equal_approx(1.4, 0.0001)
	assert_float(hook.value).is_equal_approx(0.5, 0.0001)
	assert_float(hook.after).is_equal_approx(1.9, 0.0001)


## The player is paid for each Surplus card up to the round's most; a new round starts the
## count again. Each payment is a coupon step on its card.
func test_surplus_pays_the_player_up_to_the_rounds_most() -> void:
	var state: RunState = RunState.new(1)
	var pay: SurplusPay = SurplusPay.new()
	pay.start_round()
	var before: int = state.coupons
	var first: Array[ScoreStep] = pay.pay(state, [40], PARAMS)
	assert_int(first.size()).is_equal(1)
	assert_int(first[0].figure).is_equal(ScoreStep.Figure.COUPONS)
	assert_int(first[0].card_id).is_equal(40)
	assert_str(first[0].source_id).is_equal(CardInstance.SURPLUS)
	assert_int(pay.pay(state, [41, 42], PARAMS).size()).is_equal(1)
	assert_int(state.coupons).is_equal(before + 2)
	assert_array(pay.pay(state, [43], PARAMS)).is_empty()
	assert_int(state.coupons).is_equal(before + 2)
	pay.start_round()
	assert_int(pay.pay(state, [43], PARAMS).size()).is_equal(1)
	assert_int(state.coupons).is_equal(before + 3)
