extends GdUnitTestSuite
## The loop takes a command that moves the run on only in the phase it belongs to: a
## finished Set that is not the run's last goes to the shops, where a reeducation that is
## due is served, and the run's last Set has no shops after it.

const SEED: int = 4401


func _finished_set(state: RunState, sets: SetConfig = SetConfig.new()) -> RunLoop:
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), sets)
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	return loop


func test_a_finished_set_is_not_left_past_its_shops() -> void:
	var loop: RunLoop = _finished_set(RunState.new(SEED))
	assert_bool(loop.is_last_set()).is_false()
	var before: String = JSON.stringify(loop.state.to_dict())
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	assert_str(JSON.stringify(loop.state.to_dict())).is_equal(before)
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.set_index).is_equal(1)


## A reeducation that is due is served at the Set it is due after, never a Set late.
func test_a_due_reeducation_is_served_at_the_set_it_follows() -> void:
	var loop: RunLoop = _finished_set(RunState.new(SEED))
	loop.state.reeducation_due = true
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_bool(loop.state.reeducation_due).is_true()
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.REEDUCATION)
	assert_bool(loop.state.reeducation_due).is_false()
	assert_int(loop.leave_store()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.leave_reeducation()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.set_index).is_equal(1)


## The run's last Set ends the run: no shop opens after it, where black-market purchases
## would still move the Resentment the ending reads.
func test_no_shop_opens_after_the_runs_last_set() -> void:
	var sets: SetConfig = SetConfig.new()
	var state: RunState = RunState.new(SEED)
	state.year = sets.years()
	state.set_index = SetConfig.SETS_PER_YEAR - 1
	state.set_type = RunState.SetType.BOSS
	var loop: RunLoop = _finished_set(state, sets)
	assert_bool(loop.is_last_set()).is_true()
	var commands: int = loop.record.commands.size()
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.record.commands.size()).is_equal(commands)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)


## Leaving the shops is taken only at the shops, and leaving reeducation only there.
func test_each_leave_is_taken_only_in_its_own_phase() -> void:
	var loop: RunLoop = _finished_set(RunState.new(SEED))
	assert_int(loop.leave_store()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.leave_reeducation()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.leave_reeducation()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SHOP)
	assert_int(loop.leave_store()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.set_index).is_equal(1)
