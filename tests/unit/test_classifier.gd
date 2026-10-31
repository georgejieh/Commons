extends GdUnitTestSuite
## Table-driven classifier cases: every rules table row, disputed rule and illegal case.
## Each valid row is "cards" then the description, or "!" when the cards must be refused.

const VALID_CASES: Array[Array] = [
	["3", "SINGLE 3 x1 "],
	["T", "SINGLE T x1 "],
	["A", "SINGLE A x1 "],
	["2", "SINGLE 2 x1 "],
	["s", "SINGLE s x1 "],
	["b", "SINGLE b x1 "],
	["33", "PAIR 3 x1 "],
	["JJ", "PAIR J x1 "],
	["AA", "PAIR A x1 "],
	["22", "PAIR 2 x1 "],
	["333", "TRIO 3 x1 "],
	["QQQ", "TRIO Q x1 "],
	["222", "TRIO 2 x1 "],
	["3334", "TRIO_SINGLE 3 x1 4"],
	["3444", "TRIO_SINGLE 4 x1 3"],
	["KKK2", "TRIO_SINGLE K x1 2"],
	["999s", "TRIO_SINGLE 9 x1 s"],
	["999b", "TRIO_SINGLE 9 x1 b"],
	["2223", "TRIO_SINGLE 2 x1 3"],
	["222A", "TRIO_SINGLE 2 x1 A"],
	["33344", "TRIO_PAIR 3 x1 44"],
	["33444", "TRIO_PAIR 4 x1 33"],
	["TTT22", "TRIO_PAIR T x1 22"],
	["222AA", "TRIO_PAIR 2 x1 AA"],
	["34567", "STRAIGHT 3 x5 "],
	["45678", "STRAIGHT 4 x5 "],
	["TJQKA", "STRAIGHT T x5 "],
	["9TJQKA", "STRAIGHT 9 x6 "],
	["345678", "STRAIGHT 3 x6 "],
	["3456789T", "STRAIGHT 3 x8 "],
	["3456789TJQKA", "STRAIGHT 3 x12 "],
	["456789TJQKA", "STRAIGHT 4 x11 "],
	["334455", "PAIR_CHAIN 3 x3 "],
	["QQKKAA", "PAIR_CHAIN Q x3 "],
	["33445566", "PAIR_CHAIN 3 x4 "],
	["TTJJQQKKAA", "PAIR_CHAIN T x5 "],
	["334455667788", "PAIR_CHAIN 3 x6 "],
	["333444", "AIRPLANE 3 x2 "],
	["KKKAAA", "AIRPLANE K x2 "],
	["333444555", "AIRPLANE 3 x3 "],
	["333444555666", "AIRPLANE 3 x4 "],
	["333444555666777", "AIRPLANE 3 x5 "],
	["33344456", "AIRPLANE_SINGLES 3 x2 56"],
	["34777888", "AIRPLANE_SINGLES 7 x2 34"],
	["3777888A", "AIRPLANE_SINGLES 7 x2 3A"],
	["77788892", "AIRPLANE_SINGLES 7 x2 92"],
	["777888s5", "AIRPLANE_SINGLES 7 x2 5s"],
	["777888b5", "AIRPLANE_SINGLES 7 x2 5b"],
	["777888s2", "AIRPLANE_SINGLES 7 x2 2s"],
	["777888b2", "AIRPLANE_SINGLES 7 x2 2b"],
	["KKKAAA23", "AIRPLANE_SINGLES K x2 32"],
	["44455599", "AIRPLANE_SINGLES 4 x2 99"],
	["44455522", "AIRPLANE_SINGLES 4 x2 22"],
	["333444555678", "AIRPLANE_SINGLES 3 x3 678"],
	["44455566637", "!"],
	["444555666379", "AIRPLANE_SINGLES 4 x3 379"],
	["3334445556667899", "!"],
	["3334445556668899", "AIRPLANE_SINGLES 3 x4 8899"],
	["33344455566678TJ", "AIRPLANE_SINGLES 3 x4 78TJ"],
	["3334445556667778TJQ", "!"],
	["3334445556667778TJQK", "AIRPLANE_SINGLES 3 x5 8TJQK"],
	["3334445566", "AIRPLANE_PAIRS 3 x2 5566"],
	["3355777888", "AIRPLANE_PAIRS 7 x2 3355"],
	["88899922TT", "AIRPLANE_PAIRS 8 x2 TT22"],
	["333444555778899", "AIRPLANE_PAIRS 3 x3 778899"],
	["33344455566677889922", "AIRPLANE_PAIRS 3 x4 77889922"],
	["44455566677889TT", "!"],
	["444555666777889922TT", "AIRPLANE_PAIRS 4 x4 8899TT22"],
	["333345", "FOUR_TWO_SINGLES 3 x1 45"],
	["34TTTT", "FOUR_TWO_SINGLES T x1 34"],
	["22224A", "FOUR_TWO_SINGLES 2 x1 4A"],
	["AAAA2s", "FOUR_TWO_SINGLES A x1 2s"],
	["AAAA2b", "FOUR_TWO_SINGLES A x1 2b"],
	["33334455", "FOUR_TWO_PAIRS 3 x1 4455"],
	["5566JJJJ", "FOUR_TWO_PAIRS J x1 5566"],
	["AAAA3322", "FOUR_TWO_PAIRS A x1 3322"],
	["2222AAKK", "FOUR_TWO_PAIRS 2 x1 KKAA"],
	["3333", "BOMB 3 x1 "],
	["9999", "BOMB 9 x1 "],
	["AAAA", "BOMB A x1 "],
	["2222", "BOMB 2 x1 "],
	["sb", "ROCKET s x1 "],
	["4", "SINGLE 4 x1 "],
	["K", "SINGLE K x1 "],
	["44", "PAIR 4 x1 "],
	["555", "TRIO 5 x1 "],
	["AAA", "TRIO A x1 "],
	["AAA3", "TRIO_SINGLE A x1 3"],
	["AAAKK", "TRIO_PAIR A x1 KK"],
	["56789", "STRAIGHT 5 x5 "],
	["456789T", "STRAIGHT 4 x7 "],
	["JJQQKK", "PAIR_CHAIN J x3 "],
]

## Each illegal row is "cards" and the expected reason.
const INVALID_CASES: Array[Array] = [
	["", Classification.Reason.EMPTY],
	# The two jokers are never a pair, and only form the rocket alone.
	["ss b", Classification.Reason.UNKNOWN_SHAPE],
	["3s", Classification.Reason.UNCHAINABLE_RANK],
	["2s", Classification.Reason.UNCHAINABLE_RANK],
	["2b", Classification.Reason.UNCHAINABLE_RANK],
	["34", Classification.Reason.CHAIN_TOO_SHORT],
	["35", Classification.Reason.UNKNOWN_SHAPE],
	["3345", Classification.Reason.UNKNOWN_SHAPE],
	["33345", Classification.Reason.BAD_KICKERS],
	["333456", Classification.Reason.BAD_KICKERS],
	["333sb", Classification.Reason.BAD_KICKERS],
	["3334455", Classification.Reason.BAD_KICKERS],
	# Straights.
	["3456", Classification.Reason.CHAIN_TOO_SHORT],
	["345", Classification.Reason.CHAIN_TOO_SHORT],
	["34568", Classification.Reason.UNKNOWN_SHAPE],
	["JQKA2", Classification.Reason.UNCHAINABLE_RANK],
	["A2345", Classification.Reason.UNCHAINABLE_RANK],
	["2345", Classification.Reason.UNCHAINABLE_RANK],
	["23456", Classification.Reason.UNCHAINABLE_RANK],
	["QKA2s", Classification.Reason.UNCHAINABLE_RANK],
	["KA2sb", Classification.Reason.UNCHAINABLE_RANK],
	["3456789TJQKA2", Classification.Reason.UNCHAINABLE_RANK],
	["34567s", Classification.Reason.UNCHAINABLE_RANK],
	# Pair chains.
	["3344", Classification.Reason.CHAIN_TOO_SHORT],
	["KKAA", Classification.Reason.CHAIN_TOO_SHORT],
	["334466", Classification.Reason.UNKNOWN_SHAPE],
	["QQKKAA22", Classification.Reason.UNCHAINABLE_RANK],
	["KKAA22", Classification.Reason.UNCHAINABLE_RANK],
	["AA2233", Classification.Reason.UNCHAINABLE_RANK],
	["AA22", Classification.Reason.UNCHAINABLE_RANK],
	["33445", Classification.Reason.UNKNOWN_SHAPE],
	# Airplanes.
	["333555", Classification.Reason.UNKNOWN_SHAPE],
	["AAA222", Classification.Reason.UNCHAINABLE_RANK],
	["KKKAAA222", Classification.Reason.UNCHAINABLE_RANK],
	["3334445", Classification.Reason.BAD_WINGS],
	["333444567", Classification.Reason.BAD_WINGS],
	["333444555 777", Classification.Reason.UNKNOWN_SHAPE],
	# Mixed wing kinds.
	["333444555677", Classification.Reason.BAD_WINGS],
	["333444556", Classification.Reason.BAD_WINGS],
	["3334445566778", Classification.Reason.BAD_WINGS],
	["3334445556677889", Classification.Reason.BAD_WINGS],
	# The rocket as wings.
	["333444sb", Classification.Reason.ROCKET_AS_KICKER],
	["333444555sb6", Classification.Reason.ROCKET_AS_KICKER],
	# A bomb as wings.
	["3334447777", Classification.Reason.BAD_KICKERS],
	["3334445555", Classification.Reason.BAD_KICKERS],
	["333444555666 7777", Classification.Reason.BAD_KICKERS],
	# A trio as a wing, consecutive or not.
	["333444555777", Classification.Reason.UNKNOWN_SHAPE],
	["33344455577", Classification.Reason.BAD_WINGS],
	["333444555666 7779", Classification.Reason.BAD_WINGS],
	["333444777", Classification.Reason.UNKNOWN_SHAPE],
	# A rank spread across body and wing.
	["33334445", Classification.Reason.BAD_KICKERS],
	# Four with two.
	["33334", Classification.Reason.BAD_KICKERS],
	["333344", Classification.Reason.BAD_KICKERS],
	["33334456", Classification.Reason.BAD_KICKERS],
	["3333456", Classification.Reason.BAD_KICKERS],
	["333344445", Classification.Reason.BAD_KICKERS],
	["33334444", Classification.Reason.BAD_KICKERS],
	["3333sb", Classification.Reason.ROCKET_AS_KICKER],
	["3333444", Classification.Reason.BAD_KICKERS],
	["22224444", Classification.Reason.BAD_KICKERS],
	["3333445", Classification.Reason.BAD_KICKERS],
	["333355", Classification.Reason.BAD_KICKERS],
	["33344455555", Classification.Reason.UNKNOWN_SHAPE],
	# Five of a kind, off by default.
	["33333", Classification.Reason.UNKNOWN_SHAPE],
	["333334", Classification.Reason.UNKNOWN_SHAPE],
]


func _classify(text: String, rules: RuleSet = RuleSet.default_rules()) -> Classification:
	var counts: PackedByteArray = RankText.counts(text.replace(" ", ""))
	return Classifier.classify(counts, rules, Ranks.identity_map())


func _edited(field: String, value: Variant) -> RuleSet:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	params.set(field, value)
	return RuleSet.new(params)


func test_the_table_has_at_least_150_cases() -> void:
	assert_bool(VALID_CASES.size() + INVALID_CASES.size() >= 150).is_true()


func test_valid_table() -> void:
	for row: Array in VALID_CASES:
		var text: String = row[0]
		var expected: String = row[1]
		var result: Classification = _classify(text)
		if expected == "!":
			assert_bool(result.is_valid()).override_failure_message(text).is_false()
			continue
		assert_bool(result.is_valid()).override_failure_message(text).is_true()
		if result.is_valid():
			var actual: String = RankText.describe(result.pattern)
			assert_str(actual).override_failure_message(text + ": " + actual).is_equal(expected)


func test_invalid_table() -> void:
	for row: Array in INVALID_CASES:
		var text: String = row[0]
		var expected: int = row[1]
		var result: Classification = _classify(text)
		var message: String = "%s gave %d" % [text, result.reason]
		assert_int(result.reason).override_failure_message(message).is_equal(expected)
		assert_object(result.pattern).is_null()


func test_valid_patterns_reproduce_their_cards() -> void:
	for row: Array in VALID_CASES:
		var text: String = row[0]
		var result: Classification = _classify(text)
		if result.is_valid():
			assert_bool(result.pattern.counts() == RankText.counts(text)).is_true()
			assert_int(result.pattern.card_count).is_equal(text.length())


func test_a_two_may_join_chains_when_the_rule_allows() -> void:
	var rules: RuleSet = _edited("two_may_chain", true)
	assert_bool(_classify("JQKA2", rules).is_valid()).is_true()
	assert_bool(_classify("KA2sb", rules).is_valid()).is_false()


func test_short_straights_follow_the_minimum() -> void:
	assert_bool(_classify("345", _edited("min_straight_length", 3)).is_valid()).is_true()


func test_four_two_singles_may_share_a_rank_when_the_rule_allows() -> void:
	var rules: RuleSet = _edited("four_two_singles_may_share_rank", true)
	var result: Classification = _classify("333344", rules)
	assert_int(result.pattern.type).is_equal(Pattern.Type.FOUR_TWO_SINGLES)


func test_joker_and_two_wings_can_be_refused() -> void:
	var rules: RuleSet = _edited("joker_or_two_may_be_wing", false)
	assert_int(_classify("33344452", rules).reason).is_equal(Classification.Reason.BAD_WINGS)
	assert_int(_classify("3334445s", rules).reason).is_equal(Classification.Reason.BAD_WINGS)


func test_the_rocket_may_be_a_kicker_when_the_rule_allows() -> void:
	var rules: RuleSet = _edited("rocket_may_be_kicker", true)
	assert_bool(_classify("333444sb", rules).is_valid()).is_true()
	assert_bool(_classify("3333sb", rules).is_valid()).is_true()


func test_wing_kinds_can_be_refused() -> void:
	var no_singles: RuleSet = _edited("single_wings_allowed", false)
	assert_bool(_classify("33344456", no_singles).is_valid()).is_false()
	assert_bool(_classify("3334445566", no_singles).is_valid()).is_true()
	var no_pairs: RuleSet = _edited("pair_wings_allowed", false)
	assert_bool(_classify("3334445566", no_pairs).is_valid()).is_false()
	assert_bool(_classify("33344456", no_pairs).is_valid()).is_true()


func test_a_paired_wing_can_be_refused() -> void:
	var rules: RuleSet = _edited("single_wings_may_pair", false)
	assert_bool(_classify("33344455", rules).is_valid()).is_false()


func test_four_with_two_shapes_can_be_refused() -> void:
	(
		assert_bool(_classify("333345", _edited("four_two_singles_allowed", false)).is_valid())
		. is_false()
	)
	(
		assert_bool(_classify("33334455", _edited("four_two_pairs_allowed", false)).is_valid())
		. is_false()
	)


func test_five_of_a_kind_is_a_bomb_when_the_rule_allows() -> void:
	var result: Classification = _classify("33333", _edited("five_plus_is_bomb", true))
	assert_int(result.pattern.type).is_equal(Pattern.Type.BOMB)
	assert_int(result.pattern.card_count).is_equal(5)


func test_a_plot_duplicate_joker_is_a_plain_pair() -> void:
	var result: Classification = _classify("ss")
	assert_int(result.pattern.type).is_equal(Pattern.Type.PAIR)


func test_the_key_reads_the_effective_rank_map() -> void:
	var map: PackedByteArray = Ranks.identity_map()
	map[Ranks.THREE] = Ranks.TWO
	var counts: PackedByteArray = RankText.counts("33")
	var pattern: Pattern = Classifier.classify(counts, RuleSet.default_rules(), map).pattern
	assert_int(pattern.main_rank).is_equal(Ranks.THREE)
	assert_int(pattern.key & 0xFF).is_equal(Ranks.TWO)
