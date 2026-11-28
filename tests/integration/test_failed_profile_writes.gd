extends GdUnitTestSuite
## A profile write that fails is reported as failed: filing an entry and committing a
## Quota both say they wrote nothing, so no caller tells the player it was recorded, and
## once the profile can be written again the same entry and Quota are taken. A finished
## run whose record cannot be written keeps its save, so Continue opens its ending again
## and leaving it records the run once the profile can be written.

const SEED: int = 5281

static var _dir: String = TestFolder.of("test_failed_profile_writes")
static var _path: String = _dir + "profile.json"

var _profile: SaveService


func before_test() -> void:
	_profile = Profile.service(_path)
	AppKit.fresh_saves(self)
	_unblock(_path)
	_unblock(Saves.profile_service().path())
	_profile.delete()


func after_test() -> void:
	_unblock(_path)
	_unblock(Saves.profile_service().path())
	_profile.delete()
	Saves.run_service().delete()
	Saves.profile_service().delete()


## A folder where the temporary file would go: no write can open it.
func _block(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path + SaveService.TEMP_SUFFIX)


func _unblock(path: String) -> void:
	DirAccess.remove_absolute(path + SaveService.TEMP_SUFFIX)


func _quota_state() -> RunState:
	var state: RunState = RunState.new(SEED)
	state.identity.id = RunIdentity.make_id(SEED, 5)
	state.identity.kind = RunIdentity.Kind.FULL
	state.phase = RunFlow.State.SET_END
	return state


## A full run at its end saved where the app keeps runs, and a profile that has seen the
## arrival, so the app opens as on any later launch, and the app made over them.
func _app_at_a_finished_run() -> App:
	var state: RunState = _quota_state()
	state.identity.generation = 1
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	Roster.start(state, RunDefaults.VILLAGE, [])
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	assert_int(Saves.run_service().save(record.to_dict())).is_equal(OK)
	assert_int(ProfileSeen.mark(Saves.profile_service(), ProfileSeen.TUTORIAL)).is_equal(OK)
	var app: App = AppKit.make(self)
	await await_idle_frame()
	return app


## The notice the title shows over its page, or null.
func _notice(app: App) -> SessionNotice:
	for child: Node in app.switcher.current().get_children():
		if child is SessionNotice:
			return child
	return null


func _saved_run() -> bool:
	return FileAccess.file_exists(Saves.run_service().path())


func _recorded() -> int:
	var count: int = 0
	for entry: HistoryEntry in Profile.read(Saves.profile_service()).history:
		if entry.run_id == _quota_state().identity.id:
			count += 1
	return count


func test_an_entry_that_could_not_be_written_is_not_reported_as_filed() -> void:
	_block(_path)
	assert_bool(ProfileFile.add(_profile, FileWatchKit.entry("a"))).is_false()
	assert_array(ProfileFile.entries(_profile)).is_empty()
	_unblock(_path)
	assert_bool(ProfileFile.add(_profile, FileWatchKit.entry("a"))).is_true()
	assert_int(ProfileFile.entries(_profile).size()).is_equal(1)


func test_a_quota_that_could_not_be_written_is_not_reported_as_taken() -> void:
	var state: RunState = _quota_state()
	_block(_path)
	assert_int(ProfileCommits.commit(_profile, state, false)).is_not_equal(OK)
	assert_bool(FileAccess.file_exists(_path)).is_false()
	_unblock(_path)
	assert_int(ProfileCommits.commit(_profile, state, false)).is_equal(OK)
	assert_str(Profile.read(_profile).committed_run).is_equal(state.identity.id)


## A full run started while the profile cannot be written still starts, with no heirloom:
## the profile keeps it for the next run that can take it, and that run takes it once. The
## profile's generation did not move for the first, so the heir is given the same one.
func test_a_run_started_on_a_failed_write_inherits_nothing() -> void:
	var data: ProfileData = ProfileData.new()
	data.lineage_kind = RunLineage.HEIRLOOM
	data.lineage_values = {RunLineage.RANK: Ranks.KING, RunLineage.SUIT: 1}
	assert_int(Profile.write(_profile, data)).is_equal(OK)
	_block(_path)
	var blocked: RunState = RunStarter.state(RunRequest.new(RunRequest.FULL, SEED, 1), _profile)
	assert_object(blocked).is_not_null()
	assert_array(blocked.inventory.plot).is_empty()
	assert_int(blocked.identity.generation).is_equal(1)
	assert_str(Profile.read(_profile).lineage_kind).is_equal(RunLineage.HEIRLOOM)
	assert_int(Profile.read(_profile).generation).is_equal(0)
	_unblock(_path)
	var heir: RunState = RunStarter.state(RunRequest.new(RunRequest.FULL, SEED, 2), _profile)
	assert_int(heir.inventory.plot.size()).is_equal(1)
	assert_int(heir.inventory.plot[0].base_rank()).is_equal(Ranks.KING)
	assert_int(heir.identity.generation).is_equal(1)
	var next: RunState = RunStarter.state(RunRequest.new(RunRequest.FULL, SEED, 3), _profile)
	assert_array(next.inventory.plot).is_empty()


## A Set's end the profile could not take: the controller says the profile is not whole,
## and once the profile can be written, asking again takes that Quota.
func test_a_set_end_the_profile_missed_is_taken_when_asked() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.live_search = false
	_block(_path)
	controller.start_run(SEED, RunScript.bots(), SetConfig.new(), null, 0, _profile)
	ControllerScript.new().play_to(self, controller, RunController.AWAIT_SET_OVER)
	assert_bool(controller.is_profile_whole()).is_false()
	assert_bool(FileAccess.file_exists(_path)).is_false()
	_unblock(_path)
	assert_bool(controller.is_profile_whole()).is_true()
	var data: ProfileData = Profile.read(_profile)
	assert_str(data.committed_run).is_equal(controller.run_loop().state.identity.id)
	assert_int(data.committed_quota).is_equal(0)


func test_a_finished_run_whose_record_cannot_be_written_keeps_its_save() -> void:
	var app: App = await _app_at_a_finished_run()
	_block(Saves.profile_service().path())
	app.resume_to_screen()
	await await_idle_frame()
	assert_str(app.switcher.current_id()).is_equal(ScreenId.ENDING)
	app.leave_run()
	await await_idle_frame()
	assert_bool(app.controller.has_run()).is_false()
	assert_bool(_saved_run()).override_failure_message("the run's save was cleared").is_true()
	assert_int(_recorded()).is_equal(0)
	assert_str(app.switcher.current_id()).is_equal(ScreenId.TITLE)
	var notice: SessionNotice = _notice(app)
	assert_object(notice).override_failure_message("the title said nothing").is_not_null()
	assert_bool(app.kept_run).is_false()
	assert_str(notice.buttons()[0].text).is_equal(tr("session.run_kept.ok"))
	# The profile can be written again: Continue opens the ending, and leaving records it.
	_unblock(Saves.profile_service().path())
	app.resume_to_screen()
	await await_idle_frame()
	assert_str(app.switcher.current_id()).is_equal(ScreenId.ENDING)
	app.leave_run()
	await await_idle_frame()
	assert_int(_recorded()).is_equal(1)
	assert_bool(_saved_run()).is_false()
	assert_object(_notice(app)).is_null()


func test_a_finished_run_recorded_at_once_clears_its_save() -> void:
	var app: App = await _app_at_a_finished_run()
	app.resume_to_screen()
	await await_idle_frame()
	assert_int(_recorded()).is_equal(1)
	app.leave_run()
	await await_idle_frame()
	assert_bool(_saved_run()).is_false()
	assert_int(_recorded()).is_equal(1)
	assert_str(app.switcher.current_id()).is_equal(ScreenId.TITLE)
	assert_object(_notice(app)).is_null()
