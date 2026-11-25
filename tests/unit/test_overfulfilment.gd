extends GdUnitTestSuite
## Overfulfilling a Quota: each quarter above the target is a step, up to four. Steps pay
## extra coupons, add Resentment, and raise the norm, so every later target rises by 3%
## of its base per step, added across the run and never compounded.

const SETS: SetParams = preload("res://data/run/default_sets.tres")
const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
const SEED: int = 5101


## A curve every Set beats many times over in its first scoring round.
func _easy_sets() -> SetConfig:
	var params: SetParams = SETS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(0.01)
	return SetConfig.new(params)


## A curve no Set can meet.
func _hard_sets() -> SetConfig:
	var params: SetParams = SETS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e9)
	return SetConfig.new(params)


func test_steps_are_counted_by_the_quarter_and_capped() -> void:
	var config: SetConfig = SetConfig.new()
	var cases: Dictionary[float, int] = {
		1000.0: 0, 1240.0: 0, 1250.0: 1, 1990.0: 3, 2000.0: 4, 5000.0: 4, 999.0: 0, 0.0: 0
	}
	for progress: float in cases:
		(
			assert_int(config.over_steps(progress, 1000.0))
			. override_failure_message("progress %s" % progress)
			. is_equal(cases[progress])
		)
	# The curve's own targets, exactly a quarter over, earn a step.
	for target: float in SETS.targets:
		assert_int(config.over_steps(target * 1.25, target)).is_equal(1)
		assert_int(config.over_steps(target * 1.24, target)).is_equal(0)


func test_a_bad_overfulfilment_rule_is_refused() -> void:
	var params: SetParams = SETS.duplicate()
	params.over_step_percent = 0
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.BAD_OVERFULFILMENT)
	params.over_step_percent = 25
	params.norm_percent_per_step = -1
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.BAD_OVERFULFILMENT)


## The norm adds 3% of the base per step: nine steps raise a target 27%, not 1.03^9.
func test_the_norm_raises_targets_additively() -> void:
	var state: RunState = RunState.new(SEED)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var base: float = loop.sets().target(1, RunState.SetType.SMALL)
	assert_float(loop.target()).is_equal(base)
	state.norm_steps = 3
	assert_float(loop.target()).is_equal_approx(base * 1.09, 1e-6)
	state.norm_steps = 9
	assert_float(loop.target()).is_equal_approx(base * 1.27, 1e-6)
	# Steps the Set itself earned are left out of its own target.
	state.over_steps = 4
	assert_float(loop.target()).is_equal_approx(base * 1.15, 1e-6)


func test_an_overfulfilled_set_pays_the_bonus_and_raises_later_targets() -> void:
	var state: RunState = RunState.new(SEED)
	var sets: SetConfig = _easy_sets()
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), sets)
	loop.start_set()
	var first_target: float = loop.target()
	var resentment_before: int = state.resentment
	RunScript.new().play_until_set_over(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	var steps: int = sets.over_steps(state.set_progress, first_target)
	assert_int(steps).is_equal(SETS.over_max_steps)
	assert_int(state.over_steps).is_equal(steps)
	assert_int(state.norm_steps).is_equal(steps)
	var reward: int = sets.reward(RunState.SetType.SMALL)
	assert_int(state.coupons).is_equal(reward + steps * SETS.over_bonus_coupons)
	# The finished Set still reads the target it was played against.
	assert_float(loop.target()).is_equal(first_target)
	_assert_logged(loop, steps)
	assert_int(state.resentment).is_greater_equal(
		resentment_before + steps * RESENTMENT.overfulfilment
	)
	# The next Set's target carries the raised norm, and the one after adds to it.
	var expected: float = 100.0 + steps * SETS.norm_percent_per_step
	RunScript.next_set(loop)
	var base: float = sets.target(state.year, state.set_type)
	assert_float(loop.target()).is_equal_approx(base * expected / 100.0, 1e-9)
	RunScript.new().play_until_set_over(loop)
	assert_int(state.norm_steps).is_equal(steps * 2)
	RunScript.next_set(loop)
	base = sets.target(state.year, state.set_type)
	# The third Set is the Year's boss, and a boss may change its Quota (Great Leap).
	for boss: ModifierDef in RunPools.BOSSES.all():
		if boss.id == state.boss_id:
			base = base * boss.parameters.get(GreatLeapEffect.QUOTA_PERCENT, 100) / 100.0
	var twice: float = 100.0 + steps * 2 * SETS.norm_percent_per_step
	assert_float(loop.target()).is_equal_approx(base * twice / 100.0, 1e-9)


## The steps are logged once, after the Set's end, and their Resentment is logged too.
func _assert_logged(loop: RunLoop, steps: int) -> void:
	var ended: int = -1
	var over: int = -1
	var resented: int = 0
	var events: Array[RunEvent] = loop.events()
	for index: int in events.size():
		var event: RunEvent = events[index]
		if event.type == RunEvent.Type.SET_ENDED:
			ended = index
		elif event.type == RunEvent.Type.OVERFULFILLED:
			over = index
			assert_int(event.value).is_equal(steps)
		elif event.type == RunEvent.Type.RESENTMENT and event.text == Resentment.OVERFULFILMENT:
			resented += event.value
	assert_int(over).is_equal(ended + 1)
	assert_int(resented).is_equal(steps * RESENTMENT.overfulfilment)


func test_a_missed_quota_earns_no_steps() -> void:
	var state: RunState = RunState.new(SEED)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), _hard_sets())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	assert_int(state.over_steps).is_equal(0)
	assert_int(state.norm_steps).is_equal(0)
	for event: RunEvent in loop.events():
		assert_int(event.type).is_not_equal(RunEvent.Type.OVERFULFILLED)


func test_the_norm_survives_a_save() -> void:
	var state: RunState = RunState.new(SEED)
	state.norm_steps = 7
	state.over_steps = 2
	var copy: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_int(copy.norm_steps).is_equal(7)
	assert_int(copy.over_steps).is_equal(2)


## A save from inside the Set after an overfulfilled one replays to the same state.
func test_a_replay_from_the_record_reproduces_the_state() -> void:
	var sets: SetConfig = _easy_sets()
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), sets)
	loop.start_set()
	var script: RunScript = RunScript.new()
	script.play_until_set_over(loop)
	RunScript.next_set(loop)
	for _turn: int in 3:
		script.act(loop)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
	var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), sets)
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.norm_steps).is_equal(loop.state.norm_steps)
	assert_float(resumed.target()).is_equal(loop.target())
	assert_str(JSON.stringify(resumed.state.to_dict())).is_equal(
		JSON.stringify(loop.state.to_dict())
	)
