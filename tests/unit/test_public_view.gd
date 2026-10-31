extends GdUnitTestSuite
## What a seat can see, and that nothing it holds leads back into the round.

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _round(seats: Array[String], kitty: String = "") -> RoundState:
	return RoundState.new(RoundScript.stacked_deal(seats, kitty), 0, _rules, _map)


func _apply(round_state: RoundState, text: String) -> void:
	var reason: RoundState.Reason = round_state.apply(RoundScript.play(round_state, text))
	assert_int(reason).is_equal(RoundState.Reason.OK)


func _pass(round_state: RoundState) -> void:
	var action: RoundAction = RoundAction.new(round_state.seat_to_act())
	assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)


func test_changing_a_view_can_not_change_the_round() -> void:
	var round_state: RoundState = _round(["9J", "45", "78"])
	_apply(round_state, "9")
	var view: SeatView = round_state.view_for(1)
	view.public.current_play.key &= ~0xFF
	view.public.history[0].counts[Ranks.NINE] = 0
	view.public.history[0].pattern.main_rank = Ranks.THREE
	view.own_cards[0].set_enhancement("gold")
	round_state.current_play().key = 0
	var action: RoundAction = RoundScript.play(round_state, "4")
	assert_int(round_state.apply(action)).is_equal(RoundState.Reason.DOES_NOT_BEAT)
	var fresh: SeatView = round_state.view_for(1)
	assert_int(fresh.public.history[0].counts[Ranks.NINE]).is_equal(1)
	assert_int(fresh.public.history[0].pattern.main_rank).is_equal(Ranks.NINE)
	assert_str(fresh.own_cards[0].enhancement_id()).is_equal(CardInstance.NO_ID)


func test_the_view_announces_at_two_and_one_cards() -> void:
	var round_state: RoundState = _round(["3456", "8", "9"])
	_apply(round_state, "3")
	_pass(round_state)
	_pass(round_state)
	assert_int(round_state.public_view().announced[0]).is_equal(0)
	_apply(round_state, "4")
	_pass(round_state)
	_pass(round_state)
	assert_int(round_state.public_view().announced[0]).is_equal(2)
	_apply(round_state, "5")
	assert_int(round_state.public_view().announced[0]).is_equal(1)
	assert_bool(_announcements(round_state) == [2, 1]).is_true()


func _announcements(round_state: RoundState) -> Array[int]:
	var values: Array[int] = []
	for event: RoundEvent in round_state.events():
		if event.type == RoundEvent.Type.ANNOUNCED:
			values.append(event.value)
	return values


func test_the_view_shows_counts_history_and_the_kitty() -> void:
	var round_state: RoundState = _round(["33", "44", "55"], "678")
	_apply(round_state, "33")
	_pass(round_state)
	var view: PublicView = round_state.public_view()
	assert_array(Array(view.remaining)).is_equal([3, 2, 2])
	assert_int(view.history.size()).is_equal(2)
	assert_int(view.history[0].counts[Ranks.THREE]).is_equal(2)
	assert_int(view.history[1].pattern.type).is_equal(Pattern.Type.PASS)
	assert_int(view.kitty_counts[Ranks.SIX]).is_equal(1)
	assert_int(view.current_play.type).is_equal(Pattern.Type.PAIR)


func test_a_view_is_a_snapshot() -> void:
	var round_state: RoundState = _round(["33", "44", "55"])
	var view: PublicView = round_state.public_view()
	view.history.append(PublicPlay.new(0, Pattern.pass_play(), PackedByteArray()))
	view.remaining[1] = 0
	assert_int(round_state.public_view().history.size()).is_equal(0)
	assert_array(Array(round_state.remaining())).is_equal([2, 2, 2])


func test_a_seat_view_holds_only_its_own_hand() -> void:
	var round_state: RoundState = _round(["33", "44", "55"])
	var view: SeatView = round_state.view_for(1)
	assert_int(view.own_counts[Ranks.FOUR]).is_equal(2)
	assert_int(view.own_counts[Ranks.THREE]).is_equal(0)
	assert_int(view.own_cards.size()).is_equal(2)
	view.own_cards.clear()
	view.own_counts[Ranks.FOUR] = 0
	assert_int(round_state.view_for(1).own_cards.size()).is_equal(2)
	assert_int(round_state.view_for(1).own_counts[Ranks.FOUR]).is_equal(2)


func test_a_seat_view_has_no_path_to_other_hands() -> void:
	var round_state: RoundState = _round(["33", "44", "55"], "678")
	_apply(round_state, "33")
	var view: SeatView = round_state.view_for(1)
	var visited: Array[Object] = []
	_walk(view, visited)
	var allowed: Array[String] = ["SeatView", "PublicView", "PublicPlay", "Pattern", "CardInstance"]
	for reached: Object in visited:
		var script: Script = reached.get_script()
		assert_array(allowed).contains([script.get_global_name()])
		if reached is CardInstance:
			var card: CardInstance = reached
			assert_int(card.base_rank()).is_equal(Ranks.FOUR)


func _walk(value: Variant, visited: Array[Object]) -> void:
	assert_bool(value is Callable).is_false()
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			_walk(item, visited)
	elif value is Dictionary:
		var entries: Dictionary = value
		_walk(entries.keys(), visited)
		_walk(entries.values(), visited)
	elif value is Object:
		var reached: Object = value
		if visited.has(reached):
			return
		visited.append(reached)
		for property: Dictionary in reached.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				_walk(reached.get(property["name"]), visited)
