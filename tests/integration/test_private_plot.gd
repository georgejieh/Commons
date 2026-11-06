extends GdUnitTestSuite
## P4.8 and ADR 0014: plot swaps happen after the kitty, a deck card that enters the plot
## is reissued under a new plot ID, no card is created or lost across rounds, and a
## fifth copy of a rank reads by the RuleSet's five_plus_is_bomb.

const SEEDS: Array[int] = [4801, 4802, 4803]
const PLOT_CARDS: int = 3
const DECK_SIZE: int = 54


func _state(seed_value: int) -> RunState:
	var state: RunState = RunState.new(seed_value)
	for index: int in PLOT_CARDS:
		state.inventory.plot.append(
			CardInstance.new(
				CardInstance.FIRST_PLOT_ID + index, Ranks.NINE, index, CardInstance.Origin.PLOT
			)
		)
	return state


## Every card in every hand, on the table this round and in the plot, by ID: none twice,
## and the deck's 54 between hands and the table.
func _check_round(loop: RunLoop) -> void:
	var seen: Dictionary[int, bool] = {}
	var in_hands: int = 0
	for card_id: int in _played_this_round(loop):
		assert_bool(seen.has(card_id)).override_failure_message("played %d" % card_id).is_false()
		seen[card_id] = true
		in_hands += 1
	for seat: int in Seats.COUNT:
		for card: CardInstance in loop.round_state().view_for(seat).own_cards:
			(
				assert_bool(seen.has(card.id()))
				. override_failure_message("id %d" % card.id())
				. is_false()
			)
			seen[card.id()] = true
			in_hands += 1
	for card: CardInstance in loop.state.inventory.plot:
		assert_bool(seen.has(card.id())).override_failure_message("plot %d" % card.id()).is_false()
		seen[card.id()] = true
	assert_int(in_hands).is_equal(DECK_SIZE)
	assert_int(loop.state.inventory.plot.size()).is_equal(PLOT_CARDS)


func test_swaps_across_rounds_never_create_lose_or_repeat_a_card() -> void:
	var swaps: int = 0
	for seed_value: int in SEEDS:
		var loop: RunLoop = RunLoop.new(_state(seed_value), RunScript.bots())
		var script: RunScript = RunScript.new()
		loop.start_set()
		for set_count: int in 2:
			while loop.awaiting() != RunLoop.Awaiting.SET_OVER:
				var swapping: bool = loop.awaiting() == RunLoop.Awaiting.PLAYER_SWAP
				if swapping:
					_check_round(loop)
				if not script.act(loop):
					break
				if swapping:
					_check_round(loop)
					swaps += 1
			loop.next_set()
	assert_int(swaps).is_greater(10)


func test_a_deck_card_entering_the_plot_gets_a_new_plot_id() -> void:
	var state: RunState = _state(SEEDS[0])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
		script.act(loop)
	var given: CardInstance = loop.player_cards()[0]
	var taken: int = state.inventory.plot[0].id()
	var before: int = state.next_plot_id
	assert_int(loop.player_swap([given.id()], [taken])).is_equal(RunLoop.Reason.OK)
	var stored: CardInstance = state.inventory.plot[0]
	assert_int(stored.id()).is_greater_equal(CardInstance.FIRST_PLOT_ID + PLOT_CARDS)
	assert_int(stored.origin()).is_equal(CardInstance.Origin.PLOT)
	assert_int(stored.base_rank()).is_equal(given.base_rank())
	assert_int(stored.suit()).is_equal(given.suit())
	assert_int(state.next_plot_id).is_greater(before)
	(
		assert_bool(loop.player_cards().any(func(c: CardInstance) -> bool: return c.id() == taken))
		. is_true()
	)


func test_a_landlord_may_swap_a_kitty_card() -> void:
	for seed_value: int in range(4810, 4840):
		var state: RunState = _state(seed_value)
		var loop: RunLoop = RunLoop.new(state, RunScript.bots())
		var script: RunScript = RunScript.new()
		loop.start_set()
		while loop.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
			if not script.act(loop):
				break
		if state.landlord_seat != RunLoop.PLAYER:
			continue
		var kitty: Array[int] = []
		for event: RunEvent in loop.events():
			if event.round_event != null and event.round_event.type == RoundEvent.Type.KITTY_TAKEN:
				kitty = event.round_event.card_ids
		var plot_id: int = state.inventory.plot[0].id()
		assert_int(loop.player_swap([kitty[0]], [plot_id])).is_equal(RunLoop.Reason.OK)
		(
			assert_bool(
				state.inventory.plot.any(func(c: CardInstance) -> bool: return c.id() == kitty[0])
			)
			. is_false()
		)
		return
	fail("No seed made the player landlord")


func test_a_fifth_copy_reads_by_the_ruleset() -> void:
	var deal: DealResult = RoundScript.stacked_deal(["99993", "4444", "5555"], "")
	var rules: SeatRules = SeatRules.new(ModifierStack.new())
	var round_state: RoundState = RoundState.new(deal, 0, rules)
	var plot_nine: CardInstance = CardInstance.new(
		CardInstance.FIRST_PLOT_ID, Ranks.NINE, 0, CardInstance.Origin.PLOT
	)
	var three: int = -1
	for card: CardInstance in round_state.view_for(0).own_cards:
		if card.base_rank() == Ranks.THREE:
			three = card.id()
	round_state.exchange(0, [three], [plot_nine])
	var nines: PackedByteArray = PackedByteArray()
	nines.resize(Ranks.COUNT)
	nines[Ranks.NINE] = 5
	assert_int(round_state.view_for(0).own_counts[Ranks.NINE]).is_equal(5)
	for allowed: bool in [true, false]:
		var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
		params.five_plus_is_bomb = allowed
		var reading: Classification = Classifier.classify(
			nines, RuleSet.new(params), Ranks.identity_map()
		)
		assert_bool(reading.is_valid()).override_failure_message(str(allowed)).is_equal(allowed)
		if allowed:
			assert_int(reading.pattern.type).is_equal(Pattern.Type.BOMB)


func _played_this_round(loop: RunLoop) -> Array[int]:
	var played: Array[int] = []
	for event: RunEvent in loop.events():
		var round_event: RoundEvent = event.round_event
		if round_event == null:
			continue
		if round_event.type == RoundEvent.Type.ROUND_STARTED:
			played.clear()
		elif round_event.type == RoundEvent.Type.PLAYED:
			played.append_array(round_event.card_ids)
	return played
