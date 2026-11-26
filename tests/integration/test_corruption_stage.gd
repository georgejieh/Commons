extends GdUnitTestSuite
## The corruption stage the art shows (ADR 0025): read from the profile, latched at a
## run's start and each round's start and never inside a round, ten points a stage, the
## debug flags only in a debug build, and the horror-intensity cap. Nothing in ui/ or the
## string table reads or shows the value.

const SEED: int = 9311

static var _profile_path: String = TestFolder.of("test_corruption_stage") + "profile.json"

var _profile: SaveService


func before_test() -> void:
	_profile = Profile.service(_profile_path)
	_profile.delete()
	ArtStages.stage_override = -1
	ArtStages.intensity_override = -1.0
	ArtStages.latch_value(0.0)


func after_test() -> void:
	_profile.delete()
	ArtStages.stage_override = -1
	ArtStages.intensity_override = -1.0
	ArtStages.latch_value(0.0)


func test_ten_points_a_stage_and_nine_at_most() -> void:
	var cases: Dictionary[float, int] = {0.0: 0, 9.99: 0, 10.0: 1, 99.9: 9, 100.0: 9}
	for value: float in cases:
		assert_int(ArtStages.stage_of(value)).override_failure_message(str(value)).is_equal(
			cases[value]
		)


## Only a debug build reads the flags, the stage flag before the value flag; a release
## build always shows the latched stage.
func test_the_debug_flags_and_a_release_build_ignoring_them() -> void:
	var stage_flag: PackedStringArray = ["--corruption-stage", "6"]
	var value_flag: PackedStringArray = ["--corruption", "45.5"]
	var both: PackedStringArray = ["--corruption", "95", "--corruption-stage", "2"]
	assert_int(ArtStages.stage_from(true, stage_flag, 1)).is_equal(6)
	assert_int(ArtStages.stage_from(true, value_flag, 1)).is_equal(4)
	assert_int(ArtStages.stage_from(true, both, 1)).is_equal(2)
	assert_int(ArtStages.stage_from(true, PackedStringArray(), 3)).is_equal(3)
	for args: PackedStringArray in [stage_flag, value_flag, both]:
		assert_int(ArtStages.stage_from(false, args, 1)).is_equal(1)


func test_the_stage_comes_from_the_profile_when_latched() -> void:
	var data: ProfileData = ProfileData.new()
	data.corruption = 37.5
	Profile.write(_profile, data)
	assert_int(ArtStages.stage()).is_equal(0)
	ArtStages.latch(_profile)
	assert_int(ArtStages.stage()).is_equal(3)


## A run latches at its start and at each round's start: a change to the profile in the
## middle of a round shows nothing until the next round begins.
func test_the_latch_holds_through_a_round() -> void:
	var data: ProfileData = ProfileData.new()
	data.corruption = 12.0
	Profile.write(_profile, data)
	var controller: RunController = auto_free(RunController.new())
	var dealt: Array[int] = [0]
	controller.start_run(SEED, RunScript.bots(), SetConfig.new(), null, 0, _profile)
	controller.event_emitted.connect(
		func(event: RunEvent) -> void:
			if event.type == RunEvent.Type.DEALT:
				dealt[0] += 1
	)
	assert_int(ArtStages.stage()).is_equal(1)
	data = Profile.read(_profile)
	data.corruption = 55.0
	Profile.write(_profile, data)
	var script: ControllerScript = ControllerScript.new()
	var guard: int = 0
	while dealt[0] == 0 and guard < 400 and controller.awaiting() != RunController.AWAIT_SET_OVER:
		guard += 1
		assert_int(ArtStages.stage()).is_equal(1)
		if not script.act(controller):
			break
	if dealt[0] > 0:
		assert_int(ArtStages.stage()).is_equal(5)


## At intensity i no art above stage round(9 * i) shows; the default shows all ten. The
## dread layers keep their own scaling and still read the whole stage.
func test_the_horror_intensity_caps_the_art() -> void:
	assert_float(float(SettingsStore.DEFAULTS.horror_intensity)).is_equal(1.0)
	assert_int(ArtStages.cap_for(1.0)).is_equal(9)
	assert_int(ArtStages.cap_for(0.5)).is_equal(5)
	assert_int(ArtStages.cap_for(0.0)).is_equal(0)
	ArtStages.stage_override = 9
	ArtStages.intensity_override = 1.0
	assert_int(ArtStages.art_stage()).is_equal(9)
	var title: Texture2D = ScreenKit.ART.title
	assert_object(ArtStages.resolve(title)).is_same(title)
	ArtStages.intensity_override = 0.4
	assert_int(ArtStages.art_stage()).is_equal(4)
	assert_str(ArtStages.resolve(title).resource_path).is_equal(
		"res://art/backdrops/stages/title_s4.png"
	)
	assert_str(ArtStages.resolve(title, 9).resource_path).is_equal(
		"res://art/backdrops/stages/title_s4.png"
	)
	ArtStages.intensity_override = 0.0
	assert_str(ScreenKit.cadre_art("peek").resource_path).is_equal(
		"res://art/cadres/stages/cadre_peek_s0.png"
	)
	assert_float(BowlGrime.wear()).is_equal(BowlGrime.BASE_WEAR)
	assert_int(ArtStages.stage()).is_equal(9)


## Nothing in ui/ reads the profile's corruption value, and the string table never names
## it; only the horror layer's own stage function in the dread layers carries the word.
func test_nothing_outside_the_horror_layer_shows_the_value() -> void:
	var allowed: Array[String] = ["res://ui/table2d/dread_layers.gd"]
	var word: RegEx = RegEx.create_from_string("\\bcorruption\\b|latch_value|stage_of\\(")
	var found: PackedStringArray = []
	for path: String in _scripts("res://ui"):
		if allowed.has(path):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			var code: String = lines[index].get_slice("#", 0)
			if word.search(code) != null:
				found.append("%s:%d" % [path, index + 1])
	var table: String = FileAccess.get_file_as_string("res://data/strings/strings.csv")
	if table.to_lower().contains("corrupt"):
		found.append("strings.csv")
	assert_array(found).is_empty()


func _scripts(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() in ["gd", "tscn"]:
			found.append(folder.path_join(file_name))
	for child: String in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(child)))
	return found
