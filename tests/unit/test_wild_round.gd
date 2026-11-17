extends GdUnitTestSuite
## A round under wild ranks (ADR 0029): a play names its reading or takes the strongest,
## the table's history and unseen counts follow the cards really spent, and Night Shift
## asks whether any legal reading beats the table.

var _map: PackedByteArray = Ranks.identity_map()
var _sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)


func _round(seats: Array[String], rules: RuleSet = _sevens) -> RoundState:
	return RoundState.new(RoundScript.stacked_deal(seats, ""), 0, SeatRules.uniform(rules, _map))


func _ids(round_state: RoundState, seat: int, text: String) -> Array[int]:
	var ids: Array[int] = []
	var wanted: PackedByteArray = RankText.counts(text)
	for card: CardInstance in round_state.view_for(seat).own_cards:
		if wanted[card.base_rank()] > 0:
			wanted[card.base_rank()] -= 1
			ids.append(card.id())
	return ids


func test_cards_that_read_two_ways_list_both_strongest_first() -> void:
	var round_state: RoundState = _round(["99973", "44", "55"])
	var read: PlayReading = round_state.read_play(0, _ids(round_state, 0, "9997"))
	assert_int(read.reason).is_equal(RoundState.Reason.OK)
	assert_int(read.readings.size()).is_equal(2)
	assert_int(read.readings[0].type).is_equal(Pattern.Type.BOMB)
	assert_int(read.pattern.type).is_equal(Pattern.Type.BOMB)


func test_a_play_with_no_reading_takes_the_strongest() -> void:
	var round_state: RoundState = _round(["99973", "44", "55"])
	var action: RoundAction = RoundAction.new(0, _ids(round_state, 0, "9997"))
	assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
	assert_int(round_state.current_play().type).is_equal(Pattern.Type.BOMB)


func test_a_named_reading_is_played_as_named() -> void:
	var round_state: RoundState = _round(["99973", "44", "55"])
	var ids: Array[int] = _ids(round_state, 0, "9997")
	var action: RoundAction = RoundAction.new(0, ids)
	action.reading = round_state.read_play(0, ids).readings[1]
	assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
	assert_int(round_state.current_play().type).is_equal(Pattern.Type.TRIO_SINGLE)


func test_a_reading_the_cards_do_not_allow_is_refused() -> void:
	var round_state: RoundState = _round(["99973", "44", "55"])
	var action: RoundAction = RoundAction.new(0, _ids(round_state, 0, "9997"))
	action.reading = Readings.of(RankText.counts("99"), _sevens, _map)[0]
	assert_int(round_state.apply(action)).is_equal(RoundState.Reason.ILLEGAL_PLAY)
	assert_int(round_state.remaining()[0]).is_equal(5)


func test_history_and_unseen_cards_count_the_cards_really_spent() -> void:
	var round_state: RoundState = _round(["99973", "44", "55"])
	round_state.apply(RoundAction.new(0, _ids(round_state, 0, "9997")))
	var entry: PublicPlay = round_state.public_view().history[-1]
	assert_array(Array(entry.counts)).is_equal(Array(RankText.counts("9997")))
	assert_int(entry.pattern.counts()[Ranks.NINE]).is_equal(4)
	var unseen: PackedByteArray = UnseenCards.from_view(round_state.view_for(1))
	assert_int(unseen[Ranks.SEVEN]).is_equal(3)
	# The fourth nine is still unseen: the wild seven played as a nine is a seven.
	assert_int(unseen[Ranks.NINE]).is_equal(1)
	var played: Array[RoundEvent] = round_state.events().filter(
		func(event: RoundEvent) -> bool: return event.type == RoundEvent.Type.PLAYED
	)
	assert_str(played[-1].describe()).contains("spent=")


func test_a_soft_bomb_marks_the_trick_bombed() -> void:
	var round_state: RoundState = _round(["99973", "44", "55"])
	round_state.apply(RoundAction.new(0, _ids(round_state, 0, "9997")))
	assert_bool(round_state.current_play().stand_ins() > 0).is_true()
	assert_int(round_state.current_play().type).is_equal(Pattern.Type.BOMB)


func test_night_shift_counts_a_reading_with_a_wild_card() -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
	params.wild_ranks = [Ranks.SEVEN] as Array[int]
	params.must_answer_once = true
	var wild: RuleSet = RuleSet.new(params)
	var round_state: RoundState = _round(["KK3", "A7", "55"], wild)
	round_state.apply(RoundAction.new(0, _ids(round_state, 0, "KK")))
	assert_int(round_state.pass_reason()).is_equal(RoundState.Reason.MUST_PLAY)
	params.wild_ranks = [] as Array[int]
	var plain: RoundState = _round(["KK3", "A7", "55"], RuleSet.new(params))
	plain.apply(RoundAction.new(0, _ids(plain, 0, "KK")))
	assert_int(plain.pass_reason()).is_equal(RoundState.Reason.OK)


func test_a_bot_action_names_its_reading() -> void:
	var round_state: RoundState = _round(["99973", "44", "55"])
	for move: Pattern in round_state.legal_moves():
		if move.type == Pattern.Type.TRIO_SINGLE and move.main_rank == Ranks.NINE:
			var action: RoundAction = round_state.action_for(move)
			assert_object(action.reading).is_not_null()
			assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
			assert_int(round_state.current_play().type).is_equal(Pattern.Type.TRIO_SINGLE)
			return
	fail("no trio of nines with a single")
