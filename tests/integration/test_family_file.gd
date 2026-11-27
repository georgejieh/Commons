extends GdUnitTestSuite
## ADR 0022's file in the profile: an entry is written once with its corruption,
## outlives the collective ending's reset and every new or abandoned run, raises each
## later full run's targets ten percent an entry up to double, and is strictly checked.
## A profile from before the file migrates with an empty one.

const BOOKS: BooksParams = preload("res://data/run/books.tres")

static var _dir: String = TestFolder.of("test_family_file")

var _kit: FileWatchKit = FileWatchKit.new(_dir)


func before_test() -> void:
	_kit.reset()


func after_test() -> void:
	_kit.reset()
	ArtStages.latch_value(0.0)


func _started(request: RunRequest) -> RunController:
	var controller: RunController = auto_free(_kit.controller(true))
	assert_bool(controller.start(request, _kit.saves, _kit.profile)).is_true()
	return controller


func _corruption() -> float:
	return Profile.read(_kit.profile).corruption


func test_an_entry_is_written_once_with_its_corruption() -> void:
	assert_bool(ProfileFile.add(_kit.profile, FileWatchKit.entry("a"))).is_true()
	assert_float(_corruption()).is_equal(BOOKS.entry_corruption)
	assert_bool(ProfileFile.add(_kit.profile, FileWatchKit.entry("a"))).is_false()
	assert_int(_kit.entries().size()).is_equal(1)
	assert_float(_corruption()).is_equal(BOOKS.entry_corruption)
	assert_bool(ProfileFile.add(_kit.profile, FileWatchKit.entry("b"))).is_true()
	assert_float(_corruption()).is_equal(ProfileFile.corrupted(BOOKS.entry_corruption))
	assert_float(ProfileFile.corrupted(100.0)).is_equal(100.0)


func test_the_file_outlives_the_collective_ending_and_every_new_run() -> void:
	ProfileFile.add(_kit.profile, FileWatchKit.entry("a"))
	var state: RunState = RunState.new(FileWatchKit.SEED)
	state.identity.id = RunIdentity.make_id(FileWatchKit.SEED, 7)
	state.identity.kind = RunIdentity.Kind.FULL
	state.identity.generation = 1
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.set_index = 5
	state.famine = 10
	state.denunciation = 10
	state.year_rounds = 4
	assert_str(Endings.outcome(state, RunDefaults.METERS)).is_equal(Endings.THE_COMMONS)
	ProfileCommits.commit(_kit.profile, state, true)
	assert_float(_corruption()).is_equal(0.0)
	assert_int(_kit.entries().size()).is_equal(1)
	var controller: RunController = _started(FileWatchKit.full())
	# Abandoned: the run save goes, the file stays.
	_kit.saves.delete()
	assert_int(_kit.entries().size()).is_equal(1)
	assert_int(controller.state_copy().identity.file_entries).is_equal(1)
	_started(FileWatchKit.full(FileWatchKit.SEED + 1))
	assert_int(_kit.entries().size()).is_equal(1)


func test_each_entry_raises_the_next_runs_targets_up_to_double() -> void:
	var plain: float = _started(FileWatchKit.full()).figures.target()
	for count: int in [1, 3, 12]:
		_kit.reset()
		for index: int in count:
			ProfileFile.add(_kit.profile, FileWatchKit.entry("k%d" % index))
		var controller: RunController = _started(FileWatchKit.full())
		var percent: int = mini(count * BOOKS.entry_percent, BOOKS.entry_cap_percent)
		var raise: float = 1.0 + percent / 100.0
		assert_int(controller.state_copy().identity.file_entries).is_equal(count)
		(
			assert_float(controller.figures.target())
			. override_failure_message(str(count))
			. is_equal_approx(plain * raise, 0.001)
		)
	# The demo is outside the file.
	_kit.saves.delete()
	var request: RunRequest = RunRequest.new(
		RunRequest.DEMO, FileWatchKit.SEED, FileWatchKit.START_TIME
	)
	assert_int(_started(request).state_copy().identity.file_entries).is_equal(0)


func test_a_schema_3_profile_migrates_with_an_empty_file() -> void:
	var old: Dictionary = ProfileData.new().to_dict()
	old.erase(Profile.FILE_KEY)
	old["wins"] = 2
	var text: String = JSON.stringify({"schema_version": 3, "data": old})
	FileWatchKit.write_text(_kit.profile.path(), text)
	var data: ProfileData = Profile.read(_kit.profile)
	assert_int(data.wins).is_equal(2)
	assert_array(data.file).is_empty()
	assert_str(_kit.profile.take_tampered()).is_empty()


func test_the_file_validates_strictly() -> void:
	var data: Dictionary = ProfileData.new().to_dict()
	data[Profile.FILE_KEY] = [FileWatchKit.entry("a").to_dict()]
	assert_bool(ProfileData.is_valid(data)).is_true()
	for bad: Variant in [
		{},
		[{"detector": "guess"}],
		[_with("detector", "rumour")],
		[_with("figures", {"grain": 3})],
		[_with("year", -1)],
		[_with("key", 4)],
	]:
		data[Profile.FILE_KEY] = bad
		assert_bool(ProfileData.is_valid(data)).override_failure_message(str(bad)).is_false()
	data.erase(Profile.FILE_KEY)
	assert_bool(ProfileData.is_valid(data)).is_false()


func _with(key: String, value: Variant) -> Dictionary:
	var entry: Dictionary = FileWatchKit.entry("a").to_dict()
	entry[key] = value
	return entry
