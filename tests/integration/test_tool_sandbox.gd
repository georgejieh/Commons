extends GdUnitTestSuite
## Under the test runner, as under every tool, an app made with no path of its own reads
## and writes only in the sandbox: starting a run, playing a Set and finishing it leaves
## the player's run save, backup, ledger, profile and settings exactly as they were.
## Every folder a tool names for its own saves (WalkProfile) is in the sandbox too, whatever
## name --profile gives it.

const SEED: int = 5113
const PLAYERS: Array[String] = [
	"user://run.json",
	"user://run.json.bak",
	"user://private_ledger.txt",
	"user://profile.json",
	"user://profile.json.bak",
	"user://settings.cfg",
]

var _app: DemoApp


func before_test() -> void:
	Saves.use_default_paths()
	Saves.run_service().delete()
	Saves.profile_service().delete()


func after_test() -> void:
	Saves.run_service().delete()
	Saves.profile_service().delete()


## Each file's hash, or empty where there is none.
func _hashes() -> Array[String]:
	var found: Array[String] = []
	for path: String in PLAYERS:
		found.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")
	return found


func test_an_app_with_no_paths_of_its_own_stays_in_the_sandbox() -> void:
	var before: Array[String] = _hashes()
	assert_str(Saves.run_service().path()).is_equal(SavePaths.SANDBOX.path_join("run.json"))
	assert_str(Saves.profile_service().path()).is_equal(SavePaths.SANDBOX.path_join("profile.json"))
	_app = auto_free((load("res://ui/main.tscn") as PackedScene).instantiate())
	add_child(_app)
	_app.controller.live_search = false
	assert_bool(_app.new_run(SEED)).is_true()
	var driver: ControllerScript = ControllerScript.new()
	var guard: int = 0
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER and guard < 2000:
		guard += 1
		driver.act(_app.controller)
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_SET_OVER)
	assert_int(_app.controller.finish_set()).is_equal(RunController.OK)
	Settings.save()
	assert_bool(FileAccess.file_exists(Saves.run_service().path())).is_true()
	_app.leave_run()
	assert_array(_hashes()).is_equal(before)


func test_a_tools_own_folders_are_in_the_sandbox() -> void:
	for args: PackedStringArray in [
		PackedStringArray(),
		PackedStringArray(["--profile", "second"]),
		PackedStringArray(["--profile", "../../escape"]),
	]:
		var options: ToolOptions = ToolOptions.new("", args)
		for base: String in ["playtest", "playtest_tutorial", "soak", "perf_budget"]:
			var folder: String = WalkProfile.folder(base, options)
			assert_str(folder).starts_with(SavePaths.SANDBOX + "/")
			assert_str(folder.trim_prefix(SavePaths.SANDBOX + "/").trim_suffix("/")).not_contains(
				"/"
			)
