extends GdUnitTestSuite
## ADR 0025: a full run starts through the same request the app sends, plays its eight
## Years by script with a save and Continue part way, and leaves exactly one record in
## the profile; the demo never moves it. A save and the profile can each be lost or
## written alone, and the profile still takes everything exactly once.

const SEED: int = 2514
const START_TIME: int = 1_763_200_000
## A full run is played to its end; it stops early only if it runs past this many Sets.
const MAX_SETS: int = 30

static var _dir: String = TestFolder.of("test_full_run")
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


func _request(kind: int, seed_value: int = SEED) -> RunRequest:
	return RunRequest.new(kind, seed_value, START_TIME)


## Plays by script until the run waits on its end, or until a new Year past stop_year
## begins (0 never stops). Returns the Sets it finished.
func _play(controller: RunController, stop_year: int = 0) -> int:
	var script: ControllerScript = ControllerScript.new()
	var sets: int = 0
	while sets < MAX_SETS:
		while _act(controller, script):
			pass
		match controller.awaiting():
			RunController.AWAIT_SET_OVER:
				sets += 1
				controller.finish_set()
			RunController.AWAIT_STORE:
				for slot: int in controller.store.store_stock().size():
					if controller.store.can_buy(slot):
						controller.buy(slot)
						break
				controller.leave_store()
			RunController.AWAIT_REEDUCATION:
				controller.leave_reeducation()
			_:
				return sets
		if stop_year > 0 and controller.state_copy().year > stop_year:
			return sets
	return sets


## The script's turn, but an honest claim on the Commons, so the run is not ended early by
## the Denunciation the script's fixed claim draws.
func _act(controller: RunController, script: ControllerScript) -> bool:
	if controller.awaiting() == RunController.AWAIT_NEED:
		return controller.declare_need(controller.figures.base_need()) == RunController.OK
	return script.act(controller)


func _loop(controller: RunController) -> RunLoop:
	return controller.run_loop()


func test_a_full_run_plays_through_continue_and_is_recorded_once() -> void:
	var began: int = Time.get_ticks_msec()
	var controller: RunController = auto_free(RunController.new())
	controller.start(_request(RunRequest.FULL), _saves, _profile)
	var opening: RunState = controller.state_copy()
	assert_bool(controller.seats.has_village()).is_true()
	assert_bool(opening.identity.is_full()).is_true()
	assert_str(opening.identity.id).is_equal(RunIdentity.make_id(SEED, START_TIME))
	assert_int(opening.identity.generation).is_equal(1)
	assert_int(opening.roster.size()).is_equal(8)
	assert_int(_loop(controller).sets().years()).is_equal(8)
	assert_int(Profile.read(_profile).generation).is_equal(1)
	var first: int = _play(controller, 2)
	assert_int(first).is_greater_equal(1)
	# Leave mid-run and Continue: the run comes back as the full run it was.
	var resumed: RunController = auto_free(RunController.new())
	assert_bool(resumed.continue_saved(_saves, _profile)).is_true()
	assert_bool(resumed.state_copy().identity.is_full()).is_true()
	assert_int(_loop(resumed).sets().years()).is_equal(8)
	assert_int(resumed.awaiting()).is_equal(controller.awaiting())
	controller.queue_free()
	var rest: int = _play(resumed)
	assert_int(resumed.awaiting()).is_equal(RunController.AWAIT_RUN_OVER)
	var final: RunState = resumed.state_copy()
	var data: ProfileData = Profile.read(_profile)
	assert_int(data.history.size()).is_equal(1)
	assert_int(data.finished_runs).is_equal(1)
	var outcome: String = Endings.outcome(final, RunDefaults.METERS)
	assert_int(data.wins).is_equal(0 if Endings.is_death(outcome) else 1)
	var entry: HistoryEntry = data.history[0]
	assert_str(entry.run_id).is_equal(opening.identity.id)
	assert_int(entry.generation).is_equal(1)
	assert_str(entry.outcome).is_equal(outcome)
	assert_int(entry.year).is_equal(final.year)
	assert_int(entry.dead.size()).is_equal(_dead(final))
	# The same ending page opened twice takes nothing twice.
	for again: int in 2:
		var reopened: RunController = auto_free(RunController.new())
		assert_bool(reopened.continue_saved(_saves, _profile)).is_true()
		assert_int(reopened.awaiting()).is_equal(RunController.AWAIT_RUN_OVER)
	assert_int(Profile.read(_profile).history.size()).is_equal(1)
	assert_int(Profile.read(_profile).finished_runs).is_equal(1)
	var seconds: float = (Time.get_ticks_msec() - began) / 1000.0
	print("Full run: %d Sets, Year %d, %s, %.1f s" % [first + rest, final.year, outcome, seconds])


func _dead(state: RunState) -> int:
	var count: int = 0
	for entry: RosterEntry in state.roster:
		if entry.status == RosterEntry.Status.DEAD:
			count += 1
	return count


func test_the_demo_never_moves_the_profiles_runs() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.start(_request(RunRequest.DEMO), _saves, _profile)
	assert_bool(controller.seats.has_village()).is_false()
	assert_int(_loop(controller).sets().years()).is_equal(1)
	_play(controller)
	assert_int(controller.awaiting()).is_equal(RunController.AWAIT_RUN_OVER)
	var data: ProfileData = Profile.read(_profile)
	assert_int(data.generation).is_equal(0)
	assert_int(data.finished_runs).is_equal(0)
	assert_int(data.wins).is_equal(0)
	assert_array(data.history).is_empty()
	# The demo still leaves the village's memory, as it always has.
	assert_str(data.committed_run).is_equal(RunIdentity.make_id(SEED, START_TIME))


func test_a_run_that_does_not_write_the_profile_leaves_it_alone() -> void:
	var request: RunRequest = _request(RunRequest.FULL)
	request.writes_profile = false
	var controller: RunController = auto_free(RunController.new())
	controller.start(request, _saves, _profile)
	assert_bool(FileAccess.file_exists(_profile_path)).is_false()
	assert_int(controller.state_copy().identity.generation).is_equal(0)


## Continue rebuilds the kind of run that was saved: a demo save as the demo's one Year,
## a full save as eight.
func test_continue_rebuilds_each_kind() -> void:
	for kind: int in [RunRequest.DEMO, RunRequest.FULL]:
		_saves.delete()
		var controller: RunController = auto_free(RunController.new())
		controller.start(_request(kind), _saves, _profile)
		var resumed: RunController = auto_free(RunController.new())
		assert_bool(resumed.continue_saved(_saves, _profile)).is_true()
		var years: int = 8 if kind == RunRequest.FULL else 1
		assert_int(_loop(resumed).sets().years()).is_equal(years)
		assert_int(resumed.state_copy().identity.kind).is_equal(kind)
		assert_bool(resumed.seats.has_village()).is_equal(kind == RunRequest.FULL)
		assert_array(resumed.table.player_cards()).is_equal(controller.table.player_cards())


func test_a_starting_full_run_is_the_next_generation() -> void:
	for expected: int in [1, 2, 3]:
		var controller: RunController = auto_free(RunController.new())
		controller.start(_request(RunRequest.FULL, SEED + expected), _saves, _profile)
		assert_int(controller.state_copy().identity.generation).is_equal(expected)
	assert_int(Profile.read(_profile).generation).is_equal(3)
	assert_array(Profile.read(_profile).history).is_empty()
