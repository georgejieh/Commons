extends GdUnitTestSuite
## ADR 0025: the profile's schema 2, its migration from 1, strict validation, the history
## cap, and the once-only commits through every crash ordering between the run save and
## the profile. Also the run save's schema 11 and its migration from 10.

const SEED: int = 9101

static var _dir: String = TestFolder.of("test_profile_saves")
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


func _write_raw(path: String, version: int, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": version, "data": data}))
	file.close()


func _memory() -> VillageMemory:
	var memory: VillageMemory = VillageMemory.new()
	var summary: SetSummary = SetSummary.new(0)
	summary.add("li", SetSummary.Kind.FED, 3)
	summary.add("chen", SetSummary.Kind.BOMBED, 1)
	memory.record(summary)
	return memory


func test_a_new_profile_holds_every_field_empty() -> void:
	var data: ProfileData = Profile.read(_profile)
	assert_int(data.generation).is_equal(0)
	assert_int(data.finished_runs).is_equal(0)
	assert_int(data.wins).is_equal(0)
	assert_array(data.history).is_empty()
	assert_str(data.lineage_kind).is_empty()
	assert_int(data.stake).is_equal(0)
	assert_float(data.corruption).is_equal(0.0)
	assert_array(data.seen).is_empty()
	assert_str(data.surname).is_empty()
	var saved: Dictionary = data.to_dict()
	for key: String in ProfileData.KEYS:
		assert_bool(saved.has(key)).override_failure_message(key).is_true()
	assert_bool(ProfileData.is_valid(saved)).is_true()


func test_schema_1_migrates_and_keeps_the_memory() -> void:
	var memory: VillageMemory = _memory()
	_write_raw(_profile_path, 1, {Profile.MEMORY_KEY: memory.to_dict()})
	var loaded: SaveLoad = _profile.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var data: ProfileData = Profile.read(_profile)
	assert_dict(data.memory.to_dict()).is_equal(memory.to_dict())
	assert_int(data.generation).is_equal(0)
	assert_array(data.history).is_empty()


func test_validation_is_strict() -> void:
	var whole: Dictionary = ProfileData.new().to_dict()
	assert_bool(ProfileData.is_valid(whole)).is_true()
	for key: String in ProfileData.KEYS:
		var missing: Dictionary = whole.duplicate(true)
		missing.erase(key)
		assert_bool(ProfileData.is_valid(missing)).override_failure_message(key).is_false()
	var cases: Dictionary[String, Variant] = {
		"generation": -1,
		"wins": 1.5,
		"history": [{"run_id": "x"}],
		"lineage": {"kind": 3, "values": {}},
		"corruption": 12.0,
		"seen": [1],
		"surname": 4,
		"committed": {"run_id": "", "quota": -2},
		"memory": {"li": [1, 2, 3, 4]},
	}
	for key: String in cases:
		var broken: Dictionary = whole.duplicate(true)
		broken[key] = cases[key]
		assert_bool(ProfileData.is_valid(broken)).override_failure_message(key).is_false()


func test_corruption_is_clamped_and_saved_exactly() -> void:
	var data: ProfileData = ProfileData.new()
	data.corruption = 140.0
	assert_float(data.corruption).is_equal(ProfileData.CORRUPTION_MAX)
	data.corruption = -3.0
	assert_float(data.corruption).is_equal(0.0)
	data.corruption = 37.123456789
	Profile.write(_profile, data)
	assert_float(Profile.read(_profile).corruption).is_equal(37.123456789)


func test_history_keeps_the_newest_fifty() -> void:
	var data: ProfileData = ProfileData.new()
	for index: int in ProfileData.HISTORY_CAP + 5:
		var entry: HistoryEntry = HistoryEntry.new()
		entry.run_id = "run-%d" % index
		data.add_history(entry)
	assert_int(data.history.size()).is_equal(ProfileData.HISTORY_CAP)
	assert_str(data.history[0].run_id).is_equal("run-5")
	Profile.write(_profile, data)
	assert_int(Profile.read(_profile).history.size()).is_equal(ProfileData.HISTORY_CAP)
	var over: Dictionary = data.to_dict()
	var entries: Array = over["history"]
	entries.append(HistoryEntry.new().to_dict())
	assert_bool(ProfileData.is_valid(over)).is_false()


## A full run's state at a boundary: a Set's end, or the run's end.
func _full_state(phase: RunFlow.State, set_index: int = 0) -> RunState:
	var state: RunState = RunState.new(SEED)
	state.identity.id = RunIdentity.make_id(SEED, 5)
	state.identity.kind = RunIdentity.Kind.FULL
	state.identity.generation = 1
	Roster.start(state, RunDefaults.VILLAGE, [])
	state.roster[2].status = RosterEntry.Status.DEAD
	state.phase = phase
	state.set_index = set_index
	state.memory = _memory()
	state.year_rounds = 4
	return state


func _save_run(state: RunState) -> void:
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	_saves.save(record.to_dict())


func test_a_quota_is_taken_once_per_run() -> void:
	var state: RunState = _full_state(RunFlow.State.SET_END)
	assert_bool(ProfileCommits.commit(_profile, state, false)).is_true()
	assert_bool(ProfileCommits.commit(_profile, state, false)).is_false()
	state.set_index = 1
	assert_bool(ProfileCommits.commit(_profile, state, false)).is_true()
	state.set_index = 0
	assert_bool(ProfileCommits.commit(_profile, state, false)).is_false()
	var other: RunState = _full_state(RunFlow.State.SET_END)
	other.identity.id = "another"
	assert_bool(ProfileCommits.commit(_profile, other, false)).is_true()
	assert_int(Profile.read(_profile).committed_quota).is_equal(0)


## The profile was written at the Quota's end but the run save was not: the run replays
## to that end again, and the profile takes nothing twice.
func test_profile_written_but_run_save_not() -> void:
	var state: RunState = _full_state(RunFlow.State.SET_END)
	ProfileCommits.commit(_profile, state, false)
	var was: String = FileAccess.get_file_as_string(_profile_path)
	var controller: RunController = auto_free(RunController.new())
	_save_run(state)
	assert_bool(controller.continue_saved(_saves, _profile)).is_true()
	assert_str(FileAccess.get_file_as_string(_profile_path)).is_equal(was)


## The run save reached the Quota's end but the profile never took it: Continue offers
## it again, and the profile takes it once.
func test_run_save_written_but_profile_not() -> void:
	var state: RunState = _full_state(RunFlow.State.SET_END, 1)
	_save_run(state)
	var controller: RunController = auto_free(RunController.new())
	assert_bool(controller.continue_saved(_saves, _profile)).is_true()
	var data: ProfileData = Profile.read(_profile)
	assert_str(data.committed_run).is_equal(state.identity.id)
	assert_int(data.committed_quota).is_equal(1)
	assert_dict(data.memory.to_dict()).is_equal(state.memory.to_dict())
	assert_array(data.history).is_empty()


## A finished run saved before the profile took its record: Continue records it, once,
## however often the ending page is opened.
func test_a_finished_run_is_recorded_once() -> void:
	var state: RunState = _full_state(RunFlow.State.RUN_END)
	state.year = 8
	_save_run(state)
	for opened: int in 3:
		var controller: RunController = auto_free(RunController.new())
		assert_bool(controller.continue_saved(_saves, _profile)).is_true()
		assert_int(controller.awaiting()).is_equal(RunController.AWAIT_RUN_OVER)
	var data: ProfileData = Profile.read(_profile)
	assert_int(data.history.size()).is_equal(1)
	assert_int(data.finished_runs).is_equal(1)
	assert_int(data.wins).is_equal(1)
	var entry: HistoryEntry = data.history[0]
	assert_str(entry.run_id).is_equal(state.identity.id)
	assert_int(entry.generation).is_equal(1)
	assert_int(entry.year).is_equal(8)
	assert_str(entry.class_id).is_equal(HistoryEntry.PEASANT)
	assert_array(entry.dead).is_equal([RunDefaults.VILLAGE.families[2].name_key])


## The profile's file is damaged and its backup is older. A backup that already holds the
## record takes it no second time; one from before the record takes it once.
func test_a_backup_restore_of_the_profile() -> void:
	var state: RunState = _full_state(RunFlow.State.RUN_END)
	state.year = 8
	ProfileCommits.commit(_profile, state, true)
	# A later write moves the recorded profile to the backup; then the main file breaks.
	Profile.write(_profile, Profile.read(_profile))
	FileAccess.open(_profile_path, FileAccess.WRITE).store_string("{broken")
	assert_int(_profile.load_save().status).is_equal(SaveLoad.Status.RESTORED_FROM_BACKUP)
	assert_bool(ProfileCommits.commit(_profile, state, true)).is_false()
	assert_int(Profile.read(_profile).history.size()).is_equal(1)
	# A backup from before the run ended: the record is taken once, then never again.
	_profile.delete()
	Profile.write(_profile, ProfileData.new())
	Profile.write(_profile, ProfileData.new())
	FileAccess.open(_profile_path, FileAccess.WRITE).store_string("{broken")
	assert_bool(ProfileCommits.commit(_profile, state, true)).is_true()
	assert_bool(ProfileCommits.commit(_profile, state, true)).is_false()
	assert_int(Profile.read(_profile).history.size()).is_equal(1)


func test_a_demo_run_is_never_recorded() -> void:
	var state: RunState = _full_state(RunFlow.State.RUN_END)
	state.identity.kind = RunIdentity.Kind.DEMO
	assert_bool(ProfileCommits.commit(_profile, state, true)).is_true()
	var data: ProfileData = Profile.read(_profile)
	assert_array(data.history).is_empty()
	assert_int(data.finished_runs).is_equal(0)
	assert_dict(data.memory.to_dict()).is_equal(state.memory.to_dict())


## Deleting the run save leaves the profile as it was.
func test_deleting_the_run_save_leaves_the_profile_untouched() -> void:
	var state: RunState = _full_state(RunFlow.State.RUN_END)
	ProfileCommits.commit(_profile, state, true)
	_save_run(state)
	var was: String = FileAccess.get_file_as_string(_profile_path)
	_saves.delete()
	assert_bool(FileAccess.file_exists(_run_path)).is_false()
	assert_str(FileAccess.get_file_as_string(_profile_path)).is_equal(was)
	assert_int(Profile.read(_profile).history.size()).is_equal(1)


## A schema 10 save is a demo run with an ID made from its seed, and Continue picks it
## up as the demo.
func test_a_schema_10_save_resumes_as_a_demo_run() -> void:
	var state: RunState = RunState.new(SEED)
	state.phase = RunFlow.State.SET_END
	var data: Dictionary = {"checkpoint": state.to_dict(), "commands": []}
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("identity")
	_write_raw(_run_path, 10, data)
	var loaded: SaveLoad = _saves.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var migrated: Dictionary = loaded.data["checkpoint"]
	var identity: RunIdentity = RunIdentity.from_dict(migrated["identity"])
	assert_int(identity.kind).is_equal(RunIdentity.Kind.DEMO)
	assert_str(identity.id).is_equal(RunIdentity.make_id(SEED, 0))
	assert_int(RunStarter.saved_kind(loaded.data)).is_equal(RunRequest.DEMO)
	var controller: RunController = auto_free(RunController.new())
	assert_bool(controller.continue_saved(_saves)).is_true()
	assert_bool(controller.seats.has_village()).is_false()


func test_a_run_save_with_a_broken_identity_falls_back() -> void:
	var record: RunRecord = RunRecord.new()
	record.mark(RunState.new(SEED))
	var data: Dictionary = record.to_dict()
	assert_bool(RunRecordCheck.is_valid(data)).is_true()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint["identity"] = {"id": 4, "kind": 9}
	assert_bool(RunRecordCheck.is_valid(data)).is_false()
