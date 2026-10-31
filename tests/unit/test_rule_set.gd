extends GdUnitTestSuite
## The default RuleSet matches the Plan's rules table, one test per field.

var _rules: RuleSet = RuleSet.default_rules()


func test_minimum_straight_length_is_five() -> void:
	assert_int(_rules.min_straight_length()).is_equal(5)


func test_minimum_pair_chain_length_is_three() -> void:
	assert_int(_rules.min_pair_chain_length()).is_equal(3)


func test_minimum_airplane_length_is_two() -> void:
	assert_int(_rules.min_airplane_length()).is_equal(2)


func test_two_may_not_chain() -> void:
	assert_bool(_rules.two_may_chain()).is_false()
	assert_int(_rules.last_chain_rank()).is_equal(Ranks.ACE)


func test_both_wing_kinds_are_allowed() -> void:
	assert_bool(_rules.single_wings_allowed()).is_true()
	assert_bool(_rules.pair_wings_allowed()).is_true()


func test_single_wings_may_form_a_pair() -> void:
	assert_bool(_rules.single_wings_may_pair()).is_true()


func test_a_joker_or_two_may_be_a_wing() -> void:
	assert_bool(_rules.joker_or_two_may_be_wing()).is_true()


func test_the_rocket_may_not_be_a_kicker() -> void:
	assert_bool(_rules.rocket_may_be_kicker()).is_false()


func test_both_four_with_two_shapes_are_allowed() -> void:
	assert_bool(_rules.four_two_singles_allowed()).is_true()
	assert_bool(_rules.four_two_pairs_allowed()).is_true()


func test_four_with_two_singles_may_not_share_a_rank() -> void:
	assert_bool(_rules.four_two_singles_may_share_rank()).is_false()


func test_five_of_a_kind_is_not_a_bomb() -> void:
	assert_bool(_rules.five_plus_is_bomb()).is_false()


func test_there_are_no_wild_ranks() -> void:
	assert_int(_rules.wild_ranks().size()).is_equal(0)
	for rank: int in Ranks.COUNT:
		assert_bool(_rules.is_wild(rank)).is_false()


func test_the_rocket_stays_above_a_wild_bomb() -> void:
	assert_bool(_rules.rocket_above_wild_bomb()).is_true()


func test_anti_spring_doubles() -> void:
	assert_bool(_rules.anti_spring_doubles()).is_true()


func test_a_rule_set_ignores_later_edits_to_its_params() -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	var wild: Array[int] = [Ranks.SEVEN]
	params.wild_ranks = wild
	var rules: RuleSet = RuleSet.new(params)
	params.min_straight_length = 3
	params.wild_ranks.append(Ranks.NINE)
	rules.wild_ranks().append(Ranks.TEN)
	assert_int(rules.min_straight_length()).is_equal(5)
	assert_bool(rules.is_wild(Ranks.NINE)).is_false()
	assert_bool(rules.is_wild(Ranks.TEN)).is_false()
