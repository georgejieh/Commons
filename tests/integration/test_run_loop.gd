extends GdUnitTestSuite
## Full scripted Sets play end to end through the run loop and match a golden log.
## Set UPDATE_GOLDEN=1 to rewrite the golden file after an intended change.

const GOLDEN_PATH: String = "res://tests/golden/run_sets.golden"
const SEEDS: Array[int] = [3501, 3502, 3503]
const PLOT_SEED: int = 3504
const MISSED_SEED: int = 3505
const TOTAL_CARDS: int = 54


## A curve no Set can meet, so every round and debuff plays and the target is missed.
func _hard_sets() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e9)
	return SetConfig.new(params)


func _set_log(
	seed_value: int, plot_cards: int, sets: SetConfig = SetConfig.new()
) -> PackedStringArray:
	var state: RunState = RunState.new(seed_value)
	for index: int in plot_cards:
		state.inventory.plot.append(
			CardInstance.new(CardInstance.FIRST_PLOT_ID + index, 12, 0, CardInstance.Origin.PLOT)
		)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), sets)
	var script: RunScript = RunScript.new()
	loop.start_set()
	script.play_until_set_over(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	assert_int(loop.flow.state()).is_equal(RunFlow.State.SET_END)
	var lines: PackedStringArray = ["set %d" % seed_value]
	for event: RunEvent in loop.events():
		lines.append(event.describe())
	lines.append(
		(
			"end progress=%.3f coupons=%d famine=%d plot=%d"
			% [state.set_progress, state.coupons, state.famine, state.inventory.plot.size()]
		)
	)
	return lines


func _all_sets() -> String:
	var lines: PackedStringArray = []
	for seed_value: int in SEEDS:
		lines.append_array(_set_log(seed_value, 0))
	lines.append_array(_set_log(PLOT_SEED, 2))
	lines.append_array(_set_log(MISSED_SEED, 0, _hard_sets()))
	return "\n".join(lines) + "\n"


func test_sets_are_repeatable() -> void:
	assert_str(_all_sets()).is_equal(_all_sets())


func test_sets_match_the_golden_file() -> void:
	var text: String = _all_sets()
	if OS.get_environment("UPDATE_GOLDEN") == "1":
		var file: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	assert_str(text).is_equal(FileAccess.get_file_as_string(GOLDEN_PATH))


func test_a_set_ends_by_target_or_by_rounds() -> void:
	for seed_value: int in SEEDS:
		var state: RunState = RunState.new(seed_value)
		var loop: RunLoop = RunLoop.new(state, RunScript.bots())
		loop.start_set()
		RunScript.new().play_until_set_over(loop)
		var met: bool = state.set_progress >= loop.target()
		var rounds: int = (
			_count(loop, RunEvent.Type.SEAT_KEPT) + _count(loop, RunEvent.Type.SEAT_LOST)
		)
		assert_bool(met or rounds == SetConfig.new().max_rounds()).is_true()
		assert_bool(rounds <= SetConfig.new().max_rounds()).is_true()
		if met:
			assert_int(state.coupons).is_equal(SetConfig.new().reward(state.set_type))
		else:
			assert_int(state.famine).is_greater(0)


func test_a_missed_target_plays_every_round_and_raises_famine() -> void:
	var state: RunState = RunState.new(MISSED_SEED)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), _hard_sets())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	var max_rounds: int = SetConfig.new().max_rounds()
	var rounds: int = _count(loop, RunEvent.Type.SEAT_KEPT) + _count(loop, RunEvent.Type.SEAT_LOST)
	assert_int(rounds).is_equal(max_rounds)
	var ladder_debuffs: int = max_rounds - state.debuff_ladder.count(RunState.NO_DEBUFF)
	assert_int(_count(loop, RunEvent.Type.DEBUFF_ADDED)).is_equal(ladder_debuffs)
	assert_int(state.coupons).is_equal(0)
	assert_int(state.famine).is_equal(RunLoop.DEFAULT_PARAMS.famine_on_missed_target)


func test_every_round_accounts_for_all_cards() -> void:
	var state: RunState = RunState.new(PLOT_SEED)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	var played: int = 0
	var rounds: int = 0
	for event: RunEvent in loop.events():
		if event.round_event == null:
			continue
		if event.round_event.type == RoundEvent.Type.PLAYED:
			played += event.round_event.card_ids.size()
		elif event.round_event.type == RoundEvent.Type.ROUND_ENDED:
			rounds += 1
	# A finished round leaves cards only in the two losing hands, so play alone can't
	# reach 54; every round still plays at least the winner's whole hand.
	assert_int(rounds).is_greater(0)
	assert_int(played).is_greater_equal(rounds * 17)


func test_plot_swaps_conserve_cards() -> void:
	var state: RunState = RunState.new(PLOT_SEED)
	for index: int in 2:
		state.inventory.plot.append(
			CardInstance.new(CardInstance.FIRST_PLOT_ID + index, 12, 0, CardInstance.Origin.PLOT)
		)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() == RunLoop.Awaiting.PLAYER_BID:
		script.act(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.PLAYER_SWAP)
	var before: Array[int] = _ids(loop.player_cards()) + _ids(state.inventory.plot)
	var hand_ids: Array[int] = [loop.player_cards()[0].id()]
	var plot_ids: Array[int] = [state.inventory.plot[0].id()]
	assert_int(loop.player_swap(hand_ids, [] as Array[int])).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.player_swap(hand_ids, plot_ids)).is_equal(RunLoop.Reason.OK)
	var after: Array[int] = _ids(loop.player_cards()) + _ids(state.inventory.plot)
	var kitty: int = 3 if state.landlord_seat == RunLoop.PLAYER else 0
	assert_int(after.size()).is_equal(before.size() + kitty)
	for card_id: int in before:
		assert_bool(after.has(card_id)).is_true()
	assert_bool(_ids(loop.player_cards()).has(plot_ids[0])).is_true()
	assert_bool(_ids(state.inventory.plot).has(hand_ids[0])).is_true()


func test_commands_out_of_turn_are_refused() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEEDS[0]), RunScript.bots())
	assert_int(loop.player_bid(true)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.start_set()).is_equal(RunLoop.Reason.OK)
	var before: String = JSON.stringify(loop.state.to_dict())
	assert_int(loop.start_set()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_str(JSON.stringify(loop.state.to_dict())).is_equal(before)
	var none: Array[int] = []
	if loop.awaiting() != RunLoop.Awaiting.PLAYER_NEED:
		assert_int(loop.player_need(1)).is_equal(RunLoop.Reason.NOT_AWAITED)
	if loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		assert_int(loop.player_play(none)).is_equal(RunLoop.Reason.NOT_AWAITED)
	if loop.awaiting() != RunLoop.Awaiting.PLAYER_BID:
		assert_int(loop.player_bid(false)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.player_swap(none, none)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_str(JSON.stringify(loop.state.to_dict())).is_equal(before)


## An all-pass bid redeals on the deal stream and bidding starts again.
func test_an_all_pass_redeals_and_the_round_goes_on() -> void:
	var found: bool = false
	for seed_value: int in range(3800, 3900):
		var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots())
		loop.start_set()
		RunScript.new().play_until_set_over(loop)
		var types: Array[int] = []
		for event: RunEvent in loop.events():
			types.append(event.type)
		var at: int = types.find(RunEvent.Type.REDEALT)
		if at < 0:
			continue
		found = true
		assert_int(types[at + 1]).is_equal(RunEvent.Type.DEALT)
		assert_int(types.find(RunEvent.Type.LANDLORD_CHOSEN, at)).is_greater(at)
		assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
		break
	assert_bool(found).is_true()


func test_illegal_swaps_are_refused() -> void:
	var state: RunState = RunState.new(PLOT_SEED)
	for index: int in 2:
		state.inventory.plot.append(
			CardInstance.new(CardInstance.FIRST_PLOT_ID + index, 12, 0, CardInstance.Origin.PLOT)
		)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() == RunLoop.Awaiting.PLAYER_BID:
		script.act(loop)
	var first: int = loop.player_cards()[0].id()
	var second: int = loop.player_cards()[1].id()
	var plot: Array[int] = [state.inventory.plot[0].id(), state.inventory.plot[1].id()]
	var over_limit: Array[int] = [first, second]
	assert_int(loop.player_swap(over_limit, plot)).is_equal(RunLoop.Reason.ILLEGAL)
	var repeated: Array[int] = [first]
	var repeated_plot: Array[int] = [plot[0], plot[0]]
	assert_int(loop.player_swap([first, first] as Array[int], repeated_plot)).is_equal(
		RunLoop.Reason.ILLEGAL
	)
	assert_int(loop.player_swap(repeated, [999] as Array[int])).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.PLAYER_SWAP)


func _count(loop: RunLoop, type: RunEvent.Type) -> int:
	var total: int = 0
	for event: RunEvent in loop.events():
		if event.type == type:
			total += 1
	return total


func _ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	return ids
