extends GdUnitTestSuite
## Turn order, validation, trick flow, spring detection and the public boundary.

const SEED: int = 1802
const RANDOM_GAMES: int = 10000
const TOTAL_CARDS: int = 54
## Every three actions play at least one card, so a game can't need more.
const MAX_ACTIONS: int = 162

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _round(seats: Array[String], kitty: String = "") -> RoundState:
	return RoundState.new(
		RoundScript.stacked_deal(seats, kitty), 0, SeatRules.uniform(_rules, _map)
	)


func _apply(round_state: RoundState, text: String) -> void:
	var reason: RoundState.Reason = round_state.apply(RoundScript.play(round_state, text))
	assert_int(reason).is_equal(RoundState.Reason.OK)


func _pass(round_state: RoundState) -> void:
	var action: RoundAction = RoundAction.new(round_state.seat_to_act())
	assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)


func _last_finish(round_state: RoundState) -> int:
	var last: RoundEvent = round_state.events()[-1]
	assert_int(last.type).is_equal(RoundEvent.Type.ROUND_ENDED)
	return last.value


func test_the_landlord_takes_the_kitty_and_leads() -> void:
	var round_state: RoundState = _round(["33", "44", "55"], "678")
	assert_int(round_state.seat_to_act()).is_equal(0)
	assert_array(Array(round_state.remaining())).is_equal([5, 2, 2])
	(
		assert_array(round_state.events().map(func(e: RoundEvent) -> int: return e.type))
		. is_equal([RoundEvent.Type.ROUND_STARTED, RoundEvent.Type.KITTY_TAKEN])
	)


func test_two_passes_return_the_lead_to_the_last_player() -> void:
	var round_state: RoundState = _round(["345", "6", "7"])
	_apply(round_state, "3")
	_pass(round_state)
	_pass(round_state)
	assert_int(round_state.seat_to_act()).is_equal(0)
	assert_object(round_state.current_play()).is_null()


func test_a_passer_may_play_later_in_the_trick() -> void:
	var round_state: RoundState = _round(["35", "49", "7J"])
	_apply(round_state, "3")
	_pass(round_state)
	_apply(round_state, "7")
	_pass(round_state)
	_apply(round_state, "9")
	assert_int(round_state.seat_to_act()).is_equal(2)


func test_a_seat_cannot_pass_on_the_lead() -> void:
	var round_state: RoundState = _round(["3", "4", "5"])
	var reason: RoundState.Reason = round_state.apply(RoundAction.new(0))
	assert_int(reason).is_equal(RoundState.Reason.CANNOT_PASS_ON_LEAD)


func test_rejected_actions_change_nothing() -> void:
	var round_state: RoundState = _round(["345", "6", "7"])
	var before: int = round_state.events().size()
	assert_int(round_state.apply(RoundAction.new(1, [1]))).is_equal(RoundState.Reason.OUT_OF_TURN)
	assert_int(round_state.apply(RoundAction.new(0, [99]))).is_equal(RoundState.Reason.UNKNOWN_CARD)
	assert_int(round_state.apply(RoundAction.new(0, [0, 0]))).is_equal(
		RoundState.Reason.REPEATED_CARD
	)
	assert_int(round_state.apply(RoundAction.new(0, [0, 4]))).is_equal(
		RoundState.Reason.ILLEGAL_PLAY
	)
	assert_int(round_state.events().size()).is_equal(before)
	assert_array(Array(round_state.remaining())).is_equal([3, 1, 1])


func test_a_play_that_does_not_beat_is_rejected() -> void:
	var round_state: RoundState = _round(["58", "3", "7"])
	_apply(round_state, "5")
	var action: RoundAction = RoundScript.play(round_state, "3")
	assert_int(round_state.apply(action)).is_equal(RoundState.Reason.DOES_NOT_BEAT)
	assert_int(round_state.seat_to_act()).is_equal(1)


func test_the_round_ends_when_a_hand_is_empty() -> void:
	var round_state: RoundState = _round(["3", "4", "5"])
	_apply(round_state, "3")
	assert_bool(round_state.is_over()).is_true()
	assert_int(round_state.winner()).is_equal(0)
	assert_int(round_state.seat_to_act()).is_equal(Seats.NONE)
	assert_int(round_state.apply(RoundAction.new(0))).is_equal(RoundState.Reason.ROUND_OVER)


func test_landlord_going_out_with_no_peasant_play_is_a_spring() -> void:
	var round_state: RoundState = _round(["39", "4", "5"])
	_apply(round_state, "3")
	_pass(round_state)
	_pass(round_state)
	_apply(round_state, "9")
	assert_int(_last_finish(round_state)).is_equal(RoundEvent.Finish.SPRING)


func test_a_peasant_play_stops_a_spring() -> void:
	var round_state: RoundState = _round(["3A", "46", "59"])
	_apply(round_state, "3")
	_apply(round_state, "4")
	_pass(round_state)
	_apply(round_state, "A")
	assert_int(_last_finish(round_state)).is_equal(RoundEvent.Finish.NORMAL)


func test_landlord_stopped_after_the_opening_lead_is_an_anti_spring() -> void:
	var round_state: RoundState = _round(["38", "4", "5"])
	_apply(round_state, "3")
	_apply(round_state, "4")
	assert_int(_last_finish(round_state)).is_equal(RoundEvent.Finish.ANTI_SPRING)


func test_a_second_landlord_play_stops_an_anti_spring() -> void:
	var round_state: RoundState = _round(["3589", "47", "6J"])
	_apply(round_state, "3")
	_apply(round_state, "4")
	_pass(round_state)
	_apply(round_state, "5")
	_apply(round_state, "7")
	assert_int(_last_finish(round_state)).is_equal(RoundEvent.Finish.NORMAL)


func test_anti_spring_is_detected_even_when_it_does_not_double() -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	params.anti_spring_doubles = false
	var rules: RuleSet = RuleSet.new(params)
	var deal: DealResult = RoundScript.stacked_deal(["38", "4", "5"], "")
	var round_state: RoundState = RoundState.new(deal, 0, SeatRules.uniform(rules, _map))
	_apply(round_state, "3")
	_apply(round_state, "4")
	assert_int(_last_finish(round_state)).is_equal(RoundEvent.Finish.ANTI_SPRING)


## Hands listed from the landlord round the table, for a landlord in the given seat.
func _round_for_landlord(landlord: int, hands: Array[String]) -> RoundState:
	var seats: Array[String] = ["", "", ""]
	var seat: int = landlord
	for text: String in hands:
		seats[seat] = text
		seat = Seats.next(seat)
	return RoundState.new(
		RoundScript.stacked_deal(seats, ""), landlord, SeatRules.uniform(_rules, _map)
	)


func test_finishes_hold_for_a_landlord_in_every_seat() -> void:
	for landlord: int in Seats.COUNT:
		var spring: RoundState = _round_for_landlord(landlord, ["39", "4", "5"])
		_apply(spring, "3")
		_pass(spring)
		_pass(spring)
		_apply(spring, "9")
		assert_int(_last_finish(spring)).is_equal(RoundEvent.Finish.SPRING)
		assert_bool(spring.landlord_won()).is_true()

		var anti_spring: RoundState = _round_for_landlord(landlord, ["38", "4", "5"])
		_apply(anti_spring, "3")
		_apply(anti_spring, "4")
		assert_int(_last_finish(anti_spring)).is_equal(RoundEvent.Finish.ANTI_SPRING)
		assert_bool(anti_spring.landlord_won()).is_false()

		var normal: RoundState = _round_for_landlord(landlord, ["3589", "47", "6J"])
		_apply(normal, "3")
		_apply(normal, "4")
		_pass(normal)
		_apply(normal, "5")
		_apply(normal, "7")
		assert_int(_last_finish(normal)).is_equal(RoundEvent.Finish.NORMAL)


func test_the_last_play_wins_its_trick_before_the_round_ends() -> void:
	var round_state: RoundState = _round(["3", "4", "5"])
	_apply(round_state, "3")
	var events: Array[RoundEvent] = round_state.events()
	assert_int(events[-2].type).is_equal(RoundEvent.Type.TRICK_WON)
	assert_int(events[-2].seat).is_equal(0)


func test_a_deal_can_not_reach_the_round_afterwards() -> void:
	var deal: DealResult = RoundScript.stacked_deal(["33", "44", "55"], "6")
	var round_state: RoundState = RoundState.new(deal, 0, SeatRules.uniform(_rules, _map))
	deal.hands[1].remove(deal.hands[1].cards()[0].id())
	deal.kitty.clear()
	assert_array(Array(round_state.remaining())).is_equal([3, 2, 2])


func test_a_played_event_carries_copies_of_the_cards() -> void:
	var deal: DealResult = RoundScript.stacked_deal(["34567", "8", "9"], "")
	var card: CardInstance = deal.hands[0].cards()[0]
	CardModifiers.enhance(card, "gold")
	var round_state: RoundState = RoundState.new(deal, 0, SeatRules.uniform(_rules, _map))
	_apply(round_state, "3")
	var event: RoundEvent = round_state.events()[-1]
	assert_int(event.cards.size()).is_equal(1)
	assert_str(event.cards[0].enhancement_id()).is_equal("gold")
	CardModifiers.enhance(card, "silver")
	assert_str(event.cards[0].enhancement_id()).is_equal("gold")


func test_every_applied_action_emits_an_event() -> void:
	var round_state: RoundState = _round(["34567", "8", "9"])
	var before: int = round_state.events().size()
	_apply(round_state, "3")
	assert_int(round_state.events().size()).is_equal(before + 1)
	_pass(round_state)
	assert_int(round_state.events().size()).is_equal(before + 2)


func test_seats_get_their_turn_in_order() -> void:
	assert_int(Seats.next(0)).is_equal(1)
	assert_int(Seats.next(1)).is_equal(2)
	assert_int(Seats.next(2)).is_equal(0)


## Walks every object a bot can reach from its view. No type on the walk may lead to a
## Hand or a round, and no card outside its own hand may appear.
func test_random_legal_games_terminate_with_every_card_accounted_for() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	for game: int in RANDOM_GAMES:
		var cards: Array[CardInstance] = []
		for deck_id: int in Deck.generate():
			cards.append(CardInstance.from_deck_id(deck_id))
		var deal: DealResult = Dealer.deal(cards, stream)
		var round_state: RoundState = RoundState.new(
			deal, game % Seats.COUNT, SeatRules.uniform(_rules, _map)
		)
		var seen: Dictionary[int, bool] = _play_randomly(round_state, stream)
		assert_bool(round_state.is_over()).is_true()
		assert_int(round_state.remaining()[round_state.winner()]).is_equal(0)
		for seat: int in Seats.COUNT:
			for card: CardInstance in round_state.view_for(seat).own_cards:
				assert_bool(seen.has(card.id())).is_false()
				seen[card.id()] = true
		for deck_id: int in Deck.generate():
			assert_bool(seen.has(deck_id)).is_true()
		assert_int(seen.size()).is_equal(TOTAL_CARDS)


func _play_randomly(round_state: RoundState, stream: RandomStream) -> Dictionary[int, bool]:
	var played: Dictionary[int, bool] = {}
	var actions: int = 0
	while not round_state.is_over() and actions < MAX_ACTIONS:
		actions += 1
		var moves: Array[Pattern] = round_state.legal_moves()
		var pick: int = stream.next_int(0, moves.size())
		if pick == moves.size() and round_state.current_play() == null:
			pick = 0
		var action: RoundAction = RoundAction.new(round_state.seat_to_act())
		if pick < moves.size():
			action = round_state.action_for(moves[pick])
		var reason: RoundState.Reason = round_state.apply(action)
		if reason != RoundState.Reason.OK:
			assert_int(reason).is_equal(RoundState.Reason.OK)
			break
		for card_id: int in action.card_ids:
			assert_bool(played.has(card_id)).is_false()
			played[card_id] = true
	return played
