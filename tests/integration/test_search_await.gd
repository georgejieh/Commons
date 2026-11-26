extends GdUnitTestSuite
## P5.0: the loop stands still for a searching villager when its searches are answered
## from outside, hands the search what it needs, takes the play back as a bot's, and
## resumes a save written while one was thinking standing still for it again. With that
## off it plays exactly as it did before.
## Set UPDATE_GOLDEN=1 to rewrite the golden file after an intended change.

const GOLDEN_PATH: String = "res://tests/golden/searched_turns.golden"
const DIR: String = "user://test_search_await/"
const SEED: int = 5011
## Player turns played for the golden log.
const TURNS: int = 14
## Steps, player commands and searched plays both, played for the resume test, and how
## often a save is taken among them.
const STEPS: int = 70
const SAVE_EVERY: int = 4
const ILLEGAL_ACTION: String = "Assertion failed: A bot chose an illegal action"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	SaveService.for_run(DIR + "run.json").delete()


## Seats 1 and 2 are Expert, sampling the fewest deals a search may decide on.
static func configs() -> Array[BotConfig]:
	var fast: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
	fast.expert_samples = fast.expert_min_samples
	return [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.new(fast, BotConfig.Tier.EXPERT, SEED),
		BotConfig.new(fast, BotConfig.Tier.EXPERT, SEED + 1),
	]


## The events and written decisions of a loop, one line each.
static func log_of(loop: RunLoop) -> String:
	var lines: PackedStringArray = []
	for event: RunEvent in loop.events():
		lines.append(event.describe())
	for decision: Dictionary in loop.record.decisions:
		lines.append(JSON.stringify(decision, "", true))
	lines.append("awaiting %d" % loop.awaiting())
	return "\n".join(lines) + "\n"


## The play a searching seat makes with no limit, as the loop makes it with nothing
## handed in.
static func unlimited(request: SearchRequest) -> BotPlay:
	return Bot.decide_play(
		request.view, request.legal, request.table, request.config, BotBudget.unlimited()
	)


## The first legal move the policy would not play, so a resume that searched again would
## not land where the run did.
static func overturn(request: SearchRequest) -> BotPlay:
	var job: BotSearchJob = Bot.search_job(
		request.view, request.legal, request.table, request.config
	)
	for move: Pattern in request.legal:
		if not move.equals(job.fallback.pattern):
			return BotPlay.new(move, BotRationale.Code.SEARCHED)
	return job.fallback


func _outside() -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), configs(), SetConfig.new())
	loop.decisions.answered_outside = true
	loop.start_set()
	return loop


## One step: the searched play of a villager the loop stands still for, by answer, or
## else one player command. False when the loop waits on neither.
func _step(loop: RunLoop, script: RunScript, answer: Callable) -> bool:
	if loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH:
		var play: BotPlay = answer.call(loop.search_request())
		return loop.villager_play(play) == RunLoop.Reason.OK
	return script.act(loop)


## Runs until the loop stands still for a villager, by the player's commands alone.
func _to_a_villager(loop: RunLoop) -> void:
	var script: RunScript = RunScript.new()
	while loop.awaiting() != RunLoop.Awaiting.VILLAGER_SEARCH:
		assert_bool(script.act(loop)).is_true()


## The record as a load reads it back: written as JSON, migrated and validated.
func _through_disk(data: Dictionary) -> Dictionary:
	var file: FileAccess = FileAccess.open(DIR + "run.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": SaveService.SCHEMA_VERSION, "data": data}))
	file.close()
	var loaded: SaveLoad = SaveService.for_run(DIR + "run.json").load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	return loaded.data


func _resume(data: Dictionary) -> RunLoop:
	return RunRecord.resume(
		data,
		configs(),
		SetConfig.new(),
		RunDefaults.PARAMS,
		RunPools.DEBUFFS.debuffs,
		RunDefaults.METERS,
		Callable(),
		true
	)


func _text(data: Dictionary) -> String:
	return JSON.stringify(data, "", true)


## With nothing answered from outside, a searching seat searches with no limit inside
## the loop, as every tool does, and the events are the ones it gave before P5.0.
func test_the_flag_off_plays_as_before() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), configs(), SetConfig.new())
	loop.start_set()
	var script: RunScript = RunScript.new()
	for _turn: int in TURNS:
		if not script.act(loop):
			break
	var text: String = log_of(loop)
	if OS.get_environment("UPDATE_GOLDEN") == "1":
		var file: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	assert_str(text).is_equal(FileAccess.get_file_as_string(GOLDEN_PATH))


## Answered at once with the search the loop would make itself, standing still changes
## nothing: the same events and the same written decisions.
func test_answered_at_once_it_plays_as_the_flag_off_does() -> void:
	var loop: RunLoop = _outside()
	var script: RunScript = RunScript.new()
	var turns: int = 0
	var answered: int = 0
	while true:
		if loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH:
			var play: BotPlay = unlimited(loop.search_request())
			assert_int(loop.villager_play(play)).is_equal(RunLoop.Reason.OK)
			answered += 1
			continue
		if turns == TURNS or not script.act(loop):
			break
		turns += 1
	assert_int(answered).is_greater(0)
	assert_str(log_of(loop)).is_equal(FileAccess.get_file_as_string(GOLDEN_PATH))


func test_the_loop_stands_still_for_a_searching_villager() -> void:
	var loop: RunLoop = _outside()
	_to_a_villager(loop)
	var request: SearchRequest = loop.search_request()
	assert_object(request).is_not_null()
	var seat: int = loop.round_state().seat_to_act()
	assert_int(request.seat).is_equal(seat)
	assert_int(request.view.seat).is_equal(seat)
	assert_array(request.legal).is_not_empty()
	assert_bool(SearchedDecisions.searches(request.config)).is_true()
	# Copies: the search never holds the run's own config or moves.
	var seated: Array[BotConfig] = loop.get("_configs")
	assert_object(request.config).is_not_same(seated[seat])
	var own: Array[Pattern] = loop.get("_request_legal")
	assert_int(request.legal.size()).is_equal(own.size())
	for index: int in own.size():
		assert_object(request.legal[index]).is_not_same(own[index])
		assert_bool(request.legal[index].equals(own[index])).is_true()
	var commands: int = loop.record.commands.size()
	var decisions: int = loop.record.decisions.size()
	var events: int = loop.events().size()
	var none: Array[int] = []
	var refused: Array[int] = [
		loop.player_play(none),
		loop.player_bid(true),
		loop.player_need(RunScript.NEED),
		loop.player_begin(),
		loop.player_books({RunCorrections.COUPONS: 1}),
		loop.player_campaign(0, none),
		loop.open_shop(),
		RunScript.next_set(loop),
	]
	for reason: int in refused:
		assert_int(reason).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.VILLAGER_SEARCH)
	assert_object(loop.search_request()).is_same(request)
	assert_int(loop.record.commands.size()).is_equal(commands)
	assert_int(loop.events().size()).is_equal(events)
	var play: BotPlay = unlimited(request)
	assert_int(loop.villager_play(play)).is_equal(RunLoop.Reason.OK)
	# Written with the villagers' decisions, never with the player's commands.
	assert_int(loop.record.commands.size()).is_equal(commands)
	assert_int(loop.record.decisions.size()).is_greater(decisions)
	assert_int(int(loop.record.decisions[decisions]["seat"])).is_equal(seat)
	assert_int(loop.events().size()).is_greater(events)
	assert_object(loop.search_request()).is_not_same(request)
	assert_int(loop.refused_bot_actions).is_equal(0)
	# Once the loop waits on the player, an answer is refused.
	while loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH:
		loop.villager_play(unlimited(loop.search_request()))
	assert_object(loop.search_request()).is_null()
	assert_int(loop.villager_play(play)).is_equal(RunLoop.Reason.NOT_AWAITED)


## A play the villager was not offered is a bot's illegal action, counted as one; the
## debug build's assert stops that play, so the loop stands still for the seat again.
func test_a_play_it_was_not_offered_is_refused_as_a_bots() -> void:
	var loop: RunLoop = _outside()
	_to_a_villager(loop)
	var request: SearchRequest = loop.search_request()
	var missing: int = Ranks.THREE
	while request.view.own_counts[missing] > 0:
		missing += 1
	var lone: Pattern = Pattern.new(Pattern.Type.SINGLE, missing, 1, 1, PackedByteArray(), missing)
	var offered: bool = request.legal.any(func(move: Pattern) -> bool: return move.equals(lone))
	assert_bool(offered).is_false()
	var bad: BotPlay = BotPlay.new(lone, BotRationale.Code.SEARCHED)
	await assert_error(func() -> void: loop.villager_play(bad)).is_runtime_error(ILLEGAL_ACTION)
	assert_int(loop.refused_bot_actions).is_equal(1)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.VILLAGER_SEARCH)
	assert_int(loop.search_request().seat).is_equal(request.seat)


## Saves taken all through a run whose searches were answered from outside, some while a
## villager was awaited, each resume where the run was and play on to where it went.
func test_saves_taken_anywhere_resume_where_the_run_was() -> void:
	var loop: RunLoop = _outside()
	var script: RunScript = RunScript.new()
	var saves: Array[Dictionary] = []
	var at: Array[int] = []
	var thinking: int = 0
	var done: int = 0
	while done < STEPS:
		if done % SAVE_EVERY == 0:
			saves.append(_through_disk(loop.record.to_dict()))
			at.append(done)
			if loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH:
				thinking += 1
		if not _step(loop, script, overturn):
			break
		done += 1
	assert_int(thinking).is_greater(0)
	assert_int(saves.size() - thinking).is_greater(0)
	var ended: String = log_of(loop)
	for index: int in saves.size():
		var resumed: RunLoop = _resume(saves[index])
		assert_object(resumed).override_failure_message("save %d" % index).is_not_null()
		var again: RunScript = RunScript.new()
		for _step_left: int in done - at[index]:
			assert_bool(_step(resumed, again, overturn)).is_true()
		assert_str(log_of(resumed)).override_failure_message("save %d" % index).is_equal(ended)
		assert_str(_text(resumed.state.to_dict())).is_equal(_text(loop.state.to_dict()))
		assert_str(_text(resumed.record.to_dict())).is_equal(_text(loop.record.to_dict()))


## A save written while a villager thinks ends before its play, and resumes standing
## still for the same seat with the same view.
func test_a_save_while_a_villager_thinks_resumes_standing_still_for_it() -> void:
	var loop: RunLoop = _outside()
	_to_a_villager(loop)
	var saved: Dictionary = _through_disk(loop.record.to_dict())
	var resumed: RunLoop = _resume(saved)
	assert_object(resumed).is_not_null()
	assert_int(resumed.awaiting()).is_equal(RunLoop.Awaiting.VILLAGER_SEARCH)
	var request: SearchRequest = resumed.search_request()
	assert_int(request.seat).is_equal(loop.search_request().seat)
	assert_str(str(request.view.own_counts)).is_equal(str(loop.search_request().view.own_counts))
	assert_str(_text(resumed.state.to_dict())).is_equal(_text(loop.state.to_dict()))
	# Resumed as before P5.0, with nothing answered from outside, the villager is decided
	# during the load.
	var inside: RunLoop = RunRecord.resume(saved, configs(), SetConfig.new())
	assert_object(inside).is_not_null()
	assert_int(inside.awaiting()).is_not_equal(RunLoop.Awaiting.VILLAGER_SEARCH)
