extends GdUnitTestSuite
## Qin at the table when Famine is high (ADR 0043): in a whole Set above the band, every
## claim Qin makes above the fair half is counted for the dossier, and none is below it;
## the dossier says so once there is one to report and not before; a save from before the
## count loads with none; and the bots play the Sets with no refused action.

const SEED: int = 4311
const SAVE_PATH: String = "user://test_hungry_claims/run.json"
const STEPS: int = 1500

var _app: DemoApp = null


func after_test() -> void:
	if _app != null:
		Saves.run_service().delete()
		Saves.profile_service().delete()
		_app = null


## A run whose only families are Qin and Wang, so both are seated, at the Famine given.
func _loop(seed_value: int, famine: int) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	Roster.start(state, RunLoop.DEFAULT_VILLAGE, [])
	state.roster = state.roster.filter(
		func(found: RosterEntry) -> bool: return found.family_id in ["qin", "wang"]
	)
	state.famine = famine
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	return loop


## Plays the Set and returns how many of Qin's claims were above the fair half.
func _play(loop: RunLoop) -> int:
	var script: RunScript = RunScript.new()
	for _step: int in STEPS:
		if not script.act(loop):
			break
	var over: Array[RunLoop.Awaiting] = [RunLoop.Awaiting.SET_OVER, RunLoop.Awaiting.RUN_OVER]
	assert_bool(over.has(loop.awaiting())).is_true()
	assert_int(loop.refused_bot_actions).is_zero()
	var qin: int = loop.state.table.find("qin")
	var above: int = 0
	for event: RunEvent in loop.events():
		var claim: bool = event.type == RunEvent.Type.NEED_DECLARED and event.seat == qin
		if claim and event.value > RunLoop.DEFAULT_PARAMS.base_need:
			above += 1
	return above


func test_above_the_band_every_larger_claim_of_qins_is_counted() -> void:
	var counted: int = 0
	for offset: int in 3:
		var loop: RunLoop = _loop(SEED + offset, RunLoop.DEFAULT_METERS.famine.high + 1)
		var above: int = _play(loop)
		var seen: int = loop.state.observations.count("qin", Observations.Kind.SHIFTED_CLAIMS)
		assert_int(seen).is_equal(above)
		counted += seen
	assert_int(counted).is_greater(0)


func test_below_the_band_no_claim_is_counted() -> void:
	for offset: int in 3:
		var loop: RunLoop = _loop(SEED + offset, RunLoop.DEFAULT_METERS.famine.high - 10)
		_play(loop)
		var seen: int = loop.state.observations.count("qin", Observations.Kind.SHIFTED_CLAIMS)
		assert_int(seen).is_zero()


func test_a_save_from_before_the_count_loads_with_none() -> void:
	var loop: RunLoop = _loop(SEED, 0)
	_play(loop)
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.OK)
	var data: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	var rows: Dictionary = checkpoint["observations"]
	assert_bool(rows.is_empty()).is_false()
	for family: String in rows:
		var row: Array = rows[family]
		row.resize(Observations.KIND_COUNT - 1)
	var migrated: Dictionary = RunRecord.migrate_from_19(data)
	assert_bool(RunRecord.is_valid(migrated)).is_true()
	for family: String in rows:
		var row: Array = rows[family]
		assert_int(row.size()).is_equal(Observations.KIND_COUNT)
		assert_int(int(row[Observations.Kind.SHIFTED_CLAIMS])).is_zero()
	var resumed: RunLoop = RunRecord.resume(migrated, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_int(SaveService.SCHEMA_VERSION).is_equal(20)


func test_the_dossier_tells_the_shift_once_it_was_seen() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED, true)
	var loop: RunLoop = _app.controller.get("_loop")
	loop.state.table[1] = "qin"
	loop.state.observations.add("qin", Observations.Kind.PASSES)
	var at: int = RunLoop.DEFAULT_METERS.famine.high
	var line: String = tr("dossier.shift.famine").format({"count": 2, "at": at})
	var dossier: DossierScreen = _app.show_screen("dossier", true)
	assert_array(Array(dossier.entries(1))).not_contains([line])
	loop.state.observations.add("qin", Observations.Kind.SHIFTED_CLAIMS, 2)
	dossier = _app.show_screen("dossier", true)
	assert_array(Array(dossier.entries(1))).contains([line])
	assert_str(line).is_equal("Claimed more than a fair half with Famine at 75 or more: 2")
