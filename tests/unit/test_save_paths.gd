extends GdUnitTestSuite
## SavePaths: the game keeps the player's files where they are; anything run by a script
## (a tool, the playtest, the test run) keeps its defaults in the sandbox.


func test_the_game_keeps_the_players_paths() -> void:
	for path: String in [SaveService.RUN_PATH, SaveService.PROFILE_PATH, SettingsStore.PATH]:
		assert_str(SavePaths.of(path, true)).is_equal(path)


func test_a_tool_or_test_keeps_its_defaults_in_the_sandbox() -> void:
	assert_str(SavePaths.of(SaveService.RUN_PATH, false)).is_equal("user://tools/run.json")
	assert_str(SavePaths.of(SaveService.PROFILE_PATH, false)).is_equal("user://tools/profile.json")
	assert_str(SavePaths.of(SettingsStore.PATH, false)).is_equal("user://tools/settings.cfg")
	var run: SaveService = SaveService.for_run(SavePaths.of(SaveService.RUN_PATH, false))
	assert_str(run.backup_path()).is_equal("user://tools/run.json.bak")
	assert_array(run.companions).is_equal(["user://tools/private_ledger.txt"])


func test_the_test_run_is_not_a_launch_of_the_game() -> void:
	assert_bool(SavePaths.normal_launch(get_tree())).is_false()
	assert_bool(SavePaths.normal_launch(null)).is_false()
