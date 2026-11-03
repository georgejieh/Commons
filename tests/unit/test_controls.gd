extends GdUnitTestSuite
## What counts as a control, from what a seat has not seen.

var _table: BotTable = BotTable.new(RuleSet.default_rules(), Ranks.identity_map())


func _view(seats: Array[String], plays: Array[String] = [], seat: int = 0) -> SeatView:
	var map: PackedByteArray = _table.rank_map
	var round_state: RoundState = RoundState.new(
		RoundScript.stacked_deal(seats, ""), 0, SeatRules.uniform(_table.rules, map)
	)
	for text: String in plays:
		if text.is_empty():
			round_state.apply(RoundAction.new(round_state.seat_to_act()))
		else:
			round_state.apply(RoundScript.play(round_state, text))
	return round_state.view_for(seat)


func _pattern(text: String) -> Pattern:
	return Classifier.classify(RankText.counts(text), _table.rules, _table.rank_map).pattern


func _controls(view: SeatView, group: String, largest: int = 17) -> Controls:
	var groups: Array[Pattern] = [_pattern(group)]
	return Controls.new(groups, UnseenCards.from_view(view), largest, _table)


func test_unseen_is_the_deck_less_own_cards_and_plays() -> void:
	var view: SeatView = _view(["334", "5", "6"], ["3"])
	var unseen: PackedByteArray = UnseenCards.from_view(view)
	assert_int(unseen[Ranks.THREE]).is_equal(2)
	assert_int(unseen[Ranks.FOUR]).is_equal(3)
	assert_int(unseen[Ranks.FIVE]).is_equal(4)
	assert_int(unseen[Ranks.BIG_JOKER]).is_equal(1)


func test_a_lone_two_with_both_jokers_unseen_is_no_control() -> void:
	var controls: Controls = _controls(_view(["2345", "6", "7"]), "2")
	assert_bool(controls.flags[0]).is_false()
	assert_bool(controls.rocket_possible).is_true()
	assert_int(controls.effective_hands).is_equal(1)


func test_a_big_joker_single_is_a_control() -> void:
	var controls: Controls = _controls(_view(["b345", "6", "7"]), "b")
	assert_bool(controls.flags[0]).is_true()
	assert_bool(controls.rocket_possible).is_false()
	assert_int(controls.effective_hands).is_equal(0)


func test_the_top_straight_is_a_control() -> void:
	var view: SeatView = _view(["TJQKA3", "4", "5"])
	assert_bool(_controls(view, "TJQKA").flags[0]).is_true()
	assert_bool(_controls(view, "789TJ").flags[0]).is_false()


func test_a_bomb_stops_being_possible_once_every_rank_is_broken() -> void:
	var live: Controls = _controls(_view(["3", "4", "5"]), "3")
	assert_bool(live.bomb_possible).is_true()
	var hand: String = "3456789TJQKA2"
	var broken: Controls = _controls(_view([hand, "3", "4"]), "2")
	assert_bool(broken.bomb_possible).is_false()


func test_the_last_bomb_rank_seen_makes_a_bomb_a_control() -> void:
	var view: SeatView = _view(["AAAA2222sb3", "4", "5"])
	assert_bool(_controls(view, "2222").flags[0]).is_true()
	assert_bool(_controls(view, "AAAA").flags[0]).is_true()
	var low_view: SeatView = _view(["4444", "5", "6"])
	assert_bool(_controls(low_view, "4444").flags[0]).is_false()


func test_an_answer_larger_than_any_hand_does_not_count() -> void:
	var view: SeatView = _view(["34567", "8", "9"])
	assert_bool(_controls(view, "34567", 17).flags[0]).is_false()
	assert_bool(_controls(view, "34567", 4).flags[0]).is_true()
