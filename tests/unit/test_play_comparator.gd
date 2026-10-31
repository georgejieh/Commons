extends GdUnitTestSuite
## Compares every pair of a generated set of every shape against a plain statement of
## the rules, written here without using keys.

var _rules: RuleSet = RuleSet.default_rules()


func _read(text: String, rules: RuleSet = _rules) -> Pattern:
	return Classifier.classify(RankText.counts(text), rules, Ranks.identity_map()).pattern


func _all_shapes() -> Array[Pattern]:
	var texts: PackedStringArray = []
	var symbols: String = RankText.SYMBOLS
	for rank: int in Ranks.COUNT:
		texts.append(symbols[rank])
	for rank: int in Ranks.SMALL_JOKER:
		var symbol: String = symbols[rank]
		var other: String = symbols[(rank + 1) % Ranks.SMALL_JOKER]
		var third: String = symbols[(rank + 2) % Ranks.SMALL_JOKER]
		texts.append(symbol.repeat(2))
		texts.append(symbol.repeat(3))
		texts.append(symbol.repeat(3) + other)
		texts.append(symbol.repeat(3) + other.repeat(2))
		texts.append(symbol.repeat(4))
		texts.append(symbol.repeat(4) + other + third)
		texts.append(symbol.repeat(4) + other.repeat(2) + third.repeat(2))
	for start: int in Ranks.ACE + 1:
		for length: int in range(2, Ranks.ACE + 2 - start):
			_append_chains(texts, start, length)
	texts.append("sb")

	var patterns: Array[Pattern] = []
	for text: String in texts:
		var pattern: Pattern = _read(text)
		if pattern != null:
			patterns.append(pattern)
	return patterns


func _append_chains(texts: PackedStringArray, start: int, length: int) -> void:
	var symbols: String = RankText.SYMBOLS
	var single_run: String = symbols.substr(start, length)
	var pair_run: String = ""
	var trio_run: String = ""
	for symbol: String in single_run:
		pair_run += symbol.repeat(2)
		trio_run += symbol.repeat(3)
	texts.append(single_run)
	texts.append(pair_run)
	texts.append(trio_run)
	var outside: String = symbols.replace(single_run, "").substr(0, Ranks.COUNT)
	if outside.length() >= 2 * length:
		var wings: String = outside.substr(0, length)
		texts.append(trio_run + wings)
		var pairs: String = ""
		for symbol: String in wings:
			pairs += symbol.repeat(2)
		texts.append(trio_run + pairs)


func _expected(play: Pattern, current: Pattern) -> bool:
	var play_bomb: bool = play.type == Pattern.Type.BOMB
	var current_bomb: bool = current.type == Pattern.Type.BOMB
	if current.type == Pattern.Type.ROCKET:
		return false
	if play.type == Pattern.Type.ROCKET:
		return true
	if play_bomb and current_bomb:
		return play.main_rank > current.main_rank
	if play_bomb != current_bomb:
		return play_bomb
	var same_shape: bool = (
		play.type == current.type
		and play.card_count == current.card_count
		and play.chain_length == current.chain_length
	)
	return same_shape and play.main_rank > current.main_rank


func test_the_set_covers_every_type() -> void:
	var seen: Dictionary[int, bool] = {}
	for pattern: Pattern in _all_shapes():
		seen[pattern.type] = true
	assert_int(seen.size()).is_equal(Pattern.Type.size() - 1)


func test_every_pair_of_shapes() -> void:
	var patterns: Array[Pattern] = _all_shapes()
	var wrong: int = 0
	for play: Pattern in patterns:
		for current: Pattern in patterns:
			if PlayComparator.beats(play, current, _rules) != _expected(play, current):
				wrong += 1
	assert_int(wrong).is_equal(0)


func test_kickers_never_matter() -> void:
	assert_bool(PlayComparator.beats(_read("4443"), _read("333b"), _rules)).is_true()
	assert_bool(PlayComparator.beats(_read("333b"), _read("4443"), _rules)).is_false()


func test_a_lower_bomb_beats_a_higher_four_with_two() -> void:
	assert_bool(PlayComparator.beats(_read("3333"), _read("AAAA45"), _rules)).is_true()


func test_a_longer_straight_does_not_beat_a_shorter_one() -> void:
	assert_bool(PlayComparator.beats(_read("456789"), _read("34567"), _rules)).is_false()


func test_the_two_four_with_two_shapes_never_meet() -> void:
	assert_bool(PlayComparator.beats(_read("AAAA3344"), _read("333345"), _rules)).is_false()


func test_anything_beats_a_pass() -> void:
	assert_bool(PlayComparator.beats(_read("3"), Pattern.pass_play(), _rules)).is_true()


func test_a_pass_beats_nothing() -> void:
	assert_bool(PlayComparator.beats(Pattern.pass_play(), _read("3"), _rules)).is_false()


func test_a_bigger_bomb_wins_when_five_of_a_kind_is_enabled() -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	params.five_plus_is_bomb = true
	var rules: RuleSet = RuleSet.new(params)
	var low_five: Pattern = _read("33333", rules)
	assert_bool(PlayComparator.beats(low_five, _read("2222", rules), rules)).is_true()
	assert_bool(PlayComparator.beats(_read("2222", rules), low_five, rules)).is_false()
	assert_bool(PlayComparator.beats(_read("44444", rules), low_five, rules)).is_true()


func test_a_rocket_never_beats_a_rocket_whatever_the_rank_maps() -> void:
	var counts: PackedByteArray = RankText.counts("sb")
	var plain: Pattern = Classifier.classify(counts, _rules, Ranks.identity_map()).pattern
	var reversed_map: PackedByteArray = Ranks.identity_map()
	reversed_map.reverse()
	var reversed: Pattern = Classifier.classify(counts, _rules, reversed_map).pattern
	assert_bool(PlayComparator.beats(plain, reversed, _rules)).is_false()
	assert_bool(PlayComparator.beats(reversed, plain, _rules)).is_false()


func test_wild_bomb_sits_below_the_rocket_by_default() -> void:
	var rules: RuleSet = _wild_rules(true)
	var wild: Pattern = _read("7777", rules)
	assert_bool(PlayComparator.beats(wild, _read("2222", rules), rules)).is_true()
	assert_bool(PlayComparator.beats(wild, _read("sb", rules), rules)).is_false()
	assert_bool(PlayComparator.beats(_read("sb", rules), wild, rules)).is_true()


func test_wild_bomb_can_outrank_the_rocket() -> void:
	var rules: RuleSet = _wild_rules(false)
	var wild: Pattern = _read("7777", rules)
	assert_bool(PlayComparator.beats(wild, _read("sb", rules), rules)).is_true()
	assert_bool(PlayComparator.beats(_read("sb", rules), wild, rules)).is_false()
	assert_bool(PlayComparator.beats(_read("sb", rules), _read("2222", rules), rules)).is_true()


func _wild_rules(rocket_on_top: bool) -> RuleSet:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	var wild: Array[int] = [Ranks.SEVEN]
	params.wild_ranks = wild
	params.rocket_above_wild_bomb = rocket_on_top
	return RuleSet.new(params)
