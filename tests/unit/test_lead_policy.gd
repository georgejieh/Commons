extends GdUnitTestSuite
## One scripted position per lead rule, in priority order.

## Enough cards that a rival is never about to go out.
const FAR: String = "456789TJQ"


func _assert_lead(seats: Array[String], expected: String, plays: Array[String] = []) -> void:
	assert_str(BotScript.text_of(BotScript.decide(seats, plays))).is_equal(expected)


func test_plays_the_whole_hand_when_legal() -> void:
	_assert_lead(["3334", FAR, FAR], "3334")


func test_a_forced_win_plays_controls_first() -> void:
	_assert_lead(["b33", FAR, FAR], "b")


func test_a_forced_win_keeps_the_beatable_group_for_last() -> void:
	_assert_lead(["sb3", FAR, FAR], "sb")


func test_no_low_single_into_an_opponent_on_one_card() -> void:
	_assert_lead(["38TT", "4", FAR], "TT")


func test_the_top_single_is_allowed_into_an_opponent_on_one_card() -> void:
	_assert_lead(["b4TT", "4", "5"], "b")


func test_only_singles_left_plays_the_highest() -> void:
	_assert_lead(["38", "4", FAR], "8")


func test_no_low_pair_into_an_opponent_on_two_cards() -> void:
	_assert_lead(["3389", "44", FAR], "8")


func test_the_top_pair_is_allowed_into_an_opponent_on_two_cards() -> void:
	_assert_lead(["2233", "44", FAR], "22")


func test_leads_the_smallest_single_to_a_teammate_on_one_card() -> void:
	var seats: Array[String] = ["39TJQKA", "458TT", "6"]
	_assert_lead(seats, "5", ["3", "4", "", ""])


func test_leads_the_smallest_pair_to_a_teammate_on_two_cards() -> void:
	var seats: Array[String] = ["39TJQKA", "455KK", "66"]
	_assert_lead(seats, "55", ["3", "4", "", ""])


func test_otherwise_leads_the_group_shedding_most_low_cards() -> void:
	_assert_lead(["3456799KK", FAR, FAR], "34567")


func test_prefers_the_weakest_of_equal_groups() -> void:
	_assert_lead(["468TQK", FAR, FAR], "4")


func test_never_uses_a_two_as_a_kicker() -> void:
	_assert_lead(["333277QQ", FAR, FAR], "333")


func test_never_breaks_a_bomb_for_a_kicker() -> void:
	var text: String = BotScript.text_of(BotScript.decide(["333777788", FAR, FAR]))
	assert_str(text).is_not_equal("3337")
