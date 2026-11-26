extends GdUnitTestSuite
## Saves under wild ranks (ADR 0029): a play whose cards read more than one way is saved
## with its reading and replays as it was played, and a save from before wild ranks
## migrates and replays exactly.

const SEED: int = 2941

static var _dir: String = TestFolder.of("test_wild_saves")

var _service: SaveService


func before_test() -> void:
	_service = SaveService.for_run(_dir + "run.json")
	_service.delete()


func after_test() -> void:
	_service.delete()


func _log_lines(loop: RunLoop) -> PackedStringArray:
	var lines: PackedStringArray = []
	for event: RunEvent in loop.events():
		lines.append(event.describe())
	return lines


func _through_json(loop: RunLoop) -> Dictionary:
	_service.save(loop.record.to_dict())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	return loaded.data


## Plays the player's first ambiguous play of round 0 as its weakest reading. Returns
## false when round 0 offered none.
func _play_ambiguous(loop: RunLoop) -> bool:
	var script: RunScript = RunScript.new()
	while loop.state.round_index == 0:
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY:
			var round_state: RoundState = loop.round_state()
			for move: Pattern in round_state.legal_moves():
				var ids: Array[int] = round_state.action_for(move).card_ids
				var read: PlayReading = round_state.read_play(RunLoop.PLAYER, ids)
				if read.readings.size() > 1:
					var weakest: Pattern = read.readings[-1]
					assert_int(loop.player_play(ids, weakest)).is_equal(RunLoop.Reason.OK)
					return true
		if not script.act(loop):
			return false
	return false


func test_an_ambiguous_play_saves_its_reading_and_replays_it() -> void:
	var found: bool = false
	for rank: int in Ranks.TWO + 1:
		var state: RunState = RunState.new(SEED)
		state.wild_ranks.append(rank)
		var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
		loop.start_set()
		if not _play_ambiguous(loop):
			continue
		found = true
		var last: Dictionary = loop.record.commands[-1]
		assert_bool(last.has(ReadingCodec.KEY)).is_true()
		var played: Pattern = ReadingCodec.decode(last[ReadingCodec.KEY])
		var resumed: RunLoop = RunRecord.resume(_through_json(loop), RunScript.bots())
		assert_object(resumed).is_not_null()
		assert_array(Array(_log_lines(resumed))).is_equal(Array(_log_lines(loop)))
		var last_play: RoundEvent = null
		for event: RunEvent in resumed.events():
			var inner: RoundEvent = event.round_event
			if inner != null and inner.type == RoundEvent.Type.PLAYED and inner.seat == 0:
				var ids: Array = inner.card_ids.duplicate()
				var command_ids: Array = last["cards"]
				var saved_ids: Array = command_ids.duplicate()
				ids.sort()
				saved_ids.sort()
				if ids == saved_ids:
					last_play = inner
		assert_object(last_play).is_not_null()
		assert_int(last_play.pattern.type).is_equal(played.type)
		assert_int(last_play.pattern.main_rank).is_equal(played.main_rank)
		break
	assert_bool(found).is_true()


func test_a_play_that_reads_one_way_saves_no_reading() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.state.round_index == 0 and script.act(loop):
		pass
	var plays: int = 0
	for command: Dictionary in loop.record.commands:
		if command["type"] == "play":
			plays += 1
			assert_bool(command.has(ReadingCodec.KEY)).is_false()
	assert_int(plays).is_greater(0)


func test_a_save_from_before_wild_ranks_migrates_and_replays_exactly() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots(), SetConfig.new())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.state.round_index == 0 and script.act(loop):
		pass
	var old: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = old["checkpoint"]
	checkpoint.erase("wild_ranks")
	assert_bool(RunRecordCheck.is_valid(old)).is_false()
	var migrated: Dictionary = RunRecordMigrations.migrate_from_15(old)
	assert_bool(RunRecordCheck.is_valid(migrated)).is_true()
	var resumed: RunLoop = RunRecord.resume(migrated, RunScript.bots())
	assert_array(Array(_log_lines(resumed))).is_equal(Array(_log_lines(loop)))
	assert_int(SaveService.SCHEMA_VERSION).is_greater_equal(16)


func test_saved_wild_ranks_and_readings_are_checked() -> void:
	assert_bool(ReadingCodec.wild_ranks_valid([])).is_true()
	assert_bool(ReadingCodec.wild_ranks_valid([4.0, 9.0])).is_true()
	assert_bool(ReadingCodec.wild_ranks_valid([4, 4])).is_false()
	assert_bool(ReadingCodec.wild_ranks_valid([13])).is_false()
	assert_bool(ReadingCodec.wild_ranks_valid([1, 2, 3])).is_false()
	var sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)
	var trio: Pattern = Readings.of(RankText.counts("9997"), sevens, Ranks.identity_map())[1]
	var saved: Variant = JSON.parse_string(JSON.stringify(ReadingCodec.encode(trio)))
	assert_bool(ReadingCodec.is_valid(saved)).is_true()
	assert_bool(ReadingCodec.decode(saved).same_reading(trio)).is_true()
	assert_bool(ReadingCodec.is_valid({"type": 99})).is_false()
	var kept: Dictionary = saved
	var long: Dictionary = kept.duplicate()
	long["chain"] = 14.0
	assert_bool(ReadingCodec.is_valid(long)).is_false()
	var crowded: Dictionary = kept.duplicate()
	crowded["kickers"] = [3.0, 4.0, 5.0, 6.0]
	assert_bool(ReadingCodec.is_valid(crowded)).is_false()
	var decision: Dictionary = {"seat": 1, "cards": [3, 4, 5, 6], ReadingCodec.KEY: saved}
	assert_bool(SearchedDecisions.is_valid([decision], true)).is_true()
	decision[ReadingCodec.KEY] = {"type": 2}
	assert_bool(SearchedDecisions.is_valid([decision], true)).is_false()
