extends GdUnitTestSuite
## ADR 0025's stakes: the six as data, each number applied and every lower stake's kept,
## both audit paths reading the run's own copy, a loaded save rebuilding the same numbers,
## the shared Resources never changed, and a win at the highest stake unlocked opening the
## next, once.

const DIR: String = "user://test_stakes/"
const RUN_PATH: String = DIR + "run.json"
const PROFILE_PATH: String = DIR + "profile.json"
const START_TIME: int = 1_763_400_000
const LADDER: LadderParams = preload("res://data/run/default_ladder.tres")

var _saves: SaveService
var _profile: SaveService


func before_test() -> void:
	_saves = SaveService.for_run(RUN_PATH)
	_profile = Profile.service(PROFILE_PATH)
	_saves.delete()
	_profile.delete()


func after_test() -> void:
	_saves.delete()
	_profile.delete()


func _loop_at(stake: int, seed_value: int = 8100) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.identity.kind = RunIdentity.Kind.FULL
	state.identity.stake = stake
	return RunLoop.new(state, RunScript.bots(), SetConfig.new())


func test_the_six_stakes_are_the_adrs() -> void:
	var rows: Array[Array] = [
		["base", 0, 0, 0, 0, 0, 0],
		["second_harvest", 10, 0, 0, 0, 0, 0],
		["tight_books", 0, 1, 0, 0, 0, 0],
		["short_rations", 0, 0, 10, 0, 0, 0],
		["watchful_eyes", 0, 0, 0, 10, 1, 0],
		["third_year", 0, 0, 0, 0, 0, 1],
	]
	var stakes: Array[StakeDef] = RunStakes.STAKES.stakes
	assert_int(stakes.size()).is_equal(rows.size())
	assert_int(RunStakes.last()).is_equal(5)
	for index: int in rows.size():
		var stake: StakeDef = stakes[index]
		var got: Array = [
			stake.id,
			stake.target_percent,
			stake.store_slot_cut,
			stake.famine,
			stake.denunciation,
			stake.audit_faces,
			stake.ladder_severity,
		]
		assert_array(got).is_equal(rows[index])


func test_each_stake_keeps_every_lower_stakes_numbers() -> void:
	var expected: Array[Array] = [
		[0, 0, 0, 0, 0, 0],
		[10, 0, 0, 0, 0, 0],
		[10, 1, 0, 0, 0, 0],
		[10, 1, 10, 0, 0, 0],
		[10, 1, 10, 10, 1, 0],
		[10, 1, 10, 10, 1, 1],
	]
	for stake: int in expected.size():
		var sum: StakeDef = RunStakes.total(stake)
		var got: Array = [
			sum.target_percent,
			sum.store_slot_cut,
			sum.famine,
			sum.denunciation,
			sum.audit_faces,
			sum.ladder_severity,
		]
		assert_array(got).override_failure_message(str(stake)).is_equal(expected[stake])


func test_each_number_reaches_the_run() -> void:
	var base: RunLoop = _loop_at(0)
	var top: RunLoop = _loop_at(5)
	var sets: SetConfig = SetConfig.new()
	for year: int in [1, 8]:
		for type: int in 3:
			var plain: float = sets.target(year, type as RunState.SetType)
			var raised: float = top.sets().target(year, type as RunState.SetType)
			assert_float(raised).is_equal_approx(plain * 1.1, 0.001)
			assert_float(base.sets().target(year, type as RunState.SetType)).is_equal(plain)
	assert_int(top.pools.store.slots).is_equal(RunPools.STORE.slots - 1)
	assert_int(top.pools.market.slots).is_equal(RunPools.MARKET.slots)
	assert_int(top.pools.audit.base_faces).is_equal(RunPools.AUDIT.base_faces + 1)
	for type: int in LADDER.severity_budgets.size():
		var budget: int = top.pools.ladder.severity_budgets[type]
		assert_int(budget).is_equal(LADDER.severity_budgets[type] + 1)
	# The store shows one Cadre fewer.
	top.state.coupons = 100
	top.shop.open()
	assert_int(top.shop.stock().size()).is_equal(RunPools.STORE.slots - 1)
	# The loop's first target is the raised one.
	assert_float(top.target()).is_equal_approx(sets.target(1, RunState.SetType.SMALL) * 1.1, 0.001)


func test_the_starting_meters_add_up_with_the_household_and_the_label() -> void:
	var data: ProfileData = ProfileData.new()
	data.finished_runs = 3
	data.stake = 5
	data.lineage_kind = RunLineage.LABEL
	Profile.write(_profile, data)
	var request: RunRequest = RunRequest.new(RunRequest.FULL, 8200, START_TIME)
	request.household = "old_family"
	request.stake = 5
	var state: RunState = RunStarter.state(request, _profile)
	assert_int(state.famine).is_equal(10)
	assert_int(state.denunciation).is_equal(10 + 10 + 15)
	assert_int(state.resentment).is_equal(15)
	assert_bool(state.denunciation_armed).is_true()
	assert_bool(state.reeducation_due).is_false()


## The audit's chance the table shows and the faces the split rolls against both read the
## run's copy: one face more at Watchful Eyes, in the first round, which no debuff or
## informer touches.
func test_both_audit_paths_read_the_runs_copy() -> void:
	for stake: int in [0, 4]:
		var expected: int = RunPools.AUDIT.base_faces + (1 if stake == 4 else 0)
		var loop: RunLoop = _loop_at(stake, 8300)
		loop.start_set()
		var shown: int = roundi(loop.audit_chance() * RunPools.AUDIT.die_sides)
		assert_int(shown).override_failure_message(str(stake)).is_equal(expected)
		var script: RunScript = RunScript.new()
		var rolled: int = -1
		while rolled < 0 and loop.state.round_index == 0 and script.act(loop):
			for event: RunEvent in loop.events():
				if event.type == RunEvent.Type.AUDIT_ROLLED and rolled < 0:
					rolled = int(event.amount)
		assert_int(rolled).override_failure_message(str(stake)).is_equal(expected)


func test_the_faces_stay_under_the_cap() -> void:
	var params: AuditParams = RunStakes.audit(RunPools.AUDIT, RunStakes.total(5))
	params.base_faces = 99
	var state: RunState = RunState.new(8400)
	assert_int(NeedAudit.faces(state, params, ModifierStack.new())).is_equal(params.max_faces)


func test_a_loaded_save_rebuilds_the_same_numbers() -> void:
	var loop: RunLoop = _loop_at(5, 8500)
	loop.start_set()
	var saved: Dictionary = loop.record.to_dict()
	var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), SetConfig.new())
	assert_int(resumed.state.identity.stake).is_equal(5)
	assert_int(resumed.pools.store.slots).is_equal(loop.pools.store.slots)
	assert_int(resumed.pools.audit.base_faces).is_equal(loop.pools.audit.base_faces)
	assert_array(resumed.pools.ladder.severity_budgets).is_equal(loop.pools.ladder.severity_budgets)
	assert_float(resumed.target()).is_equal(loop.target())
	assert_array(resumed.state.debuff_ladder).is_equal(loop.state.debuff_ladder)


func test_a_stake_five_run_changes_no_shared_resource() -> void:
	var slots: int = RunPools.STORE.slots
	var envelopes: int = RunPools.STORE.envelopes.size()
	var faces: int = RunPools.AUDIT.base_faces
	var budgets: Array[int] = LADDER.severity_budgets.duplicate()
	var targets: Array[float] = SetConfig.DEFAULT_PARAMS.targets.duplicate()
	var data: ProfileData = ProfileData.new()
	data.finished_runs = 0
	data.stake = 5
	Profile.write(_profile, data)
	var request: RunRequest = RunRequest.new(RunRequest.FULL, 8600, START_TIME)
	request.stake = 5
	var controller: RunController = auto_free(RunController.new())
	assert_bool(controller.start(request, _saves, _profile)).is_true()
	var loop: RunLoop = controller.run_loop()
	assert_int(loop.pools.store.slots).is_equal(slots - 1)
	assert_int(loop.pools.store.envelopes.size()).is_equal(envelopes)
	assert_int(RunPools.STORE.slots).is_equal(slots)
	assert_int(RunPools.STORE.slots).is_equal(slots)
	assert_int(RunPools.AUDIT.base_faces).is_equal(faces)
	assert_int(RunPools.AUDIT.base_faces).is_equal(faces)
	assert_array(LADDER.severity_budgets).is_equal(budgets)
	assert_array(SetConfig.DEFAULT_PARAMS.targets).is_equal(targets)
	assert_array(RunStarter.FULL_RUN.sets.targets).is_equal(targets)
	var famine: int = RunStakes.STAKES.stakes[3].famine
	assert_int(famine).is_equal(10)


func test_a_stake_above_the_highest_unlocked_is_refused() -> void:
	var request: RunRequest = RunRequest.new(RunRequest.FULL, 8700, START_TIME)
	request.stake = 1
	assert_object(RunStarter.state(request, _profile)).is_null()
	request.stake = 0
	assert_object(RunStarter.state(request, _profile)).is_not_null()


## A win at the highest stake unlocked opens the next, once; a win below it, a death, or a
## second record of the same run opens nothing; the last stake stays the last.
func test_a_win_at_the_top_stake_unlocks_the_next_once() -> void:
	var data: ProfileData = ProfileData.new()
	data.stake = 2
	Profile.write(_profile, data)
	assert_int(_finish(2, false, "a")).is_equal(3)
	assert_int(_finish(3, false, "a")).is_equal(3)
	assert_int(_finish(1, false, "b")).is_equal(3)
	assert_int(_finish(3, true, "c")).is_equal(3)
	assert_int(_finish(3, false, "d")).is_equal(4)
	data = Profile.read(_profile)
	data.stake = 5
	Profile.write(_profile, data)
	assert_int(_finish(5, false, "e")).is_equal(5)


## Records a full run at stake, won or dead, under run ID suffix; returns the profile's
## highest stake after.
func _finish(stake: int, died: bool, run_id: String) -> int:
	var state: RunState = RunState.new(8800)
	state.identity.kind = RunIdentity.Kind.FULL
	state.identity.id = "stake-" + run_id
	state.identity.stake = stake
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.year_rounds = 4
	if died:
		state.famine = 100
	ProfileCommits.commit(_profile, state, true)
	return Profile.read(_profile).stake
