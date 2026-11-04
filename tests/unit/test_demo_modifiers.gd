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


func test_iron_rice_bowl_adds_grain_and_caps_zeal() -> void:
	assert_float(_score("9", [])).is_equal(14.0)
	assert_float(_score("9", ["iron_rice_bowl"])).is_equal(44.0)
	assert_float(_score("9999", [])).is_equal(1088.0)
	assert_float(_score("9999", ["iron_rice_bowl"])).is_equal(996.0)
	assert_float(_score("9", ["iron_rice_bowl"], OTHER)).is_equal(14.0)


func test_stakhanovite_adds_zeal_past_five_cards() -> void:
	var five: float = _score("34567", [])
	assert_float(_score("34567", ["stakhanovite"])).is_equal(five)
	var seven: float = _score("3456789", [])
	assert_float(_score("3456789", ["stakhanovite"])).is_greater(seven)


func test_hidden_reserves_scores_kickers() -> void:
	# 999+3 scores Grain for the trio only; the 3 kicker adds its 3 Grain, times Zeal.
	var plain: float = _score("9993", [])
	assert_float(_score("9993", ["hidden_reserves"])).is_greater(plain)
	assert_float(_score("999", ["hidden_reserves"])).is_equal(_score("999", []))


func test_ration_cut_takes_zeal() -> void:
	assert_float(_score("99", [])).is_greater(_score("99", ["ration_cut"]))


func test_paperwork_halves_pair_grain_only() -> void:
	assert_float(_score("99", ["paperwork"])).is_equal(_score("99", []) / 2.0)
	assert_float(_score("9", ["paperwork"])).is_equal(_score("9", []))


func test_morning_meeting_zeroes_only_the_first_play() -> void:
	assert_float(_score("9", ["morning_meeting"], PLAYER, 0)).is_equal(0.0)
	assert_float(_score("9", ["morning_meeting"], PLAYER, 1)).is_equal(14.0)


func test_straightened_lines_halves_straights() -> void:
	assert_float(_score("34567", ["straightened_lines"])).is_equal(_score("34567", []) / 2.0)
	assert_float(_score("99", ["straightened_lines"])).is_equal(_score("99", []))


func test_paperwork_halves_grain_that_cadres_added_too() -> void:
	# A pair of 9s: 10 base + 18 card Grain, plus Iron Rice Bowl's 30, then halved.
	assert_float(_score("99", ["iron_rice_bowl"])).is_equal(116.0)
	assert_float(_score("99", ["iron_rice_bowl", "paperwork"])).is_equal(58.0)


func test_straightened_lines_halves_a_capped_total() -> void:
	var capped: float = _score("3456789TJQ", ["iron_rice_bowl", "stakhanovite"])
	var both: Array[String] = ["iron_rice_bowl", "stakhanovite", "straightened_lines"]
	assert_float(_score("3456789TJQ", both)).is_equal(capped / 2.0)


func test_zeal_never_falls_below_one() -> void:
	# A Single has 1 Zeal; Ration Cut takes 1, and the floor keeps it scoring.
	assert_float(_score("9", ["ration_cut"])).is_equal(14.0)
