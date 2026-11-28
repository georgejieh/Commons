extends GdUnitTestSuite
## ADR 0025's corruption: each event read from a scripted Quota with its near misses, the
## order within a Quota, purchases in a famine, the events surviving a save, the growth
## formula and clamping, once-only commits through the four crash orderings, a demo run
## adding nothing, and The Commons resetting it.

const SEED: int = 9301
const PLAYER: int = 0
const TRUE_NEED: int = 10

static var _dir: String = TestFolder.of("test_corruption")
static var _run_path: String = _dir + "run.json"
static var _profile_path: String = _dir + "profile.json"

var _saves: SaveService
var _profile: SaveService


func before_test() -> void:
	_saves = SaveService.for_run(_run_path)
	_profile = Profile.service(_profile_path)
	_saves.delete()
	_profile.delete()


func after_test() -> void:
	_saves.delete()
	_profile.delete()
	ArtStages.latch_value(0.0)


# Scripted logs ------------------------------------------------------------------------


func _round(landlord: int) -> RunEvent:
	return RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, landlord))


func _play(seat: int, type: Pattern.Type) -> RunEvent:
	var pattern: Pattern = Pattern.new(type, 0, 1, 4, PackedByteArray(), 0)
	return RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, seat, [], pattern))


func _trick(seat: int) -> RunEvent:
	return RunEvent.wrap(RoundEvent.new(RoundEvent.Type.TRICK_WON, seat))


func _round_end() -> RunEvent:
	return RunEvent.new(RunEvent.Type.SEAT_KEPT, 1)


func _found(events: Array[RunEvent], state: RunState = RunState.new(SEED)) -> Array[String]:
	return CorruptionEvents.detect(events, state, TRUE_NEED)


func test_declaring_more_than_the_true_need_and_being_caught() -> void:
	var over: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.NEED_DECLARED, PLAYER, TRUE_NEED + 1),
		RunEvent.new(RunEvent.Type.AUDITED, PLAYER, 1),
	]
	assert_array(_found(over)).is_equal(
		[CorruptionEvents.DECLARED_OVER, CorruptionEvents.CAUGHT_LYING]
	)
	var honest: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.NEED_DECLARED, PLAYER, TRUE_NEED),
		RunEvent.new(RunEvent.Type.AUDITED, PLAYER, 0),
		RunEvent.new(RunEvent.Type.NEED_DECLARED, 1, TRUE_NEED + 5),
		RunEvent.new(RunEvent.Type.AUDITED, 1, 1),
	]
	assert_array(_found(honest)).is_empty()


func test_bombing_a_play_the_teammate_made() -> void:
	var teammate: Array[RunEvent] = [
		_round(1), _play(2, Pattern.Type.SINGLE), _play(PLAYER, Pattern.Type.BOMB)
	]
	assert_array(_found(teammate)).is_equal([CorruptionEvents.BOMBED_TEAMMATE])
	var rocket: Array[RunEvent] = [
		_round(2), _play(1, Pattern.Type.PAIR), _play(PLAYER, Pattern.Type.ROCKET)
	]
	assert_array(_found(rocket)).is_equal([CorruptionEvents.BOMBED_TEAMMATE])
	# Bombing the landlord, bombing as the landlord, a plain answer to the teammate, and a
	# bomb that leads after the trick was won are not.
	var misses: Array[RunEvent] = [
		_round(1),
		_play(1, Pattern.Type.SINGLE),
		_play(PLAYER, Pattern.Type.BOMB),
		_trick(PLAYER),
		_play(2, Pattern.Type.SINGLE),
		_play(PLAYER, Pattern.Type.SINGLE),
		_trick(2),
		_play(PLAYER, Pattern.Type.BOMB),
		_round(PLAYER),
		_play(1, Pattern.Type.SINGLE),
		_play(PLAYER, Pattern.Type.BOMB),
	]
	assert_array(_found(misses)).is_empty()


func test_using_a_hostile_campaign() -> void:
	var used: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.CAMPAIGN_USED, PLAYER, 0, 0.0, "anonymous_letter"),
		RunEvent.new(RunEvent.Type.CAMPAIGN_USED, PLAYER, 1, 0.0, "seizure_notice"),
		RunEvent.new(RunEvent.Type.CAMPAIGN_USED, PLAYER, 0, 0.0, "mutual_aid"),
	]
	assert_array(_found(used)).is_equal(
		[CorruptionEvents.HOSTILE_CAMPAIGN, CorruptionEvents.HOSTILE_CAMPAIGN]
	)


func test_landlord_in_every_round_of_two_or_more() -> void:
	var every: Array[RunEvent] = [_round(PLAYER), _round_end(), _round(PLAYER), _round_end()]
	assert_array(_found(every)).is_equal([CorruptionEvents.LANDLORD_EVERY_ROUND])
	var all_but_one: Array[RunEvent] = [
		_round(PLAYER), _round_end(), _round(PLAYER), _round_end(), _round(1), _round_end()
	]
	assert_array(_found(all_but_one)).is_empty()
	var single: Array[RunEvent] = [_round(PLAYER), _round_end()]
	assert_array(_found(single)).is_empty()


func test_a_family_starving_while_the_player_holds_eight_coupons() -> void:
	var starved: Array[RunEvent] = [RunEvent.new(RunEvent.Type.STARVED, 1, 0, 0.0, "li")]
	var state: RunState = RunState.new(SEED)
	state.coupons = 8
	assert_array(_found(starved, state)).is_equal([CorruptionEvents.STARVED_WHILE_RICH])
	state.coupons = 7
	assert_array(_found(starved, state)).is_empty()


func test_reeducation_of_a_family_the_player_bombed_or_denounced() -> void:
	var state: RunState = RunState.new(SEED)
	var summary: SetSummary = SetSummary.new(0)
	summary.add("li", SetSummary.Kind.BOMBED)
	summary.add("chen", SetSummary.Kind.DENOUNCED)
	summary.add("wang", SetSummary.Kind.FED, 3)
	state.summaries.append(summary)
	var reeducated: int = RosterEntry.Status.REEDUCATION
	var events: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.ROSTER_CHANGED, Seats.NONE, reeducated, 0.0, "li"),
		RunEvent.new(RunEvent.Type.ROSTER_CHANGED, Seats.NONE, reeducated, 0.0, "chen"),
		RunEvent.new(RunEvent.Type.ROSTER_CHANGED, Seats.NONE, reeducated, 0.0, "wang"),
		RunEvent.new(
			RunEvent.Type.ROSTER_CHANGED, Seats.NONE, RosterEntry.Status.ACTIVE, 0.0, "li"
		),
	]
	assert_array(_found(events, state)).is_equal(
		[CorruptionEvents.REEDUCATED_VICTIM, CorruptionEvents.REEDUCATED_VICTIM]
	)


## Purchases come first, then the log's events in order, with landlord in every round
## where the last round ended, before the Quota's end.
func test_a_quotas_events_keep_their_order() -> void:
	var state: RunState = RunState.new(SEED)
	state.famine_market_buys = 2
	state.coupons = 9
	var events: Array[RunEvent] = [
		_round(PLAYER),
		RunEvent.new(RunEvent.Type.CAMPAIGN_USED, PLAYER, 0, 0.0, "seizure_notice"),
		_round_end(),
		_round(PLAYER),
		_round_end(),
		RunEvent.new(RunEvent.Type.STARVED, 1, 0, 0.0, "li"),
	]
	(
		assert_array(_found(events, state))
		. is_equal(
			[
				CorruptionEvents.FAMINE_PURCHASE,
				CorruptionEvents.FAMINE_PURCHASE,
				CorruptionEvents.HOSTILE_CAMPAIGN,
				CorruptionEvents.LANDLORD_EVERY_ROUND,
				CorruptionEvents.STARVED_WHILE_RICH,
			]
		)
	)


# Purchases in a famine, through the real loop -----------------------------------------


func test_every_market_purchase_in_high_famine_counts_and_a_reroll_does_not() -> void:
	var loop: RunLoop = RunScript.at_the_shops(self, SEED, 1000)
	loop.state.famine = 80
	assert_int(loop.player_market_reroll()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.famine_market_buys).is_equal(0)
	assert_int(loop.player_upgrade(PlotUpgrades.CAPACITY)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.famine_market_buys).is_equal(1)
	assert_int(loop.player_market_buy(0, Ranks.SEVEN)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.famine_market_buys).is_equal(2)
	# The same purchase with Famine in its middle band counts nothing.
	var calm: RunLoop = RunScript.at_the_shops(self, SEED, 1000)
	calm.state.famine = 60
	assert_int(calm.player_market_buy(0, Ranks.SEVEN)).is_equal(RunLoop.Reason.OK)
	assert_int(calm.player_upgrade(PlotUpgrades.CAPACITY)).is_equal(RunLoop.Reason.OK)
	assert_int(calm.state.famine_market_buys).is_equal(0)
	# The count goes to the next Quota to end, first in its list, and starts again.
	loop.state.famine = 0
	assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	RunScript.new().play_until_set_over(loop)
	assert_array(loop.state.quota_corruption.slice(0, 2)).is_equal(
		[CorruptionEvents.FAMINE_PURCHASE, CorruptionEvents.FAMINE_PURCHASE]
	)
	assert_int(loop.state.famine_market_buys).is_equal(0)


## A Quota's events are the same whether the run was saved and loaded inside it or at
## its end.
func test_a_quotas_events_survive_a_save_inside_it_and_at_its_end() -> void:
	# The first seed whose Quota holds events, so the comparison means something.
	var seed_value: int = SEED
	var whole: RunLoop = null
	for candidate: int in range(SEED, SEED + 40):
		seed_value = candidate
		whole = RunLoop.new(RunState.new(candidate), RunScript.bots())
		whole.start_set()
		RunScript.new().play_until_set_over(whole)
		if not whole.state.quota_corruption.is_empty():
			break
	var expected: Array[String] = whole.state.quota_corruption
	assert_array(expected).is_not_empty()
	var cut: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots())
	cut.start_set()
	var script: RunScript = RunScript.new()
	for _turn: int in 6:
		script.act(cut)
	var resumed: RunLoop = RunRecord.resume(cut.record.to_dict(), RunScript.bots())
	RunScript.new().play_until_set_over(resumed)
	assert_array(resumed.state.quota_corruption).is_equal(expected)
	var at_end: RunLoop = RunRecord.resume(whole.record.to_dict(), RunScript.bots())
	assert_array(at_end.state.quota_corruption).is_equal(expected)


# The value ------------------------------------------------------------------------------


func test_growth_at_0_50_and_99_and_the_clamp() -> void:
	var params: CorruptionParams = CorruptionEvents.DEFAULT_PARAMS
	var one: Array[String] = [CorruptionEvents.DECLARED_OVER]
	assert_float(params.growth).is_equal(3.0)
	assert_float(CorruptionEvents.added(0.0, one)).is_equal_approx(1.0, 0.0001)
	assert_float(CorruptionEvents.added(50.0, one)).is_equal_approx(52.5, 0.0001)
	var light: CorruptionParams = params.duplicate()
	light.weights = {CorruptionEvents.DECLARED_OVER: 0.1}
	assert_float(CorruptionEvents.added(99.0, one, light)).is_equal_approx(99.397, 0.0001)
	var starved: Array[String] = [CorruptionEvents.STARVED_WHILE_RICH]
	assert_float(CorruptionEvents.added(99.0, starved)).is_equal(100.0)
	assert_float(CorruptionEvents.added(100.0, starved)).is_equal(100.0)
	# Each event uses the value as the one before it left it.
	var two: Array[String] = [CorruptionEvents.STARVED_WHILE_RICH, CorruptionEvents.DECLARED_OVER]
	assert_float(CorruptionEvents.added(0.0, two)).is_equal_approx(6.0 + 1.18, 0.0001)


func _quota_state(set_index: int, events: Array[String]) -> RunState:
	var state: RunState = RunState.new(SEED)
	state.identity.id = RunIdentity.make_id(SEED, 7)
	state.identity.kind = RunIdentity.Kind.FULL
	state.identity.generation = 1
	state.phase = RunFlow.State.SET_END
	state.set_index = set_index
	state.quota_corruption.assign(events)
	return state


func _save_run(state: RunState) -> void:
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	_saves.save(record.to_dict())


func _corruption() -> float:
	return Profile.read(_profile).corruption


func test_a_quotas_events_are_applied_once() -> void:
	var events: Array[String] = [CorruptionEvents.STARVED_WHILE_RICH]
	var state: RunState = _quota_state(0, events)
	ProfileCommits.commit(_profile, state, false)
	ProfileCommits.commit(_profile, state, false)
	assert_float(_corruption()).is_equal(6.0)
	state.set_index = 1
	ProfileCommits.commit(_profile, state, false)
	assert_float(_corruption()).is_equal_approx(6.0 + 6.0 * 1.18, 0.0001)


func test_profile_written_but_run_save_not_adds_nothing_more() -> void:
	var state: RunState = _quota_state(0, [CorruptionEvents.HOSTILE_CAMPAIGN])
	ProfileCommits.commit(_profile, state, false)
	_save_run(state)
	var controller: RunController = auto_free(RunController.new())
	assert_bool(controller.continue_saved(_saves, _profile)).is_true()
	assert_float(_corruption()).is_equal(2.0)


func test_run_save_written_but_profile_not_adds_once() -> void:
	_save_run(_quota_state(1, [CorruptionEvents.HOSTILE_CAMPAIGN]))
	for opened: int in 2:
		var controller: RunController = auto_free(RunController.new())
		assert_bool(controller.continue_saved(_saves, _profile)).is_true()
	assert_float(_corruption()).is_equal(2.0)


func test_a_backup_restore_adds_once() -> void:
	var state: RunState = _quota_state(0, [CorruptionEvents.HOSTILE_CAMPAIGN])
	Profile.write(_profile, ProfileData.new())
	Profile.write(_profile, ProfileData.new())
	var broken: FileAccess = FileAccess.open(_profile_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	assert_int(ProfileCommits.commit(_profile, state, false)).is_equal(OK)
	assert_int(ProfileCommits.commit(_profile, state, false)).is_equal(OK)
	assert_float(_corruption()).is_equal(2.0)


func test_a_demo_run_adds_nothing() -> void:
	var state: RunState = _quota_state(0, [CorruptionEvents.STARVED_WHILE_RICH])
	state.identity.kind = RunIdentity.Kind.DEMO
	assert_int(ProfileCommits.commit(_profile, state, false)).is_equal(OK)
	assert_float(_corruption()).is_equal(0.0)


## The Commons sets corruption to 0 after the run's last Quota, in the same write, and
## no later Quota of that run can add to it again.
func test_the_commons_resets_and_nothing_of_the_run_comes_back() -> void:
	var data: ProfileData = ProfileData.new()
	data.corruption = 64.0
	Profile.write(_profile, data)
	var state: RunState = _quota_state(5, [CorruptionEvents.STARVED_WHILE_RICH])
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.famine = 10
	state.denunciation = 10
	state.year_rounds = 4
	assert_str(Endings.outcome(state, RunDefaults.METERS)).is_equal(Endings.THE_COMMONS)
	assert_int(ProfileCommits.commit(_profile, state, true)).is_equal(OK)
	assert_float(_corruption()).is_equal(0.0)
	state.set_index = 6
	var recorded: String = FileAccess.get_file_as_string(_profile_path)
	assert_int(ProfileCommits.commit(_profile, state, true)).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(_profile_path)).is_equal(recorded)
	assert_float(_corruption()).is_equal(0.0)
	# Any other ending keeps what the run added.
	_profile.delete()
	Profile.write(_profile, data)
	var other: RunState = _quota_state(5, [CorruptionEvents.STARVED_WHILE_RICH])
	other.phase = RunFlow.State.RUN_END
	other.year = 8
	other.famine = 80
	other.year_rounds = 4
	ProfileCommits.commit(_profile, other, true)
	assert_float(_corruption()).is_greater(64.0)


## A run save from schema 11 has no Quota's events and no purchase counted.
func test_a_schema_11_save_migrates() -> void:
	var state: RunState = RunState.new(SEED)
	state.phase = RunFlow.State.SET_END
	var data: Dictionary = {"checkpoint": state.to_dict(), "commands": []}
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("quota_corruption")
	checkpoint.erase("famine_market_buys")
	assert_bool(RunRecordCheck.is_valid(data)).is_false()
	var migrated: Dictionary = RunRecordMigrations.migrate_from_12(
		RunRecordMigrations.migrate_from_11(data)
	)
	assert_bool(RunRecordCheck.is_valid(migrated)).is_true()
	var broken: Dictionary = migrated.duplicate(true)
	broken["checkpoint"]["quota_corruption"] = [3]
	assert_bool(RunRecordCheck.is_valid(broken)).is_false()
