extends GdUnitTestSuite
## P5.0 through the controller in the tree, as the game runs it: an Expert villager's
## search runs on the worker pool while frames go on, its play is handed in, saved and
## sealed into the second book, a save taken while one thinks loads and searches again,
## and a run abandoned or replaced mid-search leaves nothing behind.

const DIR: String = "user://test_search_frames/"
const SEED: int = 5021
## Rounds played by frames in the frame test.
const ROUNDS: int = 3
## The longest a frame may take while a villager thinks.
const FRAME_LIMIT_USEC: int = 50_000
## The search's own time must be well above that for the frame test to mean anything.
const SEARCH_FLOOR_USEC: int = 3 * FRAME_LIMIT_USEC
## Deals each slow search would sample: far more than its deadline lets finish, so every
## search that has a choice runs to its deadline.
const SLOW_SAMPLES: int = 480
## A test that goes wrong stops after this long.
const TIME_LIMIT_MSEC: int = 180_000
## Seeds tried for a full run that seats an Expert family in its first Quota.
## Enough finished runs for both Expert families to have joined the village.
const FINISHED_RUNS: int = 5

var _saves: SaveService = SaveService.for_run(DIR + "run.json")
var _kit: FileWatchKit = FileWatchKit.new(DIR + "book_")
## What the frame probe and the signal handlers saw.
var _watched: RunController = null
var _last_frame: int = 0
var _last_thinking: bool = false
var _longest_gap: int = 0
var _longest_hand_in: int = 0
var _longest_wait: int = 0
var _frame_hand_ins: int = 0
var _thinking_frames: int = 0
var _thinking_since: int = 0
var _last_awaiting: int = -1
var _search_times: Array[int] = []
var _villager_signals: int = 0
var _hand_ins: int = 0
var _deals: int = 0
var _figures_before: Array[float] = []
var _changed_by_play: int = 0


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_saves.delete()
	_kit.reset()
	_watched = null
	_last_frame = 0
	_last_thinking = false
	_longest_gap = 0
	_longest_hand_in = 0
	_longest_wait = 0
	_frame_hand_ins = 0
	_thinking_frames = 0
	_last_awaiting = -1
	_search_times.clear()
	_villager_signals = 0
	_hand_ins = 0
	_deals = 0
	_changed_by_play = 0


func after_test() -> void:
	if get_tree().process_frame.is_connected(_on_frame):
		get_tree().process_frame.disconnect(_on_frame)
	_saves.delete()
	_kit.reset()
	ArtStages.latch_value(0.0)


## Seats 1 and 2 are Expert, sampling the given deals.
static func _configs(samples: int) -> Array[BotConfig]:
	return [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.new(_weights(samples), BotConfig.Tier.EXPERT, SEED),
		BotConfig.new(_weights(samples), BotConfig.Tier.EXPERT, SEED + 1),
	]


static func _weights(samples: int) -> BotWeights:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
	weights.expert_samples = samples
	return weights


static func _fast() -> Array[BotConfig]:
	return _configs(BotConfig.DEFAULT_WEIGHTS.expert_min_samples)


## A controller in the tree, which searches live, watched by the handlers below.
func _in_tree() -> RunController:
	var controller: RunController = auto_free(RunController.new())
	add_child(controller)
	_watch(controller)
	return controller


func _watch(controller: RunController) -> void:
	_watched = controller
	_last_awaiting = -1
	_hand_ins = 0
	_villager_signals = 0
	controller.awaiting_changed.connect(_on_awaiting)
	controller.event_emitted.connect(_on_event)


func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _last_frame > 0 and _last_thinking:
		_longest_gap = maxi(_longest_gap, now - _last_frame)
		_thinking_frames += 1
		# Told apart for the report: frames that handed a play in, and frames that only
		# waited.
		if _hand_ins != _frame_hand_ins:
			_longest_hand_in = maxi(_longest_hand_in, now - _last_frame)
		else:
			_longest_wait = maxi(_longest_wait, now - _last_frame)
	_last_frame = now
	_frame_hand_ins = _hand_ins
	_last_thinking = _watched != null and _thinking(_watched)


func _on_awaiting(awaiting: int) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_awaiting == RunController.AWAIT_VILLAGER:
		_hand_ins += 1
		_search_times.append(now - _thinking_since)
		if _figures(_watched) != _figures_before:
			_changed_by_play += 1
	if awaiting == RunController.AWAIT_VILLAGER:
		_villager_signals += 1
		_thinking_since = now
		_figures_before = _figures(_watched)
	_last_awaiting = awaiting


func _on_event(event: RunEvent) -> void:
	if event.type == RunEvent.Type.DEALT:
		_deals += 1


static func _thinking(controller: RunController) -> bool:
	return controller.has_run() and controller.awaiting() == RunController.AWAIT_VILLAGER


## The six figures the second book holds.
static func _figures(controller: RunController) -> Array[float]:
	var state: RunState = controller.state_copy()
	return [
		float(state.coupons),
		state.set_progress,
		float(state.famine),
		float(state.denunciation),
		float(state.resentment),
		float(state.norm_steps),
	]


static func _loop_of(controller: RunController) -> RunLoop:
	return controller.get("_loop")


func _out_of_time(began: int) -> bool:
	return Time.get_ticks_msec() - began > TIME_LIMIT_MSEC


## Plays the player's seat a frame at a time until done says so, waiting while a villager
## thinks. False when the run stopped somewhere the driver does not answer, or time ran
## out.
func _play_by_frames(controller: RunController, done: Callable) -> bool:
	var began: int = Time.get_ticks_msec()
	while not done.call():
		if _out_of_time(began):
			return false
		await get_tree().process_frame
		if _thinking(controller):
			continue
		if done.call():
			return true
		if not _kit.one_command(controller):
			return false
	return true


## Waits frames until a villager thinks, by the player's commands.
func _to_a_villager(controller: RunController) -> void:
	var thinking: Callable = func() -> bool: return _thinking(controller)
	assert_bool(await _play_by_frames(controller, thinking)).is_true()


func _wait_until(condition: Callable) -> bool:
	var began: int = Time.get_ticks_msec()
	while not condition.call():
		if _out_of_time(began):
			return false
		await get_tree().process_frame
	return true


static func _state_text(controller: RunController) -> String:
	return JSON.stringify(controller.state_copy().to_dict(), "", true)


func test_frames_go_on_while_two_experts_think() -> void:
	var controller: RunController = _in_tree()
	get_tree().process_frame.connect(_on_frame)
	var configs: Array[BotConfig] = _configs(SLOW_SAMPLES)
	controller.start_run(SEED, configs, SetConfig.new())
	var player_waits: Callable = func() -> bool:
		var over: bool = controller.awaiting() == RunController.AWAIT_SET_OVER
		return (_deals > ROUNDS or over) and not _thinking(controller)
	assert_bool(await _play_by_frames(controller, player_waits)).is_true()
	get_tree().process_frame.disconnect(_on_frame)
	_search_times.sort()
	var slowest: int = _search_times[-1] if not _search_times.is_empty() else 0
	var middle: int = _search_times[_search_times.size() >> 1] if slowest > 0 else 0
	var line: String = "P5.0 frames: %d searches, %d frames thinking, longest frame %d usec"
	print(line % [_search_times.size(), _thinking_frames, _longest_gap])
	print("P5.0 search time: median %d usec, slowest %d usec" % [middle, slowest])
	var split: String = "P5.0 longest frame handing a play in %d usec, only waiting %d usec"
	print(split % [_longest_hand_in, _longest_wait])
	assert_int(_hand_ins).is_greater(ROUNDS)
	assert_int(slowest).is_greater(SEARCH_FLOOR_USEC)
	assert_int(_thinking_frames).is_greater(_hand_ins)
	assert_int(_longest_gap).is_less(FRAME_LIMIT_USEC)
	# Every villager the run waited on was handed in, and told after it.
	assert_int(_villager_signals).is_equal(_hand_ins)
	var loop: RunLoop = _loop_of(controller)
	assert_int(loop.refused_bot_actions).is_equal(0)
	assert_int(controller.searches_running()).is_equal(0)
	# No play was lost: the record replays to exactly where the run is.
	var resumed: RunLoop = RunRecord.resume(
		loop.record.to_dict(),
		_configs(SLOW_SAMPLES),
		SetConfig.new(),
		RunLoop.DEFAULT_PARAMS,
		RunLoop.DEFAULT_POOL.debuffs,
		RunLoop.DEFAULT_METERS,
		Callable(),
		true
	)
	assert_object(resumed).is_not_null()
	assert_int(resumed.awaiting()).is_equal(loop.awaiting())
	var resumed_text: String = JSON.stringify(resumed.state.to_dict(), "", true)
	assert_str(resumed_text).is_equal(_state_text(controller))


func test_a_save_taken_while_a_villager_thinks_loads_and_searches_again() -> void:
	var first: RunController = _in_tree()
	first.start_run(SEED, _fast(), SetConfig.new(), _saves)
	await _to_a_villager(first)
	assert_int(first.searches_running()).is_equal(1)
	var shown: String = _state_text(first)
	# Leaving the tree stops the search and keeps the run standing still for it.
	remove_child(first)
	assert_int(first.searches_running()).is_equal(0)
	assert_int(first.awaiting()).is_equal(RunController.AWAIT_VILLAGER)
	var second: RunController = _in_tree()
	assert_bool(second.resume_saved(_saves, _fast(), SetConfig.new())).is_true()
	assert_int(second.awaiting()).is_equal(RunController.AWAIT_VILLAGER)
	assert_int(second.searches_running()).is_equal(1)
	assert_str(_state_text(second)).is_equal(shown)
	var decisions: int = _loop_of(second).record.decisions.size()
	assert_bool(await _wait_until(func() -> bool: return _hand_ins > 0)).is_true()
	assert_int(_loop_of(second).record.decisions.size()).is_greater(decisions)
	# Outside the tree a resumed villager is searched at once, as headless callers need.
	var headless: RunController = auto_free(RunController.new())
	assert_bool(headless.resume_saved(_saves, _fast(), SetConfig.new())).is_true()
	assert_int(headless.awaiting()).is_not_equal(RunController.AWAIT_VILLAGER)
	assert_int(headless.searches_running()).is_equal(0)
	# The first controller, out of the tree, makes its villager's play when asked to.
	first.settle_search()
	assert_int(first.awaiting()).is_not_equal(RunController.AWAIT_VILLAGER)


func test_a_run_replaced_or_dropped_mid_search_leaves_nothing_behind() -> void:
	var controller: RunController = _in_tree()
	controller.start_run(SEED, _fast(), SetConfig.new())
	await _to_a_villager(controller)
	var old: RunLoop = _loop_of(controller)
	var request: SearchRequest = old.search_request()
	var written: int = old.record.decisions.size()
	controller.start_run(SEED + 1, _fast(), SetConfig.new())
	assert_object(_loop_of(controller)).is_not_same(old)
	var settled: Callable = func() -> bool:
		return controller.searches_running() == (1 if _thinking(controller) else 0)
	assert_bool(await _wait_until(settled)).is_true()
	# The search for the run let go of finished and was thrown away.
	assert_int(old.awaiting()).is_equal(RunLoop.Awaiting.VILLAGER_SEARCH)
	assert_object(old.search_request()).is_same(request)
	assert_int(old.record.decisions.size()).is_equal(written)
	await _to_a_villager(controller)
	controller.drop()
	assert_bool(controller.has_run()).is_false()
	var idle: Callable = func() -> bool: return controller.searches_running() == 0
	assert_bool(await _wait_until(idle)).is_true()
	# Freed mid-search: leaving the tree waits for the search, so no worker outlives it.
	var freed: RunController = RunController.new()
	add_child(freed)
	freed.start_run(SEED + 2, _fast(), SetConfig.new())
	_watch(freed)
	await _to_a_villager(freed)
	assert_int(freed.searches_running()).is_equal(1)
	freed.free()
	for _frame: int in 30:
		await get_tree().process_frame


## A full run with a profile, with the file's detectors acting. Both villagers at the
## table are made Expert once it starts, whatever their families are, so every play of
## theirs is searched off the frame, the ones that end a round among them.
func _full_run_with_an_expert() -> RunController:
	_with_unlocked_profile()
	var controller: RunController = _in_tree()
	controller.file_watch.release = true
	controller.file_watch.report = func(line: String) -> void: _kit.lines.append(line)
	controller.search_weights = _weights(BotConfig.DEFAULT_WEIGHTS.expert_min_samples)
	assert_bool(controller.start(FileWatchKit.full(SEED), _kit.saves, _kit.profile)).is_true()
	var seated: Array[BotConfig] = _loop_of(controller).get("_configs")
	for seat: int in [1, 2]:
		seated[seat].tier = BotConfig.Tier.EXPERT
	return controller


func _with_unlocked_profile() -> void:
	_kit.reset()
	var data: ProfileData = ProfileData.new()
	data.finished_runs = FINISHED_RUNS
	assert_int(Profile.write(_kit.profile, data)).is_equal(OK)


## A villager's play can end a round and bank Grain. Sealed again after the play, the
## second book takes that as the run's own and the player's next command is honest.
func test_an_expert_play_off_the_frame_then_a_command_is_no_offence() -> void:
	var controller: RunController = _full_run_with_an_expert()
	assert_object(controller).is_not_null()
	assert_bool(controller.file_watch.acts(_loop_of(controller))).is_true()
	var began: int = Time.get_ticks_msec()
	var after_change: int = 0
	while after_change < 2:
		if _out_of_time(began):
			fail("no villager's play changed a figure in time")
			return
		await get_tree().process_frame
		if _thinking(controller):
			continue
		var changed: int = _changed_by_play
		if not _kit.one_command(controller):
			var at: RunState = controller.state_copy()
			var where: Array = [controller.awaiting(), at.year, at.set_index, at.round_index]
			where.append_array([at.famine, at.denunciation, _hand_ins, _changed_by_play])
			fail(
				"the run stopped: awaiting %d, year %d, set %d, round %d, F %d, D %d, %d %d" % where
			)
			return
		if changed > 0:
			after_change += 1
	assert_array(Array(_kit.lines)).is_empty()
	assert_array(_kit.entries()).is_empty()
	assert_bool(FileWatchKit.has_books_command(controller)).is_false()
	assert_int(FileWatchKit.corrections(controller)).is_equal(0)
