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


## Takes more Zeal than any play has.
class Drain:
	extends ModifierEffect

	func play_scored(context: PlayContext) -> void:
		context.add_zeal -= 5.0


## Caps Rate at 2.
class Capper:
	extends ModifierEffect

	func play_scored(context: PlayContext) -> void:
		context.rate_cap = minf(context.rate_cap, 2.0)


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


func test_a_pair_scores_card_grain_times_rate_times_zeal() -> void:
	var result: ScoreBreakdown = _score("99")
	assert_float(result.grain).is_equal(9.0 + 9.0)
	assert_float(result.rate).is_equal(3.0)
	assert_float(result.zeal).is_equal(1.0)
	assert_float(result.total).is_equal(54.0)


func test_face_cards_and_twos_count_their_rank() -> void:
	# J 11, Q 12, K 13, A 14, 2 15.
	assert_float(_score("J").grain).is_equal(11.0)
	assert_float(_score("KK").grain).is_equal(26.0)
	assert_float(_score("A").grain).is_equal(14.0)
	assert_float(_score("22").grain).is_equal(30.0)


func test_kickers_do_not_score() -> void:
	assert_float(_score("9993").grain).is_equal(27.0)
	assert_float(_score("999A").grain).is_equal(27.0)
	assert_float(_score("9993").total).is_equal(27.0 * 7.0)


func test_a_bomb_scores_its_rate_with_no_extra_zeal() -> void:
	var result: ScoreBreakdown = _score("9999")
	assert_float(result.rate).is_equal(32.0)
	assert_float(result.zeal).is_equal(1.0)
	assert_float(result.total).is_equal(36.0 * 32.0)


func test_a_rocket_scores_both_jokers() -> void:
	var result: ScoreBreakdown = _score("sb")
	assert_float(result.grain).is_equal(16.0 + 17.0)
	assert_float(result.rate).is_equal(50.0)
	assert_float(result.total).is_equal(33.0 * 50.0)


func test_hooks_apply_grain_then_rate_then_added_then_multiplied_zeal() -> void:
	var stack: ModifierStack = _scoring_stack(Adder.new())
	var result: ScoreBreakdown = _score("9", stack)
	assert_float(result.grain).is_equal(9.0 + 1.0 + 10.0)
	assert_float(result.rate).is_equal(1.0)
	assert_float(result.zeal).is_equal((1.0 + 2.0) * 3.0)
	assert_float(result.total).is_equal(20.0 * 9.0)
	var kinds: Array[int] = []
	for index: int in result.step_count:
		kinds.append(result.step_kind(index))
	(
		assert_array(kinds)
		. is_equal(
			[
				ScoreBreakdown.Step.CARD_GRAIN,
				ScoreBreakdown.Step.ADD_GRAIN,
				ScoreBreakdown.Step.RATE,
				ScoreBreakdown.Step.ADD_ZEAL,
				ScoreBreakdown.Step.MUL_ZEAL,
			]
		)
	)


func test_zeal_never_falls_below_the_minimum() -> void:
	var result: ScoreBreakdown = _score("99", _scoring_stack(Drain.new()))
	assert_float(result.zeal).is_equal(Scorer.DEFAULT_PARAMS.min_zeal)
	assert_float(result.zeal).is_equal(0.5)
	assert_float(result.total).is_equal(18.0 * 3.0 * 0.5)


func test_a_rate_cap_limits_the_rate_and_shows_as_a_step() -> void:
	var result: ScoreBreakdown = _score("9999", _scoring_stack(Capper.new()))
	assert_float(result.rate).is_equal(2.0)
	assert_float(result.total).is_equal(36.0 * 2.0)
	var kinds: Array[int] = []
	for index: int in result.step_count:
		kinds.append(result.step_kind(index))
	assert_array(kinds).contains([ScoreBreakdown.Step.RATE_CAP])


func test_a_rate_under_the_cap_is_left_alone() -> void:
	var result: ScoreBreakdown = _score("9", _scoring_stack(Capper.new()))
	assert_float(result.rate).is_equal(1.0)
	for index: int in result.step_count:
		assert_int(result.step_kind(index)).is_not_equal(ScoreBreakdown.Step.RATE_CAP)


func test_hooks_receive_the_seat_and_role() -> void:
	var effect: Adder = Adder.new()
	Scorer.score_play(_cards("9"), _pattern("9"), 1, 2, true, _scoring_stack(effect))
	assert_int(effect.seen_seat).is_equal(2)
	assert_bool(effect.seen_landlord).is_true()


func test_rates_come_from_the_params() -> void:
	var params: ScoreParams = Scorer.DEFAULT_PARAMS.duplicate()
	var rates: Array[int] = params.hand_rate.duplicate()
	rates[Pattern.Type.BOMB * params.max_level] = 5
	params.hand_rate = rates
	var result: ScoreBreakdown = Scorer.score_play(
		_cards("9999"), _pattern("9999"), 1, 0, false, _stack, params
	)
	assert_float(result.rate).is_equal(5.0)
	assert_float(result.total).is_equal(36.0 * 5.0)


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
