extends GdUnitTestSuite
## The hand debuffs of ADR 0023 at the table, through RunLoop: Levy, Night Shift, Shared
## Kitchen, Confiscation, Glass Walls, Redistribution and Plot Seized. Each is put in
## force from round 2 (index 1) by hand, so it applies in every later round of the Set,
## and each test proves it acts in each of those rounds and in no round before.

const IN_FORCE: Array[int] = [1, 2, 3]


func _held(cadres: Array[String], plot: int = 0, consumables: Array[String] = []) -> Callable:
	return func(state: RunState) -> void:
		state.inventory.cadres.assign(cadres)
		state.inventory.consumables.assign(consumables)
		for index: int in plot:
			state.inventory.plot.append(
				CardInstance.new(
					CardInstance.FIRST_PLOT_ID + index,
					Ranks.KING,
					index % 4,
					CardInstance.Origin.PLOT
				)
			)


static func _ids(text: String) -> Array[int]:
	var ids: Array[int] = []
	for part: String in text.split(",", false):
		ids.append(part.to_int())
	return ids


static func _hand_ids(loop: RunLoop, seat: int) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in loop.round_state().view_for(seat).own_cards:
		ids.append(card.id())
	return ids


## Every card a seat played this round.
static func _played(loop: RunLoop, seat: int) -> Array[int]:
	var ids: Array[int] = []
	for event: RoundEvent in loop.round_state().events():
		if event.type == RoundEvent.Type.PLAYED and event.seat == seat:
			ids.append_array(event.card_ids)
	return ids


func test_levy_gives_your_highest_card_left_and_takes_their_lowest_each_round() -> void:
	var stamped: Callable = func(state: RunState) -> void:
		for deck_id: int in Deck.SIZE:
			state.card_marks.stamps[deck_id] = RunLoop.PLAYER
	var loop: RunLoop = DebuffScript.loop_with(31, "levy", 1, stamped)
	var left: int = Seats.left(RunLoop.PLAYER)
	assert_int(left).is_equal(2)
	var checked: Array[int] = []
	var given_ids: Array[int] = []
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			var round_index: int = at.state.round_index
			var passes: Array = DebuffScript.per_round(at, RunEvent.Type.CARDS_PASSED).get(
				round_index, []
			)
			if round_index == 0:
				assert_array(passes).is_empty()
				return false
			assert_int(passes.size()).is_equal(2)
			var out: RunEvent = passes[0]
			var back: RunEvent = passes[1]
			assert_int(out.seat).is_equal(RunLoop.PLAYER)
			assert_int(out.value).is_equal(left)
			assert_int(back.seat).is_equal(left)
			assert_int(back.value).is_equal(RunLoop.PLAYER)
			var given: int = _ids(out.text)[0]
			var taken: int = _ids(back.text)[0]
			var hand: Array[int] = _hand_ids(at, RunLoop.PLAYER)
			assert_bool(hand.has(given)).is_false()
			assert_bool(hand.has(taken)).is_true()
			var given_rank: int = Deck.new().card(given).base_rank()
			for card: CardInstance in at.player_cards():
				if card.id() != taken:
					assert_int(card.base_rank()).is_less_equal(given_rank)
			# The card now sits with the left seat, or was played by it, still stamped.
			var with_left: bool = _hand_ids(at, left).has(given) or _played(at, left).has(given)
			assert_bool(with_left).is_true()
			for card: CardInstance in at.round_state().view_for(left).own_cards:
				if card.id() == given:
					assert_int(card.owner_stamp()).is_equal(RunLoop.PLAYER)
			given_ids.append(given)
			checked.append(round_index)
			return false
	)
	assert_array(checked).is_equal(IN_FORCE)
	# A deck card's saved mark is kept by its ID, whoever held it for a round.
	for given: int in given_ids:
		assert_int(loop.state.card_marks.stamps[given]).is_equal(RunLoop.PLAYER)


## Appeal is used after the cards moved: they stay moved, and the debuff still applies in
## the next round.
func test_appeal_after_a_levy_leaves_the_cards_moved() -> void:
	for seed_value: int in range(40, 80):
		var loop: RunLoop = DebuffScript.loop_with(
			seed_value, "levy", 1, _held([], 0, ["appeal"] as Array[String])
		)
		var lifted: Array[int] = []
		DebuffScript.play(
			loop,
			func(at: RunLoop) -> bool:
				if at.state.round_index == 0 or not lifted.is_empty():
					return false
				if at.awaiting() != RunLoop.Awaiting.PLAYER_OPENING:
					return false
				var hand: Array[int] = _hand_ids(at, RunLoop.PLAYER)
				assert_int(at.player_campaign(0, [])).is_equal(RunLoop.Reason.OK)
				assert_str(at.campaigns.flags.lifted).is_equal("levy")
				assert_array(_hand_ids(at, RunLoop.PLAYER)).contains_exactly_in_any_order(hand)
				lifted.append(at.state.round_index)
				return true
		)
		if lifted.is_empty():
			continue
		var later: Dictionary[int, Array] = DebuffScript.per_round(loop, RunEvent.Type.CARDS_PASSED)
		for round_index: int in range(lifted[0] + 1, 4):
			assert_int(later[round_index].size()).is_equal(2)
		return
	fail("No seed let the player appeal a Levy as a peasant")


func test_night_shift_refuses_the_first_pass_while_a_play_beats_the_table() -> void:
	var loop: RunLoop = DebuffScript.loop_with(52, "night_shift")
	var script: RunScript = RunScript.new()
	var spent: Dictionary[int, bool] = {}
	var refused: int = 0
	var free_passes: int = 0
	for _step: int in DebuffScript.STEPS:
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY:
			var round_state: RoundState = loop.round_state()
			var round_index: int = loop.state.round_index
			var answering: bool = round_state.current_play() != null
			if answering and round_index >= 1 and not spent.has(round_index):
				spent[round_index] = true
				var legal: Array[Pattern] = round_state.legal_moves()
				if legal.is_empty():
					assert_int(loop.player_play([])).is_equal(RunLoop.Reason.OK)
					continue
				var was: String = DebuffScript.snapshot(loop)
				assert_int(round_state.pass_reason()).is_equal(RoundState.Reason.MUST_PLAY)
				assert_int(loop.player_play([])).is_equal(RunLoop.Reason.ILLEGAL)
				assert_str(DebuffScript.snapshot(loop)).is_equal(was)
				refused += 1
				var ids: Array[int] = round_state.action_for(legal[0]).card_ids
				assert_int(loop.player_play(ids)).is_equal(RunLoop.Reason.OK)
				continue
			if answering:
				# Before it is in force, and once it is spent, a pass is free.
				assert_int(round_state.pass_reason()).is_equal(RoundState.Reason.OK)
				free_passes += 1
		if not script.act(loop):
			break
	assert_int(spent.size()).is_equal(IN_FORCE.size())
	assert_int(refused).is_greater(0)
	assert_int(free_passes).is_greater(0)


## With nothing that beats the table, the first pass goes through and spends the rule;
## a hand that can beat it may not pass.
func test_night_shift_never_traps_a_hand_that_cannot_beat_the_table() -> void:
	for holds_joker: bool in [false, true]:
		var stack: ModifierStack = ModifierStack.new()
		stack.add(DebuffScript.definition("night_shift"), 1)
		var table: SeatRules = SeatRules.new(stack)
		var second: String = "3b" if holds_joker else "34"
		var deal: DealResult = RoundScript.stacked_deal(["25", second, "67"], "")
		var round_state: RoundState = RoundState.new(deal, 0, table)
		assert_int(round_state.apply(RoundScript.play(round_state, "2"))).is_equal(
			RoundState.Reason.OK
		)
		var reason: RoundState.Reason = round_state.pass_reason()
		var pass_done: RoundState.Reason = round_state.apply(RoundAction.new(1))
		if holds_joker:
			assert_int(reason).is_equal(RoundState.Reason.MUST_PLAY)
			assert_int(pass_done).is_equal(RoundState.Reason.MUST_PLAY)
		else:
			assert_int(reason).is_equal(RoundState.Reason.OK)
			assert_int(pass_done).is_equal(RoundState.Reason.OK)


func test_shared_kitchen_allows_one_plot_swap_a_round() -> void:
	var roomy: Callable = func(state: RunState) -> void:
		_held([], 3).call(state)
		state.swap_bonus = 2
	var loop: RunLoop = DebuffScript.loop_with(61, "shared_kitchen", 1, roomy)
	var limits: Dictionary[int, int] = {}
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			if at.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
				return false
			limits[at.state.round_index] = at.swap_limit()
			if at.state.round_index >= 1:
				var hand: Array[CardInstance] = at.player_cards()
				var hand_ids: Array[int] = [hand[0].id(), hand[1].id()]
				var plot_ids: Array[int] = [
					at.state.inventory.plot[0].id(), at.state.inventory.plot[1].id()
				]
				assert_int(at.player_swap(hand_ids, plot_ids)).is_equal(RunLoop.Reason.ILLEGAL)
			return false
	)
	assert_int(limits[0]).is_equal(3)
	for round_index: int in IN_FORCE:
		assert_int(limits[round_index]).is_equal(1)


func test_confiscation_leaves_one_cadre_out_each_round_and_keeps_its_count() -> void:
	var loop: RunLoop = DebuffScript.loop_with(73, "confiscation", 1, _held(["ration_coupon"]))
	var memos: Dictionary[int, Dictionary] = {}
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			var round_index: int = at.state.round_index
			var expected: Array[String] = []
			if round_index >= 1:
				expected.append("ration_coupon")
			assert_array(at.debuffs.confiscated_ids()).is_equal(expected)
			memos[round_index] = at.state.cadre_memos.to_dict().duplicate(true)
			return false
	)
	var taken: Dictionary[int, Array] = DebuffScript.per_round(
		loop, RunEvent.Type.CADRE_CONFISCATED
	)
	assert_bool(taken.has(0)).is_false()
	for round_index: int in IN_FORCE:
		assert_int(taken[round_index].size()).is_equal(1)
		var event: RunEvent = taken[round_index][0]
		assert_int(event.value).is_equal(0)
		assert_str(event.text).is_equal("ration_coupon")
	# Left out from each round's start, it counted none of the player's passes since.
	assert_dict(memos[2]).is_equal(memos[1])
	assert_dict(memos[3]).is_equal(memos[1])


func test_confiscation_with_no_cadres_does_nothing_and_draws_nothing() -> void:
	var loop: RunLoop = DebuffScript.loop_with(74, "confiscation")
	var streams: Dictionary[int, String] = {}
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			streams[at.state.round_index] = (
				at.state.streams.stream(RandomStreams.DEBUFF).save_state()
			)
			return false
	)
	assert_array(DebuffScript.all_of(loop, RunEvent.Type.CADRE_CONFISCATED)).is_empty()
	assert_str(streams[3]).is_equal(streams[0])


func test_appeal_hands_a_confiscated_cadre_back() -> void:
	for seed_value: int in range(80, 120):
		var held: Callable = _held(["ration_coupon"], 0, ["appeal"] as Array[String])
		var loop: RunLoop = DebuffScript.loop_with(seed_value, "confiscation", 1, held)
		var restored: Array[bool] = []
		DebuffScript.play(
			loop,
			func(at: RunLoop) -> bool:
				if at.state.round_index != 1 or at.awaiting() != RunLoop.Awaiting.PLAYER_OPENING:
					return false
				assert_array(at.debuffs.confiscated_ids()).is_equal(["ration_coupon"])
				assert_int(at.player_campaign(0, [])).is_equal(RunLoop.Reason.OK)
				restored.append(at.debuffs.confiscated_ids().is_empty())
				return true
		)
		if not restored.is_empty():
			assert_array(restored).is_equal([true])
			return
	fail("No seed let the player appeal a Confiscation as a peasant")


func test_glass_walls_show_your_hand_to_both_villagers_and_no_one_else() -> void:
	var loop: RunLoop = DebuffScript.loop_with(85, "glass_walls")
	var checked: Array[int] = []
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			var round_state: RoundState = at.round_state()
			var mine: PackedByteArray = round_state.view_for(RunLoop.PLAYER).own_counts
			assert_dict(round_state.view_for(RunLoop.PLAYER).exposed).is_empty()
			assert_dict(at.player_view().exposed).is_empty()
			for seat: int in [1, 2]:
				var exposed: Dictionary[int, PackedByteArray] = round_state.view_for(seat).exposed
				if at.state.round_index == 0:
					assert_dict(exposed).is_empty()
				else:
					assert_array(exposed.keys()).is_equal([RunLoop.PLAYER])
					assert_that(exposed[RunLoop.PLAYER]).is_equal(mine)
			checked.append(at.state.round_index)
			return false
	)
	assert_array(checked).is_equal([0, 1, 2, 3])


func test_redistribution_passes_two_random_cards_left_from_every_hand() -> void:
	var loop: RunLoop = DebuffScript.loop_with(91, "redistribution")
	var checked: Array[int] = []
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			var round_index: int = at.state.round_index
			var passes: Array = DebuffScript.per_round(at, RunEvent.Type.CARDS_PASSED).get(
				round_index, []
			)
			if round_index == 0:
				assert_array(passes).is_empty()
				return false
			assert_int(passes.size()).is_equal(3)
			for moved: RunEvent in passes:
				assert_int(moved.value).is_equal(Seats.left(moved.seat))
				assert_int(_ids(moved.text).size()).is_equal(2)
			# No card leaves the table, and the public kitty is only what the landlord holds.
			var round_state: RoundState = at.round_state()
			var all_cards: Array[int] = []
			for seat: int in Seats.COUNT:
				all_cards.append_array(_hand_ids(at, seat))
				all_cards.append_array(_played(at, seat))
			assert_int(all_cards.size()).is_equal(Deck.SIZE)
			var landlord: int = round_state.landlord()
			var counts: PackedByteArray = round_state.view_for(landlord).own_counts
			for played: int in _played(at, landlord):
				counts[Deck.new().card(played).base_rank()] += 1
			var kitty: PackedByteArray = round_state.public_view().kitty_counts
			for rank: int in Ranks.COUNT:
				assert_int(kitty[rank]).is_less_equal(counts[rank])
			checked.append(round_index)
			return false
	)
	assert_array(checked).is_equal(IN_FORCE)


func test_plot_seized_destroys_one_plot_card_once_and_stops_every_swap() -> void:
	var loop: RunLoop = DebuffScript.loop_with(97, "plot_seized", 1, _held([], 3))
	var swapped: Array[int] = []
	var plots: Dictionary[int, int] = {}
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			plots[at.state.round_index] = at.state.inventory.plot.size()
			if at.awaiting() == RunLoop.Awaiting.PLAYER_SWAP:
				swapped.append(at.state.round_index)
			if at.state.round_index >= 1:
				assert_int(at.swap_limit()).is_equal(0)
			return false
	)
	assert_array(swapped).is_equal([0])
	var seized: Array[RunEvent] = DebuffScript.all_of(loop, RunEvent.Type.PLOT_SEIZED)
	assert_int(seized.size()).is_equal(1)
	assert_int(DebuffScript.per_round(loop, RunEvent.Type.PLOT_SEIZED)[1].size()).is_equal(1)
	assert_int(plots[1]).is_equal(2)
	assert_int(plots[3]).is_equal(2)
	for card: CardInstance in loop.state.inventory.plot:
		assert_int(card.id()).is_not_equal(seized[0].value)


func test_plot_seized_with_an_empty_plot_only_stops_the_swap() -> void:
	var loop: RunLoop = DebuffScript.loop_with(98, "plot_seized")
	DebuffScript.play(loop)
	assert_array(DebuffScript.all_of(loop, RunEvent.Type.PLOT_SEIZED)).is_empty()
	assert_array(loop.state.inventory.plot).is_empty()


## Appeal, used at the opening of a round the debuff is in force: what it still does this
## round is lifted, and what it already did stays done.
func test_appeal_ends_glass_walls_for_the_round_and_leaves_a_seized_card_destroyed() -> void:
	var glass: Callable = func(at: RunLoop) -> void:
		assert_dict(at.round_state().view_for(1).exposed).is_empty()
		assert_dict(at.round_state().view_for(2).exposed).is_empty()
	_appeal_once("glass_walls", 0, glass)
	var seized: Callable = func(at: RunLoop) -> void:
		assert_int(at.state.inventory.plot.size()).is_equal(1)
		assert_int(DebuffScript.all_of(at, RunEvent.Type.PLOT_SEIZED).size()).is_equal(1)
	_appeal_once("plot_seized", 2, seized)


func _appeal_once(debuff_id: String, plot: int, then: Callable) -> void:
	for seed_value: int in range(120, 170):
		var setup: Callable = _held([], plot, ["appeal"] as Array[String])
		var loop: RunLoop = DebuffScript.loop_with(seed_value, debuff_id, 1, setup)
		var used: Array[int] = []
		DebuffScript.play(
			loop,
			func(at: RunLoop) -> bool:
				if at.state.round_index != 1 or at.awaiting() != RunLoop.Awaiting.PLAYER_OPENING:
					return false
				assert_int(at.player_campaign(0, [])).is_equal(RunLoop.Reason.OK)
				then.call(at)
				used.append(1)
				return true
		)
		if not used.is_empty():
			return
	fail("No seed let the player appeal %s as a peasant" % debuff_id)
