extends GdUnitTestSuite
## ADR 0032's three Campaigns played through the run loop: each one's effect at the table
## and, where its rule allows, in a shop; where each stops; and a fall replayed from a
## save to the same state.

const SEEDS: int = 80


func _loop(seed_value: int, held: Array[String]) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.inventory.consumables.assign(held)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


func _drive(loop: RunLoop, moment: Callable, limit: int = 300) -> bool:
	var script: RunScript = RunScript.new()
	for _step: int in limit:
		if moment.call(loop):
			return true
		if not script.act(loop):
			return false
	return false


func _find(held: Array[String], moment: Callable) -> RunLoop:
	for seed_value: int in range(1, 1 + SEEDS):
		var loop: RunLoop = _loop(seed_value, held)
		if _drive(loop, moment):
			return loop
	return null


func _my_turn(loop: RunLoop) -> bool:
	return loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY


func _events_of(loop: RunLoop, type: RunEvent.Type) -> Array[RunEvent]:
	return loop.events().filter(func(event: RunEvent) -> bool: return event.type == type)


func _to_shop(loop: RunLoop) -> void:
	var script: RunScript = RunScript.new()
	for _step: int in 500:
		if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
			break
		assert_bool(script.act(loop)).is_true()
	loop.state.reeducation_due = false
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)


func test_self_criticism_lowers_resentment_and_raises_denunciation_at_the_table() -> void:
	var loop: RunLoop = _find(["self_criticism"], _my_turn)
	loop.state.resentment = 10
	var denunciation: int = loop.state.denunciation
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.resentment).is_equal(4)
	assert_int(loop.state.denunciation).is_equal(denunciation + 2)
	var resented: Array[RunEvent] = _events_of(loop, RunEvent.Type.RESENTMENT)
	assert_int(resented[-1].value).is_equal(-6)
	assert_str(resented[-1].text).is_equal(Resentment.CAMPAIGN)
	var meter: Array[RunEvent] = _events_of(loop, RunEvent.Type.METER_CHANGED)
	assert_str(meter[-1].text).is_equal(RunMeters.DENUNCIATION)
	assert_int(meter[-1].value).is_equal(2)


## Resentment stops at 0, and Denunciation still rises.
func test_self_criticism_in_a_shop_stops_resentment_at_zero() -> void:
	var loop: RunLoop = _find(["self_criticism"], _my_turn)
	_to_shop(loop)
	loop.state.resentment = 4
	var denunciation: int = loop.state.denunciation
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.resentment).is_equal(0)
	assert_int(loop.state.denunciation).is_equal(denunciation + 2)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SHOP)


func test_a_self_criticism_that_denounces_the_player_to_death_ends_the_run() -> void:
	var loop: RunLoop = _find(["self_criticism"], _my_turn)
	_to_shop(loop)
	loop.state.denunciation = RunLoop.DEFAULT_METERS.denunciation.death - 1
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)


func test_relief_grain_lowers_famine_at_the_table_and_in_the_shop_and_stops_at_zero() -> void:
	var loop: RunLoop = _find(["relief_grain", "relief_grain"], _my_turn)
	loop.state.famine = 20
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.famine).is_equal(14)
	var meter: Array[RunEvent] = _events_of(loop, RunEvent.Type.METER_CHANGED)
	assert_int(meter[-1].value).is_equal(-6)
	assert_str(meter[-1].text).is_equal(RunMeters.FAMINE)
	_to_shop(loop)
	loop.state.famine = 2
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.famine).is_equal(0)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SHOP)


## Famine at 52 is rationed; Relief Grain takes it to 46, still inside the margin, and the
## next one to 40, which lifts rationing.
func test_relief_grain_below_the_band_lifts_rationing() -> void:
	var loop: RunLoop = _find(["relief_grain", "relief_grain"], _my_turn)
	loop.state.famine = 52
	loop.state.rationed = true
	loop.state.famine_armed = false
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_bool(loop.state.rationed).is_true()
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.famine).is_equal(40)
	assert_bool(loop.state.rationed).is_false()
	assert_bool(loop.state.famine_armed).is_true()


## The fall replays from the record to the same state: the use is a saved command.
func test_a_fall_replays_from_a_save_to_the_same_state() -> void:
	var loop: RunLoop = _find(["relief_grain", "self_criticism"], _my_turn)
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	var saved: Dictionary = loop.record.to_dict()
	var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_dict(resumed.state.to_dict()).is_equal(loop.state.to_dict())


func test_relief_grain_and_self_criticism_are_not_used_outside_their_moments() -> void:
	var loop: RunLoop = _loop(3, ["relief_grain", "self_criticism"])
	var bidding: Callable = func(at: RunLoop) -> bool:
		return at.awaiting() == RunLoop.Awaiting.PLAYER_BID
	assert_bool(_drive(loop, bidding)).is_true()
	var none: Array[int] = []
	for slot: int in 2:
		assert_int(loop.campaign_reason(slot, none)).is_equal(CampaignEffect.Reason.NOT_NOW)


## Progress rises by 15% of the target, the norm one step for later Quotas while this
## Quota's target stays, and Resentment 2.
func test_false_report_raises_progress_and_the_norm_for_later_quotas() -> void:
	var loop: RunLoop = _find(["false_report"], _my_turn)
	var target: float = loop.target()
	var progress: float = loop.state.set_progress
	var resentment: int = loop.state.resentment
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_float(loop.state.set_progress).is_equal_approx(progress + target * 0.15, 0.0001)
	assert_int(loop.state.norm_steps).is_equal(1)
	assert_int(loop.state.reported_steps).is_equal(1)
	assert_float(loop.target()).is_equal_approx(target, 0.0001)
	assert_int(loop.state.resentment).is_equal(resentment + 2)
	# Saved and resumed, the target in force is still this Quota's.
	var resumed: RunLoop = RunRecord.resume(
		loop.record.to_dict(), RunScript.bots(), SetConfig.new()
	)
	assert_float(resumed.target()).is_equal_approx(target, 0.0001)
	# The next Quota starts under the raised norm.
	RunScript.new().play_until_set_over(loop)
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER:
		assert_bool(RunScript.new().act(loop)).is_true()
	var steps: int = loop.state.norm_steps
	assert_int(steps).is_greater_equal(1)
	assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.reported_steps).is_equal(0)
	var base: float = loop.sets().target(loop.state.year, loop.state.set_type)
	assert_float(loop.target()).is_equal_approx(loop.sets().normed(base, steps), 0.001)


func test_false_report_is_used_on_the_players_turn_only() -> void:
	var loop: RunLoop = _find(["false_report"], _my_turn)
	_to_shop(loop)
	var none: Array[int] = []
	assert_int(loop.campaign_reason(0, none)).is_equal(CampaignEffect.Reason.NOT_NOW)
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.ILLEGAL)


## A version 17 save holds no reported steps; migrated, it has none, and a damaged count
## is refused.
func test_a_schema_17_save_migrates_to_no_reported_steps() -> void:
	var loop: RunLoop = _loop(5, [])
	var data: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("reported_steps")
	assert_bool(RunRecord.is_valid(data)).is_false()
	var migrated: Dictionary = RunRecord.migrate_from_17(data)
	assert_bool(RunRecord.is_valid(migrated)).is_true()
	assert_int(int(migrated["checkpoint"]["reported_steps"])).is_equal(0)
	migrated["checkpoint"]["reported_steps"] = -1
	assert_bool(RunRecord.is_valid(migrated)).is_false()
	migrated["checkpoint"]["reported_steps"] = 1
	migrated["checkpoint"]["norm_steps"] = 0
	assert_bool(RunRecord.is_valid(migrated)).is_false()
