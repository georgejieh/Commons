extends GdUnitTestSuite
## Scoring order, levels and the table.

const SUFFIXES: PackedStringArray = ["K", "M", "B", "T"]

var _stack: ModifierStack = ModifierStack.new()
var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


class Adder:
	extends ModifierEffect

	func play_scored(context: PlayContext) -> void:
		context.mul_zeal *= 3.0
		context.add_zeal += 2.0
		context.add_grain += 10.0

	func card_scored(context: CardContext) -> void:
		context.grain += 1.0


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
	var stack: ModifierStack = ModifierStack.new()
	stack.add_entry(ActiveModifier.new(ModifierDef.new(), Adder.new()))
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


func test_a_play_costs_one_array_allocation() -> void:
	var result: ScoreBreakdown = _score("9999")
	var size: int = result.steps.size()
	assert_int(result.allocations).is_equal(1)
	assert_bool(result.step_count * ScoreBreakdown.VALUES_PER_STEP <= size).is_true()


func test_the_largest_breakdown_fits_its_array() -> void:
	var text: String = "3334445556667778TJQK"
	var result: ScoreBreakdown = _score(text)
	assert_bool(result.step_count * ScoreBreakdown.VALUES_PER_STEP <= result.steps.size()).is_true()


func test_round_multipliers() -> void:
	var normal: RoundEvent.Finish = RoundEvent.Finish.NORMAL
	var spring: RoundEvent.Finish = RoundEvent.Finish.SPRING
	var anti: RoundEvent.Finish = RoundEvent.Finish.ANTI_SPRING
	assert_float(Scorer.round_multiplier(normal, false, _rules)).is_equal(1.0)
	assert_float(Scorer.round_multiplier(normal, true, _rules)).is_equal(1.5)
	assert_float(Scorer.round_multiplier(spring, true, _rules)).is_equal(3.0)
	assert_float(Scorer.round_multiplier(anti, false, _rules)).is_equal(2.0)


func test_anti_spring_only_doubles_when_the_rules_say_so() -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	params.anti_spring_doubles = false
	var anti: RoundEvent.Finish = RoundEvent.Finish.ANTI_SPRING
	assert_float(Scorer.round_multiplier(anti, false, RuleSet.new(params))).is_equal(1.0)


func test_nan_and_infinity_clamp() -> void:
	assert_float(Scorer.clamp_score(NAN)).is_equal(Scorer.MAX_SCORE)
	assert_float(Scorer.clamp_score(INF)).is_equal(Scorer.MAX_SCORE)
	assert_float(Scorer.clamp_score(-INF)).is_equal(-Scorer.MAX_SCORE)


func test_short_format() -> void:
	assert_str(ScoreFormat.short(999.0, SUFFIXES)).is_equal("999")
	assert_str(ScoreFormat.short(1250.0, SUFFIXES)).contains("K")
	assert_str(ScoreFormat.short(2500000.0, SUFFIXES)).is_equal("2.5M")
	assert_str(ScoreFormat.short(-2500.0, SUFFIXES)).is_equal("-2.5K")
	assert_str(ScoreFormat.short(INF, SUFFIXES)).ends_with("T")


func test_the_table_has_a_value_for_every_type_and_level() -> void:
	var params: ScoreParams = Scorer.DEFAULT_PARAMS
	var cells: int = Pattern.Type.size() * params.max_level
	assert_int(params.hand_grain.size()).is_equal(cells)
	assert_int(params.hand_zeal.size()).is_equal(cells)
	assert_int(params.card_grain.size()).is_equal(Ranks.COUNT)
	for type: int in range(Pattern.Type.SINGLE, Pattern.Type.size()):
		for level: int in range(2, params.max_level + 1):
			assert_bool(params.grain_for(type, level) > params.grain_for(type, level - 1)).is_true()


func test_a_level_change_shows_in_the_next_play() -> void:
	var levels: HandLevels = HandLevels.new(Scorer.DEFAULT_PARAMS.max_level)
	var pair: Pattern.Type = Pattern.Type.PAIR
	var before: ScoreBreakdown = Scorer.score_play(
		_cards("99"), _pattern("99"), levels.level_of(pair), 0, false, _stack
	)
	levels.raise(pair)
	var after: ScoreBreakdown = Scorer.score_play(
		_cards("99"), _pattern("99"), levels.level_of(pair), 0, false, _stack
	)
	assert_bool(after.total > before.total).is_true()
	assert_int(levels.level_of(Pattern.Type.TRIO)).is_equal(1)


func test_levels_stop_at_the_maximum() -> void:
	var levels: HandLevels = HandLevels.new(2)
	levels.raise(Pattern.Type.PAIR)
	levels.raise(Pattern.Type.PAIR)
	assert_int(levels.level_of(Pattern.Type.PAIR)).is_equal(2)
