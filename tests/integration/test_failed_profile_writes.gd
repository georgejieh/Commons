extends GdUnitTestSuite
## A profile write that fails is reported as failed: filing an entry and committing a
## Quota both say they wrote nothing, so no caller tells the player it was recorded, and
## once the profile can be written again the same entry and Quota are taken.

const DIR: String = "user://test_failed_profile_writes/"
const PATH: String = DIR + "profile.json"
const SEED: int = 5281

var _profile: SaveService


func before_test() -> void:
	_profile = Profile.service(PATH)
	_unblock()
	_profile.delete()


func after_test() -> void:
	_unblock()
	_profile.delete()


## A folder where the temporary file would go: no write can open it.
func _block() -> void:
	DirAccess.make_dir_recursive_absolute(PATH + SaveService.TEMP_SUFFIX)


func _unblock() -> void:
	DirAccess.remove_absolute(PATH + SaveService.TEMP_SUFFIX)


func _quota_state() -> RunState:
	var state: RunState = RunState.new(SEED)
	state.identity.id = RunIdentity.make_id(SEED, 5)
	state.identity.kind = RunIdentity.Kind.FULL
	state.phase = RunFlow.State.SET_END
	return state


func test_an_entry_that_could_not_be_written_is_not_reported_as_filed() -> void:
	_block()
	assert_bool(ProfileFile.add(_profile, FileWatchKit.entry("a"))).is_false()
	assert_array(ProfileFile.entries(_profile)).is_empty()
	_unblock()
	assert_bool(ProfileFile.add(_profile, FileWatchKit.entry("a"))).is_true()
	assert_int(ProfileFile.entries(_profile).size()).is_equal(1)


func test_a_quota_that_could_not_be_written_is_not_reported_as_taken() -> void:
	var state: RunState = _quota_state()
	_block()
	assert_bool(ProfileCommits.commit(_profile, state, false)).is_false()
	_unblock()
	assert_bool(ProfileCommits.commit(_profile, state, false)).is_true()
	assert_str(Profile.read(_profile).committed_run).is_equal(state.identity.id)
