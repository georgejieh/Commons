extends GdUnitTestSuite
## Scoring order, levels and the table.

var _stack: ModifierStack = ModifierStack.new()
var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


## Every scoring hook, with fixed adjustments that show their order.
class Adder:
	extends ModifierEffect
	var seen_seat: int = Seats.NONE
	var seen_landlord: bool = false

	func play_scored(context: PlayContext) -> void:
		seen_seat = context.seat
		seen_landlord = context.is_landlord
		context.mul_zeal *= 3.0
		context.add_zeal += 2.0
		context.add_grain += 10.0

	func card_scored(context: CardContext) -> void:
		context.grain += 1.0


## Sends a huge value through the hooks.
class Overflow:
	extends ModifierEffect

	func play_scored(context: PlayContext) -> void:
		context.mul_zeal = INF


func _scoring_stack(effect: ModifierEffect) -> ModifierStack:
	var definition: ModifierDef = ModifierDef.new()
	var hooks: Array[String] = [Hooks.PLAY_SCORED, Hooks.CARD_SCORED]
	definition.hooks = hooks
	var stack: ModifierStack = ModifierStack.new()
	stack.add_entry(ActiveModifier.new(definition, effect))
	return stack


func _cards(text: String) -> Array[CardInstance]:
	return RoundScript.stacked_deal([text], "").hands[0].cards()


func _pattern(text: String) -> Pattern:
	return Classifier.classify(RankText.counts(text), _rules, _map).pattern


func _score(text: String, stack: ModifierStack = _stack) -> ScoreBreakdown:
	return Scorer.score_play(_cards(text), _pattern(text), 1, 0, false, stack)


func test_a_pair_scores_base_plus_cards_times_zeal() -> void:
	var result: ScoreBreakdown = _score("99")
	assert_float(result.grain).is_equal(10.0 + 9.0 + 9.0)
	assert_float(result.zeal).is_equal(2.0)
	assert_float(result.total).is_equal(56.0)


func test_kickers_do_not_score() -> void:
	assert_float(_score("9993").grain).is_equal(35.0 + 27.0)
	assert_float(_score("999A").grain).is_equal(35.0 + 27.0)


func test_a_bomb_doubles_zeal() -> void:
	assert_float(_score("9999").zeal).is_equal(16.0)


func test_a_rocket_doubles_zeal_and_both_jokers_score() -> void:
	var result: ScoreBreakdown = _score("sb")
	assert_float(result.zeal).is_equal(20.0)
	assert_float(result.grain).is_equal(150.0 + 13.0 + 14.0)


func test_hooks_apply_grain_then_added_zeal_then_multiplied_zeal() -> void:
	var stack: ModifierStack = _scoring_stack(Adder.new())
	var result: ScoreBreakdown = _score("9", stack)
	assert_float(result.grain).is_equal(5.0 + 9.0 + 1.0 + 10.0)
	assert_float(result.zeal).is_equal((1.0 + 2.0) * 3.0)
	var kinds: Array[int] = []
	for index: int in result.step_count:
		kinds.append(result.step_kind(index))
	(
		assert_array(kinds)
		. is_equal(
			[
				ScoreBreakdown.Step.BASE_GRAIN,
				ScoreBreakdown.Step.CARD_GRAIN,
				ScoreBreakdown.Step.BASE_ZEAL,
				ScoreBreakdown.Step.ADD_GRAIN,
				ScoreBreakdown.Step.ADD_ZEAL,
				ScoreBreakdown.Step.MUL_ZEAL,
			]
		)
	)


func test_a_bomb_doubles_after_the_hooks() -> void:
	var result: ScoreBreakdown = _score("9999", _scoring_stack(Adder.new()))
	assert_float(result.zeal).is_equal((8.0 + 2.0) * 3.0 * 2.0)


func test_hooks_receive_the_seat_and_role() -> void:
	var effect: Adder = Adder.new()
	Scorer.score_play(_cards("9"), _pattern("9"), 1, 2, true, _scoring_stack(effect))
	assert_int(effect.seen_seat).is_equal(2)
	assert_bool(effect.seen_landlord).is_true()


func test_multipliers_come_from_the_params() -> void:
	var params: ScoreParams = Scorer.DEFAULT_PARAMS.duplicate()
	params.bomb_zeal_multiplier = 5.0
	var result: ScoreBreakdown = Scorer.score_play(
		_cards("9999"), _pattern("9999"), 1, 0, false, _stack, params
	)
	assert_float(result.zeal).is_equal(40.0)


func test_a_score_through_the_hooks_clamps() -> void:
	var result: ScoreBreakdown = _score("9", _scoring_stack(Overflow.new()))
	assert_float(result.zeal).is_equal(Scorer.MAX_SCORE)
	assert_float(result.total).is_equal(Scorer.MAX_SCORE)
	assert_float(Scorer.round_total(Scorer.MAX_SCORE, 3.0)).is_equal(Scorer.MAX_SCORE)


func test_steps_fill_one_array_of_a_known_size() -> void:
	for text: String in ["9999", "sb", "33344456", "3334445556667778TJQK"]:
		var result: ScoreBreakdown = _score(text)
		var scored: int = text.length() - _pattern(text).kicker_ranks.size()
		var size: int = (scored + ScoreBreakdown.FIXED_STEPS) * ScoreBreakdown.VALUES_PER_STEP
		assert_int(result.steps.size()).is_equal(size)
		assert_bool(result.step_count * ScoreBreakdown.VALUES_PER_STEP <= size).is_true()


func test_round_multipliers() -> void:
	var normal: RoundEvent.Finish = RoundEvent.Finish.NORMAL
	var spring: RoundEvent.Finish = RoundEvent.Finish.SPRING
	var anti: RoundEvent.Finish = RoundEvent.Finish.ANTI_SPRING
	assert_float(Scorer.round_multiplier(normal, false, true, _rules)).is_equal(1.0)
	assert_float(Scorer.round_multiplier(normal, true, true, _rules)).is_equal(1.5)
	assert_float(Scorer.round_multiplier(spring, true, true, _rules)).is_equal(3.0)
	assert_float(Scorer.round_multiplier(anti, false, true, _rules)).is_equal(2.0)


func test_the_losing_side_gets_no_spring_bonus() -> void:
	var spring: RoundEvent.Finish = RoundEvent.Finish.SPRING
	var anti: RoundEvent.Finish = RoundEvent.Finish.ANTI_SPRING
	assert_float(Scorer.round_multiplier(spring, false, false, _rules)).is_equal(1.0)
	assert_float(Scorer.round_multiplier(anti, false, false, _rules)).is_equal(1.0)


func test_anti_spring_only_doubles_when_the_rules_say_so() -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	params.anti_spring_doubles = false
	var anti: RoundEvent.Finish = RoundEvent.Finish.ANTI_SPRING
	assert_float(Scorer.round_multiplier(anti, false, true, RuleSet.new(params))).is_equal(1.0)


func test_nan_and_infinity_clamp() -> void:
	assert_float(Scorer.clamp_score(NAN)).is_equal(Scorer.MAX_SCORE)
	assert_float(Scorer.clamp_score(INF)).is_equal(Scorer.MAX_SCORE)
	assert_float(Scorer.clamp_score(-INF)).is_equal(-Scorer.MAX_SCORE)
