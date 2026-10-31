extends GdUnitTestSuite
## Hand levels, their table and short number display.

const SUFFIXES: PackedStringArray = ["K", "M", "B", "T"]

var _stack: ModifierStack = ModifierStack.new()
var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _cards(text: String) -> Array[CardInstance]:
	return RoundScript.stacked_deal([text], "").hands[0].cards()


func _pattern(text: String) -> Pattern:
	return Classifier.classify(RankText.counts(text), _rules, _map).pattern


func test_short_format() -> void:
	assert_str(ScoreFormat.short(999.0, SUFFIXES)).is_equal("999")
	assert_str(ScoreFormat.short(1500.0, SUFFIXES)).is_equal("1.5K")
	assert_str(ScoreFormat.short(2500000.0, SUFFIXES)).is_equal("2.5M")
	assert_str(ScoreFormat.short(-2500.0, SUFFIXES)).is_equal("-2.5K")


func test_short_format_carries_into_the_next_suffix() -> void:
	assert_str(ScoreFormat.short(999999.0, SUFFIXES)).is_equal("1.0M")


func test_short_format_past_the_last_suffix_uses_an_exponent() -> void:
	assert_str(ScoreFormat.short(1e15, SUFFIXES)).contains("e+")
	var longest: String = ScoreFormat.short(INF, SUFFIXES)
	assert_str(longest).contains("e+")
	assert_bool(longest.length() < 12).is_true()


func test_every_suffix_key_is_in_the_string_table() -> void:
	var table: String = FileAccess.get_file_as_string("res://data/strings/strings.csv")
	for key: String in ScoreFormat.SUFFIX_KEYS:
		assert_str(table).contains(key)


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
	assert_float(before.total).is_equal(56.0)
	levels.raise(pair)
	var after: ScoreBreakdown = Scorer.score_play(
		_cards("99"), _pattern("99"), levels.level_of(pair), 0, false, _stack
	)
	assert_float(after.grain).is_equal(25.0 + 18.0)
	assert_float(after.zeal).is_equal(3.0)
	assert_float(after.total).is_equal(129.0)
	assert_int(levels.level_of(Pattern.Type.TRIO)).is_equal(1)


func test_levels_stop_at_the_maximum() -> void:
	var levels: HandLevels = HandLevels.new(2)
	levels.raise(Pattern.Type.PAIR)
	levels.raise(Pattern.Type.PAIR)
	assert_int(levels.level_of(Pattern.Type.PAIR)).is_equal(2)
