class_name AppKit
extends RefCounted
## The app as a suite opens it. Its run save and profile live in the suite's own
## TestFolder, never in the player's files or another run's, and the app is freed with the
## test that made it.

const SCENE: String = "res://ui/main.tscn"


## Points the run save, and the profile beside it, at the suite's folder and removes both,
## so the suite starts with no run saved and no profile.
static func fresh_saves(suite: GdUnitTestSuite) -> void:
	Saves.use_run_path(TestFolder.of(suite_name(suite)) + "run.json")
	Saves.run_service().delete()
	Saves.profile_service().delete()


## A new app in the suite's tree, saving where the last fresh_saves pointed. No run is
## started, so a suite can set the app up first.
static func make(suite: GdUnitTestSuite) -> App:
	var scene: PackedScene = load(SCENE)
	var app: App = suite.auto_free(scene.instantiate())
	suite.add_child(app)
	return app


## The suite's file name, which names its folder.
static func suite_name(suite: GdUnitTestSuite) -> String:
	var script: Script = suite.get_script()
	return script.resource_path.get_file().get_basename()
