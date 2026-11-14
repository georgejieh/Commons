extends GdUnitTestSuite
## Golden scores for the demo's Cadres and debuffs (ADR 0017), each against a known play
## with and without the modifier. Values follow default_scoring.tres.

const PLAYER: int = 0
const OTHER: int = 1

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _stack(ids: Array[String]) -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	for modifier_id: String in ids:
		stack.add(load("res://data/modifiers/%s.tres" % modifier_id), PLAYER)
	return stack


func _score(text: String, ids: Array[String], seat: int = PLAYER, plays_before: int = 0) -> float:
	var cards: Array[CardInstance] = RoundScript.stacked_deal([text], "").hands[0].cards()
	var pattern: Pattern = Classifier.classify(RankText.counts(text), _rules, _map).pattern
	return (
		Scorer
		. score_play(
			cards, pattern, 1, seat, false, _stack(ids), Scorer.DEFAULT_PARAMS, plays_before
		)
		. total
	)


func test_iron_rice_bowl_adds_grain_and_caps_rate() -> void:
	# A 9 scores 9 Grain × 1 Rate × 1 Zeal; the Bowl adds 30 Grain.
	assert_float(_score("9", [])).is_equal(9.0)
	assert_float(_score("9", ["iron_rice_bowl"])).is_equal(39.0)
	# A bomb of 9s: 36 Grain × 32 Rate, then (36 + 30) Grain × the capped 20 Rate.
	assert_float(_score("9999", [])).is_equal(1152.0)
	assert_float(_score("9999", ["iron_rice_bowl"])).is_equal(1320.0)
	assert_float(_score("9", ["iron_rice_bowl"], OTHER)).is_equal(9.0)


func test_stakhanovite_adds_half_a_zeal_per_card_past_five() -> void:
	# 3 to 7: 25 Grain × 7 Rate. 3 to 9: 42 Grain × 7 Rate × (1 + 2 × 0.5) Zeal.
	assert_float(_score("34567", [])).is_equal(175.0)
	assert_float(_score("34567", ["stakhanovite"])).is_equal(175.0)
	assert_float(_score("3456789", [])).is_equal(294.0)
	assert_float(_score("3456789", ["stakhanovite"])).is_equal(588.0)


func test_hidden_reserves_scores_kickers() -> void:
	# 999+3 scores Grain for the trio only; the 3 kicker adds its 3 Grain, times Rate 7.
	assert_float(_score("9993", [])).is_equal(189.0)
	assert_float(_score("9993", ["hidden_reserves"])).is_equal(210.0)
	assert_float(_score("999", ["hidden_reserves"])).is_equal(_score("999", []))


func test_ration_cut_takes_a_quarter_zeal() -> void:
	# A pair of 9s: 18 Grain × 3 Rate × 0.75 Zeal.
	assert_float(_score("99", [])).is_equal(54.0)
	assert_float(_score("99", ["ration_cut"])).is_equal(40.5)


func test_paperwork_halves_pair_grain_only() -> void:
	assert_float(_score("99", ["paperwork"])).is_equal(_score("99", []) / 2.0)
	assert_float(_score("9", ["paperwork"])).is_equal(_score("9", []))


func test_morning_meeting_zeroes_only_the_first_play() -> void:
	assert_float(_score("9", ["morning_meeting"], PLAYER, 0)).is_equal(0.0)
	assert_float(_score("9", ["morning_meeting"], PLAYER, 1)).is_equal(9.0)


func test_straightened_lines_halves_straights() -> void:
	assert_float(_score("34567", ["straightened_lines"])).is_equal(_score("34567", []) / 2.0)
	assert_float(_score("99", ["straightened_lines"])).is_equal(_score("99", []))


func test_paperwork_halves_grain_that_cadres_added_too() -> void:
	# A pair of 9s: 18 card Grain plus Iron Rice Bowl's 30, × 3 Rate, then Grain halved.
	assert_float(_score("99", ["iron_rice_bowl"])).is_equal(144.0)
	assert_float(_score("99", ["iron_rice_bowl", "paperwork"])).is_equal(72.0)


func test_straightened_lines_halves_a_total_cadres_raised() -> void:
	# 3 to Q: (75 + 30) Grain × 7 Rate × (1 + 5 × 0.5) Zeal.
	var raised: float = _score("3456789TJQ", ["iron_rice_bowl", "stakhanovite"])
	assert_float(raised).is_equal(2572.5)
	var both: Array[String] = ["iron_rice_bowl", "stakhanovite", "straightened_lines"]
	assert_float(_score("3456789TJQ", both)).is_equal(raised / 2.0)


func test_ration_cut_leaves_a_fraction_of_zeal() -> void:
	# A Single of 9 keeps 0.75 Zeal, above the 0.5 floor.
	assert_float(_score("9", ["ration_cut"])).is_equal(6.75)


func test_zeal_parameters_read_as_decimals() -> void:
	assert_str(_text("ration_cut")).is_equal("Your plays lose 0.25 Zeal.")
	assert_str(_text("stakhanovite")).is_equal(
		"Your Straights gain +0.5 Zeal for each card past 5."
	)
	assert_str(_text("iron_rice_bowl")).is_equal(
		"Your plays gain 30 Grain. Your Rate can't go above ×20."
	)
	assert_str(_text("bosses/great_leap")).is_equal(
		"The Quota is doubled. Your plays gain +0.5 Zeal."
	)


func _text(path: String) -> String:
	var definition: ModifierDef = load("res://data/modifiers/%s.tres" % path)
	return tr(definition.text_key).format(definition.text_values())
