extends GdUnitTestSuite
## Scripted positions for following a play.

const FAR: String = "456789TJQKA"


func _assert_follow(seats: Array[String], plays: Array[String], expected: String) -> void:
	assert_str(BotScript.text_of(BotScript.decide(seats, plays))).is_equal(expected)


func test_never_bombs_a_teammate() -> void:
	_assert_follow(["3" + FAR, "K6677", "9999KK"], ["3", "K"], "")
	_assert_follow(["3" + FAR, "T" + FAR, "9999K"], ["3", "T"], "")


func test_never_bombs_a_lone_nine() -> void:
	_assert_follow(["9" + FAR, "33335678", FAR], ["9"], "")


func test_blocks_an_opponent_on_one_card() -> void:
	_assert_follow(["98", "4QK2", "567"], ["9"], "2")


func test_bombs_to_stop_an_opponent_going_out() -> void:
	_assert_follow(["98", "3333", "567"], ["9"], "3333")


func test_passes_on_the_teammates_winning_card() -> void:
	_assert_follow(["3" + FAR, "A" + FAR, "2KK"], ["3", "A"], "")


func test_goes_out_over_a_teammate() -> void:
	_assert_follow(["3" + FAR, "6" + FAR, "K"], ["3", "6"], "K")


func test_bombs_a_runaway_landlord() -> void:
	_assert_follow(["K34578", "66669TJQ", FAR], ["K"], "6666")


func test_keeps_the_bomb_while_the_landlord_is_far_from_out() -> void:
	_assert_follow(["K345789", "66669TJQ", FAR], ["K"], "")


func test_saves_a_two_on_a_peasants_low_single() -> void:
	_assert_follow(["342", "6" + FAR, FAR], ["3", "6", ""], "")


func test_sheds_the_lowest_card_that_beats_the_table() -> void:
	_assert_follow(["39" + FAR, "48T", "QKA"], ["3"], "4")
