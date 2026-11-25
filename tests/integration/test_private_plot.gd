extends GdUnitTestSuite
## ADR 0038: a plot swap lasts one round. Swaps happen after the kitty, a plot card comes
## into the hand under its own plot ID and is back in the plot when the round is over,
## played or not; the hand card it replaced sits the round out and is dealt again next
## round. The plot is never changed by a swap, no card is created, lost or repeated, no
## seat acts while the swap waits, and a plot an older rule filled still loads and swaps.
## A fifth copy of a rank reads by the RuleSet's five_plus_is_bomb.

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


## The plot as text, every card with its marks, to compare before and after.
func _plot_text(state: RunState) -> String:
	var lines: PackedStringArray = []
	for card: CardInstance in state.inventory.plot:
		lines.append(JSON.stringify(card.to_dict()))
	return "\n".join(lines)


## Every card in every hand and on the table this round, by ID: none twice, 54 in all.
## Each plot ID among them names a card the plot still holds; each deck ID not among them
## was set aside by this round's swap.
func _check_round(loop: RunLoop, set_aside: Array[int]) -> void:
	var seen: Dictionary[int, bool] = {}
	var in_play: Array[int] = _played_this_round(loop)
	for seat: int in Seats.COUNT:
		for card: CardInstance in loop.round_state().view_for(seat).own_cards:
			in_play.append(card.id())
	for card_id: int in in_play:
		assert_bool(seen.has(card_id)).override_failure_message("twice %d" % card_id).is_false()
		seen[card_id] = true
	assert_int(in_play.size()).is_equal(DECK_SIZE)
	var plot_ids: Array[int] = []
	for card: CardInstance in loop.state.inventory.plot:
		plot_ids.append(card.id())
	var deck_in_play: int = 0
	for card_id: int in in_play:
		if card_id >= CardInstance.FIRST_PLOT_ID:
			assert_array(plot_ids).contains([card_id])
		else:
			deck_in_play += 1
	assert_int(deck_in_play + set_aside.size()).is_equal(DECK_SIZE)
	for card_id: int in set_aside:
		assert_bool(seen.has(card_id)).override_failure_message("aside %d" % card_id).is_false()


func test_swaps_across_rounds_never_change_the_plot_or_lose_a_card() -> void:
	var swaps: int = 0
	for seed_value: int in SEEDS:
		var state: RunState = _state(seed_value)
		var plot_before: String = _plot_text(state)
		var next_id: int = state.next_plot_id
		var loop: RunLoop = RunLoop.new(state, RunScript.bots())
		var script: RunScript = RunScript.new()
		loop.start_set()
		for set_count: int in 2:
			var set_aside: Array[int] = []
			var round_at: int = -1
			var seized: int = 0
			while loop.awaiting() != RunLoop.Awaiting.SET_OVER:
				# Plot Seized destroys a plot card by its own rule, never a swap.
				if _seized(loop) != seized:
					seized = _seized(loop)
					plot_before = _plot_text(state)
				if loop.round_state() != null and state.round_index != round_at:
					round_at = state.round_index
					set_aside.clear()
				var swapping: bool = loop.awaiting() == RunLoop.Awaiting.PLAYER_SWAP
				if swapping:
					_check_round(loop, set_aside)
					var held: Array[int] = _ids(loop.player_cards())
					if not script.act(loop):
						break
					for card_id: int in held:
						if not _ids(loop.player_cards()).has(card_id):
							set_aside.append(card_id)
					assert_int(set_aside.size()).is_equal(1)
					swaps += 1
				elif loop.round_state() != null:
					_check_round(loop, set_aside)
					if not script.act(loop):
						break
				elif not script.act(loop):
					break
				assert_str(_plot_text(state)).is_equal(plot_before)
			loop.next_set()
		assert_int(state.next_plot_id).is_equal(next_id)
	assert_int(swaps).is_greater(10)


func test_a_swap_brings_the_plot_card_in_and_leaves_the_plot_as_it_was() -> void:
	var state: RunState = _state(SEEDS[0])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
		script.act(loop)
	var given: CardInstance = loop.player_cards()[0]
	var taken: int = state.inventory.plot[1].id()
	var plot_before: String = _plot_text(state)
	var before: int = state.next_plot_id
	assert_int(loop.player_swap([given.id()], [taken])).is_equal(RunLoop.Reason.OK)
	assert_str(_plot_text(state)).is_equal(plot_before)
	assert_int(state.next_plot_id).is_equal(before)
	var hand: Array[int] = _ids(loop.player_cards())
	assert_array(hand).contains([taken])
	assert_array(hand).not_contains([given.id()])
	# The hand holds a copy: what the round does to its card never reaches the plot.
	for card: CardInstance in loop.round_state().view_for(RunLoop.PLAYER).own_cards:
		assert_bool(state.inventory.plot.has(card)).is_false()


## Played or not, the plot card is back in the plot after the round, and the card it
## replaced is dealt again with the next round's fresh deck.
func test_the_plot_card_comes_back_and_the_set_aside_card_is_dealt_again() -> void:
	for seed_value: int in SEEDS:
		var state: RunState = _state(seed_value)
		var plot_before: String = _plot_text(state)
		var loop: RunLoop = RunLoop.new(state, RunScript.bots())
		var script: RunScript = RunScript.new()
		loop.start_set()
		while loop.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
			script.act(loop)
		var given: int = loop.player_cards()[0].id()
		var taken: int = state.inventory.plot[0].id()
		assert_int(loop.player_swap([given], [taken])).is_equal(RunLoop.Reason.OK)
		var round_index: int = state.round_index
		while state.round_index == round_index and loop.awaiting() != RunLoop.Awaiting.SET_OVER:
			script.act(loop)
		if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
			continue
		assert_str(_plot_text(state)).is_equal(plot_before)
		while loop.round_state() == null:
			script.act(loop)
		var dealt: Array[int] = _played_this_round(loop)
		for seat: int in Seats.COUNT:
			dealt.append_array(_ids(loop.round_state().view_for(seat).own_cards))
		assert_array(dealt).contains([given])
		assert_array(dealt).not_contains([taken])
		return
	fail("No seed reached a second round")


func test_a_landlord_may_swap_a_kitty_card_which_then_sits_the_round_out() -> void:
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
		var rank: int = Deck.new().rank_of(kitty[0])
		var shown: int = loop.round_state().view_for(1).public.kitty_counts[rank]
		assert_int(loop.player_swap([kitty[0]], [plot_id])).is_equal(RunLoop.Reason.OK)
		assert_array(_ids(state.inventory.plot)).not_contains([kitty[0]])
		assert_array(_ids(loop.player_cards())).not_contains([kitty[0]])
		# The table no longer counts the set-aside card among the landlord's kitty.
		var after: int = loop.round_state().view_for(1).public.kitty_counts[rank]
		assert_int(after).is_equal(shown - 1)
		return
	fail("No seed made the player landlord")


## The risen villager's boss Quota (ADR 0018's even Years) starts with the villager as
## landlord and no bidding. The villager opens the round, yet nothing is played until the
## player's swap is answered, and then the villager plays first.
func test_no_seat_plays_while_the_swap_waits_on_a_villager_landlord() -> void:
	var state: RunState = _state(SEEDS[2])
	state.year = 2
	state.set_index = 2
	state.set_type = RunState.SetType.BOSS
	state.risen.assign(["zhao"])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.PLAYER_SWAP)
	assert_int(state.landlord_seat).is_equal(1)
	for event: RunEvent in loop.events():
		assert_int(event.type).is_not_equal(RunEvent.Type.BID)
		if event.round_event != null:
			assert_int(event.round_event.type).is_not_equal(RoundEvent.Type.PLAYED)
			assert_int(event.round_event.type).is_not_equal(RoundEvent.Type.PASSED)
	# Nothing the loop is asked to do moves a seat while the swap waits.
	loop.advance()
	assert_int(loop.round_state().events().size()).is_equal(_round_events(loop))
	var none: Array[int] = []
	assert_int(loop.player_swap(none, none)).is_equal(RunLoop.Reason.OK)
	var first: RoundEvent = null
	for event: RoundEvent in loop.round_state().events():
		if event.type == RoundEvent.Type.PLAYED or event.type == RoundEvent.Type.PASSED:
			first = event
			break
	assert_object(first).is_not_null()
	assert_int(first.seat).is_equal(1)


## A save made under ADR 0014 holds deck cards reissued into the plot: plot cards with
## IDs from the counter. It loads, and those cards swap and come back like any other.
func test_a_plot_the_old_rule_reissued_into_still_loads_and_swaps() -> void:
	var state: RunState = RunState.new(SEEDS[1])
	var reissued: CardInstance = CardInstance.new(
		CardInstance.FIRST_PLOT_ID + 7, Ranks.FOUR, 2, CardInstance.Origin.PLOT
	)
	CardMarks.enhance(state, reissued, CardInstance.MODEL)
	state.inventory.plot.append(reissued)
	state.next_plot_id = CardInstance.FIRST_PLOT_ID + 8
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var loaded: RunState = RunState.from_dict(data)
	var plot_before: String = _plot_text(loaded)
	var loop: RunLoop = RunLoop.new(loaded, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
		script.act(loop)
	var given: int = loop.player_cards()[0].id()
	assert_int(loop.player_swap([given], [reissued.id()])).is_equal(RunLoop.Reason.OK)
	assert_str(_plot_text(loaded)).is_equal(plot_before)
	assert_int(loaded.take_plot_id()).is_equal(CardInstance.FIRST_PLOT_ID + 8)


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


func _ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	return ids


func _seized(loop: RunLoop) -> int:
	var count: int = 0
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.PLOT_SEIZED:
			count += 1
	return count


func _round_events(loop: RunLoop) -> int:
	var count: int = 0
	for event: RunEvent in loop.events():
		if event.round_event != null:
			count += 1
	return count


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
